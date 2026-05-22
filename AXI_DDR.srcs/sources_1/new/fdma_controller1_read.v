`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: fdma_controller1_read
// Create Date: 2021/06/29 17:25:39
//
//------------------------------------------------------------------------------
// 0. 读这个模块，先记住一句话
//
// fdma_controller1_read 做的事只有一件：
//   按以太网发送侧的节拍，向下游 FDMA(MSXBO_FDMA_1) 发起“从 DDR 读 1 包”的请求，
//   把环形缓存里写进去的 ADC 数据搬出来。
//
// 它是 fdma_controller1_write 的“读对偶”：
//   写侧把 ADC 数据按 128 beat (=1024 字节) 一包持续写进 DDR (环形缓冲，2GB 回卷)
//   读侧追在写侧后面读，水位差 = cache_wr_size - cache_rd_size = DDR 里还没读的字节数
//
// 为什么要这样做？
//   - DDR3 / AXI burst 必须成包读，不能一拍一拍随读 → 中间必须按 128 beat 发 burst
//   - 读不能追上甚至超过写，否则就读到“还没写好的旧位置” → 必须看水位
//   - 读不能闲等，必须等以太网发送 FIFO 真的需要新数据时才去读 → 由 read_req 触发
//
// 先把单位记牢：
//   1 beat       = 64 bit
//   1 包/burst   = pkg_rd_size = 128 beat = 1024 字节  (与写侧 PKG_SIZE 对得上)
//   触发水位     = 2048 字节 = 2 包 (写侧至少领先 2 包才允许读，留 1 包安全余量)
//   DDR 读区上限 = 0x80000000 (2 GB)，到这里地址回卷到 0
//
// 它在 DL2 数据链路里的位置：
//   fdma_controller1_write → DDR3 (写) → fdma_controller1_read (本模块)
//        → [pkg1_rd_areq/addr/size + FDMA 返回 pkg1_rd_en/data/last]
//        → LAN_TX_FREAME → UDP payload → 以太网
//
//   注意：本模块只“发读请求和推进地址”，
//         FDMA 真正返回的 pkg_rd_data 不在本文件处理，
//         它在 adcdata_config 里直接连到 LAN_TX_FREAME 的输入。
//------------------------------------------------------------------------------

module fdma_controller1_read(
    // ---- 时钟 / 复位 ----
    input               ui_clk,
    input               rstn,                   // 低有效

    // ---- 水位输入：写侧累计字节数 (来自 fdma_controller1_write) ----
    input   [63:0]      cache_wr_size,          // 写侧到现在为止已经写进 DDR 多少字节
    input               read_req,               // 来自 LAN_TX_FREAME 的“我想要数据”请求

    // ---- 与下游 FDMA 的读合同 (从 FDMA 看是“它给我们的返回”) ----
    input       [63:0]  pkg_rd_data,            // FDMA 返回的当拍 64-bit 数据 (本模块不用，仅穿透)
    input               pkg_rd_en,              // FDMA 表示“这一拍 data 有效” (本模块也不用)
    input               pkg_rd_last,            // 一包 128 拍中的最后一拍，状态机用它判结束
    output reg  [31:0]  pkg_rd_addr,            // 本包要读的 DDR 起始字节地址
    output reg          pkg_rd_areq,            // 单拍脉冲：本模块申请发起一次读 burst
    output      [31:0]  pkg_rd_size             // 本包 beat 数 = 128
    );

//------------------------------------------------------------------------------
// 1. read_req 同步打拍 (read_req_r0 → read_req_r1)
//
//   read_req 来自 LAN_TX_FREAME 模块，虽然两边都在 ui_clk 域，
//   但打两拍可以避免组合逻辑毛刺被状态机错误地当成请求，并形成稳定的判决面。
//   下面 rd_req 判决直接用 read_req_r1。
//------------------------------------------------------------------------------
reg read_req_r0;
reg read_req_r1;
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        read_req_r0 <= 0;
        read_req_r1 <= 0;
    end
    else begin
        read_req_r0 <= read_req;
        read_req_r1 <= read_req_r0;
    end
end

//------------------------------------------------------------------------------
// 2. 读包大小常量：1 包 = 128 beat (与写侧 PKG_SIZE 完全一致)
//------------------------------------------------------------------------------
assign     pkg_rd_size = 32'd128;

//------------------------------------------------------------------------------
// 3. 5 状态机：IDLE → S0 → S1 → S2 → S3 → IDLE
//
//   IDLE: 等 rd_req=1 (水位足够 + 以太网要数据)
//   S0  : 拉一拍 pkg_rd_areq=1 给 FDMA，告诉它“可以来送这一包了”
//   S1  : FDMA 用 pkg_rd_en 一拍拍把 128 拍数据送上来 (数据直接给 LAN_TX_FREAME，
//         本模块只等 pkg_rd_last)
//   S2  : 一包结束的那一拍，更新读地址 / 累计字节数
//   S3  : 多停一拍再回 IDLE，给写侧累计量 / FDMA 状态留一拍稳定时间
//         (写侧只有 4 状态没有 S3，读侧多这一拍纯粹是给水位差留缓冲)
//------------------------------------------------------------------------------
reg [2:0] current_state;
reg [2:0] next_state;
parameter IDLE = 3'b000;
parameter S0 = 3'b001;
parameter S1 = 3'b010;
parameter S2 = 3'b011;
parameter S3 = 3'b100;
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

//------------------------------------------------------------------------------
// 4. 水位 + 读触发：rd_req
//
//   cache_rd_size  : 读侧已经读出 DDR 多少字节 (本模块自己累计)
//   cache_size     : 写减读 = DDR 里“还没被读出去”的字节量
//   rd_req         : 真正能读的条件：cache_size ≥ 2048 字节 (≥ 2 包) 且以太网在请求
//
//   为什么门限是 2048 而不是 1024？
//     如果门限只有 1 包，读完这一包水位就可能瞬间 0，下一刻才被写侧补上，
//     会造成读侧反复在“能读↔不能读”之间抖动；
//     留 2 包水位让读侧可以连续读一段时间，写侧也有空间继续写。
//------------------------------------------------------------------------------
reg [63:0]  cache_rd_size;
wire[63:0]  cache_size;
reg         rd_req;
assign       cache_size = cache_wr_size - cache_rd_size;

always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn)
        rd_req <= 1'b0;
    else if(cache_size >= 2048 && read_req_r1 == 1)
        rd_req <= 1'b1;
    else
        rd_req <= 1'b0;
end

//------------------------------------------------------------------------------
// 5. 状态转移：什么时候跳到下一个状态
//------------------------------------------------------------------------------
always@(current_state or rd_req or pkg_rd_last)
begin
    case(current_state)
    IDLE:   next_state = (rd_req)? S0:IDLE;
    S0:     next_state =  S1;
    S1:     next_state = (pkg_rd_last==1)?S2:S1;
    S2:     next_state = S3;
    S3:     next_state = IDLE;
    default:next_state = IDLE;
    endcase
end

//------------------------------------------------------------------------------
// 6. 读请求脉冲 + 读地址递增
//
//   pkg_rd_areq   : 只在 S0 那一拍是 1，其他全是 0 —— 给 FDMA 的请求脉冲
//   pkg_rd_addr   : 本包要读的 DDR 起始字节地址，搬完一包 (S2) +1024
//                   到 0x80000000 (2GB) 回卷到 0，与写侧地址空间完全相同
//   cache_rd_size : 累计读字节数，跟着 +1024，喂给 cache_size 判定读追到哪儿了
//
//   换一种说法：
//     和写侧一样，读侧也是“第 0 包→0x0000, 第 1 包→0x0400, …”按 1024 字节步进。
//     只要读地址和写地址在同一个 2GB 环形空间里、读追在写后面，就永远读到有效数据。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        pkg_rd_areq     <= 1'b0;
        pkg_rd_addr     <= 32'd0;
        cache_rd_size   <= 64'd0;
    end
    else
        case(current_state)
        IDLE:   begin   pkg_rd_areq         <= 1'b0; end
        S0:     begin   pkg_rd_areq         <= 1'b1; end
        S1:     begin   pkg_rd_areq         <= 1'b0; end
        S2:     begin   pkg_rd_areq         <= 1'b0;
                        cache_rd_size       <= cache_rd_size + 1024;
                        if(pkg_rd_addr + 1024 >= 32'h80000000)
                            pkg_rd_addr     <= 32'd0;
                        else
                            pkg_rd_addr     <= pkg_rd_addr + 1024;
                end
        S3:     begin   pkg_rd_areq         <= 1'b0; end
        default:begin
                    pkg_rd_areq         <= 1'b0;
                    pkg_rd_addr         <= 32'd0;
                    cache_rd_size       <= 64'd0;
                end
        endcase
end

//------------------------------------------------------------------------------
// 7. 调试探针：在线观察 cache_size 水位
//
//   ila_6 只采 cache_size 一路，作用是开发/上板时看“读追得上写吗”、
//   “水位有没有掉到 0 (读追上写) / 顶到很高 (以太网堵了)”。不影响功能。
//------------------------------------------------------------------------------
 ila_6 tx_data_ila(
    .clk        (ui_clk),
    .probe0     (cache_size)
    );
endmodule
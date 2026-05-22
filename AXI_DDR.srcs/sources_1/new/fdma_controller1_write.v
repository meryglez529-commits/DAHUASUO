
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: fdma_controller1_write
// Create Date: 2021/06/28 16:53:15
//
//------------------------------------------------------------------------------
// 0. 读这个模块，先记住一句话
//
// fdma_controller1_write 做的事只有一件：
//   把上游 adcdata_get 流过来的 64-bit ADC 数据，攒够一整包后，
//   向下游 FDMA(MSXBO_FDMA_1) 发起一次写 DDR 的 burst 请求。
//
// 为什么要这样做？
//   ADC 数据是连续“随时来”的流（adc_data_mix_wr_en 高就来一拍 64-bit），
//   而 DDR3 / AXI burst 要求“成包整段”地写，不能一拍一拍随写。
//   所以中间要一个写侧 FIFO 做蓄水池：流进来零散，流出去成包。
//
// 先把单位记牢：
//   1 beat   = 1 个 64-bit 数据字（pkg_wr_data 一拍）
//   1 包/burst = PKG_SIZE = 128 beat = 128 * 8 = 1024 字节
//   1 包写入 DDR 的地址跨度 = 1024 (pkg_wr_addr 每次 +1024)
//   DDR 写区上限 = 0x80000000 (2 GB)，写到这里地址回卷到 0
//
// 它在 DL2 数据链路里的位置：
//   adcdata_get  →  [adc_data_mix_wr_en / _wr_fifo[63:0]]
//        →  fdma_controller1_write (本模块: FIFO + 状态机)
//        →  [pkg_wr_areq / pkg_wr_en / pkg_wr_last / pkg_wr_addr / pkg_wr_data]
//        →  MSXBO_FDMA_1 → AXI Interconnect → MIG7Series → DDR3
//
//   全模块时钟是 MIG 给出来的 ui_clk，没有跨时钟域。
//------------------------------------------------------------------------------

module fdma_controller1_write(
    // ---- 时钟 / 复位 (ui_clk 是 MIG 用户时钟，整模块单时钟域) ----
    input   wire            ui_clk,
    input   wire            rstn,                   // 低有效复位

    // ---- 上游写入合同：来自 adcdata_get 的 64-bit ADC 数据流 ----
    input   wire            adc_data_mix_wr_en,     // = 1 这一拍 _wr_fifo 有效，写进 FIFO
    input   wire[63:0]      adc_data_mix_wr_fifo,   // 64-bit 数据（多通道打包后的一拍）

    // ---- 下游 FDMA 写请求合同：送给 MSXBO_FDMA_1 ----
    output  reg             pkg_wr_areq,            // 单拍脉冲：本模块申请发起一次写 burst
    input   wire            pkg_wr_en,              // FDMA 回的“正在搬一拍”使能，用作 FIFO rd_en
    input   wire            pkg_wr_last,            // 本包最后一拍（128 拍中的第 128 拍）
    output  reg [31:0]      pkg_wr_addr,            // 本包的 DDR 起始字节地址
    output      [63:0]      pkg_wr_data,            // 给 FDMA 的当拍数据 = FIFO dout
    output  wire[31:0]      pkg_wr_size,            // 本包 beat 数 = 128
    output  reg [63:0]      cache_wr_size           // 累计已写入 DDR 的字节数（用于回卷/统计）
    );

//------------------------------------------------------------------------------
// 1. 写包大小常量：一包 = 128 beat = 1024 字节
//
//   PKG_SIZE 是 beat 数，不是字节数。
//   pkg_wr_size 把它扩成 32-bit 输出给 FDMA，FDMA 用它判断本次 burst 长度。
//   下游 FDMA(MSXBO_FDMA_v1_0_M00_AXI) 的 BURST_LEN 也是 128，两边对得上。
//------------------------------------------------------------------------------
wire    [7:0]   PKG_SIZE;
assign          PKG_SIZE     = 8'd128;
assign          pkg_wr_size  = {24'd0,PKG_SIZE};

//------------------------------------------------------------------------------
// 2. 内部信号
//
//   W0_REQ        : “FIFO 里已经攒够一包了吗？” 1 = 已攒够 ≥128 拍，可以发请求
//   rd_data_count : FIFO 当前可读拍数（fifo_generator_3 的 data_count 输出）
//   current/next_state : 下面 4 状态机用，控制“申请→等开搬→等 last→收尾”
//------------------------------------------------------------------------------
reg             W0_REQ;
wire    [9:0]   rd_data_count;
reg     [1:0]   current_state;
reg     [1:0]   next_state;
parameter       IDLE = 2'b00;   // 等 FIFO 攒够一包
parameter       S0 = 2'b01;     // 拉一拍 pkg_wr_areq，向 FDMA 发起写请求
parameter       S1 = 2'b10;     // FDMA 正在把一包 128 拍搬走，等 pkg_wr_last
parameter       S2 = 2'b11;     // 一包搬完，递增地址 / 累计字节数

//------------------------------------------------------------------------------
// 3. W0_REQ：FIFO 攒够一包就抬手
//
//   只要 FIFO 里可读拍数 ≥ 128，就持续置 1。
//   状态机在 IDLE 看到它高，就转去 S0 发请求。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn)
        W0_REQ <= 1'b0;
    else
        W0_REQ <= (rd_data_count >= PKG_SIZE);
end

//------------------------------------------------------------------------------
// 4. 写包状态机：IDLE → S0 → S1 → S2 → IDLE
//
//   IDLE: 等 W0_REQ=1 (FIFO 攒满一包)
//   S0  : 拉一拍 pkg_wr_areq=1 给 FDMA，告诉它“可以来搬这一包了”
//   S1  : FDMA 开始用 pkg_wr_en 一拍一拍读 FIFO，直到 pkg_wr_last=1
//   S2  : 这一包搬完，更新写地址 / 累计字节数，回 IDLE 等下一包
//
//   注意：FIFO 的真正读出由 FDMA 的 pkg_wr_en 直接驱动，
//         状态机本身不直接控制 FIFO rd_en。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

always@(current_state or W0_REQ or pkg_wr_last)
begin
    case(current_state)
    IDLE:   next_state = (W0_REQ == 1)? S0:IDLE;
    S0:     next_state = S1;
    S1:     next_state = (pkg_wr_last==1)?S2:S1;
    S2:     next_state = IDLE;
    default:next_state = IDLE;
    endcase
end

//------------------------------------------------------------------------------
// 5. 写请求脉冲 + 写地址递增
//
//   pkg_wr_areq   : 只在 S0 那一拍是 1，其他状态都是 0 —— 给 FDMA 的请求脉冲
//   pkg_wr_addr   : 本包写入 DDR 的字节起始地址，每搬完一包 +1024
//                   到 0x80000000 (2 GB) 就回卷到 0，把 DDR 当成环形缓冲
//   cache_wr_size : 累计字节数，调试/上位机统计用，跟着 +1024
//
//   换一种说法：
//     第 0 包写到 0x00000000，第 1 包写到 0x00000400，第 2 包写到 0x00000800 …
//     直到地址快到 2 GB，下一次回到 0，覆盖最早的数据。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        pkg_wr_areq     <= 1'b0;
        pkg_wr_addr     <= 32'd0;
        cache_wr_size   <= 64'd0;
    end
    else
        case(next_state)
        IDLE:   begin   pkg_wr_areq     <= 1'b0; end
        S0:     begin   pkg_wr_areq     <= 1'b1; end
        S1:     begin   pkg_wr_areq     <= 1'b0; end
        S2:     begin
                        pkg_wr_areq     <= 1'b0;
                        cache_wr_size   <= cache_wr_size + 1024;
                        if (pkg_wr_addr + 1024 >= 32'h80000000)
                            pkg_wr_addr <= 32'd0;
                        else
                            pkg_wr_addr <= pkg_wr_addr + 1024;
                end
        default:begin
                        pkg_wr_areq     <= 1'b0;
                        pkg_wr_addr     <= 32'd0;
                        cache_wr_size   <= 64'd0;
                end
        endcase
end

//------------------------------------------------------------------------------
// 6. 写侧蓄水池 FIFO：fifo_generator_3
//
//   写侧 (上游)  : adc_data_mix_wr_en / _wr_fifo  ← 来自 adcdata_get
//   读侧 (下游)  : pkg_wr_en / pkg_wr_data        ← 由 FDMA 拍读
//   data_count   : 当前可读拍数 → 喂给 W0_REQ 判断是否攒够 128 拍
//
//   两侧都用 ui_clk —— 这是同步 FIFO，不是异步 FIFO，没有 CDC。
//   srst 用 !rstn 转成同步高有效复位，符合 fifo_generator IP 的复位口约定。
//------------------------------------------------------------------------------
fifo_generator_3 W0_fifo_generator_3(
    .srst            (!rstn),
    .clk             (ui_clk),
    .din             (adc_data_mix_wr_fifo),
    .wr_en           (adc_data_mix_wr_en),
    .rd_en           (pkg_wr_en),
    .dout            (pkg_wr_data),
    .data_count      (rd_data_count)
    );

endmodule
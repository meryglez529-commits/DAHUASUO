`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LAN_TX_FREAME
// Create Date: 2019/11/12 10:34:32
//
//------------------------------------------------------------------------------
// 0. 读这个模块，先记住一句话
//
// LAN_TX_FREAME 做的事只有一件：
//   把从 DDR 读出来的 ADC 数据，在 eth_clk 域按 “每包 N 字节” 切成多个
//   应用层数据包，每包前面加 12 字节自定义包头，然后字节一拍一拍交给
//   后面的以太网发送链 (LAN_TX_MUX → LAN_TX_TOP → lan_tx)。
//
// 为什么要这样做？(4 个设计压力一起出现)
//   1) 跨时钟域 + 宽度转换：
//      ADC 数据在 ui_clk 域、64-bit；以太网在 eth_clk 域、8-bit。
//      → 必须有一个 异步 / 异宽 FIFO (fifo_generator_9)。
//   2) 一帧 ADC 数据太大，UDP 一包发不下：
//      要把一帧切成多个固定大小 (single_frame_count 字节) 的 payload，
//      最后剩下的零头单独成最后一包。
//   3) 上位机要重组：
//      所以每包前面贴 12 字节应用头 = 同步字 AA55AA55 + 包序号 + 包长度。
//   4) 与以太网仲裁器握手：
//      数据准备好 → 拉 data_req_o → 等 data_ACK_i 上升沿 → 开始发 payload
//      → 全部发完后等 tx_data_done → 回 IDLE。
//
// 它在 DL2 链路里的位置：
//   fdma_controller1_read → MSXBO_FDMA_1 → pkg1_rd_data/en
//        → (接到本模块 adc_data_mix_wr_fifo / _wr_en，但实际就是 DDR 出来的数据)
//        → LAN_TX_FREAME (本模块: CDC FIFO + 分包状态机 + 帧头)
//        → [data_req_o / data_ACK_i / data_tx_data_o / data_tx_valid_o]
//        → LAN_TX_MUX (多路仲裁) → LAN_TX_TOP → lan_tx → TEMAC → MAC/PHY
//
// 先把单位和量级记牢：
//   1 个采样点 = 16 bit = 2 字节                  (单通道时每点 2 字节)
//   1 帧字节数 all_image_point = image_point * (2 或 4 或 8)
//                              = 取决于 adc_channel 里 “开了几路”
//   1 个 UDP payload = single_frame_count 字节   (来自 vio_2 上位机配置)
//   1 包总长 data_wr_last_pack_num = single_frame_count + 12 (含头)
//   一帧总包数 frame_count                       (来自 vio_2)
//   12 = 应用头字节数
//   30000 = DDR 续读触发水位 (本地 FIFO 剩 ≤30000 拍 8-bit 就向 DDR 要数据)
//
// 两种工作模式：
//   tx_data_type = 1 (普通采集模式)  → 状态机走 fsm_r=2，payload 是 fifo_dout (DDR 来的 ADC 数据)
//   tx_data_type = 0 (超快扫描模式)  → 状态机走 fsm_r=5，payload 是 line_count_tx (扫描行号)
//
//   不论哪种模式，都先发 12 字节应用头，再发 payload。
//------------------------------------------------------------------------------

module LAN_TX_FREAME(
    // ---- 时钟 / 复位 ----
    input                   eth_clk,                // 以太网域时钟 (主控时钟)
    input                   eth_rstn,               // 以太网域复位，低有效
    input                   adc_dco,                // ADC DCO 时钟，给 fifo_generator_2 的写侧用
    input                   ui_clk,                 // MIG ui_clk，DDR 数据出来时所在的域
    input                   rstn,                   // ui_clk 域复位，低有效

    // ---- 帧/通道参数 (来自 command_monitor_new 寄存器) ----
    input           [31:0]  image_point,            // 一帧多少个采样点 (不计通道)
    input           [20:0]  adc_len_single,         // 单通道采样长度 (本模块未使用，仅穿透接口)
    input           [3:0]   adc_channel,            // 4 路 ADC 通道使能位，决定每点占几字节
    input                   scan_state,             // 1 = 正在扫描，可以发数据；0 = 停止/复位本模块状态

    // ---- 从 DDR 读出的 ADC 数据 (经 fdma_controller1_read + FDMA 进来) ----
    input                   adc_data_mix_wr_en,     // = pkg_rd_en，FDMA 当拍数据有效
    input           [63:0]  adc_data_mix_wr_fifo,   // = pkg_rd_data，64-bit ADC 数据
    output  reg             fdma_rd_req,            // 本地 FIFO 不够，请 fdma_controller1_read 继续读 DDR

    input           [31:0]  pc_ack,                 // 上位机回应计数 (用于 fsm_r=4 的暂停/超时路径)
    input                   ultrafast_mode,         // 1 = 超快扫描模式 (发行号)，0 = 普通采集模式 (发 ADC)
    input           [15:0]  line_count,             // 超快模式下当前扫描行号 (adc_dco 域)
    input                   line_count_en,          // line_count 写入有效

    // ---- 与以太网发送仲裁/链路的接口 ----
    input                   tx_data_done,           // 本包全部送出 TEMAC 完成
    input                   prog_full,              // 下游 UDP 发送 FIFO 接近满，节流用
    output  reg             data_req_o,             // 我有数据要发，请仲裁器给我机会
    input                   data_ACK_i,             // 仲裁器应答：现在轮到你发了
    output          [21:0]  data_wr_pack_num,       // 本次请求要发几包，固定 1
    output  reg     [15:0]  data_wr_last_pack_num,  // 本包总字节数 (含 12 字节头)
    output  reg     [7:0]   data_tx_data_o,         // 给以太网链的 1 字节 payload
    output  reg             data_tx_valid_o         // 上面字节有效
    );

//==============================================================================
// 1. 超快模式专用：扫描行号 CDC FIFO (fifo_generator_2)
//
// 超快扫描模式下，要把扫描行号 line_count[15:0] 送给上位机看。
// line_count 在 adc_dco 域产生，但发送在 eth_clk 域，所以用一个异步 FIFO
// 把行号从 adc_dco 跨到 eth_clk。
//
// 状态机在 fsm_r=5 时，从这个 FIFO 读出 line_count_tx 作为本包 payload。
//==============================================================================
reg         line_rd_en;
wire [15:0] line_count_tx;
wire        empty;
wire [4:0]  line_rd_data_count;
fifo_generator_2 your_instance_name (
  .rst              (!(rstn & fifo_rstn)),         // 写侧 + 读侧任一路 reset，都复位
  .wr_clk           (adc_dco),                     // 写侧时钟 = ADC DCO 域
  .rd_clk           (eth_clk),                     // 读侧时钟 = 以太网域
  .din              (line_count),
  .wr_en            (line_count_en),
  .rd_en            (line_rd_en),
  .dout             (line_count_tx),
  .rd_data_count    (line_rd_data_count),
  .empty            (empty)
);

//==============================================================================
// 2. VIO 调试接口：每包字节数 + 每帧包数 (上位机/上板时设)
//
// single_frame_count = 每个 UDP payload 多少字节 (不含 12 字节头)
// frame_count        = 一帧切多少包
//
// 这两个值是通过 Vivado VIO 在线设进来的，方便联调时改大小不用重编。
//==============================================================================
wire [15:0] single_frame_count;
wire [15:0] frame_count;
vio_2 vio_inst(
    .clk        (eth_clk),
    .probe_out0 (single_frame_count),
    .probe_out1 (frame_count)
    );

//==============================================================================
// 3. 主数据通路 CDC + 宽度转换 FIFO (fifo_generator_9)
//
// 写侧：ui_clk 域, 64-bit (DDR 读出来的 ADC 数据，一拍 8 字节)
// 读侧：eth_clk 域, 8-bit (以太网每拍只发 1 字节)
//
// 这是本模块最关键的一块 IP — 它同时做 “异步时钟域跨越” + “64bit→8bit 宽度转换”。
// 写一拍进来 = 读 8 拍出去；rd_data_count 是 “以 8-bit 拍为单位” 的可读量。
//
// 注意：本模块只看 fifo_rd_data_count 来判断要不要继续向 DDR 要数据 (见下面 4)。
//==============================================================================
reg         fifo_rstn;
reg         fifo_rd_en;
wire [7:0]  fifo_dout;
wire [15:0] fifo_rd_data_count;
fifo_generator_9 tx_data_fifo(
    .wr_clk         (ui_clk),
    .rd_clk         (eth_clk),
    .rst            (!(rstn & fifo_rstn)),
    .din            (adc_data_mix_wr_fifo),
    .wr_en          (adc_data_mix_wr_en),
    .rd_en          (fifo_rd_en),
    .dout           (fifo_dout),
    .rd_data_count  (fifo_rd_data_count)
    );

//==============================================================================
// 4. 向 DDR 续读请求：fdma_rd_req
//
// 本地 8-bit FIFO 容量约 32K，剩 ≤ 30000 拍时拉高 fdma_rd_req，
// 让 fdma_controller1_read 继续从 DDR 拿数据 (经 FDMA → 写入本 FIFO)。
// 这是 “以太网发送速率 vs DDR 读速率” 的简单背压机制。
//==============================================================================
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(!eth_rstn)
        fdma_rd_req <= 1'b0;
    else if(fifo_rd_data_count <= 30000)
        fdma_rd_req <= 1'b1;
    else
        fdma_rd_req <= 1'b0;
end

//==============================================================================
// 5. all_image_point —— 一帧 ADC 数据的 “总字节数”
//
// 先把维度讲清楚（这是整个模块最容易绕的地方）：
//   image_point = 一帧的“像素位置数” = 行 × 列  (由 command_monitor_new 用上位机
//                                                 写入的 row*col 算出来)。
//                 通道数不会改变 image_point —— 它只是空间位置数。
//   adc_channel[3:0] = 4 路 ADC 的使能掩码 (bit0~bit3 = ADC1~ADC4)，
//                      开几路 → 每个位置要携带几个 16-bit (=2 字节) 测量值。
//
// 所以每个 “像素位置” 实际占的字节数 = (启用通道数) × 2 字节：
//   单通道 (popcount=1) → 每像素 2 字节  → all_image_point = image_point*2
//   双通道 (popcount=2) → 每像素 4 字节  → all_image_point = image_point*4
//   三通道 (popcount=3) → 每像素 8 字节* → all_image_point = image_point*8
//   四通道 (popcount=4) → 每像素 8 字节  → all_image_point = image_point*8
//
//   * 注：三通道实际只有 3*2=6 字节有效数据，但 adcdata_get 统一按 4 槽位
//     (4*16bit=64bit=8 字节) 输出，未启用的槽位由上位机按 adc_channel 解释。
//
// 代码里用 “image_point 左移 N 位” 直接实现 “×2^N”：
//   {2'd0, image_point, 1'd0}  ≡  image_point << 1  ≡  ×2
//   {1'd0, image_point, 2'd0}  ≡  image_point << 2  ≡  ×4
//   {image_point, 3'd0}        ≡  image_point << 3  ≡  ×8
//
// 默认值 2097152 = 2^21 = 2 MB，是 “一帧很大不会立即触发分包结束” 的保守初值。
//==============================================================================
reg [34:0]  all_image_point;
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(!eth_rstn)
        all_image_point <= 35'd2097152;
    else
        case(adc_channel)
        4'b0001,4'b0010,4'b0100,4'b1000:                begin all_image_point <= {2'd0,image_point,1'd0}; end // ×2
        4'b0011,4'b0101,4'b1001,4'b0110,4'b1010,4'b1100:begin all_image_point <= {1'd0,image_point,2'd0}; end // ×4
        4'b0111,4'b1011,4'b1101,4'b1110,4'b1111:        begin all_image_point <= {image_point,3'd0}; end     // ×8
        default:                                        begin all_image_point <= 35'd2097152; end
        endcase
end

//==============================================================================
// 6. 给仲裁器的 “本次要发几包” —— 固定 1
//
// 本模块每次抬手 (data_req_o=1) 只承诺发 1 包。要发下一包就回 IDLE 再抬手。
//==============================================================================
assign data_wr_pack_num = 22'd1;

//==============================================================================
// 7. data_ACK_i 打两拍 —— 用于检测 “ACK 上升沿”
//
// 状态机 fsm_r=1 用 (data_ACK_r0 && !data_ACK_r1) 检测 ACK 上升沿，
// 而不是直接看电平，避免在仲裁器持续保持 ACK 时反复触发。
//==============================================================================
reg     data_ACK_r0;
reg     data_ACK_r1;
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(!eth_rstn) begin
        data_ACK_r0 <= 0;
        data_ACK_r1 <= 0;
    end
    else begin
        data_ACK_r0 <= data_ACK_i;
        data_ACK_r1 <= data_ACK_r0;
    end
end
  
//==============================================================================
// 8. 发送状态机 fsm_r —— 整个模块的核心
//
// 主链路：0 (等待+决策) → 1 (等 ACK) → 2/5 (发包) → 3 (收尾) → 0
//   0 : 看 scan_state，选模式，看数据/字节够不够，准备 head_data 和长度，
//       然后拉 data_req_o 跳 1。
//   1 : 等 data_ACK_i 的上升沿；按 tx_data_type 跳 2 (普通) 或 5 (超快)。
//   2 : 普通模式发包 = 12 字节头 + payload(从 fifo_dout 取 ADC 数据)。
//   5 : 超快模式发包 = 12 字节头 + payload(从 line_count_tx 取行号)。
//   3 : 拉低 data_req_o，等 tx_data_done 表示这包真的发到 MAC 了，回 0。
//   4 : 上位机暂停/超时分支 (非主链路)，当前业务从未进入。
//
// 关键中间量：
//   package_count        : 累计已发包数 (48-bit 大计数器，跨帧不清零)，
//                          每次发包前 +1 并写进 head_data。
//   tx_byte_count        : 本帧已发字节数；
//   remain_byte_count    = all_image_point - tx_byte_count = 本帧剩多少字节；
//                          决定本包是发整 single_frame_count 还是剩多少发多少。
//   data_wr_last_pack_num: 本包总字节数 (含 12 字节头)，告诉下游发多长。
//   byte_cnt             : 本包内已发了多少字节，控制头/payload 切换。
//   head_data[95:0]      : 12 字节应用头的临时缓冲，每发一字节左移 8。
//
// 应用头格式：
//   普通模式: AA55 AA55 + package_count(6 字节, 按字节序排) + length(2 字节)
//   超快模式: CC55 CC55 + 0 (8 字节占位)
//
// 字节序提示：
//   普通模式头部把 48-bit package_count 拆成
//   [39:32] [47:40] [7:0] [15:8] [23:16] [31:24]
//   —— 高 16 bit “反过来”、低 32 bit “反过来”，与上位机协议约定一致。
//==============================================================================
reg [47:0]  package_count;
reg [34:0]  tx_byte_count;
wire[34:0]  remain_byte_count;
assign      remain_byte_count   = all_image_point - tx_byte_count;
reg [95:0]  head_data;
reg [3:0]   fsm_r;
reg [15:0]  byte_cnt;

reg [15:0]  wait_count;
reg [31:0]  pc_ack_cnt;
reg [15:0]  incre_count;
reg [31:0]  js_cnt;
reg         flag;
reg [31:0]  overtime_cnt;
reg         tx_data_type;       // 0 = 发行号(超快模式)，1 = 发 ADC 数据(普通模式)
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(!eth_rstn) begin
        fifo_rstn               <= 1'b0;
        package_count           <= 1;
        tx_byte_count           <= 0;
        head_data               <= {16'hAA55, 16'hAA55,48'd0, 32'd0};
        data_wr_last_pack_num   <= 0;
        fsm_r                   <= 0;
        data_req_o              <= 0;
        
        data_tx_valid_o         <= 0;
        data_tx_data_o          <= 0;
        byte_cnt                <= 0;
        fifo_rd_en              <= 1'b0;
 
        wait_count              <= 0;
        pc_ack_cnt              <= 0;
        js_cnt                  <= 0;
        flag                    <= 0; 
        overtime_cnt            <= 0;
        tx_data_type            <= 1'b1;
    end
    else
        case(fsm_r)
        //----------------------------------------------------------------------
        // State 0 —— 等待 / 模式选择 / 准备 head + 长度 / 抬手请求发送
        //
        //   scan_state=0 时整体被踩 reset (除了 package_count 永久累加这点除外)。
        //   scan_state=1 时按优先级判断三种发包场景：
        //     (a) 超快模式且行号 FIFO 非空        → CC55CC55 头, payload=14 字节(12头+2行号)
        //     (b) 普通模式且本帧剩 > 一包 且 FIFO 够 → 发整包，tx_byte_count += single_frame_count
        //     (c) 普通模式且本帧剩 ≤ 一包 且 FIFO 够 → 发完零头，tx_byte_count 清零开始下一帧
        //   都不满足 → 留在 0 等。
        //----------------------------------------------------------------------
        0:  begin
                if(scan_state==1) begin
                    fifo_rstn <= 1'b1;
                    if(ultrafast_mode == 1 && (!empty))begin
                        // (a) 超快模式：发 12 字节 CC55... 头 + 2 字节行号，total = 14
                        head_data               <= {16'hCC55,16'hCC55,16'h0000,16'h0000,16'h0000,16'h0000};
                        data_wr_last_pack_num   <= 14;
                        fsm_r                   <= 1;
                        data_req_o              <= 1'b1;
                        tx_data_type            <= 1'b0;
                    end
                    else if(remain_byte_count > single_frame_count && fifo_rd_data_count >= single_frame_count)begin
                        // (b) 普通模式整包：本帧剩余 > 一包大小，FIFO 也够，发满 single_frame_count
                        package_count           <= package_count + 1'b1;
                        tx_byte_count           <= tx_byte_count + single_frame_count;
                        head_data               <= {16'hAA55,16'hAA55,
                                                    package_count[39:32],package_count[47:40],package_count[7:0], package_count[15:8], package_count[23:16], package_count[31:24],
                                                    single_frame_count[7:0],single_frame_count[15:8]};   // length 也是低字节在前
                        data_wr_last_pack_num   <= single_frame_count + 12;                              // payload + 12 字节头
                        fsm_r                   <= 1;
                        data_req_o              <= 1'b1;
                        tx_data_type            <= 1'b1;
                    end
                    else if(remain_byte_count <= single_frame_count && fifo_rd_data_count >= remain_byte_count) begin
                        // (c) 普通模式收尾包：本帧只剩 ≤ 一包，发完后 tx_byte_count 清零，下一帧重新计
                        package_count           <= package_count + 1'b1;
                        tx_byte_count           <= 0;
                        head_data               <= {16'hAA55,16'hAA55,
                                                    package_count[39:32],package_count[47:40],package_count[7:0], package_count[15:8], package_count[23:16], package_count[31:24],
                                                    remain_byte_count[7:0],remain_byte_count[15:8]};
                        data_wr_last_pack_num   <= remain_byte_count + 12;
                        fsm_r                   <= 1;
                        data_req_o              <= 1'b1;
                        tx_data_type            <= 1'b1;
                    end
                    else begin
                        // 条件都不满足 → 保持等待
                        fsm_r                   <= 0;
                        data_req_o              <= 1'b0;
                        tx_data_type            <= 1'b1;
                    end
                end
                else begin
                    // scan_state=0 → 整体复位本地寄存器 (注意 package_count 此处清回 1, tx_byte_count 清零)
                    fifo_rstn                   <= 1'b0;
                    package_count               <= 1;
                    tx_byte_count               <= 0;
                    head_data                   <= {16'hAA55, 16'hAA55,48'd0, 32'd0};
                    data_wr_last_pack_num       <= 0;
                    fsm_r                       <= 0;
                    data_req_o                  <= 0;

                    data_tx_valid_o             <= 0;
                    data_tx_data_o              <= 0;
                    byte_cnt                    <= 0;
                    fifo_rd_en                  <= 1'b0;

                    wait_count                  <= 0;
                    pc_ack_cnt                  <= 0;
                    js_cnt                      <= 0;
                    flag                        <= 0;
                    overtime_cnt                <= 0;
                end
            end
        //----------------------------------------------------------------------
        // State 1 —— 等仲裁器 ACK 上升沿
        //
        // data_ACK_r0/r1 是 data_ACK_i 的两拍延迟，
        // (r0 && !r1) 只在 ACK 从低跳到高的那一拍为 1，捕获边沿后选发送支路。
        //----------------------------------------------------------------------
        1:  begin
                if(data_ACK_r0 && !data_ACK_r1)         // ACK 上升沿
                    if(tx_data_type == 1)
                    fsm_r                       <= 2;   // 普通模式：发 ADC 数据
                    else
                    fsm_r                       <= 5;   // 超快模式：发行号
                else
                    fsm_r                       <= 1;
            end

        //----------------------------------------------------------------------
        // State 2 —— 普通模式发包: 前 12 字节头 + 后面 N 字节 ADC payload
        //
        // 发送节奏 (每个 eth_clk 一字节)：
        //   byte_cnt = 0..11   : 从 head_data[95:88] 取一字节，head_data 左移 8
        //                        相当于把 12 字节头按顺序“串行抽出”
        //   byte_cnt = 12..end : 从 fifo_dout 读 ADC payload
        //   byte_cnt = end     : 切到 fsm_r=3 收尾
        //   prog_full=1 时停止 valid → 给下游 UDP FIFO 留时间消化
        //
        // 提前读 FIFO 的窍门 (最后那段 if)：
        //   fifo_generator_9 是 FWFT FIFO，但仍需 1 拍读 latency 才能让 dout
        //   稳定到下一个数据。如果到 byte_cnt=12 才拉 rd_en，第一个 payload
        //   字节会重复发上一拍的数据。所以从 byte_cnt=10 提前拉 fifo_rd_en，
        //   让 dout 在 byte_cnt=12 之前就准备好。
        //   止点 data_wr_last_pack_num - 2：留 2 字节 “缓冲”，最后两个字节
        //   不再读 FIFO，避免读多一字节、下次发包错位。
        //----------------------------------------------------------------------
        2:  begin
                if(prog_full==0 && byte_cnt < 12) begin
                    // 发 12 字节应用头：每拍从 head_data 顶部取一字节，剩余左移
                    data_tx_valid_o             <= 1'b1;
                    data_tx_data_o              <= head_data[95:88];  head_data <= {head_data[87:0],8'd0};
                    byte_cnt                    <= byte_cnt + 1'b1;
                    fsm_r                       <= 2;
                end
                else if(prog_full==0 && byte_cnt < data_wr_last_pack_num) begin
                    // 发 ADC payload：从 fifo_dout 一字节一字节往外送
                    byte_cnt                    <= byte_cnt + 1'b1;
                    fsm_r                       <= 2;
                    data_tx_valid_o             <= 1'b1;
                    data_tx_data_o              <= fifo_dout;
                end
                else begin
                    // 本包发完，去 3 等 tx_data_done
                    data_tx_valid_o             <= 1'b0;
                    data_tx_data_o              <= data_tx_data_o;
                    byte_cnt                    <= 0;
                    fsm_r                       <= 3;
                end

                // 提前 2 字节拉 fifo_rd_en，让下一拍 fifo_dout 就位
                if(byte_cnt >= 10 && byte_cnt < data_wr_last_pack_num - 2)
                    fifo_rd_en                  <= 1'b1;
                else
                    fifo_rd_en                  <= 1'b0;
            end

        //----------------------------------------------------------------------
        // State 5 —— 超快模式发包: 12 字节 CC55... 头 + 2 字节 line_count
        //
        // 结构与 state 2 完全平行，只是 payload 源变成 line_count_tx，
        // 读使能变成 line_rd_en (从 fifo_generator_2 读行号)。
        //----------------------------------------------------------------------
        5:  begin
                if(prog_full==0 && byte_cnt < 12) begin
                    data_tx_valid_o             <= 1'b1;
                    data_tx_data_o              <= head_data[95:88];  head_data <= {head_data[87:0],8'd0};
                    byte_cnt                    <= byte_cnt + 1'b1;
                    fsm_r                       <= 5;
                end
                else if(prog_full==0 && byte_cnt < data_wr_last_pack_num) begin
                    byte_cnt                    <= byte_cnt + 1'b1;
                    fsm_r                       <= 5;
                    data_tx_valid_o             <= 1'b1;
                    data_tx_data_o              <= line_count_tx;
                end
                else begin
                    data_tx_valid_o             <= 1'b0;
                    data_tx_data_o              <= data_tx_data_o;
                    byte_cnt                    <= 0;
                    fsm_r                       <= 3;
                end

                if(byte_cnt >= 10 && byte_cnt < data_wr_last_pack_num - 2)
                    line_rd_en                  <= 1'b1;
                else
                    line_rd_en                  <= 1'b0;
            end

        //----------------------------------------------------------------------
        // State 3 —— 收尾: 拉低 data_req_o，等 tx_data_done
        //
        // 必须等下游回 tx_data_done 才能回 IDLE，
        // 否则状态机会比物理发送更快、frame 错位。
        //----------------------------------------------------------------------
        3:  begin
                data_req_o                      <= 1'b0;
                if(tx_data_done) begin
                    fsm_r                       <= 0;
                    wait_count                  <= wait_count + 1'b1;
                end
                else
                    fsm_r                       <= 3;
            end

        //----------------------------------------------------------------------
        // State 4 —— 暂停 / 上位机回应 / 超时分支 (当前业务从未进入)
        //
        // 设计意图：发完一帧 (wait_count==frame_count) 后等上位机 pc_ack 跟上，
        // 跟不上就 js_cnt 计数 1 秒 (125_000_000 个 eth_clk @ 125MHz) 超时；
        // overtime_cnt 给调试看。
        // 但状态机从 3 不会进 4，所以这是预留路径。
        //----------------------------------------------------------------------
        4:  begin
                if(scan_state==1 && wait_count==frame_count)
                    if(pc_ack_cnt >= pc_ack && pc_ack_cnt - pc_ack < 3) begin
                        fsm_r                   <= 0;
                        wait_count              <= 0;
                        pc_ack_cnt              <= pc_ack_cnt + 1'b1;
                        js_cnt                  <= 0;
                        flag                    <= 0;
                    end
                    else if(js_cnt==125000000) begin     // 1 秒超时阈值 (eth_clk = 125 MHz)
                        fsm_r                   <= 0;
                        wait_count              <= 0;
                        pc_ack_cnt              <= pc_ack_cnt + 1'b1;
                        js_cnt                  <= 0;
                        flag                    <= 0;
                        overtime_cnt            <= overtime_cnt + 1'b1;
                    end
                    else begin
                        fsm_r                   <= fsm_r;
                        js_cnt                  <= js_cnt + 1'b1;
                        flag                    <= 1;
                    end
                else
                    fsm_r                       <= 0;
            end
        default:begin data_req_o <= 0; data_tx_data_o <= 0; data_tx_valid_o <= 0; byte_cnt <= 0; fifo_rd_en <= 1'b0; end
        endcase
end

//==============================================================================
// 9. 调试探针 ila_10 —— 抓状态机 + 握手 + payload 字节
//
// 把状态机、req/ACK、字节计数、payload 出口、FIFO 水位一起抓，
// 上板时直接看一个 ila 就能定位 “没发出去” 是哪一环卡住。
// 不影响功能，可以整段忽略。
//==============================================================================
ila_10 tx_data_ila(
    .clk        (eth_clk),
    .probe0     (fsm_r),                //4   状态机
    .probe1     (data_req_o),           //1   抬手
    .probe2     (data_ACK_i),           //1   仲裁器应答
    .probe3     (byte_cnt),             //16  本包内字节位置
    .probe4     (prog_full),            //1   下游 FIFO 接近满
    .probe5     (data_tx_valid_o),      //1   payload 有效
    .probe6     (data_tx_data_o),       //8   payload 字节

    .probe7     (line_rd_data_count),   //5   行号 FIFO 水位
    .probe8     (fifo_rd_en),           //1   ADC FIFO 读使能
    .probe9     (fifo_rd_data_count),   //16  ADC FIFO 水位 (用来判 30000 阈值)
    .probe10    (pc_ack),               //32  上位机回应计数 (state 4 用)
    .probe11    (pc_ack_cnt),           //32  本地累计 (state 4 用)
    .probe12    (js_cnt),               //    超时计数 (state 4 用)
    .probe13    (empty),                //1   行号 FIFO 空
    .probe14    (scan_state),           //1   扫描使能
    .probe15    (overtime_cnt)          //32  累计超时次数 (state 4 用)
    );

endmodule
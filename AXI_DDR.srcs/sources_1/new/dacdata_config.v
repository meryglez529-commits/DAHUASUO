`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : dacdata_config
// 创建日期    : 2020/06/04
//
// === 一句话作用 ===
//   DL1（DAC 扫描输出）数据链路的"顶层包装"。本模块不做波形计算，只做三件杂事：
//     1) 参数预处理（µs→拍数换算、峰峰值计算）
//     2) 在 scan_state 上升沿产生一个 6 拍的复位脉冲送给波形生成器
//     3) 把外部 TRIGGER_IN 做两拍同步并提取上升沿
//   真正的工作交给两个子模块：
//     - parameter_dacdata_gen ：14 态状态机，预先算出整帧每一拍的 DAX/DAY/adc_tri，
//                               以 35-bit 的 {sync2,sync1,adc_tri,DAX[15:0],DAY[15:0]}
//                               写入跨时钟 FIFO；
//     - dac_output            ：在 dac_dco(50MHz) 域从 FIFO 读出，拆包成 DAX/DAY/adc_tri，
//                               并在 ui_clk(200MHz) 域生成可调延迟的 sync 脉冲。
//
// === 数据流 ===
//   PC/ETH 寄存器  ─►  dacdata_config(本文件)  ─►  parameter_dacdata_gen ─►
//                                                       │(35-bit 异步 FIFO)
//                                                       ▼
//                                                  dac_output ─► DAX/DAY/adc_tri
//                                                                 │
//                                                  ETH_TOP 顶层做 65535-X 反相 ─► AD9747
//
// === 时钟域 ===
//   本文件所有逻辑都在 eth_clk(125MHz) 域；
//   parameter_dacdata_gen 也跑在 eth_clk（虽然端口名叫 ui_clk，是历史遗留误导）；
//   dac_output 内部跨到 dac_dco(50MHz) 和 ui_clk(200MHz)。
//
//////////////////////////////////////////////////////////////////////////////////
  module dacdata_config(
    // ─── 时钟与复位 ─────────────────────────────────────────────────────────
    input           eth_clk,            // 125MHz：本模块主时钟，也是 FIFO 写侧时钟
    input           eth_rstn,           // 低有效全局复位
    input           dac_dco,            // 50MHz：来自 AD9747 的 DCO 时钟（FIFO 读侧 + DAC 输出时钟）
    input           ui_clk,             // 200MHz：MIG 的 ui_clk（dac_output 内 sync 脉冲延迟用，5ns 分辨率）

    // ─── 扫描参数（来自 PC 通过以太网写入的寄存器，eth_clk 域，复位后稳定保持）────
    input [31:0]    dac_sample,         // 每个像素点 DAC 保持的拍数（同时是 ADC 平均采样数）
    input [15:0]    image_row,          // 一帧的总行数
    input [15:0]    dacx_strat_level,   // X 轴起始 DAC 码值（注：strat 是原作者拼写笔误，应为 start）
    input [15:0]    dacx_end_level,     // X 轴结束 DAC 码值
    input [63:0]    dacx_step,          // X 轴每像素步进（64-bit 定点，高 16=整数，低 48=小数）
    input [15:0]    dacx_tk_point,      // 一行的像素个数（Tk 段长度）
    input [15:0]    dacx_recovery_time, // 行首恢复时间（普通模式 Tb 段拍数）
    input [15:0]    dacy_strat_level,   // Y 轴起始 DAC 码值
    input [15:0]    dacy_end_level,     // Y 轴结束 DAC 码值
    input [63:0]    dacy_step,          // Y 轴每行步进（64-bit 定点）
    input [31:0]    frame_waiting_time, // 帧间等待拍数
    input [31:0]    dax_fall_time,      // 行尾下降斜坡（单位：µs，下面 ×50 转为拍数）
    input [3:0]     scan_mode,          // 扫描模式（4'h1=参数扫描模式，dac_output 据此判断是否工作）
    input           scan_state,         // 1=正在扫描，0=停止扫描
    input           ultrafast_mode,     // 1=超快模式（行恢复时间用 ultrafast_line_rec，且 sync 输出启用）
    input   [31:0]   ultrafast_line_rec, // 超快模式专用的行恢复时间
    input       [15:0]  sync_sig_delay1, // sync1 脉冲相对像素边沿的延迟（ui_clk 拍）
    input       [15:0]  sync_sig_delay2, // sync2 脉冲延迟

    // ─── 交错/重复扫描参数 ─────────────────────────────────────────────────
    input [15:0]    row_m,              // 交错扫描每组 m 行（类似隔行扫描）
    input [15:0]    row_n,              // 交错扫描每组中扫 n 行
    input [15:0]    row_repeat,         // 每行重复扫描次数（用于多次平均提高信噪比）
    input [15:0]    sync1_pixel_tri_wigth, // sync1 脉冲宽度（拍数）（wigth 是 width 的笔误）
    input [15:0]    sync2_pixel_tri_wigth, // sync2 脉冲宽度

    // ─── 外部触发（用于与外部设备做行同步） ──────────────────────────────────
    input    clk_sel,                   // 1=每行扫描前等 TRIGGER_IN 上升沿才启动；0=自由运行
    input    TRIGGER_IN,                // 外部触发输入（异步，本模块负责同步进 eth_clk）

    // ─── DL5 飞秒激光同步采集模式（v3）─────────────────────────────────────────
    //   全部 7 个新输入。前 6 个是 eth_clk 域寄存器（来自 command_monitor_new），
    //   laser_sync_in 是外部异步信号（来自顶层 ETH_TOP 直通），本模块内做 CDC。
    input           laser_mode_en,           // 1=启用激光同步采集
    input [15:0]    blanker_delay_time,      // ui_clk 拍 (5ns)
    input [15:0]    blanker_time,            // ui_clk 拍 (5ns)
    input [15:0]    acq_data_delay_time,     // 20ns 步进
    input [15:0]    acq_time,                // 20ns 步进
    input [31:0]    laser_period,            // ui_clk 拍 (5ns)
    input           laser_sync_in,           // 外部 2.5V TTL 异步脉冲

    // ─── 输出（最终送到 ETH_TOP 顶层 → AD9747 / ADC 触发 / 同步连接器）─────────
    output          adc_tri,            // ADC 采集触发：每个像素 dac_sample 拍期间为 1（DL1→DL2 唯一交汇点）
    output          sync_pixel_tri1,    // 同步脉冲 1（超快模式才输出，低电平有效，已取反）
    output          sync_pixel_tri2,    // 同步脉冲 2（超快模式才输出，高电平有效，连到顶层 TRIGGER_OUT）
    output [15:0]   DAX_DATA,           // X 轴 DAC 码值（顶层会做 65535-X 反相后输出到 AD9747）
    output [15:0]   DAY_DATA            // Y 轴 DAC 码值
    );

// ═════════════════════════════════════════════════════════════════════════════
//  第 1 段：参数预处理（µs → 拍数，以及 X 轴峰峰值）
// ─────────────────────────────────────────────────────────────────────────────
//  关键概念：用户在 PC 端填的 dax_fall_time 单位是"微秒(µs)"，不是"拍数"。
//  这里乘以 50 是因为 50MHz 时钟下 1µs = 50 拍。注意虽然本模块在 eth_clk(125MHz)
//  跑，但下游波形生成器的"步"是按 dac_dco 域的节拍刻度来设计的，FIFO 反压会
//  自动把写入速率压到读出速率，所以拍数单位以 dac_dco(50MHz) 为准。
//
//  ×50 用移位实现：50 = 32 + 16 + 2，所以 ×50 = <<5 + <<4 + <<1
//  这样做是为了让综合工具用加法器和移位，避免推断 DSP 硬件乘法器（省 DSP 资源）。
// ═════════════════════════════════════════════════════════════════════════════
reg [31:0] dax_fall_time_r;
reg [15:0] dacx_pp_level;
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(~eth_rstn) begin
        dax_fall_time_r <= 32'd1000;    // 默认 1000 拍 ≈ 20µs，避免复位刚释放时除数为 0
        dacx_pp_level   <= 0;
    end
    else begin
        dax_fall_time_r <= (dax_fall_time<<5) + (dax_fall_time<<4) + (dax_fall_time<<1); // ×50：µs → 拍
        dacx_pp_level   <= dacx_end_level - dacx_strat_level;                            // 峰峰值=end-start，下游用它计算下降斜坡步进
    end
end
//new function,when stop scan,DAC_output continue
reg         scan_state_r0;
reg         rstn_r0;
reg [5:0]   rstn_r1;
wire        rstn_r2;
assign      rstn_r2 =  rstn_r1[5] & rstn_r1[4] & rstn_r1[3] & rstn_r1[2] & rstn_r1[1] & rstn_r1[0];
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(~eth_rstn) begin
        scan_state_r0   <= 0;
        rstn_r0         <= 0;
        rstn_r1         <= 0;
    end
    else begin
        scan_state_r0   <= scan_state;
        rstn_r0         <= (scan_state_r0==0 && scan_state==1) ? 0 : 1;
        rstn_r1         <= {rstn_r1[4:0],rstn_r0};
    end
end
//new function,when stop scan,DAC_output continue
reg  TRIGGER_IN_r0,TRIGGER_IN_r1;
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(~eth_rstn) begin
        TRIGGER_IN_r0   <= 0;
        TRIGGER_IN_r1   <= 0;
    end
    else begin
				TRIGGER_IN_r0 <= TRIGGER_IN;
				TRIGGER_IN_r1 <= TRIGGER_IN_r0;
    end
end
wire  TRIGGER_IN_Rise;
assign  TRIGGER_IN_Rise = ((!TRIGGER_IN_r1)&&TRIGGER_IN_r0);

// ═════════════════════════════════════════════════════════════════════════════
//  DL5（v3）：飞秒激光同步采集模式的 CDC 与子模块例化
//
//  本段处理 5 类跨域：
//    1) eth_rstn -> ui_clk 域复位（sync_module，3 级 FF）
//    2) eth_clk -> ui_clk 的 7 个静态/慢变信号：laser_mode_en、scan_state 和 6 个时间参数（双 FF）
//    3) 外部异步 laser_sync_in：在 laser_sync_blanker_ctrl 内部做 3 级 FF + 边沿检测
//    4) ui_clk -> eth_clk 单拍 pixel_done_pulse_ui（toggle-FF 同步器）
//    5) laser_mode_en_ui 同时送 laser_sync_blanker_ctrl 和 dac_output（同一份 ui_clk 域信号）
//
//  设计文档：AI-work/guide/data-paths/DL5_LASER_SYNC_MODE_DESIGN.md
// ═════════════════════════════════════════════════════════════════════════════

// ── (1) ui_rstn_dl5：eth_rstn -> ui_clk 域 ──
wire ui_rstn_dl5;
sync_module rstn_sync_dl5(.data_in(eth_rstn), .clk_in(ui_clk), .data_out(ui_rstn_dl5));

// ── (2) eth_clk -> ui_clk：mode_en + scan_state + 6 个时间参数 ──
// 静态/慢变多 bit 信号用双 FF。所有寄存器都加 ASYNC_REG 属性帮助综合工具
// 在第一级附近布线 + 抑制 timing 检查（同时配合 set_max_delay datapath_only）。
(* ASYNC_REG = "TRUE" *) reg          laser_mode_en_ui_r0;
(* ASYNC_REG = "TRUE" *) reg          laser_mode_en_ui;
(* ASYNC_REG = "TRUE" *) reg          scan_state_ui_r0;
(* ASYNC_REG = "TRUE" *) reg          scan_state_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0]   blanker_delay_time_ui_r0;
(* ASYNC_REG = "TRUE" *) reg [15:0]   blanker_delay_time_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0]   blanker_time_ui_r0;
(* ASYNC_REG = "TRUE" *) reg [15:0]   blanker_time_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0]   acq_data_delay_time_ui_r0;
(* ASYNC_REG = "TRUE" *) reg [15:0]   acq_data_delay_time_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0]   acq_time_ui_r0;
(* ASYNC_REG = "TRUE" *) reg [15:0]   acq_time_ui;
(* ASYNC_REG = "TRUE" *) reg [31:0]   laser_period_ui_r0;
(* ASYNC_REG = "TRUE" *) reg [31:0]   laser_period_ui;

always @(posedge ui_clk or negedge ui_rstn_dl5) begin
    if(!ui_rstn_dl5) begin
        laser_mode_en_ui_r0       <= 1'b0;
        laser_mode_en_ui          <= 1'b0;
        scan_state_ui_r0          <= 1'b0;
        scan_state_ui             <= 1'b0;
        blanker_delay_time_ui_r0  <= 16'd0;
        blanker_delay_time_ui     <= 16'd0;
        blanker_time_ui_r0        <= 16'd0;
        blanker_time_ui           <= 16'd0;
        acq_data_delay_time_ui_r0 <= 16'd0;
        acq_data_delay_time_ui    <= 16'd0;
        acq_time_ui_r0            <= 16'd0;
        acq_time_ui               <= 16'd0;
        laser_period_ui_r0        <= 32'd0;
        laser_period_ui           <= 32'd0;
    end
    else begin
        laser_mode_en_ui_r0       <= laser_mode_en;
        laser_mode_en_ui          <= laser_mode_en_ui_r0;
        scan_state_ui_r0          <= scan_state;
        scan_state_ui             <= scan_state_ui_r0;
        blanker_delay_time_ui_r0  <= blanker_delay_time;
        blanker_delay_time_ui     <= blanker_delay_time_ui_r0;
        blanker_time_ui_r0        <= blanker_time;
        blanker_time_ui           <= blanker_time_ui_r0;
        acq_data_delay_time_ui_r0 <= acq_data_delay_time;
        acq_data_delay_time_ui    <= acq_data_delay_time_ui_r0;
        acq_time_ui_r0            <= acq_time;
        acq_time_ui               <= acq_time_ui_r0;
        laser_period_ui_r0        <= laser_period;
        laser_period_ui           <= laser_period_ui_r0;
    end
end

// ── 例化 laser_sync_blanker_ctrl（ui_clk 域）──
wire blanker_pulse_ui;
wire laser_acq_pulse_ui;
wire laser_event_busy_ui;
wire pixel_done_pulse_ui;
laser_sync_blanker_ctrl laser_ctrl_i(
    .ui_clk                 (ui_clk),
    .rstn                   (ui_rstn_dl5),
    .laser_mode_en          (laser_mode_en_ui),
    .scan_state             (scan_state_ui),
    .blanker_delay_time     (blanker_delay_time_ui),
    .blanker_time           (blanker_time_ui),
    .acq_data_delay_time    (acq_data_delay_time_ui),
    .acq_time               (acq_time_ui),
    .laser_period           (laser_period_ui),
    .laser_sync_in          (laser_sync_in),
    .blanker_pulse          (blanker_pulse_ui),
    .laser_acq_pulse        (laser_acq_pulse_ui),
    .laser_event_busy       (laser_event_busy_ui),
    .pixel_done_pulse_ui    (pixel_done_pulse_ui)
    );

// ── (4) pixel_done_pulse_ui (ui_clk) -> pixel_done_pulse_eth (eth_clk) ──
// toggle-FF 脉冲同步器：ui_clk 侧每收到 1 拍 pulse 翻转一次 toggle；
// eth_clk 侧 3 级 FF 同步后做异或得到 1 拍 pulse。
// 适用条件：pulse 间隔 >= 3 个 eth_clk 周期；DL5 中相邻 pulse 间隔 ~ laser_period
// (典型 500KHz=2us=250 个 eth_clk @125MHz)，远满足。
reg                                  pixel_done_toggle_ui;
(* ASYNC_REG = "TRUE" *) reg [2:0]   pixel_done_toggle_eth;
wire                                 pixel_done_pulse_eth;
always @(posedge ui_clk or negedge ui_rstn_dl5) begin
    if(!ui_rstn_dl5)
        pixel_done_toggle_ui <= 1'b0;
    else if(pixel_done_pulse_ui)
        pixel_done_toggle_ui <= ~pixel_done_toggle_ui;
end
always @(posedge eth_clk or negedge eth_rstn) begin
    if(!eth_rstn)
        pixel_done_toggle_eth <= 3'd0;
    else
        pixel_done_toggle_eth <= {pixel_done_toggle_eth[1:0], pixel_done_toggle_ui};
end
assign pixel_done_pulse_eth = pixel_done_toggle_eth[2] ^ pixel_done_toggle_eth[1];

//-------------------------------------------------------------------
wire        para_config_wr_en;
wire [34:0] para_config_data;
wire        para_config_prog_full;
wire        para_config_wr_rst_busy;
parameter_dacdata_gen N1(
    .ui_clk                 (eth_clk),
//  .rstn                   (scan_state),
    .rstn                   (rstn_r2),
    .row_repeat             (row_repeat),
    .dac_sample             (dac_sample),
    .image_row              (image_row),
    .dacx_strat_level       (dacx_strat_level),
    .dacx_step              (dacx_step),
    .dacx_tk_point          (dacx_tk_point),
    .dacx_recovery_time     (dacx_recovery_time),
    .dacy_strat_level       (dacy_strat_level),
    .dacy_step              (dacy_step),  
    .frame_waiting_time     (frame_waiting_time),
    .dax_fall_time          (dax_fall_time_r),
    .dacx_pp_level          (dacx_pp_level),
    .sync1_pixel_tri_wigth   (sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth   (sync2_pixel_tri_wigth),
    .row_m                  (row_m),
    .row_n                  (row_n),
    .clk_sel								( clk_sel),
    
    .TRIGGER_IN							(TRIGGER_IN_Rise),
    .ultrafast_mode         (ultrafast_mode),
    .ultrafast_line_rec     (ultrafast_line_rec),
    // DL5: laser 模式控制 + pixel_done 反馈（已 ui_clk -> eth_clk 同步）
    .laser_mode_en          (laser_mode_en),
    .pixel_done_pulse       (pixel_done_pulse_eth),
    .para_config_wr_en      (para_config_wr_en),
    .para_config_data       (para_config_data),
    .para_config_prog_full  (para_config_prog_full),
    .para_config_wr_rst_busy(para_config_wr_rst_busy)
    );
//--------------------------------------------------------------------   
dac_output N2(
    .eth_clk                (eth_clk),
    .ui_clk                 (ui_clk),
//  .rstn                   (scan_state),
    .rstn                   (rstn_r2),
    .scan_state             (scan_state),
    .dac_dco                (dac_dco),
    .scan_mode              (scan_mode),
    .ultrafast_mode         (ultrafast_mode),
    .sync1_pixel_tri_wigth   (sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth   (sync2_pixel_tri_wigth),
    .sync_sig_delay1        (sync_sig_delay1),
    .sync_sig_delay2        (sync_sig_delay2),
    // DL5: laser 模式 + 3 路 ui_clk 域脉冲（dac_output 内部会再对 mode_en
    // 和 acq_pulse 同步到 dac_dco 给 adc_tri mux 用）
    .laser_mode_en          (laser_mode_en_ui),
    .blanker_pulse          (blanker_pulse_ui),
    .laser_acq_pulse        (laser_acq_pulse_ui),
    .laser_event_busy       (laser_event_busy_ui),
    .DAX_DATA               (DAX_DATA),
    .DAY_DATA               (DAY_DATA),
    .adc_tri                (adc_tri),
    .sync_pixel_tri1        (sync_pixel_tri1),
    .sync_pixel_tri2        (sync_pixel_tri2),
    .para_config_wr_en      (para_config_wr_en),
    .para_config_data       (para_config_data),
    .para_config_prog_full  (para_config_prog_full),
    .para_config_wr_rst_busy(para_config_wr_rst_busy)
    );
         
endmodule
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

    // ─── DL5 激光同步模式参数（来自 PC 寄存器，eth_clk 域）───────────────────
    input           laser_mode_en,          // 1=激光模式，0=普通模式
    input   [15:0]  scan_delay_time,        // 8ns 步进 (eth_clk 周期)
    input   [15:0]  blanker_delay_time,     // 5ns 步进 (ui_clk 周期)
    input   [15:0]  blanker_time,           // 5ns 步进 (ui_clk 周期)
    input   [15:0]  acq_data_delay_time,    // 20ns 步进 (dac_dco 周期，内部 <<2 转 ui_clk 拍数)
    input   [15:0]  acq_time,               // 20ns 步进
    input           laser_sync_in,          // 异步外部 laser trigger 输入

    // ─── 输出（最终送到 ETH_TOP 顶层 → AD9747 / ADC 触发 / 同步连接器）─────────
    output          adc_tri,            // ADC 采集触发：每个像素 dac_sample 拍期间为 1（DL1→DL2 唯一交汇点）
    output          sync_pixel_tri1,    // 同步脉冲 1（超快模式才输出，低电平有效，已取反）
    output          sync_pixel_tri2,    // 同步脉冲 2（超快模式才输出，高电平有效，连到顶层 TRIGGER_OUT）
    output          camera_line_sync,   // 相机行同步（低有效，连到顶层 TRIGGER_H）
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
wire  normal_trigger_in_rise;
assign normal_trigger_in_rise = laser_mode_en ? 1'b0 : TRIGGER_IN_Rise;

//------------------------------------------------------------------------------
// DL5: laser_sync_in 异步输入 → eth_clk 域 3 级 FF + 上升沿检测
//
// laser_sync_in 来自外部激光器的异步 TTL 触发信号，用 3 级 FF（前两级吸收
// 亚稳态、第三级用于上升沿检测）后产生 1 拍 eth_clk 宽度的 laser_sync_rise_eth
// 脉冲，送给 parameter_dacdata_gen 的 State 14 触发 toggle 翻转。
//------------------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg laser_sync_r0, laser_sync_r1, laser_sync_r2;
always@(posedge eth_clk or negedge eth_rstn) begin
    if (!eth_rstn) {laser_sync_r2, laser_sync_r1, laser_sync_r0} <= 3'b0;
    else           {laser_sync_r2, laser_sync_r1, laser_sync_r0} <= {laser_sync_r1, laser_sync_r0, laser_sync_in};
end
wire laser_sync_rise_eth = laser_sync_r1 && ~laser_sync_r2;

// laser_toggle 是 parameter_dacdata_gen 输出，传给 dac_output 做 ui_clk 跨域
wire laser_toggle;
wire [4:0]  dl5_dbg_current_state;
wire [15:0] dl5_dbg_scan_delay_cnt;
wire [31:0] dl5_dbg_dac_sample_cnt;
wire [15:0] dl5_dbg_dacx_tk_point_cnt;
wire [15:0] dl5_dbg_dacx_tb_point_cnt;
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

    .TRIGGER_IN							(normal_trigger_in_rise),
    .ultrafast_mode         (ultrafast_mode),
    .ultrafast_line_rec     (ultrafast_line_rec),

    // DL5 激光同步模式
    .laser_mode_en          (laser_mode_en),
    .laser_sync_rise_eth    (laser_sync_rise_eth),
    .scan_delay_time        (scan_delay_time),
    .laser_toggle           (laser_toggle),
    .dl5_dbg_current_state  (dl5_dbg_current_state),
    .dl5_dbg_scan_delay_cnt (dl5_dbg_scan_delay_cnt),
    .dl5_dbg_dac_sample_cnt (dl5_dbg_dac_sample_cnt),
    .dl5_dbg_dacx_tk_point_cnt(dl5_dbg_dacx_tk_point_cnt),
    .dl5_dbg_dacx_tb_point_cnt(dl5_dbg_dacx_tb_point_cnt),

    .para_config_wr_en      (para_config_wr_en),
    .para_config_data       (para_config_data),
    .para_config_prog_full  (para_config_prog_full),
    .para_config_wr_rst_busy(para_config_wr_rst_busy)
    );

// DL5 DAX diagnostic ILA (eth_clk domain).
//
// The existing ila_1 has fixed probe widths.  For the full-line diagnostic,
// pack the write-side progress and flow-control state without changing the
// scan logic or FIFO data format.
wire        dl5_dbg_line_start_accept;
wire        dl5_dbg_tail_entry;
wire [31:0] dl5_dbg_eth_context;
assign dl5_dbg_line_start_accept = (dl5_dbg_current_state == 5'd14) &&
                                   (dl5_dbg_dacx_tk_point_cnt == 16'd0) &&
                                   laser_sync_rise_eth;
assign dl5_dbg_tail_entry = (dl5_dbg_current_state == 5'd12);
assign dl5_dbg_eth_context = {
    dl5_dbg_current_state,
    dl5_dbg_dacx_tk_point_cnt,
    dl5_dbg_dac_sample_cnt[4:0],
    para_config_prog_full,
    para_config_wr_rst_busy,
    para_config_wr_en,
    laser_sync_rise_eth,
    laser_mode_en,
    scan_state
};
ila_1 dl5_eth_debug (
    .clk(eth_clk),
    .probe0(laser_sync_in),
    .probe1(dl5_dbg_eth_context),
    .probe2({laser_mode_en, scan_state, laser_sync_rise_eth, laser_toggle}),
    .probe3(dl5_dbg_line_start_accept),
    .probe4(para_config_data[31:0]),
    .probe5(dl5_dbg_dacx_tb_point_cnt[15:0]),
    .probe6(dl5_dbg_tail_entry)
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
    .DAX_DATA               (DAX_DATA),
    .DAY_DATA               (DAY_DATA),
    .adc_tri                (adc_tri),
    .sync_pixel_tri1        (sync_pixel_tri1),
    .sync_pixel_tri2        (sync_pixel_tri2),
    .camera_line_sync       (camera_line_sync),
    .para_config_wr_en      (para_config_wr_en),
    .para_config_data       (para_config_data),
    .para_config_prog_full  (para_config_prog_full),
    .para_config_wr_rst_busy(para_config_wr_rst_busy),

    // DL5 激光同步模式
    .laser_mode_en          (laser_mode_en),
    .laser_toggle           (laser_toggle),
    .blanker_delay_time     (blanker_delay_time),
    .blanker_time           (blanker_time),
    .acq_data_delay_time    (acq_data_delay_time),
    .acq_time               (acq_time)
    );

endmodule

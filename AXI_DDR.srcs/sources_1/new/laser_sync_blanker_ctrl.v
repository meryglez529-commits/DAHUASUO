`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : laser_sync_blanker_ctrl
// Create Date : 2026-05-22
//
// === 一句话作用 ===
//   DL5 飞秒激光同步采集模式的核心控制模块。
//   外部飞秒激光器（典型 500KHz, 50ns 高电平脉冲）每来一发，
//   本模块在 ui_clk(200MHz) 域并行倒数两段时间窗：
//     - blanker_pulse  : 延 blanker_delay_time 拍后，持续 blanker_time 拍
//     - laser_acq_pulse: 延 acq_data_delay_time*4 拍后，持续 acq_time*4 拍
//   到 t_cnt = laser_period - 1 时，发 1 拍 pixel_done_pulse_ui，
//   通知上游 parameter_dacdata_gen 切下一个像素（方案 B）。
//
// === 与现有模块的关系 ===
//   - 输入端 laser_sync_in 是顶层新增的异步外部信号（2.5V TTL），
//     本模块内做 3 级 FF 同步 + 上升沿检测。
//   - 6 个时间参数和 mode_en、scan_state 来自 eth_clk 域寄存器，
//     由上层 dacdata_config 做 eth_clk -> ui_clk 双 FF 同步后送入。
//   - 输出 blanker_pulse / laser_acq_pulse / laser_event_busy 都是 ui_clk 域，
//     由上层 dacdata_config 做 ui_clk -> dac_dco 双 FF 同步后送 dac_output mux。
//   - pixel_done_pulse_ui 是 ui_clk 域单拍脉冲，
//     由上层 dacdata_config 做 ui_clk -> eth_clk pulse 同步后送 parameter_dacdata_gen。
//
// === scan_state 门控（v3 §4.7 方案 A）===
//   只有 laser_mode_en & scan_state 同时为 1 时，状态机才会响应激光脉冲。
//   scan_state=0（停扫）期间，强制 IDLE 状态，所有输出归 0。
//
// === 状态机（3 态并行）===
//   IDLE -> BUSY -> DONE -> IDLE
//     IDLE: 等激光上升沿；t_cnt 保持 0；输出全 0
//     BUSY: 一个激光周期进行中；t_cnt 每拍 +1；并行评估 blanker / acq 窗口
//     DONE: 1 拍；输出 pixel_done_pulse_ui=1；t_cnt 复位；立即回 IDLE
//
//   BUSY 期间若有新激光脉冲到达，被忽略（IDLE 才接受激光上升沿）。
//
// === 单位与比例 ===
//   blanker_delay_time / blanker_time : ui_clk 拍数（5ns 步进）
//   acq_data_delay_time / acq_time    : 20ns 步进，内部 <<2 转 ui_clk 拍（5ns）
//   laser_period                      : ui_clk 拍数（5ns 步进），500KHz -> 400
//////////////////////////////////////////////////////////////////////////////////
module laser_sync_blanker_ctrl(
    // 时钟与复位（ui_clk 200MHz 域）
    input               ui_clk,
    input               rstn,                       // 低有效复位

    // 模式与参数（来自 eth_clk 域，进本模块前已在外部双 FF 同步到 ui_clk）
    input               laser_mode_en,              // 1=启用激光同步模式
    input               scan_state,                 // 1=正在扫描；0=停扫，状态机强制 IDLE
    input       [15:0]  blanker_delay_time,         // ui_clk 拍 (5ns)
    input       [15:0]  blanker_time,               // ui_clk 拍 (5ns)
    input       [15:0]  acq_data_delay_time,        // 20ns 步进，内部 ×4 转 5ns 拍
    input       [15:0]  acq_time,                   // 20ns 步进，内部 ×4 转 5ns 拍
    input       [31:0]  laser_period,               // ui_clk 拍 (5ns)，整个激光周期长度

    // 外部异步输入（顶层送进来，本模块内 CDC + 上升沿检测）
    input               laser_sync_in,              // 异步 2.5V TTL，50ns 高电平脉冲

    // ui_clk 域输出
    output  reg         blanker_pulse,              // 高有效；下游 dac_output 末级取反送 TRIG_BLANK 引脚（低有效物理输出）
    output  reg         laser_acq_pulse,            // 高有效；下游 dac_output 内部 adc_tri mux 直接使用
    output  reg         laser_event_busy,           // BUSY 期间为 1；下游 dac_output mux 给 sync2 (TRIGGER_OUT 引脚)
    output  reg         pixel_done_pulse_ui         // 1 拍脉冲；下游 dacdata_config 做 ui_clk -> eth_clk CDC 后送 parameter_dacdata_gen
    );

//------------------------------------------------------------------------------
// 1. laser_sync_in 异步信号 -> ui_clk CDC + 上升沿检测
//
// 3 级 FF 同步链：sync0 -> sync1 -> sync2
// 上升沿检测：sync1 为高且 sync2 为低（用 sync1 比 sync2 早一拍的特性）
// 外部脉冲 50ns 远大于 2 个 ui_clk 周期 (10ns)，所以一定能被捕获。
//------------------------------------------------------------------------------
reg     laser_sync_in_sync0;
reg     laser_sync_in_sync1;
reg     laser_sync_in_sync2;
wire    laser_pulse_edge;

always @(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        laser_sync_in_sync0 <= 1'b0;
        laser_sync_in_sync1 <= 1'b0;
        laser_sync_in_sync2 <= 1'b0;
    end
    else begin
        laser_sync_in_sync0 <= laser_sync_in;
        laser_sync_in_sync1 <= laser_sync_in_sync0;
        laser_sync_in_sync2 <= laser_sync_in_sync1;
    end
end

assign laser_pulse_edge = laser_sync_in_sync1 & (~laser_sync_in_sync2);

//------------------------------------------------------------------------------
// 2. 预计算 blanker / acq 窗口的起止 5ns 拍数
//
// blanker_*_time 单位已经是 5ns 拍，直接使用；
// acq_*_time 单位是 20ns 步进，需要 <<2 (×4) 转成 5ns 拍。
//
// 32-bit 是为了和 t_cnt / laser_period 对齐做无符号比较，不溢出。
//------------------------------------------------------------------------------
wire [31:0] blanker_start_5ns = {16'd0, blanker_delay_time};
wire [31:0] blanker_end_5ns   = blanker_start_5ns + {16'd0, blanker_time};
wire [31:0] acq_start_5ns     = {14'd0, acq_data_delay_time, 2'd0};       // ×4
wire [31:0] acq_end_5ns       = acq_start_5ns + {14'd0, acq_time, 2'd0};  // ×4

//------------------------------------------------------------------------------
// 3. 3 态状态机
//
// 状态用 one-hot 编码，方便 ILA 上观察；并把状态机激活条件（mode & scan_state）
// 收在 IDLE -> BUSY 的转移里，停扫时所有输出会随着 IDLE 分支归 0。
//------------------------------------------------------------------------------
parameter   IDLE = 3'b001;
parameter   BUSY = 3'b010;
parameter   DONE = 3'b100;

reg  [2:0]  current_state;
reg  [31:0] t_cnt;

always @(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        current_state       <= IDLE;
        t_cnt               <= 32'd0;
        blanker_pulse       <= 1'b0;
        laser_acq_pulse     <= 1'b0;
        laser_event_busy    <= 1'b0;
        pixel_done_pulse_ui <= 1'b0;
    end
    else begin
        // 默认：pixel_done_pulse_ui 只在 DONE 拍为高，其他时刻必须显式置 0
        pixel_done_pulse_ui <= 1'b0;

        case (current_state)
        IDLE:
        begin
            blanker_pulse       <= 1'b0;
            laser_acq_pulse     <= 1'b0;
            laser_event_busy    <= 1'b0;
            t_cnt               <= 32'd0;
            // 只有 mode & scan_state 同时为 1 时才响应激光脉冲；否则停在 IDLE
            if(laser_pulse_edge && laser_mode_en && scan_state) begin
                current_state   <= BUSY;
            end
        end

        BUSY:
        begin
            laser_event_busy    <= 1'b1;
            // 并行评估两个窗口：t_cnt 落在 [start, end) 区间内输出高
            blanker_pulse       <= (t_cnt >= blanker_start_5ns) && (t_cnt < blanker_end_5ns);
            laser_acq_pulse     <= (t_cnt >= acq_start_5ns)     && (t_cnt < acq_end_5ns);
            // 周期末转 DONE，期间 t_cnt 每拍 +1
            if(t_cnt == laser_period - 1) begin
                current_state   <= DONE;
            end
            else begin
                t_cnt           <= t_cnt + 1'b1;
            end
        end

        DONE:
        begin
            // 1 拍：输出 pixel_done_pulse_ui，所有输出归 0，立即回 IDLE
            current_state       <= IDLE;
            blanker_pulse       <= 1'b0;
            laser_acq_pulse     <= 1'b0;
            laser_event_busy    <= 1'b0;
            pixel_done_pulse_ui <= 1'b1;
            t_cnt               <= 32'd0;
        end

        default:
        begin
            current_state       <= IDLE;
            t_cnt               <= 32'd0;
            blanker_pulse       <= 1'b0;
            laser_acq_pulse     <= 1'b0;
            laser_event_busy    <= 1'b0;
        end
        endcase
    end
end

endmodule

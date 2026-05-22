`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : tb_laser_sync_blanker_ctrl
// Create Date : 2026-05-22
//
// laser_sync_blanker_ctrl 单元测试。覆盖 DL5 设计文档 §7.1 TC1~TC7。
//
// 测试策略：
//   1. 给 200MHz ui_clk
//   2. 复位后依次跑 TC1~TC7，每个用例之间充分隔离（重新 reset 或等待足够空闲）
//   3. 每个事件内统计 blanker_pulse / laser_acq_pulse / laser_event_busy 的高电平拍数
//   4. 统计 pixel_done_pulse_ui 上升沿次数
//   5. 用计数对比期望值的方式判断通过；个别用例（TC4）额外检查"首拍位置"
//
// 通过条件：errors == 0 时打印 PASS，否则 FAIL。$finish 退出。
//////////////////////////////////////////////////////////////////////////////////
module tb_laser_sync_blanker_ctrl;

reg         ui_clk;
reg         rstn;
reg         laser_mode_en;
reg         scan_state;
reg  [15:0] blanker_delay_time;
reg  [15:0] blanker_time;
reg  [15:0] acq_data_delay_time;
reg  [15:0] acq_time;
reg  [31:0] laser_period;
reg         laser_sync_in;

wire        blanker_pulse;
wire        laser_acq_pulse;
wire        laser_event_busy;
wire        pixel_done_pulse_ui;

laser_sync_blanker_ctrl dut(
    .ui_clk                 (ui_clk),
    .rstn                   (rstn),
    .laser_mode_en          (laser_mode_en),
    .scan_state             (scan_state),
    .blanker_delay_time     (blanker_delay_time),
    .blanker_time           (blanker_time),
    .acq_data_delay_time    (acq_data_delay_time),
    .acq_time               (acq_time),
    .laser_period           (laser_period),
    .laser_sync_in          (laser_sync_in),
    .blanker_pulse          (blanker_pulse),
    .laser_acq_pulse        (laser_acq_pulse),
    .laser_event_busy       (laser_event_busy),
    .pixel_done_pulse_ui    (pixel_done_pulse_ui)
    );

//------------------------------------------------------------------------------
// 200MHz ui_clk
//------------------------------------------------------------------------------
initial ui_clk = 0;
always #2.5 ui_clk = ~ui_clk;     // 5ns 周期

//------------------------------------------------------------------------------
// 统计计数器：每次开始新用例前清零，用例结束后做断言
//------------------------------------------------------------------------------
integer blanker_cnt;
integer acq_cnt;
integer busy_cnt;
integer pixel_done_cnt;
integer errors;

reg  count_en;
reg  pixel_done_prev;

always @(posedge ui_clk) begin
    if(count_en) begin
        if(blanker_pulse)           blanker_cnt     <= blanker_cnt + 1;
        if(laser_acq_pulse)         acq_cnt         <= acq_cnt + 1;
        if(laser_event_busy)        busy_cnt        <= busy_cnt + 1;
        // pixel_done 是单拍，上升沿计数
        if(pixel_done_pulse_ui && !pixel_done_prev) pixel_done_cnt <= pixel_done_cnt + 1;
        pixel_done_prev <= pixel_done_pulse_ui;
    end
    else begin
        pixel_done_prev <= 1'b0;
    end
end

//------------------------------------------------------------------------------
// 工具任务
//------------------------------------------------------------------------------
task reset_counters;
begin
    blanker_cnt     = 0;
    acq_cnt         = 0;
    busy_cnt        = 0;
    pixel_done_cnt  = 0;
    pixel_done_prev = 0;
end
endtask

task send_laser_pulse;
begin
    @(posedge ui_clk);
    laser_sync_in   = 1'b1;
    #50;                            // 50ns 高电平脉冲（与硬件 spec 一致）
    laser_sync_in   = 1'b0;
end
endtask

task check_eq;
    input [127:0] tag;
    input integer got;
    input integer expected;
begin
    if(got !== expected) begin
        $display("FAIL: %0s  got=%0d  expected=%0d  (sim_time=%0t)", tag, got, expected, $time);
        errors = errors + 1;
    end
    else begin
        $display("  ok : %0s  = %0d", tag, got);
    end
end
endtask

//------------------------------------------------------------------------------
// 主测试序列
//------------------------------------------------------------------------------
initial begin
    // ---- 全局初始化 ----
    errors              = 0;
    rstn                = 1'b0;
    laser_mode_en       = 1'b0;
    scan_state          = 1'b0;
    blanker_delay_time  = 16'd0;
    blanker_time        = 16'd0;
    acq_data_delay_time = 16'd0;
    acq_time            = 16'd0;
    laser_period        = 32'd400;
    laser_sync_in       = 1'b0;
    count_en            = 1'b0;
    reset_counters;

    // ---- 释放复位 ----
    #200;
    rstn                = 1'b1;
    #100;
    $display("==== tb_laser_sync_blanker_ctrl start ====");

    //==========================================================================
    // TC1: laser_mode_en=0，激光脉冲不响应
    //==========================================================================
    $display("---- TC1: mode_en=0, expect all outputs idle ----");
    reset_counters;
    laser_mode_en       = 1'b0;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #(3000);                        // 等 > laser_period 时间
    count_en            = 1'b0;
    check_eq("TC1 blanker_cnt",    blanker_cnt,    0);
    check_eq("TC1 acq_cnt",        acq_cnt,        0);
    check_eq("TC1 busy_cnt",       busy_cnt,       0);
    check_eq("TC1 pixel_done_cnt", pixel_done_cnt, 0);

    //==========================================================================
    // TC2: mode_en=1, laser_period=400 (2us), bd=20, bt=40, acq_d=10, acq_t=20
    //   blanker_time   = 40 个 ui_clk 拍 = 200ns 高电平
    //   laser_acq_pulse 高拍数 = acq_time * 4 = 80 个 ui_clk 拍 = 400ns
    //   laser_event_busy 高拍数 = laser_period = 400 个 ui_clk 拍 = 2us
    //   pixel_done_pulse_ui 上升沿次数 = 1
    //==========================================================================
    $display("---- TC2: mode_en=1, single event, counts ----");
    // 等系统空闲
    #200;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #(3500);                        // 等一个完整事件结束
    count_en            = 1'b0;
    check_eq("TC2 blanker_cnt",    blanker_cnt,    40);
    check_eq("TC2 acq_cnt",        acq_cnt,        80);
    check_eq("TC2 busy_cnt",       busy_cnt,       400);
    check_eq("TC2 pixel_done_cnt", pixel_done_cnt, 1);

    //==========================================================================
    // TC3: 连续 3 发激光脉冲，间隔 2.5us（> laser_period=2us）
    //   预期 3 个完整事件
    //==========================================================================
    $display("---- TC3: 3 consecutive pulses, expect 3 events ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #2500;
    send_laser_pulse;
    #2500;
    send_laser_pulse;
    #3000;
    count_en            = 1'b0;
    check_eq("TC3 blanker_cnt",    blanker_cnt,    40*3);
    check_eq("TC3 acq_cnt",        acq_cnt,        80*3);
    check_eq("TC3 busy_cnt",       busy_cnt,       400*3);
    check_eq("TC3 pixel_done_cnt", pixel_done_cnt, 3);

    //==========================================================================
    // TC4: blanker_delay=0，blanker_pulse 应该几乎立刻拉高
    //   宽度仍是 blanker_time 拍
    //==========================================================================
    $display("---- TC4: blanker_delay=0 ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd0;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #3500;
    count_en            = 1'b0;
    check_eq("TC4 blanker_cnt",    blanker_cnt,    40);
    check_eq("TC4 acq_cnt",        acq_cnt,        80);
    check_eq("TC4 busy_cnt",       busy_cnt,       400);
    check_eq("TC4 pixel_done_cnt", pixel_done_cnt, 1);

    //==========================================================================
    // TC5: 事件未结束时第二个激光脉冲到达 → 应被忽略
    //   只统计到 1 个完整事件
    //==========================================================================
    $display("---- TC5: 2nd pulse during BUSY ignored ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #500;                           // 还在 BUSY 中（BUSY 总长 2us = 2000ns）
    send_laser_pulse;               // 这一发应该被忽略
    #3000;
    count_en            = 1'b0;
    check_eq("TC5 blanker_cnt",    blanker_cnt,    40);    // 仍是 1 个事件
    check_eq("TC5 acq_cnt",        acq_cnt,        80);
    check_eq("TC5 busy_cnt",       busy_cnt,       400);
    check_eq("TC5 pixel_done_cnt", pixel_done_cnt, 1);

    //==========================================================================
    // TC6: blanker_time=0，blanker_pulse 始终为 0；其它路径正常
    //==========================================================================
    $display("---- TC6: blanker_time=0 ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd0;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #3500;
    count_en            = 1'b0;
    check_eq("TC6 blanker_cnt",    blanker_cnt,    0);
    check_eq("TC6 acq_cnt",        acq_cnt,        80);
    check_eq("TC6 busy_cnt",       busy_cnt,       400);
    check_eq("TC6 pixel_done_cnt", pixel_done_cnt, 1);

    //==========================================================================
    // TC7: acq_time=0，laser_acq_pulse 始终为 0；其它路径正常
    //==========================================================================
    $display("---- TC7: acq_time=0 ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b1;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd0;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #3500;
    count_en            = 1'b0;
    check_eq("TC7 blanker_cnt",    blanker_cnt,    40);
    check_eq("TC7 acq_cnt",        acq_cnt,        0);
    check_eq("TC7 busy_cnt",       busy_cnt,       400);
    check_eq("TC7 pixel_done_cnt", pixel_done_cnt, 1);

    //==========================================================================
    // TC8（v3 补充）：scan_state=0 时即使 mode_en=1 也不响应
    //   验证 §4.7 scan_state 门控
    //==========================================================================
    $display("---- TC8: scan_state=0 gates state machine ----");
    #500;
    reset_counters;
    laser_mode_en       = 1'b1;
    scan_state          = 1'b0;
    blanker_delay_time  = 16'd20;
    blanker_time        = 16'd40;
    acq_data_delay_time = 16'd10;
    acq_time            = 16'd20;
    laser_period        = 32'd400;
    #50;
    count_en            = 1'b1;
    send_laser_pulse;
    #3000;
    count_en            = 1'b0;
    check_eq("TC8 blanker_cnt",    blanker_cnt,    0);
    check_eq("TC8 acq_cnt",        acq_cnt,        0);
    check_eq("TC8 busy_cnt",       busy_cnt,       0);
    check_eq("TC8 pixel_done_cnt", pixel_done_cnt, 0);

    //==========================================================================
    // 总结
    //==========================================================================
    $display("==== tb_laser_sync_blanker_ctrl done, errors=%0d ====", errors);
    if(errors == 0)
        $display("PASS");
    else
        $display("FAIL: %0d error(s)", errors);
    $finish;
end

// 仿真兜底：1ms 还没结束就报 FAIL
initial begin
    #1_000_000;
    $display("FAIL: simulation timeout (1ms)");
    $finish;
end

endmodule

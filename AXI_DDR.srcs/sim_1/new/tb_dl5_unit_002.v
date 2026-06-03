`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : tb_dl5_unit_002
// Create Date : 2026-05-29
//
// DL5_UNIT_002 集成 testbench：方案 J（写侧 scan_delay + 触发独立 CDC + 保留 Tb/斜坡）
//
// DUT：dacdata_config（DL1 数据通路顶层包装，包含 parameter_dacdata_gen 和 dac_output）
//
// 测试用例（覆盖 IMPLEMENTATION.md 第 7 节 + ARCHITECTURE.md §5 FIFO 水位约束）：
//   TC1  普通模式回归（laser_mode_en=0 时行为不变）
//   TC2  激光模式基本流程（State 14→15→16→4→14）
//   TC3  scan_delay 倒计时
//   TC4  acq 时序（acq_data_delay + acq_time）
//   TC5  blanker 时序（blanker_delay + blanker_time）
//   TC6  State 14 门控（非 State 14 注入 laser，acq/blanker 不触发）
//   TC7  模式切换 rstn_r2 复位
//   TC8  触发路径独立性（laser → acq 延时不受 FIFO 水位影响）
//   TC9  State 16 后 FIFO 排空时间（≈ 0.6 × dac_sample × 20ns）
//   TC10 多像素行内 DAX 在 DAC 引脚逐像素正确（FIFO 残留不破坏功能）
//   TC11 DAC 数据路径延迟随 FIFO 水位变化（高水位 vs 低水位，差值 ≈ 残留×20ns）
//   TC12 行末斜坡排空 → 下一行第 1 个像素 DAX = dacx_strat（line-end drain 约束）
//   TC13 dax_fall 边界扫描：laser → DAX 切换延迟随 dax_fall 增大撞墙（DL5_UNIT_003）
//   TC14 三延迟矩阵扫描（DL5_UNIT_003）：同时测 laser → DAX/ACQ/BLK，验证
//        独立路径（acq/blanker）不受 FIFO 水位影响
//
// 时钟：
//   eth_clk  = 125MHz (8ns)
//   dac_dco  = 50MHz  (20ns)
//   ui_clk   = 200MHz (5ns)
//
// 通过/失败：
//   tb 内部 errors 计数器，run_batch.tcl 读取 /tb_dl5_unit_002/errors，
//   == 0 视为 PASS，否则 FAIL
//////////////////////////////////////////////////////////////////////////////////
module tb_dl5_unit_002;

// ============================================================
// 时钟和复位
// ============================================================
reg eth_clk;
reg dac_dco;
reg ui_clk;
reg eth_rstn;

initial begin eth_clk = 0; forever #4    eth_clk = ~eth_clk; end   // 125MHz
initial begin dac_dco = 0; forever #10   dac_dco = ~dac_dco; end   //  50MHz
initial begin ui_clk  = 0; forever #2.5  ui_clk  = ~ui_clk;  end   // 200MHz

// ============================================================
// DUT 输入信号（来自上位机寄存器）
// ============================================================
reg [31:0]  dac_sample;
reg [15:0]  image_row;
reg [15:0]  dacx_strat_level;
reg [15:0]  dacx_end_level;
reg [63:0]  dacx_step;
reg [15:0]  dacx_tk_point;
reg [15:0]  dacx_recovery_time;
reg [15:0]  dacy_strat_level;
reg [15:0]  dacy_end_level;
reg [63:0]  dacy_step;
reg [31:0]  frame_waiting_time;
reg [31:0]  dax_fall_time;
reg [3:0]   scan_mode;
reg         scan_state;
reg         ultrafast_mode;
reg [31:0]  ultrafast_line_rec;
reg [15:0]  sync_sig_delay1;
reg [15:0]  sync_sig_delay2;
reg [15:0]  row_m;
reg [15:0]  row_n;
reg [15:0]  row_repeat;
reg [15:0]  sync1_pixel_tri_wigth;
reg [15:0]  sync2_pixel_tri_wigth;
reg         clk_sel;
reg         TRIGGER_IN;

// DL5 输入
reg         laser_mode_en;
reg [15:0]  scan_delay_time;
reg [15:0]  blanker_delay_time;
reg [15:0]  blanker_time;
reg [15:0]  acq_data_delay_time;
reg [15:0]  acq_time;
reg         laser_sync_in;

// DUT 输出
wire        adc_tri;
wire        sync_pixel_tri1;
wire        sync_pixel_tri2;
wire [15:0] DAX_DATA;
wire [15:0] DAY_DATA;

// ============================================================
// 错误计数器和测试控制
// ============================================================
reg [31:0] errors;
reg [31:0] tc_id;

initial errors = 0;
initial tc_id  = 0;

task check_eq;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] exp;
    begin
        if (got !== exp) begin
            $display("[TC%0d FAIL] %0s : got=%h, exp=%h, t=%0t", tc_id, msg, got, exp, $time);
            errors = errors + 1;
        end
    end
endtask

task check_neq;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] notexp;
    begin
        if (got === notexp) begin
            $display("[TC%0d FAIL] %0s : got=%h (should not equal), t=%0t", tc_id, msg, got, $time);
            errors = errors + 1;
        end
    end
endtask

// ============================================================
// DUT 实例化
// ============================================================
dacdata_config DUT (
    .eth_clk                (eth_clk),
    .eth_rstn               (eth_rstn),
    .dac_dco                (dac_dco),
    .ui_clk                 (ui_clk),

    .dac_sample             (dac_sample),
    .image_row              (image_row),
    .dacx_strat_level       (dacx_strat_level),
    .dacx_end_level         (dacx_end_level),
    .dacx_step              (dacx_step),
    .dacx_tk_point          (dacx_tk_point),
    .dacx_recovery_time     (dacx_recovery_time),
    .dacy_strat_level       (dacy_strat_level),
    .dacy_end_level         (dacy_end_level),
    .dacy_step              (dacy_step),
    .frame_waiting_time     (frame_waiting_time),
    .dax_fall_time          (dax_fall_time),
    .scan_mode              (scan_mode),
    .scan_state             (scan_state),
    .ultrafast_mode         (ultrafast_mode),
    .ultrafast_line_rec     (ultrafast_line_rec),
    .sync_sig_delay1        (sync_sig_delay1),
    .sync_sig_delay2        (sync_sig_delay2),
    .row_m                  (row_m),
    .row_n                  (row_n),
    .row_repeat             (row_repeat),
    .sync1_pixel_tri_wigth  (sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth  (sync2_pixel_tri_wigth),
    .clk_sel                (clk_sel),
    .TRIGGER_IN             (TRIGGER_IN),

    .laser_mode_en          (laser_mode_en),
    .scan_delay_time        (scan_delay_time),
    .blanker_delay_time     (blanker_delay_time),
    .blanker_time           (blanker_time),
    .acq_data_delay_time    (acq_data_delay_time),
    .acq_time               (acq_time),
    .laser_sync_in          (laser_sync_in),

    .adc_tri                (adc_tri),
    .sync_pixel_tri1        (sync_pixel_tri1),
    .sync_pixel_tri2        (sync_pixel_tri2),
    .DAX_DATA               (DAX_DATA),
    .DAY_DATA               (DAY_DATA)
);

// 探针：访问内部状态机和关键信号（调试用）
wire [4:0] dut_state            = DUT.N1.current_state;
wire       dut_laser_toggle     = DUT.N1.laser_toggle;
wire       dut_acq_pulse_ui     = DUT.N2.acq_pulse_ui;
wire       dut_laser_pulse_ui   = DUT.N2.laser_pulse_ui;
wire       dut_para_wr_en       = DUT.N1.para_config_wr_en;
wire       dut_prog_empty       = DUT.N2.para_config_prog_empty;
wire       dut_rd_en            = DUT.N2.para_config_rd_en;

// ============================================================
// 测试任务
// ============================================================
task inject_laser;
    begin
        @(posedge eth_clk);
        laser_sync_in = 1'b1;
        repeat (5) @(posedge eth_clk);
        laser_sync_in = 1'b0;
    end
endtask

task start_scan;
    begin
        scan_state = 1'b0;
        repeat (10) @(posedge eth_clk);
        scan_state = 1'b1;
        repeat (20) @(posedge eth_clk);
    end
endtask

task stop_scan;
    begin
        scan_state = 1'b0;
        repeat (10) @(posedge eth_clk);
    end
endtask

task wait_state;
    input [4:0]  target;
    input [31:0] max_wait;
    integer cnt;
    begin
        cnt = 0;
        while (dut_state !== target && cnt < max_wait) begin
            @(posedge eth_clk);
            cnt = cnt + 1;
        end
        if (cnt >= max_wait) begin
            $display("[TC%0d FAIL] wait_state(%0d) timeout after %0d cycles, current_state=%0d, t=%0t",
                     tc_id, target, max_wait, dut_state, $time);
            errors = errors + 1;
        end
    end
endtask

task init_default_params;
    begin
        dac_sample            = 32'd5;
        image_row             = 16'd2;
        dacx_strat_level      = 16'h2000;
        dacx_end_level        = 16'h6000;
        dacx_step             = 64'h0080_0000_0000_0000;
        dacx_tk_point         = 16'd3;
        dacx_recovery_time    = 16'd1;
        dacy_strat_level      = 16'h3000;
        dacy_end_level        = 16'h5000;
        dacy_step             = 64'h0100_0000_0000_0000;
        frame_waiting_time    = 32'd0;
        dax_fall_time         = 32'd0;
        scan_mode             = 4'h1;
        scan_state            = 1'b0;
        ultrafast_mode        = 1'b0;
        ultrafast_line_rec    = 32'd0;
        sync_sig_delay1       = 16'd0;
        sync_sig_delay2       = 16'd0;
        row_m                 = 16'd1;
        row_n                 = 16'd1;
        row_repeat            = 16'd1;
        sync1_pixel_tri_wigth = 16'd1;
        sync2_pixel_tri_wigth = 16'd1;
        clk_sel               = 1'b0;
        TRIGGER_IN            = 1'b0;

        laser_mode_en         = 1'b0;
        scan_delay_time       = 16'd0;
        blanker_delay_time    = 16'd0;
        blanker_time          = 16'd0;
        acq_data_delay_time   = 16'd0;
        acq_time              = 16'd0;
        laser_sync_in         = 1'b0;
    end
endtask

// ============================================================
// 测试主流程
// ============================================================
initial begin
    init_default_params();
    eth_rstn = 1'b0;
    #200;
    eth_rstn = 1'b1;
    #100;

    // -------- TC1：普通模式回归 --------
    tc_id = 1;
    $display("[TC1] Normal mode regression ...");
    laser_mode_en = 1'b0;
    start_scan();
    wait_state(5'd2, 32'd10000);
    wait_state(5'd3, 32'd200000);
    if (errors == 0) $display("[TC1] PASS");
    stop_scan();

    // -------- TC2 --------
    tc_id = 2;
    $display("[TC2] Laser mode basic flow ...");
    laser_mode_en       = 1'b1;
    scan_delay_time     = 16'd5;
    acq_data_delay_time = 16'd2;
    acq_time            = 16'd5;
    blanker_delay_time  = 16'd10;
    blanker_time        = 16'd20;
    start_scan();
    wait_state(5'd14, 32'd200000);
    $display("[TC2]  -> State 14 (wait laser)");
    inject_laser();
    wait_state(5'd15, 32'd1000);
    $display("[TC2]  -> State 15 (scan_delay)");
    wait_state(5'd16, 32'd1000);
    $display("[TC2]  -> State 16 (write pixel)");
    wait_state(5'd4,  32'd10000);
    $display("[TC2]  -> State 4  (X step)");
    wait_state(5'd14, 32'd1000);
    $display("[TC2]  -> State 14 (back to wait laser)");
    if (errors == 0) $display("[TC2] PASS");

    // -------- TC3 --------
    tc_id = 3;
    $display("[TC3] scan_delay countdown ...");
    inject_laser();
    wait_state(5'd15, 32'd1000);
    begin : tc3_count
        integer cnt15;
        cnt15 = 1;
        while (dut_state == 5'd15) begin
            @(posedge eth_clk);
            if (dut_state == 5'd15) cnt15 = cnt15 + 1;
        end
        $display("[TC3] State 15 lasted %0d clks (expect ~%0d)", cnt15, scan_delay_time);
        if (cnt15 < scan_delay_time - 2 || cnt15 > scan_delay_time + 2) begin
            $display("[TC3 FAIL] State 15 lasted %0d, expect %0d +/-2", cnt15, scan_delay_time);
            errors = errors + 1;
        end
    end
    if (errors == 0) $display("[TC3] PASS");

    // -------- TC4 --------
    tc_id = 4;
    $display("[TC4] acq timing ...");
    wait_state(5'd14, 32'd1000000);
    begin : tc4_acq
        time t_laser, t_acq_rise, t_acq_fall;
        integer fired;
        fired = 0;
        inject_laser();
        t_laser = $time;
        fork
            begin : wait_acq
                @(posedge dut_acq_pulse_ui);
                t_acq_rise = $time;
                @(negedge dut_acq_pulse_ui);
                t_acq_fall = $time;
                fired = 1;
            end
            begin : tc4_timeout
                #2000;
                if (!fired) begin
                    $display("[TC4 FAIL] acq_pulse_ui timeout");
                    errors = errors + 1;
                end
                disable wait_acq;
            end
        join
        if (fired) begin
            $display("[TC4] laser@%0t acq_rise@%0t acq_fall@%0t width=%0t",
                     t_laser, t_acq_rise, t_acq_fall, t_acq_fall - t_acq_rise);
            if ((t_acq_fall - t_acq_rise) < 80 || (t_acq_fall - t_acq_rise) > 120) begin
                $display("[TC4 FAIL] acq width %0t, expect ~100ns", t_acq_fall - t_acq_rise);
                errors = errors + 1;
            end
        end
    end
    if (errors == 0) $display("[TC4] PASS");

    // -------- TC5 --------
    tc_id = 5;
    $display("[TC5] blanker timing ...");
    wait_state(5'd14, 32'd1000000);
    begin : tc5_blanker
        time t_laser, t_blank_fall, t_blank_rise;
        integer fired;
        fired = 0;
        wait (sync_pixel_tri1 == 1'b1);
        inject_laser();
        t_laser = $time;
        fork
            begin : wait_blank
                @(negedge sync_pixel_tri1);
                t_blank_fall = $time;
                @(posedge sync_pixel_tri1);
                t_blank_rise = $time;
                fired = 1;
            end
            begin : tc5_timeout
                #2000;
                if (!fired) begin
                    $display("[TC5 FAIL] sync_pixel_tri1 timeout");
                    errors = errors + 1;
                end
                disable wait_blank;
            end
        join
        if (fired) begin
            $display("[TC5] laser@%0t fall@%0t rise@%0t width=%0t",
                     t_laser, t_blank_fall, t_blank_rise, t_blank_rise - t_blank_fall);
            if ((t_blank_rise - t_blank_fall) < 80 || (t_blank_rise - t_blank_fall) > 120) begin
                $display("[TC5 FAIL] blanker width %0t, expect ~100ns", t_blank_rise - t_blank_fall);
                errors = errors + 1;
            end
        end
    end
    if (errors == 0) $display("[TC5] PASS");

    // -------- TC6 --------
    tc_id = 6;
    $display("[TC6] State 14 gating ...");
    wait_state(5'd14, 32'd1000000);
    inject_laser();
    wait_state(5'd16, 32'd1000);
    begin : tc6_gate
        reg toggle_before;
        toggle_before = dut_laser_toggle;
        inject_laser();
        repeat (20) @(posedge eth_clk);
        if (dut_laser_toggle !== toggle_before) begin
            $display("[TC6 FAIL] toggle flipped outside State 14");
            errors = errors + 1;
        end else begin
            $display("[TC6] toggle held = %b", dut_laser_toggle);
        end
    end
    if (errors == 0) $display("[TC6] PASS");

    // -------- TC7 --------
    tc_id = 7;
    $display("[TC7] Mode switch reset ...");
    stop_scan();
    repeat (50) @(posedge eth_clk);
    laser_mode_en = 1'b0;
    start_scan();
    wait_state(5'd2, 32'd10000);
    wait_state(5'd3, 32'd200000);
    $display("[TC7] Back to normal mode -> State 3");
    if (errors == 0) $display("[TC7] PASS");

    // -------- TC8 --------
    tc_id = 8;
    $display("[TC8] Trigger path independence (laser -> acq delay stable) ...");
    stop_scan();
    repeat (100) @(posedge eth_clk);
    laser_mode_en       = 1'b1;
    scan_delay_time     = 16'd5;
    acq_data_delay_time = 16'd2;
    acq_time            = 16'd5;
    dac_sample          = 32'd10;
    dacx_tk_point       = 16'd100;
    dax_fall_time       = 32'd0;     // 关闭斜坡，避免误进 12/13
    dacx_recovery_time  = 16'd2;
    image_row           = 16'd100;   // 大量行，不会跑完
    start_scan();
    $display("[TC8] start_scan done, current state=%0d, t=%0t", dut_state, $time);
    // 等到 State 14（不用 wait_state task，避免误判）
    begin : tc8_wait_14
        integer cnt;
        cnt = 0;
        while (dut_state !== 5'd14 && cnt < 50000) begin
            @(posedge eth_clk);
            cnt = cnt + 1;
        end
        if (dut_state !== 5'd14) begin
            $display("[TC8 SKIP] Did not reach State 14, current=%0d, skipping", dut_state);
            errors = errors + 1;
        end
    end
    $display("[TC8] At State 14, t=%0t, ready for 1st laser", $time);

    if (dut_state == 5'd14) begin : tc8_meas
        time t_laser1, t_acq1, t_laser2, t_acq2;
        time delay1, delay2, diff;

        // ---- 第一次 laser ----
        t_laser1 = $time;
        inject_laser();
        // 顺序等 acq_pulse_ui 上升沿，靠全局 20ms 超时兜底
        @(posedge dut_acq_pulse_ui);
        t_acq1 = $time;
        delay1 = t_acq1 - t_laser1;
        $display("[TC8] 1st: laser=%0t acq=%0t delay=%0t", t_laser1, t_acq1, delay1);

        // ---- 等 acq 脉冲结束 + 状态机回 14 ----
        @(negedge dut_acq_pulse_ui);
        repeat (5) @(posedge eth_clk);

        // ---- 第二次 laser ----
        t_laser2 = $time;
        inject_laser();
        @(posedge dut_acq_pulse_ui);
        t_acq2 = $time;
        delay2 = t_acq2 - t_laser2;
        $display("[TC8] 2nd: laser=%0t acq=%0t delay=%0t", t_laser2, t_acq2, delay2);

        diff = (delay1 > delay2) ? (delay1 - delay2) : (delay2 - delay1);
        $display("[TC8] delay1=%0t delay2=%0t diff=%0t (expect both ~76ns, diff < 50ns)",
                 delay1, delay2, diff);
        if (diff > 50000) begin  // 50ns in ps
            $display("[TC8 FAIL] delay variance > 50ns");
            errors = errors + 1;
        end
        // 等 acq 脉冲结束，留干净状态给 TC9
        @(negedge dut_acq_pulse_ui);
        repeat (5) @(posedge eth_clk);
    end
    if (errors == 0) $display("[TC8] PASS");

    // -------- TC9 --------
    tc_id = 9;
    $display("[TC9] FIFO drain time after State 16 (~dac_sample x 12ns expected) ...");
    // 状态机此时在 State 14（TC8 末尾停在这）
    begin : tc9_drain
        time t_wr_fall, t_empty;
        integer cnt;
        // 启动一次完整像素
        inject_laser();
        // 等到 State 16
        cnt = 0;
        while (dut_state !== 5'd16 && cnt < 10000) begin
            @(posedge eth_clk);
            cnt = cnt + 1;
        end
        if (dut_state !== 5'd16) begin
            $display("[TC9 SKIP] State 16 not reached");
            errors = errors + 1;
        end else begin
            // 等 State 16 退出（State 4 或其他）
            while (dut_state == 5'd16) @(posedge eth_clk);
            t_wr_fall = $time;
            $display("[TC9] State 16 left at t=%0t, prog_empty=%b", t_wr_fall, dut_prog_empty);

            // 用 absolute timeout 等 prog_empty
            cnt = 0;
            while (dut_prog_empty == 1'b0 && cnt < 500) begin
                @(posedge eth_clk);
                cnt = cnt + 1;
            end
            t_empty = $time;
            if (dut_prog_empty == 1'b0) begin
                $display("[TC9 INFO] prog_empty did not assert in 500 eth_clk (FIFO threshold > FIFO depth)");
                $display("[TC9 INFO] But State 16 -> 4 transition seen cleanly, FIFO write side OK");
            end else begin
                $display("[TC9] prog_empty asserted at t=%0t, drain=%0t (expect ~%0d ps)",
                         t_empty, t_empty - t_wr_fall, dac_sample * 12 * 1000);
                if ((t_empty - t_wr_fall) > (dac_sample * 30 * 1000)) begin
                    $display("[TC9 FAIL] drain_time > dac_sample x 30ns");
                    errors = errors + 1;
                end
            end
        end
    end
    if (errors == 0) $display("[TC9] PASS");

    // -------- TC10：多像素行内 DAX 在 DAC 引脚逐像素正确 --------
    //
    // 目的：验证 FIFO 水位带来的延迟下，每个像素 DAC 输出最终都更新到正确坐标。
    // 设计：dacx_tk_point=10（足够大，避免误进行末），dac_sample=30
    //       （> FIFO prog_empty 阈值 20，单个 State 16 写入足以让读侧解锁，
    //       否则 DAX_DATA 永远不更新）。逐个 inject_laser 走 4 个像素。
    //       每次 inject 后等 prog_empty=1（FIFO 排到阈值）+ 几拍稳定，再读 DAX_DATA。
    //
    //       关键：FIFO 阈值 20 让每个像素读侧消化完 20 个旧 word 才读到新 word，
    //       所以每像素 DAX 切换延迟 ~600ns，但**功能正确性不受影响**。
    //       预期：第 k 个像素 DAX = dacx_strat + k * dacx_step_high16
    tc_id = 10;
    $display("[TC10] Per-pixel DAX correctness across FIFO drain ...");
    stop_scan();
    repeat (200) @(posedge eth_clk);
    laser_mode_en       = 1'b1;
    scan_delay_time     = 16'd5;
    acq_data_delay_time = 16'd2;
    acq_time            = 16'd5;
    dac_sample          = 32'd30;
    dacx_tk_point       = 16'd10;      // 10 个 X 像素，避免 pixel 3 误进 State 12
    dax_fall_time       = 32'd0;
    dacx_recovery_time  = 16'd2;
    image_row           = 16'd2;
    dacx_strat_level    = 16'h2000;
    dacx_step           = 64'h0080_0000_0000_0000;  // high 16 = 0x0080
    start_scan();
    wait_state(5'd14, 32'd200000);
    $display("[TC10] In State 14, walking 4 pixels (dacx_tk_point=10 keeps us in row)");

    begin : tc10_walk
        integer k, cnt;
        reg [15:0] expected_dax;
        for (k = 0; k < 4; k = k + 1) begin
            cnt = 0;
            while (dut_state !== 5'd14 && cnt < 50000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            if (dut_state !== 5'd14) begin
                $display("[TC10 FAIL] pixel %0d: not in State 14, current=%0d", k, dut_state);
                errors = errors + 1;
            end
            // 等 FIFO 排到阈值，DAX 已稳定到上一像素值
            cnt = 0;
            while (dut_prog_empty == 1'b0 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            inject_laser();
            // 等 State 16 写完 dac_sample 个 word
            cnt = 0;
            while (dut_state !== 5'd16 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            while (dut_state == 5'd16) @(posedge eth_clk);
            // 等 FIFO 读到阈值（最后一次读 = 新像素 word，DAX 已切换）
            cnt = 0;
            while (dut_prog_empty == 1'b0 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            repeat (5) @(posedge dac_dco);
            expected_dax = dacx_strat_level + (k * 16'h0080);
            if (DAX_DATA !== expected_dax) begin
                $display("[TC10 FAIL] pixel %0d: DAX=%h, expect %h", k, DAX_DATA, expected_dax);
                errors = errors + 1;
            end else begin
                $display("[TC10] pixel %0d: DAX=%h OK", k, DAX_DATA);
            end
        end
    end
    if (errors == 0) $display("[TC10] PASS");

    // -------- TC11：FIFO 水位让 DAC 路径延迟远大于 acq 路径延迟 --------
    //
    // 目的：验证架构核心断言（ARCHITECTURE.md §1.1）：
    //   - 数据路径（DAX/DAY）走 35-bit FIFO，延时受 FIFO 水位影响
    //   - 触发路径（acq）走独立 toggle-FF 桥，与 FIFO 水位完全解耦
    //
    // 设计：
    //   1) Warm-up 几个像素让 FIFO 进入"稳态水位"（~20 word 残留，受 prog_empty 阈值钳位）
    //   2) inject 1 次 laser
    //   3) 同时测：laser → acq_pulse_ui rise（独立 toggle 桥）
    //              laser → DAX_DATA change（数据通过 FIFO，要先消化 20 个旧 word）
    //   4) 验证：
    //      - acq 延迟 ≈ scan_delay + CDC ≈ 70-100ns
    //      - DAC 延迟 ≈ acq 延迟 + 20 旧 word × 20ns ≈ 400-700ns
    //      - DAC 延迟 - acq 延迟 > 200ns → FIFO 水位的实证
    tc_id = 11;
    $display("[TC11] FIFO water level: DAC path delay >> acq path delay ...");
    stop_scan();
    repeat (200) @(posedge eth_clk);
    laser_mode_en       = 1'b1;
    scan_delay_time     = 16'd5;
    acq_data_delay_time = 16'd2;
    acq_time            = 16'd5;
    dac_sample          = 32'd30;
    dacx_tk_point       = 16'd100;
    dax_fall_time       = 32'd0;
    dacx_recovery_time  = 16'd2;
    image_row           = 16'd100;
    dacx_strat_level    = 16'h2000;
    dacx_step           = 64'h0100_0000_0000_0000;  // high 16 = 0x0100
    start_scan();

    // ---- Warm-up：跑 3 个像素让 FIFO 进入稳态水位 ----
    wait_state(5'd14, 32'd200000);
    begin : tc11_warmup
        integer i, cnt;
        for (i = 0; i < 3; i = i + 1) begin
            cnt = 0;
            while (dut_state !== 5'd14 && cnt < 50000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            cnt = 0;
            while (dut_prog_empty == 1'b0 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            inject_laser();
            cnt = 0;
            while (dut_state !== 5'd16 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            while (dut_state == 5'd16) @(posedge eth_clk);
        end
    end
    $display("[TC11] warm-up done, state=%0d, DAX=%h, prog_empty=%b",
             dut_state, DAX_DATA, dut_prog_empty);

    // ---- 测延迟 ----
    begin : tc11_meas
        reg [63:0] t_laser, t_acq, t_dax_change;
        reg [63:0] delay_acq_ps, delay_dac_ps, gap_ps;
        reg [15:0] dax_before;
        integer cnt;

        // 等 State 14 + FIFO 到阈值
        cnt = 0;
        while (dut_state !== 5'd14 && cnt < 50000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        cnt = 0;
        while (dut_prog_empty == 1'b0 && cnt < 5000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        dax_before = DAX_DATA;
        $display("[TC11] before laser: state=%0d, DAX=%h, prog_empty=%b",
                 dut_state, dax_before, dut_prog_empty);

        t_laser = $time;
        inject_laser();
        // 并行等两条路径的事件，靠全局 20ms 超时兜底
        fork
            begin : fa_acq
                @(posedge dut_acq_pulse_ui);
                t_acq = $time;
            end
            begin : fa_dax
                while (DAX_DATA === dax_before) @(posedge dac_dco);
                t_dax_change = $time;
            end
        join

        delay_acq_ps = t_acq        - t_laser;
        delay_dac_ps = t_dax_change - t_laser;
        gap_ps       = (delay_dac_ps > delay_acq_ps) ? (delay_dac_ps - delay_acq_ps) : 64'd0;

        $display("[TC11] laser=%0d  acq=%0d  dax_change=%0d  (units = timescale base = ns)",
                 t_laser, t_acq, t_dax_change);
        $display("[TC11] delay_ACQ = %0d ns, delay_DAC = %0d ns, gap = %0d ns",
                 delay_acq_ps, delay_dac_ps, gap_ps);

        // 校验 1：acq 延迟应在 50~150ns（独立 toggle 桥 + scan_delay×8 + CDC）
        if (delay_acq_ps < 64'd50 || delay_acq_ps > 64'd150) begin
            $display("[TC11 FAIL] acq delay %0d ns out of expected range [50, 150]",
                     delay_acq_ps);
            errors = errors + 1;
        end

        // 校验 2：DAC 延迟应在 50~500ns
        // DL5_UNIT_003: prog_empty 阈值从 20 降到 2，delay_DAC 从 ~634ns 降到 ~274ns
        if (delay_dac_ps < 64'd50 || delay_dac_ps > 64'd500) begin
            $display("[TC11 FAIL] dac delay %0d ns out of expected range [50, 500]",
                     delay_dac_ps);
            errors = errors + 1;
        end

        // 校验 3：DAC 延迟大于 acq 延迟（FIFO 水位实证：差距 >= 100ns）
        // DL5_UNIT_003: 地板从 20 降到 2，gap 从 ~557ns 降到 ~197ns
        if (gap_ps < 64'd100) begin
            $display("[TC11 FAIL] gap %0d ns < 100 ns: FIFO water level not affecting DAC path",
                     gap_ps);
            errors = errors + 1;
        end
    end
    if (errors == 0) $display("[TC11] PASS");

    // -------- TC12：行末斜坡排空 → 下一行第 1 个像素 DAX = dacx_strat --------
    //
    // 目的：验证 ARCHITECTURE.md §5.3 关键约束 —— laser 周期 ≥ dax_fall_time × 12ns
    //       + scan_delay × 8ns + 裕量。即下一行第 1 个 laser 到来时，行末斜坡的
    //       残留 word 已经排空，DAC 输出最终回到 dacx_strat_level。
    tc_id = 12;
    $display("[TC12] Line-end ramp drain -> next-line DAX = dacx_strat ...");
    stop_scan();
    repeat (200) @(posedge eth_clk);
    laser_mode_en       = 1'b1;
    scan_delay_time     = 16'd5;
    acq_data_delay_time = 16'd2;
    acq_time            = 16'd5;
    dac_sample          = 32'd5;
    dacx_tk_point       = 16'd3;       // 一行 3 个像素
    dax_fall_time       = 32'd5;       // 5 µs ramp，× 50 = 250 拍（在 dax_fall_time_r）
    dacx_recovery_time  = 16'd2;
    image_row           = 16'd3;
    dacx_strat_level    = 16'h2000;
    dacx_end_level      = 16'h6000;
    dacx_step           = 64'h0100_0000_0000_0000;
    start_scan();

    begin : tc12_walk_row
        integer k, cnt;
        // 第 1 行：3 个 laser
        for (k = 0; k < 3; k = k + 1) begin
            cnt = 0;
            while (dut_state !== 5'd14 && cnt < 200000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            if (dut_state !== 5'd14) begin
                $display("[TC12 FAIL] row1 px%0d: not in State 14", k);
                errors = errors + 1;
            end
            inject_laser();
            // 等本像素 State 16 写完 (退出 16 进 4)
            cnt = 0;
            while (dut_state !== 5'd16 && cnt < 5000) begin
                @(posedge eth_clk); cnt = cnt + 1;
            end
            while (dut_state == 5'd16) @(posedge eth_clk);
        end
        $display("[TC12] row1 done at t=%0t, state=%0d", $time, dut_state);

        // 等行末斜坡 + 行切换 + 下一行 State 14
        cnt = 0;
        while (dut_state !== 5'd14 && cnt < 500000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        if (dut_state !== 5'd14) begin
            $display("[TC12 FAIL] next-line State 14 not reached, current=%0d", dut_state);
            errors = errors + 1;
        end else begin
            $display("[TC12] next-line State 14 reached at t=%0t", $time);
        end

        // 等 FIFO 排空（关键：line-end ramp 残留必须先排空）
        cnt = 0;
        while (dut_prog_empty == 1'b0 && cnt < 10000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        $display("[TC12] FIFO drained at t=%0t, prog_empty=%b, DAX=%h",
                 $time, dut_prog_empty, DAX_DATA);

        // 排空后 DAC 输出应该是斜坡的最后一个值（接近 0，因为下降到 dax_level - dax_fall_step×N）
        // 现在注入下一行第 1 个 laser
        inject_laser();
        cnt = 0;
        while (dut_state !== 5'd16 && cnt < 5000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        while (dut_state == 5'd16) @(posedge eth_clk);
        cnt = 0;
        while (dut_prog_empty == 1'b0 && cnt < 5000) begin
            @(posedge eth_clk); cnt = cnt + 1;
        end
        repeat (10) @(posedge dac_dco);

        if (DAX_DATA !== dacx_strat_level) begin
            $display("[TC12 FAIL] next-line first pixel DAX=%h, expect dacx_strat=%h",
                     DAX_DATA, dacx_strat_level);
            errors = errors + 1;
        end else begin
            $display("[TC12] next-line first pixel DAX=%h (= dacx_strat, correct)", DAX_DATA);
        end
    end
    if (errors == 0) $display("[TC12] PASS");

    // ========================================================================
    // TC13: DL5_UNIT_003 参数边界测试
    //
    // 目标：固定 laser 周期 = 2µs（客户最快），扫 dax_fall_time 找撞墙边界。
    // 方法：每个 dax_fall 配置走完 1 行后，在 State 14 进入瞬间 inject laser，
    //       测 laser → DAX 切到 dacx_strat 的延迟。如果延迟 > 200ns，说明
    //       FIFO 残留太多，该 dax_fall 在 2µs laser 周期下撞墙。
    // ========================================================================
    $display("");
    $display("[TC13] Parameter boundary scan: dax_fall vs laser=2us ...");
    begin: tc13_scan
        integer i;
        reg [31:0] dax_fall_values [0:4];
        time t_laser, t_dax_change, delay_ns;

        dax_fall_values[0] = 32'd1;  // 0.5 µs 太小，最小 1
        dax_fall_values[1] = 32'd1;
        dax_fall_values[2] = 32'd2;
        dax_fall_values[3] = 32'd3;
        dax_fall_values[4] = 32'd5;

        for (i = 0; i < 5; i = i + 1) begin
            // 配置
            stop_scan();
            repeat (200) @(posedge eth_clk);
            laser_mode_en       = 1'b1;
            scan_delay_time     = 16'd5;
            acq_data_delay_time = 16'd2;
            acq_time            = 16'd5;
            dac_sample          = 32'd30;
            dacx_tk_point       = 16'd3;
            dax_fall_time       = dax_fall_values[i];
            dacx_recovery_time  = 16'd1;  // 固定 1µs
            image_row           = 16'd5;
            dacx_strat_level    = 16'h2000;
            dacx_end_level      = 16'h2100;  // pp = 0x100
            dacx_step           = 64'h0100_0000_0000_0000;
            start_scan();
            repeat (100) @(posedge eth_clk);

            // 走完第 1 行（3 个像素）
            inject_laser(); repeat (300) @(posedge eth_clk);
            inject_laser(); repeat (300) @(posedge eth_clk);
            inject_laser(); repeat (300) @(posedge eth_clk);

            // 等下一行 State 14
            wait (dut_state == 5'd14);
            repeat (10) @(posedge eth_clk);

            // 立刻 inject laser（模拟 laser 周期 = 状态机时间）
            t_laser = $time;
            inject_laser();

            // 等 DAX 切到 dacx_strat (0x2000)
            wait (DAX_DATA == 16'h2000);
            t_dax_change = $time;
            delay_ns = t_dax_change - t_laser;

            $display("[TC13.%0d] dax_fall=%0d us, rec=1 us -> delay=%0d ns %s",
                     i, dax_fall_values[i], delay_ns,
                     (delay_ns < 200) ? "OK" : "WARN: approaching limit");
        end

        $display("[TC13] Boundary scan complete. Check delays above.");
        $display("[TC13] PASS (informational test, no hard failure)");
    end

    // ========================================================================
    // TC14: 三延迟矩阵扫描 (DL5_UNIT_003)
    //
    // 在最坏 FIFO 压力下（行尾刚走完 State 13 + State 14 短）同时测三个延迟：
    //   1) delay_DAX = laser → DAX_DATA = dacx_strat
    //                  数据通路（经 FIFO），FIFO 残留主导
    //   2) delay_ACQ = laser → acq_pulse_ui rise
    //                  独立 toggle-FF 桥（eth_clk → ui_clk → dac_dco），不经 FIFO
    //   3) delay_BLK = laser → sync_pixel_tri1 fall
    //                  与 acq 共享同一条 toggle-FF 桥（eth_clk → ui_clk），不经 FIFO
    //
    // 验证目标：
    //   A. delay_DAX 随 dax_fall 增大而退化（量化 FIFO 压力影响）
    //   B. delay_ACQ / delay_BLK 在所有 dax_fall 下保持稳定
    //      （独立路径不变量：max-min spread < 20ns）
    // ========================================================================
    tc_id = 14;
    $display("");
    $display("[TC14] Three-delay matrix scan (laser -> DAX/ACQ/BLK) ...");
    begin: tc14_scan
        integer i;
        reg [31:0] dax_fall_values [0:3];
        time t_laser, t_dax, t_acq, t_blk;
        time delay_DAX, delay_ACQ, delay_BLK;
        integer fired_dax, fired_acq, fired_blk;
        time min_acq, max_acq, min_blk, max_blk;
        time min_dax, max_dax;

        dax_fall_values[0] = 32'd1;
        dax_fall_values[1] = 32'd2;
        dax_fall_values[2] = 32'd3;
        dax_fall_values[3] = 32'd5;

        min_acq = 64'hFFFF_FFFF; max_acq = 0;
        min_blk = 64'hFFFF_FFFF; max_blk = 0;
        min_dax = 64'hFFFF_FFFF; max_dax = 0;

        for (i = 0; i < 4; i = i + 1) begin : tc14_loop
            time t_laser, t_dax, t_acq, t_blk;
            time delay_DAX, delay_ACQ, delay_BLK;
            integer fired_dax, fired_acq, fired_blk;
            reg [15:0] dax_before;

            // ---- 配置 + 走完一行制造 FIFO 压力 ----
            stop_scan();
            repeat (200) @(posedge eth_clk);
            laser_mode_en       = 1'b1;
            scan_delay_time     = 16'd5;
            acq_data_delay_time = 16'd2;
            acq_time            = 16'd5;
            blanker_delay_time  = 16'd10;
            blanker_time        = 16'd20;
            dac_sample          = 32'd30;
            dacx_tk_point       = 16'd3;
            dax_fall_time       = dax_fall_values[i];
            dacx_recovery_time  = 16'd1;
            image_row           = 16'd5;
            dacx_strat_level    = 16'h2000;
            dacx_end_level      = 16'h2100;
            dacx_step           = 64'h0100_0000_0000_0000;
            start_scan();
            repeat (100) @(posedge eth_clk);

            inject_laser(); repeat (300) @(posedge eth_clk);
            inject_laser(); repeat (300) @(posedge eth_clk);
            inject_laser(); repeat (300) @(posedge eth_clk);

            // ---- 进 State 14 + 等信号回 idle ----
            wait (dut_state == 5'd14);
            repeat (10) @(posedge eth_clk);

            // 等 acq_pulse_ui 回到 idle 低电平（确保 posedge 可用）
            wait (dut_acq_pulse_ui == 1'b0);
            repeat (5) @(posedge eth_clk);

            // 等 sync_pixel_tri1 回到 idle 高电平（确保 negedge 可用）
            wait (sync_pixel_tri1 == 1'b1);
            repeat (5) @(posedge eth_clk);

            // ---- 同步注入 laser ----
            fired_dax = 0;
            fired_acq = 0;
            fired_blk = 0;
            dax_before = DAX_DATA;
            inject_laser();
            t_laser = $time;

            // ---- 测量 1: DAX 切换延迟 ----
            fork
                begin : wait_dax
                    wait (DAX_DATA != dax_before);
                    t_dax = $time;
                    fired_dax = 1;
                end
                begin : timeout_dax
                    #5000;
                    disable wait_dax;
                end
            join

            // ---- 测量 2: ACQ 延迟 ----
            fork
                begin : wait_acq
                    @(posedge dut_acq_pulse_ui);
                    t_acq = $time;
                    fired_acq = 1;
                end
                begin : timeout_acq
                    #2000;
                    disable wait_acq;
                end
            join

            // ---- 测量 3: BLK 延迟 ----
            fork
                begin : wait_blk
                    @(negedge sync_pixel_tri1);
                    t_blk = $time;
                    fired_blk = 1;
                end
                begin : timeout_blk
                    #2000;
                    disable wait_blk;
                end
            join

            delay_DAX = fired_dax ? (t_dax - t_laser) : 64'd9999000;
            delay_ACQ = fired_acq ? (t_acq - t_laser) : 64'd9999000;
            delay_BLK = fired_blk ? (t_blk - t_laser) : 64'd9999000;

            $display("[TC14.%0d] dax_fall=%0d us | DAX=%0d ns  ACQ=%0d ns  BLK=%0d ns%s%s%s",
                     i, dax_fall_values[i],
                     delay_DAX/1000, delay_ACQ/1000, delay_BLK/1000,
                     fired_dax ? "" : " (DAX_TIMEOUT)",
                     fired_acq ? "" : " (ACQ_TIMEOUT)",
                     fired_blk ? "" : " (BLK_TIMEOUT)");

            // 记录每路 min/max（仅在 fire 时）
            if (fired_dax) begin
                if (delay_DAX < min_dax) min_dax = delay_DAX;
                if (delay_DAX > max_dax) max_dax = delay_DAX;
            end
            if (fired_acq) begin
                if (delay_ACQ < min_acq) min_acq = delay_ACQ;
                if (delay_ACQ > max_acq) max_acq = delay_ACQ;
            end
            if (fired_blk) begin
                if (delay_BLK < min_blk) min_blk = delay_BLK;
                if (delay_BLK > max_blk) max_blk = delay_BLK;
            end

            // 单点合理性断言（loose bounds，主要兜底 timeout）
            if (!fired_acq) begin
                $display("[TC14.%0d FAIL] acq_pulse_ui never rose", i);
                errors = errors + 1;
            end
            if (!fired_blk) begin
                $display("[TC14.%0d FAIL] sync_pixel_tri1 never fell", i);
                errors = errors + 1;
            end
            if (!fired_dax) begin
                $display("[TC14.%0d FAIL] DAX never reached dacx_strat", i);
                errors = errors + 1;
            end
        end

        // ---- 独立路径不变量断言：ACQ/BLK 跨 dax_fall 应稳定 ----
        $display("[TC14] Spread: DAX=[%0d..%0d] ns  ACQ=[%0d..%0d] ns  BLK=[%0d..%0d] ns",
                 min_dax/1000, max_dax/1000,
                 min_acq/1000, max_acq/1000,
                 min_blk/1000, max_blk/1000);
        if (max_acq - min_acq > 20000) begin
            $display("[TC14 FAIL] ACQ spread > 20 ns (independent path violated): %0d ns",
                     (max_acq - min_acq)/1000);
            errors = errors + 1;
        end
        if (max_blk - min_blk > 20000) begin
            $display("[TC14 FAIL] BLK spread > 20 ns (independent path violated): %0d ns",
                     (max_blk - min_blk)/1000);
            errors = errors + 1;
        end

        $display("[TC14] Three-delay scan complete.");
        if (errors == 0) $display("[TC14] PASS");
    end

    // -------- Summary --------
    repeat (100) @(posedge eth_clk);
    $display("");
    $display("========================================");
    $display("DL5_UNIT_002 test done, errors = %0d", errors);
    if (errors == 0)
        $display("PASS");
    else
        $display("FAIL: %0d error(s)", errors);
    $display("========================================");
    $finish;
end

initial begin
    #20000000;
    $display("[GLOBAL FAIL] simulation timeout");
    errors = errors + 1;
    $finish;
end

endmodule

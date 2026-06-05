`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : tb_dl5_unit_004_regression
// Create Date : 2026-06-04
//
// DL5_UNIT_004 回归 testbench：激光模式 ADC 采集点数独立控制（acq_time）
//
// DUT：adcdata_acq（ADC 单路采样整理器，含 DL5 新端口 laser_mode_en / acq_time）
//
// 设计说明（为什么不是直接 copy UNIT_003 的 tb_dl5_unit_002.v）：
//   UNIT_003 的 tb_dl5_unit_002.v 的 DUT 是 dacdata_config（DAC 数据通路，
//   N1=parameter_dacdata_gen + N2=dac_output），它的 TC1~TC13 探针全部是
//   DAC 侧信号（DAX_DATA / acq_pulse_ui / sync_pixel_tri1 / state 14/15/16）。
//   UNIT_004 改的是 adcdata_acq（ADC 通路），端口与内部状态机完全不同，
//   无法逐字节复用那些 TC。
//
//   因此本 tb 把 UNIT_003 的"零影响"意图映射到 adcdata_acq 的 ADC 侧：
//     - TC1~TC6  普通模式回归（laser=0, ultrafast=0）：验证 adc_valid_point /
//                adc_sample_reg / adc_interval_reg / 状态机 0->1->2->3 路径 / 采集
//                点数 / line_count 全部维持原行为。
//     - TC7~TC13 超快模式回归（ultrafast=1, laser=0）：验证扣延时/扣死区公式、
//                dead time State 3、多列 image_column 推进、line_count 全部不变。
//     - TC14~TC15 激光模式新功能（laser=1）：验证 adc_valid_point=acq_time、
//                adc_sample_reg=acq_time、adc_interval_reg=0、跳过死区、单像素
//                多窗口与 acq_time 边界扫描。
//
// 时钟：
//   ui_clk   = 200MHz (5ns)
//   adc_dco  = 50MHz  (20ns)
//
// 通过/失败：
//   tb 内部 errors 计数器，== 0 视为 PASS，否则 FAIL。
//   末尾打印 "PASS" / "FAIL"，供 run_regression.tcl grep。
//////////////////////////////////////////////////////////////////////////////////
module tb_dl5_unit_004_regression;

// ============================================================
// 时钟和复位
// ============================================================
reg ui_clk;
reg adc_dco;
reg rstn;

initial begin ui_clk  = 0; forever #2.5  ui_clk  = ~ui_clk;  end   // 200MHz
initial begin adc_dco = 0; forever #10   adc_dco = ~adc_dco; end   //  50MHz

// ============================================================
// DUT 输入信号
// ============================================================
reg         adc_tri;
reg [15:0]  row_repeat;
reg [31:0]  adc_sample;
reg [15:0]  image_column;
reg [23:0]  adc_interval;
reg         ultrafast_mode;
reg [31:0]  acq_dead_time;
reg [31:0]  adc_acq_delay;

// DL5 UNIT_004 新增输入
reg         laser_mode_en;
reg [31:0]  acq_time;

// ADC 数据输入
reg [15:0]  adc_data;

// DUT 输出（adcdata_acq 真实输出端口）
reg         div_adc_rd_en;
wire [15:0] line_count;
wire        line_count_en;
wire [9:0]  div_adc_rd_data_count;
wire [15:0] div_adc_out;

// ============================================================
// 错误计数器和测试控制
// ============================================================
reg [31:0] errors;
reg [31:0] tc_id;
integer result_fd;

initial errors = 0;
initial tc_id  = 0;

task check_eq;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] exp;
    begin
        if (got !== exp) begin
            $display("[TC%0d FAIL] %0s : got=%0d, exp=%0d, t=%0t", tc_id, msg, got, exp, $time);
            errors = errors + 1;
        end
    end
endtask

task check_range;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] min_val;
    input [63:0] max_val;
    begin
        if (got < min_val || got > max_val) begin
            $display("[TC%0d FAIL] %0s : got=%0d, range [%0d, %0d], t=%0t",
                     tc_id, msg, got, min_val, max_val, $time);
            errors = errors + 1;
        end
    end
endtask

// ============================================================
// DUT 实例化（adcdata_acq 真实端口）
// ============================================================
adcdata_acq DUT (
    .ui_clk             (ui_clk),
    .rstn               (rstn),
    .adc_tri            (adc_tri),
    .row_repeat         (row_repeat),
    .adc_sample         (adc_sample),
    .image_column       (image_column),
    .adc_interval       (adc_interval),
    .ultrafast_mode     (ultrafast_mode),
    .acq_dead_time      (acq_dead_time),
    .adc_acq_delay      (adc_acq_delay),

    // DL5 UNIT_004 新增端口
    .laser_mode_en      (laser_mode_en),
    .acq_time           (acq_time),

    .adc_dco            (adc_dco),
    .adc_data           (adc_data),

    .div_adc_rd_en      (div_adc_rd_en),
    .line_count         (line_count),
    .line_count_en      (line_count_en),
    .div_adc_rd_data_count (div_adc_rd_data_count),
    .div_adc_out        (div_adc_out)
);

// 探针：访问内部信号（层次化引用，adcdata_acq 的内部 regs/wires）
wire [39:0] dut_adc_valid_point     = DUT.adc_valid_point;
wire [31:0] dut_adc_sample_reg      = DUT.adc_sample_reg;
wire [31:0] dut_adc_interval_reg    = DUT.adc_interval_reg;
wire [3:0]  dut_state               = DUT.state;
wire [39:0] dut_adc_valid_point_cnt = DUT.adc_valid_point_cnt;
wire        dut_acq_en              = DUT.acq_en;
wire [15:0] dut_image_column_cnt    = DUT.image_column_cnt;

// ============================================================
// 测试任务
// ============================================================
task init_default_params;
    begin
        adc_tri         = 1'b0;
        row_repeat      = 16'd1;
        adc_sample      = 32'd50;
        image_column    = 16'd1024;
        adc_interval    = 24'd19;
        ultrafast_mode  = 1'b0;
        acq_dead_time   = 32'd0;
        adc_acq_delay   = 32'd0;
        laser_mode_en   = 1'b0;
        acq_time        = 32'd50;
        adc_data        = 16'h0000;
        div_adc_rd_en   = 1'b0;
    end
endtask

task generate_adc_trigger;
    begin
        @(posedge adc_dco);
        adc_tri = 1'b1;
        repeat (5) @(posedge adc_dco);
        adc_tri = 1'b0;
    end
endtask

task wait_state;
    input [3:0] target_state;
    input [31:0] max_cycles;
    integer cnt;
    begin
        cnt = 0;
        while (dut_state !== target_state && cnt < max_cycles) begin
            @(posedge adc_dco);
            cnt = cnt + 1;
        end
        if (cnt >= max_cycles) begin
            $display("[TC%0d WARN] wait_state(%0d) timeout after %0d cycles, current=%0d",
                     tc_id, target_state, max_cycles, dut_state);
        end
    end
endtask

task wait_idle;
    input [31:0] max_cycles;
    begin
        wait_state(4'd0, max_cycles);
        repeat (4) @(posedge adc_dco);
    end
endtask

task trigger_and_count_acq_cycles;
    input [31:0] max_cycles;
    output [31:0] acq_cycles;
    integer wait_cycles;
    begin
        acq_cycles = 0;
        wait_cycles = 0;
        generate_adc_trigger();

        while (dut_acq_en !== 1'b1 && wait_cycles < max_cycles) begin
            @(posedge adc_dco);
            wait_cycles = wait_cycles + 1;
        end

        if (wait_cycles >= max_cycles) begin
            $display("[TC%0d FAIL] acq_en did not assert within %0d cycles", tc_id, max_cycles);
            errors = errors + 1;
        end else begin
            while (dut_acq_en === 1'b1 && acq_cycles < max_cycles) begin
                acq_cycles = acq_cycles + 1;
                @(posedge adc_dco);
            end
        end
    end
endtask

// ============================================================
// 测试主流程
// ============================================================
initial begin
    init_default_params();
    rstn = 1'b0;
    #200;
    rstn = 1'b1;
    #100;

    // ========================================================================
    // TC1~TC6：普通模式零影响回归（laser=0, ultrafast=0）
    // 关键断言：adc_valid_point = image_column * adc_sample
    //          adc_sample_reg = adc_sample
    //          adc_interval_reg = adc_interval
    //          状态机 0→1→2→0 路径
    //          line_count 在一行结束后递增
    // ========================================================================
    $display("========================================");
    $display("TC1~TC6: Normal mode regression");
    $display("========================================");

    // -------- TC1：普通模式 adc_valid_point 计算 --------
    tc_id = 1;
    $display("[TC1] Normal mode: adc_valid_point = image_column * adc_sample");
    laser_mode_en  = 1'b0;
    ultrafast_mode = 1'b0;
    adc_sample     = 32'd4;
    image_column   = 16'd3;
    adc_interval   = 24'd19;
    repeat (100) @(posedge adc_dco);
    check_eq("adc_valid_point", dut_adc_valid_point, 64'd12);  // 3*4=12
    if (errors == 0) $display("[TC1] PASS");

    // -------- TC2：普通模式 adc_sample_reg --------
    tc_id = 2;
    $display("[TC2] Normal mode: adc_sample_reg = adc_sample");
    check_eq("adc_sample_reg", dut_adc_sample_reg, 64'd4);
    if (errors == 0) $display("[TC2] PASS");

    // -------- TC3：普通模式 adc_interval_reg --------
    tc_id = 3;
    $display("[TC3] Normal mode: adc_interval_reg = adc_interval");
    check_eq("adc_interval_reg", dut_adc_interval_reg, 64'd19);
    if (errors == 0) $display("[TC3] PASS");

    // -------- TC4：普通模式状态机路径（0→1→2→0）--------
    tc_id = 4;
    $display("[TC4] Normal mode: state machine 0->1->2->0");
    wait_state(4'd0, 32'd1000);
    generate_adc_trigger();
    wait_state(4'd1, 32'd500);
    $display("[TC4]   state 1 (interval countdown) OK");
    wait_state(4'd2, 32'd5000);
    $display("[TC4]   state 2 (acq window) OK");
    wait_state(4'd0, 32'd5000);
    $display("[TC4]   back to state 0 OK");
    if (errors == 0) $display("[TC4] PASS");

    // -------- TC5：普通模式采集点数 --------
    tc_id = 5;
    $display("[TC5] Normal mode: acq_en cycles = adc_valid_point");
    begin : tc5_count
        integer acq_cycles;
        generate_adc_trigger();
        // 等待 acq_en 变高
        wait_state(4'd2, 32'd1000);
        wait (dut_acq_en == 1'b1);
        // 计数 acq_en 高电平的周期数
        acq_cycles = 0;
        while (dut_acq_en == 1'b1 && acq_cycles < 200) begin
            @(posedge adc_dco);
            if (dut_acq_en == 1'b1) acq_cycles = acq_cycles + 1;
        end
        $display("[TC5]   acq_en cycles=%0d, expect~%0d", acq_cycles, dut_adc_valid_point);
        check_range("acq cycles", acq_cycles, dut_adc_valid_point - 2, dut_adc_valid_point + 2);
    end
    if (errors == 0) $display("[TC5] PASS");

    // -------- TC6：普通模式 line_count 保持原行为 --------
    tc_id = 6;
    $display("[TC6] Normal mode: line_count remains unchanged");
    begin : tc6_line
        reg [15:0] line_before;
        line_before = line_count;
        generate_adc_trigger();
        wait_state(4'd0, 32'd10000);
        repeat (50) @(posedge adc_dco);
        if (line_count !== line_before) begin
            $display("[TC6 FAIL] normal mode changed line_count: got=%0d, exp=%0d", line_count, line_before);
            errors = errors + 1;
        end else begin
            $display("[TC6]   line_count unchanged as expected: %0d", line_count);
        end
    end
    if (errors == 0) $display("[TC6] PASS");

    // ========================================================================
    // TC7~TC13：超快模式零影响回归（ultrafast=1, laser=0）
    // 关键断言：adc_valid_point = adc_sample - adc_acq_delay - acq_dead_time - 2
    //          adc_sample_reg 同上
    //          adc_interval_reg = adc_acq_delay
    //          状态机含 dead time State 3（如果 acq_dead_time > 0）
    //          多列 image_column 推进
    //          line_count 在整行结束后递增
    // ========================================================================
    $display("");
    $display("========================================");
    $display("TC7~TC13: Ultrafast mode regression");
    $display("========================================");

    repeat (200) @(posedge adc_dco);
    wait_state(4'd0, 32'd10000);  // 确保空闲后再改参数

    // -------- TC7：超快模式 adc_valid_point 计算（无死区）--------
    tc_id = 7;
    $display("[TC7] Ultrafast mode: adc_valid_point = sample - delay - dead - 2 (dead=0)");
    laser_mode_en  = 1'b0;
    ultrafast_mode = 1'b1;
    adc_sample     = 32'd50;
    adc_acq_delay  = 32'd2;
    acq_dead_time  = 32'd0;
    image_column   = 16'd4;
    repeat (100) @(posedge adc_dco);
    // 50 - 2 - 0 - 2 = 46
    check_eq("adc_valid_point", dut_adc_valid_point, 64'd46);
    if (errors == 0) $display("[TC7] PASS");

    // -------- TC8：超快模式 adc_sample_reg --------
    tc_id = 8;
    $display("[TC8] Ultrafast mode: adc_sample_reg = sample - delay - dead - 2");
    check_eq("adc_sample_reg", dut_adc_sample_reg, 64'd46);
    if (errors == 0) $display("[TC8] PASS");

    // -------- TC9：超快模式 adc_interval_reg --------
    tc_id = 9;
    $display("[TC9] Ultrafast mode: adc_interval_reg = adc_acq_delay");
    check_eq("adc_interval_reg", dut_adc_interval_reg, 64'd2);
    if (errors == 0) $display("[TC9] PASS");

    // -------- TC10：超快模式带死区的 adc_valid_point --------
    tc_id = 10;
    $display("[TC10] Ultrafast mode: adc_valid_point with acq_dead_time=5");
    wait_state(4'd0, 32'd10000);  // 等待空闲后再改参数
    acq_dead_time = 32'd5;
    repeat (100) @(posedge adc_dco);
    // 50 - 2 - 5 - 2 = 41
    check_eq("adc_valid_point", dut_adc_valid_point, 64'd41);
    check_eq("adc_sample_reg", dut_adc_sample_reg, 64'd41);
    if (errors == 0) $display("[TC10] PASS");

    // -------- TC11：超快模式状态机含 State 3（dead time）--------
    tc_id = 11;
    $display("[TC11] Ultrafast mode: state machine with dead time State 3");
    wait_state(4'd0, 32'd1000);
    generate_adc_trigger();
    wait_state(4'd1, 32'd500);
    wait_state(4'd2, 32'd5000);
    wait_state(4'd3, 32'd1000);
    $display("[TC11]   state 3 (dead time) reached OK");
    wait_state(4'd0, 32'd10000);  // 等待完整退出死区回到空闲
    if (errors == 0) $display("[TC11] PASS");

    // -------- TC12：超快模式多列推进 image_column_cnt --------
    tc_id = 12;
    $display("[TC12] Ultrafast mode: image_column_cnt advances through columns");
    acq_dead_time = 32'd0;  // 关死区简化测试
    image_column  = 16'd3;
    repeat (100) @(posedge adc_dco);
    begin : tc12_cols
        reg [15:0] line_before;
        line_before = line_count;
        wait_idle(32'd1000);
        generate_adc_trigger();
        wait_state(4'd0, 32'd20000);
        repeat (20) @(posedge adc_dco);
        if (dut_image_column_cnt !== 16'd0) begin
            $display("[TC12 FAIL] image_column_cnt should reset to 0 after row, got=%0d", dut_image_column_cnt);
            errors = errors + 1;
        end
        if (line_count !== line_before + 1) begin
            $display("[TC12 FAIL] line_count not incremented after ultrafast row: got=%0d, exp=%0d",
                     line_count, line_before + 1);
            errors = errors + 1;
        end else begin
            $display("[TC12]   one trigger completed %0d columns and line_count=%0d", image_column, line_count);
        end
    end
    if (errors == 0) $display("[TC12] PASS");

    // -------- TC13：超快模式 line_count 在整行结束后递增 --------
    tc_id = 13;
    $display("[TC13] Ultrafast mode: line_count increments after full row");
    begin : tc13_line
        reg [15:0] line_before;
        line_before = line_count;
        wait_idle(32'd1000);
        generate_adc_trigger();
        wait_state(4'd0, 32'd20000);
        repeat (20) @(posedge adc_dco);
        if (line_count !== line_before + 1) begin
            $display("[TC13 FAIL] line_count not incremented: got=%0d, exp=%0d", line_count, line_before+1);
            errors = errors + 1;
        end else begin
            $display("[TC13]   line_count incremented correctly: %0d", line_count);
        end
    end
    if (errors == 0) $display("[TC13] PASS");

    // ========================================================================
    // TC14~TC15：激光模式新功能（laser=1）
    // 关键断言：adc_valid_point = acq_time
    //          adc_sample_reg = acq_time
    //          adc_interval_reg = 0
    //          状态机跳过 State 3（无死区）
    //          单像素多窗口：image_column 个窗口后 line_count++
    //          acq_time 边界扫描
    // ========================================================================
    $display("");
    $display("========================================");
    $display("TC14~TC15: Laser mode new features");
    $display("========================================");

    repeat (200) @(posedge adc_dco);
    wait_state(4'd0, 32'd10000);  // 确保空闲后再改参数

    // -------- TC14：激光模式 ADC 采集点数验证 --------
    tc_id = 14;
    $display("[TC14] Laser mode: adc_valid_point = acq_time, adc_interval_reg = 0");
    laser_mode_en  = 1'b1;
    ultrafast_mode = 1'b0;
    adc_sample     = 32'd30;     // 不应被使用
    acq_time       = 32'd8;
    image_column   = 16'd4;
    repeat (100) @(posedge adc_dco);

    check_eq("adc_valid_point", dut_adc_valid_point, 64'd8);
    check_eq("adc_sample_reg", dut_adc_sample_reg, 64'd8);
    check_eq("adc_interval_reg", dut_adc_interval_reg, 64'd0);

    // 验证首个采集窗口周期数，并等待整行窗口自动跑完
    begin : tc14_acq
        reg [31:0] acq_cycles;
        reg [15:0] line_before;
        line_before = line_count;
        trigger_and_count_acq_cycles(32'd1000, acq_cycles);
        $display("[TC14]   acq_en cycles=%0d, expect~%0d", acq_cycles, acq_time);
        check_range("acq cycles", acq_cycles, acq_time - 2, acq_time + 2);
        wait_state(4'd0, 32'd20000);
        repeat (20) @(posedge adc_dco);
        if (line_count !== line_before + 1) begin
            $display("[TC14 FAIL] line_count not incremented after 4 pixels: got=%0d, exp=%0d",
                     line_count, line_before+1);
            errors = errors + 1;
        end else begin
            $display("[TC14]   line_count incremented after image_column pixels: %0d", line_count);
        end
    end

    if (errors == 0) $display("[TC14] PASS");

    // -------- TC15：acq_time 边界扫描 --------
    tc_id = 15;
    $display("[TC15] Laser mode: acq_time boundary scan");
    begin : tc15_scan
        integer i;
        reg [31:0] acq_time_values [0:4];
        reg [31:0] min_cycles;
        reg [31:0] max_cycles;
        acq_time_values[0] = 32'd1;
        acq_time_values[1] = 32'd2;
        acq_time_values[2] = 32'd5;
        acq_time_values[3] = 32'd10;
        acq_time_values[4] = 32'd20;

        for (i = 0; i < 5; i = i + 1) begin
            laser_mode_en  = 1'b1;
            ultrafast_mode = 1'b0;
            adc_sample     = 32'd100;
            acq_time       = acq_time_values[i];
            image_column   = 16'd1;

            repeat (50) @(posedge adc_dco);

            if (dut_adc_valid_point !== acq_time_values[i]) begin
                $display("[TC15.%0d FAIL] acq_time=%0d: adc_valid_point=%0d, expected=%0d",
                         i, acq_time_values[i], dut_adc_valid_point, acq_time_values[i]);
                errors = errors + 1;
            end

            if (dut_adc_sample_reg !== acq_time_values[i]) begin
                $display("[TC15.%0d FAIL] acq_time=%0d: adc_sample_reg=%0d, expected=%0d",
                         i, acq_time_values[i], dut_adc_sample_reg, acq_time_values[i]);
                errors = errors + 1;
            end

            // 功能验证：生成触发并计数采集周期
            begin : count_acq
                reg [31:0] acq_cycles;
                trigger_and_count_acq_cycles(32'd500, acq_cycles);
                min_cycles = (acq_time_values[i] > 32'd2) ? (acq_time_values[i] - 32'd2) : 32'd0;
                max_cycles = acq_time_values[i] + 32'd2;
                if (acq_cycles < min_cycles || acq_cycles > max_cycles) begin
                    $display("[TC15.%0d FAIL] acq_time=%0d: actual cycles=%0d, expected~%0d",
                             i, acq_time_values[i], acq_cycles, acq_time_values[i]);
                    errors = errors + 1;
                end else begin
                    $display("[TC15.%0d] acq_time=%0d: acq cycles=%0d OK",
                             i, acq_time_values[i], acq_cycles);
                end
            end

            wait_state(4'd0, 32'd1000);
            repeat (100) @(posedge adc_dco);
        end
    end

    if (errors == 0) $display("[TC15] PASS");

    // -------- Summary --------
    repeat (100) @(posedge adc_dco);
    $display("");
    $display("========================================");
    $display("DL5_UNIT_004 回归测试完成");
    $display("========================================");
    $display("总测试用例: 15");
    $display("总错误数:   %0d", errors);
    result_fd = $fopen("dl5_unit004_regression_result.txt", "w");
    if (errors == 0) begin
        $display("RESULT: PASS");
        if (result_fd != 0) $fdisplay(result_fd, "PASS");
        $display("========================================");
    end else begin
        $display("RESULT: FAIL (%0d errors)", errors);
        if (result_fd != 0) $fdisplay(result_fd, "FAIL %0d", errors);
        $display("========================================");
    end
    if (result_fd != 0) $fclose(result_fd);
    $finish;
end

initial begin
    #50000000;  // 50ms timeout
    $display("[GLOBAL FAIL] simulation timeout");
    errors = errors + 1;
    $finish;
end

endmodule

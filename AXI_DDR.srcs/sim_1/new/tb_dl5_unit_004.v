`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : tb_dl5_unit_004
// Create Date : 2026-06-04
//
// DL5_UNIT_004 集成 testbench：激光模式 ADC 采集点数独立控制（方案 V2）
//
// DUT：adcdata_acq（ADC 数据采集模块）
//
// 测试用例（覆盖 PROPOSAL_V2.md §5.1）：
//   TC14  Laser mode ADC sample count verification
//         Configuration: laser_mode_en=1, adc_sample=30, acq_time=5, image_column=16
//         Verify: adc_valid_point=5 (not 30), adc_sample_reg=5, adc_interval_reg=0
//                 line_count increments after 16 pixels
//
//   TC15  acq_time boundary scan
//         Scan acq_time in {1, 2, 5, 10, 20}
//         Verify: ADC samples correct number of points for each
//
// 时钟：
//   ui_clk   = 200MHz (5ns)
//   adc_dco  = 50MHz  (20ns)
//
// 通过/失败：
//   tb 内部 errors 计数器，== 0 视为 PASS，否则 FAIL
//////////////////////////////////////////////////////////////////////////////////
module tb_dl5_unit_004;

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

// DUT 输出
wire        acq_en;
wire        line_count_en;
wire [15:0] line_count;
wire [15:0] image_column_cnt;

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

task check_range;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] min_val;
    input [63:0] max_val;
    begin
        if (got < min_val || got > max_val) begin
            $display("[TC%0d FAIL] %0s : got=%h, expected range [%h, %h], t=%0t",
                     tc_id, msg, got, min_val, max_val, $time);
            errors = errors + 1;
        end
    end
endtask

// ============================================================
// DUT 实例化
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

    .acq_en             (acq_en),
    .line_count_en      (line_count_en),
    .line_count         (line_count),
    .image_column_cnt   (image_column_cnt)
);

// 探针：访问内部信号（调试用）
wire [39:0] dut_adc_valid_point  = DUT.adc_valid_point;
wire [31:0] dut_adc_sample_reg   = DUT.adc_sample_reg;
wire [31:0] dut_adc_interval_reg = DUT.adc_interval_reg;
wire [3:0]  dut_state            = DUT.state;
wire [39:0] dut_adc_valid_point_cnt = DUT.adc_valid_point_cnt;

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
    end
endtask

task generate_adc_trigger;
    begin
        @(posedge adc_dco);
        adc_tri = 1'b1;
        @(posedge adc_dco);
        adc_tri = 1'b0;
    end
endtask

task wait_adc_acquisition_complete;
    input [31:0] max_cycles;
    integer cnt;
    begin
        cnt = 0;
        while (acq_en == 1'b1 && cnt < max_cycles) begin
            @(posedge adc_dco);
            cnt = cnt + 1;
        end
        if (cnt >= max_cycles) begin
            $display("[TC%0d WARN] wait_adc_acquisition_complete timeout after %0d cycles", tc_id, max_cycles);
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

    // -------- TC14：激光模式 ADC 采集点数验证 --------
    tc_id = 14;
    $display("");
    $display("[TC14] Laser mode ADC sample count verification ...");
    laser_mode_en  = 1'b1;
    adc_sample     = 32'd30;     // 普通模式值（不应被使用）
    acq_time       = 32'd5;      // 激光模式：期望采 5 个点
    image_column   = 16'd16;     // 一行 16 个像素
    adc_interval   = 24'd19;
    ultrafast_mode = 1'b0;

    repeat (100) @(posedge adc_dco);

    // 验证点 1: adc_valid_point = acq_time (5), not adc_sample (30)
    check_eq("adc_valid_point", dut_adc_valid_point, 64'd5);

    // 验证点 2: adc_sample_reg = acq_time (5)
    check_eq("adc_sample_reg", dut_adc_sample_reg, 64'd5);

    // 验证点 3: adc_interval_reg = 0 (激光模式无延迟)
    check_eq("adc_interval_reg", dut_adc_interval_reg, 64'd0);

    // 验证点 4: 16 个像素后 line_count 递增
    begin : tc14_pixel_walk
        integer px;
        reg [15:0] line_count_before;
        line_count_before = line_count;

        for (px = 0; px < 16; px = px + 1) begin
            generate_adc_trigger();
            wait_adc_acquisition_complete(32'd1000);
            repeat (10) @(posedge adc_dco);

            if (px < 15) begin
                // 前 15 个像素，line_count 不变
                if (line_count !== line_count_before) begin
                    $display("[TC14 FAIL] pixel %0d: line_count changed prematurely, got=%0d, exp=%0d",
                             px, line_count, line_count_before);
                    errors = errors + 1;
                end
            end else begin
                // 第 16 个像素后，line_count 应递增
                if (line_count !== line_count_before + 1) begin
                    $display("[TC14 FAIL] after pixel 15: line_count not incremented, got=%0d, exp=%0d",
                             line_count, line_count_before + 1);
                    errors = errors + 1;
                end else begin
                    $display("[TC14] line_count incremented correctly after 16 pixels: %0d", line_count);
                end
            end
        end
    end

    if (errors == 0) $display("[TC14] PASS");
    else $display("[TC14] FAIL with %0d error(s)", errors);

    // -------- TC15：acq_time 边界扫描 --------
    tc_id = 15;
    $display("");
    $display("[TC15] acq_time boundary scan ...");

    begin : tc15_scan
        integer i;
        reg [31:0] acq_time_values [0:4];
        reg [31:0] expected_count;

        acq_time_values[0] = 32'd1;
        acq_time_values[1] = 32'd2;
        acq_time_values[2] = 32'd5;
        acq_time_values[3] = 32'd10;
        acq_time_values[4] = 32'd20;

        for (i = 0; i < 5; i = i + 1) begin
            // 配置
            laser_mode_en  = 1'b1;
            adc_sample     = 32'd100;    // 大值，不应被使用
            acq_time       = acq_time_values[i];
            image_column   = 16'd1;      // 单像素测试
            ultrafast_mode = 1'b0;

            repeat (50) @(posedge adc_dco);

            // 验证 adc_valid_point
            expected_count = acq_time_values[i];
            if (dut_adc_valid_point !== expected_count) begin
                $display("[TC15.%0d FAIL] acq_time=%0d: adc_valid_point=%0d, expected=%0d",
                         i, acq_time_values[i], dut_adc_valid_point, expected_count);
                errors = errors + 1;
            end else begin
                $display("[TC15.%0d] acq_time=%0d: adc_valid_point=%0d OK",
                         i, acq_time_values[i], dut_adc_valid_point);
            end

            // 验证 adc_sample_reg
            if (dut_adc_sample_reg !== expected_count) begin
                $display("[TC15.%0d FAIL] acq_time=%0d: adc_sample_reg=%0d, expected=%0d",
                         i, acq_time_values[i], dut_adc_sample_reg, expected_count);
                errors = errors + 1;
            end

            // 功能验证：生成触发，确认采集点数正确
            generate_adc_trigger();

            // 等待采集完成并计数
            begin : count_acq_cycles
                integer acq_cycles;
                acq_cycles = 0;
                // 等待 acq_en 变高
                while (acq_en == 1'b0 && acq_cycles < 100) begin
                    @(posedge adc_dco);
                    acq_cycles = acq_cycles + 1;
                end

                // 计数 acq_en 高电平期间的周期数
                acq_cycles = 0;
                while (acq_en == 1'b1 && acq_cycles < 1000) begin
                    @(posedge adc_dco);
                    acq_cycles = acq_cycles + 1;
                end

                // 验证采集周期数 ≈ acq_time（允许 ±2 误差）
                if (acq_cycles < expected_count - 2 || acq_cycles > expected_count + 2) begin
                    $display("[TC15.%0d FAIL] acq_time=%0d: actual acq cycles=%0d, expected~%0d",
                             i, acq_time_values[i], acq_cycles, expected_count);
                    errors = errors + 1;
                end else begin
                    $display("[TC15.%0d] acq_time=%0d: acq cycles=%0d OK",
                             i, acq_time_values[i], acq_cycles);
                end
            end

            repeat (100) @(posedge adc_dco);
        end
    end

    if (errors == 0) $display("[TC15] PASS");
    else $display("[TC15] FAIL with %0d error(s)", errors);

    // -------- Summary --------
    repeat (100) @(posedge adc_dco);
    $display("");
    $display("========================================");
    $display("DL5_UNIT_004 test done, errors = %0d", errors);
    if (errors == 0)
        $display("PASS");
    else
        $display("FAIL: %0d error(s)", errors);
    $display("========================================");
    $finish;
end

initial begin
    #10000000;  // 10ms timeout
    $display("[GLOBAL FAIL] simulation timeout");
    errors = errors + 1;
    $finish;
end

endmodule

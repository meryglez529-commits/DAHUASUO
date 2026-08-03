`timescale 1ns / 1ps

module tb_dl5_unit_005_adc_trigger_wait;

reg ui_clk = 1'b0;
reg adc_dco = 1'b0;
reg rstn = 1'b0;

always #2.5 ui_clk = ~ui_clk;
always #10  adc_dco = ~adc_dco;

reg         adc_tri = 1'b0;
reg [15:0]  row_repeat = 16'd1;
reg [31:0]  adc_sample = 32'd8;
reg [15:0]  image_column = 16'd3;
reg [23:0]  adc_interval = 24'd2;
reg         ultrafast_mode = 1'b0;
reg [31:0]  acq_dead_time = 32'd0;
reg [31:0]  adc_acq_delay = 32'd0;
reg         laser_mode_en = 1'b1;
reg [31:0]  acq_time = 32'd4;
reg [15:0]  adc_data = 16'd100;
reg         div_adc_rd_en = 1'b0;

wire [15:0] line_count;
wire        line_count_en;
wire [9:0]  div_adc_rd_data_count;
wire [15:0] div_adc_out;

integer errors = 0;
integer windows_seen = 0;

adcdata_acq dut (
    .ui_clk(ui_clk),
    .rstn(rstn),
    .row_repeat(row_repeat),
    .adc_tri(adc_tri),
    .adc_sample(adc_sample),
    .image_column(image_column),
    .adc_interval(adc_interval),
    .ultrafast_mode(ultrafast_mode),
    .acq_dead_time(acq_dead_time),
    .adc_acq_delay(adc_acq_delay),
    .laser_mode_en(laser_mode_en),
    .acq_time(acq_time),
    .adc_dco(adc_dco),
    .adc_data(adc_data),
    .div_adc_rd_en(div_adc_rd_en),
    .line_count(line_count),
    .line_count_en(line_count_en),
    .div_adc_rd_data_count(div_adc_rd_data_count),
    .div_adc_out(div_adc_out)
);

task fail;
    input [255:0] msg;
    begin
        errors = errors + 1;
        $display("FAIL: %0s at %0t", msg, $time);
    end
endtask

task check_eq;
    input [255:0] msg;
    input [63:0] got;
    input [63:0] exp;
    begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL: %0s got=%0d exp=%0d at %0t", msg, got, exp, $time);
        end
    end
endtask

task write_result_file;
    input [255:0] msg;
    integer fd;
    begin
        fd = $fopen("dl5_unit005_tb_result.txt", "w");
        if (fd != 0) begin
            $fdisplay(fd, "%0s", msg);
            $fclose(fd);
        end else begin
            $display("FAIL: could not write dl5_unit005_tb_result.txt");
        end
    end
endtask

task pulse_adc_tri;
    begin
        @(posedge adc_dco);
        adc_tri <= 1'b1;
        @(posedge adc_dco);
        adc_tri <= 1'b0;
    end
endtask

task wait_state;
    input [3:0] expected_state;
    input integer max_cycles;
    integer i;
    begin
        for (i = 0; i < max_cycles && dut.state !== expected_state; i = i + 1)
            @(negedge adc_dco);
        if (dut.state !== expected_state)
            fail("timeout waiting for expected state");
    end
endtask

task wait_window_and_count;
    input integer expected_cycles;
    integer cycles;
    integer i;
    begin
        wait_state(4'd2, 200);
        for (i = 0; i < 20 && dut.acq_en !== 1'b1; i = i + 1)
            @(negedge adc_dco);
        if (dut.acq_en !== 1'b1)
            fail("timeout waiting for acq_en high");

        cycles = 0;
        while (dut.acq_en === 1'b1 && cycles < 1000) begin
            cycles = cycles + 1;
            @(negedge adc_dco);
        end
        windows_seen = windows_seen + 1;
        check_eq("laser acq_en width", cycles, expected_cycles);
        wait_state(4'd0, 20);
    end
endtask

task assert_no_spontaneous_window;
    input integer cycles;
    integer i;
    begin
        for (i = 0; i < cycles; i = i + 1) begin
            @(negedge adc_dco);
            if (dut.acq_en !== 1'b0)
                fail("acq_en restarted without a new adc_tri");
            if (dut.state !== 4'd0)
                fail("state left trigger-wait without a new adc_tri");
        end
    end
endtask

initial begin
    $display("DL5_UNIT_005 adcdata_acq laser trigger-wait regression");
    repeat (8) @(posedge adc_dco);
    rstn <= 1'b1;
    repeat (12) @(posedge adc_dco);

    check_eq("laser adc_valid_point uses acq_time", dut.adc_valid_point, 64'd4);
    check_eq("laser adc_sample_reg uses acq_time", dut.adc_sample_reg, 64'd4);
    check_eq("laser adc_interval_reg is zero", dut.adc_interval_reg, 64'd0);

    $display("TC1: one trigger creates exactly one window");
    pulse_adc_tri();
    wait_window_and_count(4);
    check_eq("image_column_cnt after first trigger", dut.image_column_cnt, 64'd1);
    check_eq("line_count after first trigger", line_count, 64'd0);
    assert_no_spontaneous_window(30);

    $display("TC2: second trigger starts second pixel, no free-run");
    pulse_adc_tri();
    wait_window_and_count(4);
    check_eq("image_column_cnt after second trigger", dut.image_column_cnt, 64'd2);
    check_eq("line_count after second trigger", line_count, 64'd0);
    assert_no_spontaneous_window(30);

    $display("TC3: third trigger finishes the line");
    pulse_adc_tri();
    wait_window_and_count(4);
    check_eq("image_column_cnt clears at line end", dut.image_column_cnt, 64'd0);
    check_eq("line_count increments at line end", line_count, 64'd1);
    assert_no_spontaneous_window(30);

    if (windows_seen !== 3)
        fail("unexpected acquisition window count");

    if (errors == 0) begin
        $display("PASS");
        write_result_file("PASS");
        $finish;
    end else begin
        $display("FAIL: %0d error(s)", errors);
        write_result_file("FAIL");
        $finish;
    end
end

initial begin
    #200000;
    fail("simulation timeout");
    write_result_file("FAIL: simulation timeout");
    $finish;
end

endmodule

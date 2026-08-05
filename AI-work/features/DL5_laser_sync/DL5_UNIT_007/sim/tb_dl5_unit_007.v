`timescale 1ns / 1ps

module tb_dl5_unit_007;
reg eth_clk = 1'b0;
reg dac_dco = 1'b0;
reg rstn = 1'b0;
reg laser_mode_en = 1'b0;
reg ultrafast_mode = 1'b0;
reg laser_sync_rise_eth = 1'b0;

always #4 eth_clk = ~eth_clk;
always #10 dac_dco = ~dac_dco;

reg [15:0] row_repeat = 16'd1;
reg [31:0] dac_sample = 32'd2;
reg [15:0] image_row = 16'd2;
reg [15:0] dacx_strat_level = 16'h2000;
reg [63:0] dacx_step = 64'h2000_0000_0000_0000;
reg [15:0] dacx_tk_point = 16'd2;
reg [15:0] dacx_recovery_time = 16'd1;
reg [15:0] dacy_strat_level = 16'h3000;
reg [63:0] dacy_step = 64'd0;
reg [31:0] frame_waiting_time = 32'd0;
reg [31:0] dax_fall_time = 32'd4;
reg [15:0] dacx_pp_level = 16'h4000;
reg [15:0] sync1_pixel_tri_wigth = 16'd0;
reg [15:0] sync2_pixel_tri_wigth = 16'd0;
reg [15:0] row_m = 16'd1;
reg [15:0] row_n = 16'd1;
reg clk_sel = 1'b0;
reg TRIGGER_IN = 1'b0;
reg [31:0] ultrafast_line_rec = 32'd1;
reg [15:0] scan_delay_time = 16'd0;

wire laser_toggle;
wire [4:0] state;
wire [15:0] dbg_delay;
wire [31:0] dbg_sample;
wire [15:0] dbg_x;
wire [15:0] dbg_tb;
wire dbg_tail_sync;
wire dbg_tail_seen;
wire para_wr_en;
wire [34:0] para_data;
wire prog_full;
wire wr_busy;
wire tail_done_toggle_dac;
wire [15:0] dax;
wire [15:0] day;
wire adc_tri;
wire sync1;
wire sync2;
wire camera_sync;
integer errors = 0;
time tail_done_time;
time state14_time;
reg tail_done_seen = 1'b0;

always @(posedge tail_done_toggle_dac) begin
    tail_done_time = $time;
    tail_done_seen = 1'b1;
end

parameter_dacdata_gen gen (
    .ui_clk(eth_clk), .rstn(rstn), .row_repeat(row_repeat), .dac_sample(dac_sample),
    .image_row(image_row), .dacx_strat_level(dacx_strat_level), .dacx_step(dacx_step),
    .dacx_tk_point(dacx_tk_point), .dacx_recovery_time(dacx_recovery_time),
    .dacy_strat_level(dacy_strat_level), .dacy_step(dacy_step),
    .frame_waiting_time(frame_waiting_time), .dax_fall_time(dax_fall_time),
    .dacx_pp_level(dacx_pp_level), .sync1_pixel_tri_wigth(sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth(sync2_pixel_tri_wigth), .row_m(row_m), .row_n(row_n),
    .clk_sel(clk_sel), .TRIGGER_IN(TRIGGER_IN), .ultrafast_mode(ultrafast_mode),
    .ultrafast_line_rec(ultrafast_line_rec), .line_count(), .line_count_en(),
    .laser_mode_en(laser_mode_en), .laser_sync_rise_eth(laser_sync_rise_eth),
    .scan_delay_time(scan_delay_time), .laser_toggle(laser_toggle),
    .laser_tail_done_toggle_dac(tail_done_toggle_dac), .dl5_dbg_current_state(state),
    .dl5_dbg_scan_delay_cnt(dbg_delay), .dl5_dbg_dac_sample_cnt(dbg_sample),
    .dl5_dbg_dacx_tk_point_cnt(dbg_x), .dl5_dbg_dacx_tb_point_cnt(dbg_tb),
    .dl5_dbg_tail_done_sync(dbg_tail_sync), .dl5_dbg_tail_done_seen(dbg_tail_seen),
    .para_config_wr_en(para_wr_en), .para_config_data(para_data),
    .para_config_prog_full(prog_full), .para_config_wr_rst_busy(wr_busy)
);

dac_output outp (
    .eth_clk(eth_clk), .ui_clk(eth_clk), .rstn(rstn), .scan_state(1'b1),
    .dac_dco(dac_dco), .scan_mode(4'h1), .ultrafast_mode(ultrafast_mode),
    .sync1_pixel_tri_wigth(sync1_pixel_tri_wigth), .sync2_pixel_tri_wigth(sync2_pixel_tri_wigth),
    .sync_sig_delay1(16'd0), .sync_sig_delay2(16'd0), .DAX_DATA(dax), .DAY_DATA(day),
    .adc_tri(adc_tri), .sync_pixel_tri1(sync1), .sync_pixel_tri2(sync2),
    .camera_line_sync(camera_sync), .para_config_wr_en(para_wr_en),
    .para_config_data(para_data), .para_config_prog_full(prog_full),
    .para_config_wr_rst_busy(wr_busy), .laser_mode_en(laser_mode_en),
    .laser_toggle(laser_toggle), .laser_tail_done_toggle_dac(tail_done_toggle_dac),
    .blanker_delay_time(16'd0), .blanker_time(16'd0),
    .acq_data_delay_time(16'd0), .acq_time(16'd0)
);

task fail;
    input [255:0] msg;
    begin
        errors = errors + 1;
        $display("FAIL: %0s at %0t", msg, $time);
    end
endtask

task wait_state;
    input [4:0] target;
    input integer limit;
    integer n;
    begin
        n = 0;
        while (state != target && n < limit) begin @(posedge eth_clk); n = n + 1; end
        if (state != target) fail("state timeout");
    end
endtask

task pulse_laser;
    begin
        @(negedge eth_clk);
        laser_sync_rise_eth = 1'b1;
        @(negedge eth_clk);
        laser_sync_rise_eth = 1'b0;
    end
endtask

task reset_dut;
    begin
        rstn = 1'b0;
        repeat (8) @(posedge eth_clk);
        rstn = 1'b1;
        repeat (8) @(posedge eth_clk);
    end
endtask

task check_nonlaser_path;
    input expected_ultrafast;
    integer n;
    begin
        laser_mode_en = 1'b0;
        ultrafast_mode = expected_ultrafast;
        reset_dut;
        wait_state(5'd3, 1000);
        if (gen.fifo_bit32 !== gen.adc_tri) fail("FIFO[32] changed outside laser mode");
        for (n = 0; n < 100; n = n + 1) begin
            @(posedge eth_clk);
            if (state == 5'd17 || state == 5'd18) fail("nonlaser entered new recovery state");
            if (tail_done_toggle_dac !== 1'b0) fail("nonlaser toggled tail completion");
        end
    end
endtask

initial begin
    $display("DL5_UNIT_007 physical-flyback recovery regression");

    $display("TC1 normal mode preservation");
    check_nonlaser_path(1'b0);

    $display("TC2 ultrafast mode preservation");
    check_nonlaser_path(1'b1);

    $display("TC3 laser tail acknowledgement and recovery");
    laser_mode_en = 1'b1;
    ultrafast_mode = 1'b0;
    tail_done_seen = 1'b0;
    reset_dut;
    wait_state(5'd14, 2000);
    pulse_laser();
    wait_state(5'd14, 2000);
    pulse_laser();
    begin : wait_tail_done
        integer n;
        n = 0;
        while (!tail_done_seen && n < 3000) begin @(posedge eth_clk); n = n + 1; end
        if (!tail_done_seen) fail("tail done toggle timeout");
    end
    if (state == 5'd14) fail("State14 reached before tail completion");
    wait_state(5'd18, 2000);
    begin : reject_laser_during_recovery
        reg toggle_before;
        toggle_before = laser_toggle;
        pulse_laser();
        repeat (4) @(posedge eth_clk);
        if (laser_toggle !== toggle_before) fail("laser accepted during recovery");
    end
    wait_state(5'd14, 2000);
    state14_time = $time;
    if ((state14_time - tail_done_time) < 1000)
        fail("recovery began before one configured microsecond elapsed");
    $display("TC3 tail_done=%0t State14=%0t elapsed=%0t", tail_done_time, state14_time, state14_time-tail_done_time);
    pulse_laser();
    wait_state(5'd15, 100);

    if (errors == 0) begin
        $display("PASS");
        begin : write_pass
            integer fd;
            fd = $fopen("dl5_unit007_tb_result.txt", "w");
            $fdisplay(fd, "PASS");
            $fclose(fd);
        end
    end else begin
        $display("FAIL: %0d error(s)", errors);
        begin : write_fail
            integer fd;
            fd = $fopen("dl5_unit007_tb_result.txt", "w");
            $fdisplay(fd, "FAIL");
            $fclose(fd);
        end
    end
    $finish;
end

initial begin
    #100000;
    fail("global timeout");
    $finish;
end
endmodule

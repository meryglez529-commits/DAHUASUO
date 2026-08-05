`timescale 1ns / 1ps

module laser_marker_case #(
    parameter integer SAMPLE_COUNT = 4,
    parameter integer X_POINTS = 3
)(
    input eth_clk,
    input ui_clk,
    input dac_dco,
    output reg done,
    output reg [31:0] errors
);
localparam [15:0] START_CODE = 16'h1000;
localparam [15:0] STEP_CODE  = 16'h1000;
localparam [15:0] LAST_CODE  = START_CODE + (X_POINTS - 1) * STEP_CODE;
localparam integer EXPECTED_PIXEL_WORDS = SAMPLE_COUNT * X_POINTS;

reg rstn;
reg scan_state;
reg laser_sync_rise_eth;
wire laser_toggle;
wire [4:0] gen_state;
wire [15:0] gen_delay_cnt;
wire [31:0] gen_sample_cnt;
wire [15:0] gen_x_cnt;
wire [15:0] gen_recovery_cnt;
wire gen_wr_en;
wire [34:0] gen_data;
wire gen_prog_full;
wire gen_wr_rst_busy;
wire [15:0] dac_x;
wire [15:0] dac_y;
wire dac_adc_tri;
wire legacy_sync1;
wire legacy_sync2;
wire camera_line_sync;
wire [15:0] unused_line_count;
wire unused_line_count_en;

integer marker_start_count;
integer marker_end_count;
integer pixel_words_in_line;
integer camera_fall_count;
integer camera_rise_count;
integer camera_low_words;
reg tracking_line;
reg camera_prev;
reg [15:0] last_low_dax;
integer pulse_index;

task report_fail;
    input [8*112-1:0] message;
    begin
        $display("FAIL laser sample=%0d x=%0d: %0s", SAMPLE_COUNT, X_POINTS, message);
        errors = errors + 1;
    end
endtask

task send_laser_pulse;
    begin
        wait (gen_state === 5'd14);
        @(negedge eth_clk);
        laser_sync_rise_eth = 1'b1;
        @(negedge eth_clk);
        laser_sync_rise_eth = 1'b0;
    end
endtask

parameter_dacdata_gen generator(
    // parameter_dacdata_gen 的 ui_clk 端口名是历史遗留；工程实际接 eth_clk。
    .ui_clk(eth_clk),
    .rstn(rstn),
    .row_repeat(16'd1),
    .dac_sample(SAMPLE_COUNT),
    .image_row(16'd1),
    .dacx_strat_level(START_CODE),
    .dacx_step({STEP_CODE, 48'd0}),
    .dacx_tk_point(X_POINTS),
    .dacx_recovery_time(16'd1),
    .dacy_strat_level(16'h2000),
    .dacy_step(64'd0),
    .frame_waiting_time(32'd5000),
    .dax_fall_time(32'd2),
    .dacx_pp_level((X_POINTS - 1) * STEP_CODE),
    .sync1_pixel_tri_wigth(16'd1),
    .sync2_pixel_tri_wigth(16'd1),
    .row_m(16'd1),
    .row_n(16'd1),
    .clk_sel(1'b0),
    .TRIGGER_IN(1'b0),
    .ultrafast_mode(1'b0),
    .ultrafast_line_rec(32'd0),
    .line_count(unused_line_count),
    .line_count_en(unused_line_count_en),
    .laser_mode_en(1'b1),
    .laser_sync_rise_eth(laser_sync_rise_eth),
    .scan_delay_time(16'd0),
    .laser_toggle(laser_toggle),
    .dl5_dbg_current_state(gen_state),
    .dl5_dbg_scan_delay_cnt(gen_delay_cnt),
    .dl5_dbg_dac_sample_cnt(gen_sample_cnt),
    .dl5_dbg_dacx_tk_point_cnt(gen_x_cnt),
    .dl5_dbg_dacx_tb_point_cnt(gen_recovery_cnt),
    .para_config_wr_en(gen_wr_en),
    .para_config_data(gen_data),
    .para_config_prog_full(gen_prog_full),
    .para_config_wr_rst_busy(gen_wr_rst_busy)
);

dac_output consumer(
    .eth_clk(eth_clk),
    .ui_clk(ui_clk),
    .rstn(rstn),
    .scan_state(scan_state),
    .dac_dco(dac_dco),
    .scan_mode(4'h1),
    .ultrafast_mode(1'b0),
    .sync1_pixel_tri_wigth(16'd1),
    .sync2_pixel_tri_wigth(16'd1),
    .sync_sig_delay1(16'd0),
    .sync_sig_delay2(16'd0),
    .DAX_DATA(dac_x),
    .DAY_DATA(dac_y),
    .adc_tri(dac_adc_tri),
    .sync_pixel_tri1(legacy_sync1),
    .sync_pixel_tri2(legacy_sync2),
    .camera_line_sync(camera_line_sync),
    .para_config_wr_en(gen_wr_en),
    .para_config_data(gen_data),
    .para_config_prog_full(gen_prog_full),
    .para_config_wr_rst_busy(gen_wr_rst_busy),
    .laser_mode_en(1'b1),
    .laser_toggle(laser_toggle),
    .blanker_delay_time(16'd1),
    .blanker_time(16'd1),
    .acq_data_delay_time(16'd1),
    .acq_time(16'd1)
);

// The generator output is sampled before nonblocking updates, exactly as the
// FIFO write port samples it.  This proves marker/data/write-enable alignment.
always @(posedge eth_clk) begin
    if (!rstn) begin
        marker_start_count = 0;
        marker_end_count = 0;
        pixel_words_in_line = 0;
        tracking_line = 1'b0;
    end
    else if (gen_wr_en) begin
        if (gen_data[34]) begin
            marker_start_count = marker_start_count + 1;
            if (tracking_line)
                report_fail("second line-start marker before line end");
            tracking_line = 1'b1;
            pixel_words_in_line = 1;
            if (gen_data[31:16] !== START_CODE)
                report_fail("line-start marker is not on first DAX word");
        end
        else if (tracking_line)
            pixel_words_in_line = pixel_words_in_line + 1;

        if (gen_data[33]) begin
            marker_end_count = marker_end_count + 1;
            if (!tracking_line)
                report_fail("line-end marker without an active line");
            if (pixel_words_in_line != EXPECTED_PIXEL_WORDS)
                report_fail("line-end marker is not on final pixel word");
            if (gen_data[31:16] !== LAST_CODE)
                report_fail("line-end marker is not on final DAX code");
            tracking_line = 1'b0;
        end
    end
end

// DAC-domain acceptance test: low starts with the first pixel, spans every
// pixel word, and releases as the first tail/non-pixel word is presented.
always @(posedge dac_dco) begin
    #1;
    if (!rstn) begin
        camera_prev = 1'b1;
        camera_fall_count = 0;
        camera_rise_count = 0;
        camera_low_words = 0;
        last_low_dax = 16'd0;
    end
    else begin
        if (!camera_line_sync) begin
            if (camera_prev) begin
                camera_fall_count = camera_fall_count + 1;
                if (dac_x !== START_CODE)
                    report_fail("camera low does not start on first DAX code");
            end
            camera_low_words = camera_low_words + 1;
            last_low_dax = dac_x;
        end
        if (!camera_prev && camera_line_sync) begin
            camera_rise_count = camera_rise_count + 1;
            if (last_low_dax !== LAST_CODE)
                report_fail("camera released before final DAX code");
        end
        camera_prev = camera_line_sync;
    end
end

initial begin
    done = 1'b0;
    errors = 0;
    rstn = 1'b0;
    scan_state = 1'b0;
    laser_sync_rise_eth = 1'b0;
    repeat (6) @(posedge eth_clk);
    rstn = 1'b1;
    scan_state = 1'b1;
    for (pulse_index = 0; pulse_index < X_POINTS; pulse_index = pulse_index + 1)
        send_laser_pulse;
    wait (marker_end_count == 1);
    wait (camera_rise_count == 1);
    repeat (4) @(posedge dac_dco);
    if (marker_start_count != 1)
        report_fail("expected exactly one line-start marker");
    if (marker_end_count != 1)
        report_fail("expected exactly one line-end marker");
    if (tracking_line)
        report_fail("line remained active after end marker");
    if (camera_fall_count != 1 || camera_rise_count != 1)
        report_fail("expected exactly one active-low camera window");
    if (camera_low_words != EXPECTED_PIXEL_WORDS)
        report_fail("camera low width does not equal all pixel words");
    done = 1'b1;
end
endmodule

// Regression for the unchanged normal/ultrafast DAC-domain path.  Words are
// driven directly because this unit changes only the generator's laser marker
// packing; the existing FIFO[32] consumer contract must remain invariant.
module legacy_camera_case(
    input eth_clk,
    input ui_clk,
    input dac_dco,
    output reg done,
    output reg [31:0] errors
);
reg rstn;
reg scan_state;
reg ultrafast_mode;
reg wr_en;
reg [34:0] wr_data;
wire prog_full;
wire wr_rst_busy;
wire [15:0] dax;
wire [15:0] day;
wire adc_tri;
wire sync1;
wire sync2;
wire camera_line_sync;
reg camera_prev;
reg sync2_seen;
reg [1:0] phase;
integer normal_fall_count;
integer normal_rise_count;
integer ultrafast_fall_count;
integer ultrafast_rise_count;
integer normal_low_words;
integer ultrafast_low_words;

task report_fail;
    input [8*112-1:0] message;
    begin
        $display("FAIL legacy regression: %0s", message);
        errors = errors + 1;
    end
endtask

task push_word;
    input [34:0] word;
    begin
        @(negedge eth_clk);
        wr_data = word;
        wr_en = 1'b1;
        @(negedge eth_clk);
        wr_en = 1'b0;
    end
endtask

dac_output consumer(
    .eth_clk(eth_clk), .ui_clk(ui_clk), .rstn(rstn), .scan_state(scan_state),
    .dac_dco(dac_dco), .scan_mode(4'h1), .ultrafast_mode(ultrafast_mode),
    .sync1_pixel_tri_wigth(16'd1), .sync2_pixel_tri_wigth(16'd1),
    .sync_sig_delay1(16'd0), .sync_sig_delay2(16'd0),
    .DAX_DATA(dax), .DAY_DATA(day), .adc_tri(adc_tri),
    .sync_pixel_tri1(sync1), .sync_pixel_tri2(sync2),
    .camera_line_sync(camera_line_sync), .para_config_wr_en(wr_en),
    .para_config_data(wr_data), .para_config_prog_full(prog_full),
    .para_config_wr_rst_busy(wr_rst_busy), .laser_mode_en(1'b0),
    .laser_toggle(1'b0), .blanker_delay_time(16'd0), .blanker_time(16'd0),
    .acq_data_delay_time(16'd1), .acq_time(16'd1)
);

always @(posedge dac_dco) begin
    #1;
    if (!rstn) begin
        camera_prev = 1'b1;
        normal_fall_count = 0;
        normal_rise_count = 0;
        ultrafast_fall_count = 0;
        ultrafast_rise_count = 0;
        normal_low_words = 0;
        ultrafast_low_words = 0;
    end
    else begin
        if (camera_prev && !camera_line_sync) begin
            if (phase == 1)
                normal_fall_count = normal_fall_count + 1;
            else if (phase == 2)
                ultrafast_fall_count = ultrafast_fall_count + 1;
        end
        if (!camera_line_sync) begin
            if (phase == 1)
                normal_low_words = normal_low_words + 1;
            else if (phase == 2)
                ultrafast_low_words = ultrafast_low_words + 1;
        end
        if (!camera_prev && camera_line_sync) begin
            if (phase == 1)
                normal_rise_count = normal_rise_count + 1;
            else if (phase == 2)
                ultrafast_rise_count = ultrafast_rise_count + 1;
        end
        camera_prev = camera_line_sync;
    end
end

always @(posedge ui_clk) begin
    if (!rstn)
        sync2_seen = 1'b0;
    else if (sync2)
        sync2_seen = 1'b1;
end

initial begin
    done = 1'b0;
    errors = 0;
    rstn = 1'b0;
    scan_state = 1'b0;
    ultrafast_mode = 1'b0;
    wr_en = 1'b0;
    wr_data = 35'd0;
    phase = 0;
    repeat (6) @(posedge eth_clk);
    rstn = 1'b1;
    scan_state = 1'b1;
    repeat (6) @(posedge dac_dco);

    phase = 1;
    push_word({3'b000, 16'h0100, 16'h0200});
    push_word({3'b001, 16'h0101, 16'h0200});
    push_word({3'b001, 16'h0102, 16'h0200});
    push_word({3'b001, 16'h0103, 16'h0200});
    push_word({3'b001, 16'h0104, 16'h0200});
    push_word({3'b000, 16'h0105, 16'h0200});
    wait (normal_rise_count == 1);
    if (normal_fall_count != 1 || normal_low_words != 4)
        report_fail("normal FIFO[32] camera window changed");

    scan_state = 1'b0;
    repeat (6) @(posedge dac_dco);
    ultrafast_mode = 1'b1;
    scan_state = 1'b1;
    phase = 2;
    push_word({3'b000, 16'h0200, 16'h0300});
    push_word({3'b101, 16'h0201, 16'h0300});
    push_word({3'b001, 16'h0202, 16'h0300});
    push_word({3'b001, 16'h0203, 16'h0300});
    push_word({3'b000, 16'h0204, 16'h0300});
    wait (ultrafast_rise_count == 1);
    repeat (20) @(posedge ui_clk);
    if (ultrafast_fall_count != 1 || ultrafast_low_words != 3)
        report_fail("ultrafast FIFO[32] camera window changed");
    if (!sync2_seen)
        report_fail("ultrafast legacy sync2 is no longer observable");
    done = 1'b1;
end
endmodule

module tb_dl1_unit_002_marker_alignment;
reg eth_clk = 1'b0;
reg ui_clk = 1'b0;
reg dac_dco = 1'b0;
wire done_s1;
wire done_s4;
wire done_s50;
wire done_legacy;
wire [31:0] errors_s1;
wire [31:0] errors_s4;
wire [31:0] errors_s50;
wire [31:0] errors_legacy;

always #4 eth_clk = ~eth_clk;
always #2.5 ui_clk = ~ui_clk;
always #10 dac_dco = ~dac_dco;

laser_marker_case #(.SAMPLE_COUNT(1),  .X_POINTS(1))  case_sample_1 (
    .eth_clk(eth_clk), .ui_clk(ui_clk), .dac_dco(dac_dco), .done(done_s1), .errors(errors_s1));
laser_marker_case #(.SAMPLE_COUNT(4),  .X_POINTS(3))  case_sample_4 (
    .eth_clk(eth_clk), .ui_clk(ui_clk), .dac_dco(dac_dco), .done(done_s4), .errors(errors_s4));
laser_marker_case #(.SAMPLE_COUNT(50), .X_POINTS(3)) case_sample_50 (
    .eth_clk(eth_clk), .ui_clk(ui_clk), .dac_dco(dac_dco), .done(done_s50), .errors(errors_s50));
legacy_camera_case legacy_regression (
    .eth_clk(eth_clk), .ui_clk(ui_clk), .dac_dco(dac_dco), .done(done_legacy), .errors(errors_legacy));

initial begin
    wait (done_s1 && done_s4 && done_s50 && done_legacy);
    if ((errors_s1 + errors_s4 + errors_s50 + errors_legacy) == 0)
        $display("PASS: DL1_UNIT_002 marker alignment and normal/ultrafast regression");
    else
        $display("FAIL: DL1_UNIT_002 errors=%0d", errors_s1 + errors_s4 + errors_s50 + errors_legacy);
    $finish;
end

initial begin
    #100000;
    $display("FAIL: DL1_UNIT_002 simulation timeout");
    $finish;
end
endmodule

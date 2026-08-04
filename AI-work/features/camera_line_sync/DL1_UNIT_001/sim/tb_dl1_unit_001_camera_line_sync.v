`timescale 1ns / 1ps
module tb_dl1_unit_001_camera_line_sync;
reg eth_clk=0,ui_clk=0,dac_dco=0,rstn=0,scan_state=0,ultrafast_mode=0,para_wr_en=0,laser_mode_en=0,laser_toggle=0;
reg [3:0] scan_mode=4'h1; reg [15:0] sync1_width=2,sync2_width=2,sync_delay1=0,sync_delay2=0,blanker_delay=0,blanker_time=0,acq_delay=0,acq_time=2;
reg [34:0] para_data=0; wire camera_line_sync,sync1,sync2,adc_tri,prog_full,wr_busy; wire [15:0] dax,day;
integer errors=0,fall_count=0,rise_count=0; reg previous_camera=1,sync2_seen=0;
always #4 eth_clk=~eth_clk; always #2.5 ui_clk=~ui_clk; always #10 dac_dco=~dac_dco;
dac_output dut(.eth_clk(eth_clk),.ui_clk(ui_clk),.rstn(rstn),.scan_state(scan_state),.dac_dco(dac_dco),.scan_mode(scan_mode),.ultrafast_mode(ultrafast_mode),.sync1_pixel_tri_wigth(sync1_width),.sync2_pixel_tri_wigth(sync2_width),.sync_sig_delay1(sync_delay1),.sync_sig_delay2(sync_delay2),.DAX_DATA(dax),.DAY_DATA(day),.adc_tri(adc_tri),.sync_pixel_tri1(sync1),.sync_pixel_tri2(sync2),.camera_line_sync(camera_line_sync),.para_config_wr_en(para_wr_en),.para_config_data(para_data),.para_config_prog_full(prog_full),.para_config_wr_rst_busy(wr_busy),.laser_mode_en(laser_mode_en),.laser_toggle(laser_toggle),.blanker_delay_time(blanker_delay),.blanker_time(blanker_time),.acq_data_delay_time(acq_delay),.acq_time(acq_time));
always @(posedge dac_dco) begin #1; if(previous_camera&&!camera_line_sync) fall_count=fall_count+1; if(!previous_camera&&camera_line_sync) rise_count=rise_count+1; previous_camera=camera_line_sync; end
always @(posedge ui_clk) if(sync2) sync2_seen=1;
task push_word(input [34:0] word); begin @(posedge eth_clk); para_data<=word; para_wr_en<=1; @(posedge eth_clk); para_wr_en<=0; end endtask
task expect(input condition,input [8*80-1:0] message); begin if(!condition) begin $display("FAIL: %0s",message); errors=errors+1; end end endtask
initial begin
 repeat(5) @(posedge dac_dco); rstn=1; scan_state=1; repeat(5) @(posedge dac_dco);
 push_word({3'b000,16'h0100,16'h0200}); push_word({3'b001,16'h0101,16'h0200}); push_word({3'b001,16'h0102,16'h0200}); push_word({3'b001,16'h0103,16'h0200}); push_word({3'b000,16'h0104,16'h0200});
 repeat(16) @(posedge dac_dco); expect(fall_count==1&&rise_count==1,"TC1 normal mode must produce one camera low window");
 fall_count=0; rise_count=0; sync2_seen=0; ultrafast_mode=1; repeat(4) @(posedge dac_dco);
 push_word({3'b101,16'h0201,16'h0300}); push_word({3'b001,16'h0202,16'h0300}); push_word({3'b000,16'h0203,16'h0300});
 repeat(16) @(posedge dac_dco); expect(fall_count==1&&rise_count==1,"TC2 ultrafast mode must produce one camera low window"); expect(sync2_seen,"TC2 ultrafast legacy sync2 must remain observable");
 scan_state=0; repeat(4) @(posedge dac_dco); laser_mode_en=1; ultrafast_mode=1; scan_state=1; repeat(5) @(posedge dac_dco); sync2_seen=0;
 push_word({3'b100,16'h0301,16'h0400}); wait(dut.camera_line_active===1); repeat(4) @(posedge dac_dco); expect(!camera_line_sync,"TC3 laser idle gap must keep camera line active");
 push_word({3'b000,16'h0302,16'h0400}); push_word({3'b010,16'h0303,16'h0400}); wait(dut.camera_line_end_pending===1); expect(!camera_line_sync,"TC4 final laser word must remain inside low window"); @(posedge dac_dco); #1; expect(camera_line_sync,"TC4 camera line must release one DAC clock after end marker"); expect(!sync2_seen,"TC5 laser markers must not drive legacy sync2");
 if(errors==0) $display("PASS"); else $display("FAIL: errors = %0d",errors); $finish;
end
initial begin #200000; $display("FAIL: timeout"); $finish; end
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/01 11:19:50
// Design Name: 
// Module Name: rep_done_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rep_done_sync(
        input clk,
        input comb_indep_w,
        input [3:0] comb_indep_sw,

        input           chn0_rep_done,
        input           chn1_rep_done,
        input           chn2_rep_done,
        input           chn3_rep_done,

        output          chn0_rep_done_s,
        output          chn1_rep_done_s,
        output          chn2_rep_done_s,
        output          chn3_rep_done_s,  
        output          chn_rep_done_s
    );

wire chn0_rep_done_s_w;
wire chn1_rep_done_s_w;
wire chn2_rep_done_s_w;
wire chn3_rep_done_s_w;

reg chn0_rep_done_s_r = 1'b0;
reg chn1_rep_done_s_r = 1'b0;
reg chn2_rep_done_s_r = 1'b0;
reg chn3_rep_done_s_r = 1'b0;
reg chn_rep_done_s_r0 = 1'b0;
reg chn_rep_done_s_r1 = 1'b0;
reg chn_rep_done_s_r2 = 1'b0;
always @(posedge clk) begin
    chn0_rep_done_s_r <= chn0_rep_done_s_w;
    chn1_rep_done_s_r <= chn1_rep_done_s_w;
    chn2_rep_done_s_r <= chn2_rep_done_s_w;
    chn3_rep_done_s_r <= chn3_rep_done_s_w; 

    chn_rep_done_s_r1 <= chn_rep_done_s_r0;
    chn_rep_done_s_r2 <= chn_rep_done_s_r1;
end

always @(posedge clk)
if(comb_indep_w) begin
   case(comb_indep_sw)
      4'b0000:begin
        chn_rep_done_s_r0 <= 1'b0;
      end
      4'b0001:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w;
      end
      4'b0010:begin
        chn_rep_done_s_r0 <= chn1_rep_done_s_w;
      end
      4'b0011:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn1_rep_done_s_w;
      end
      4'b0100:begin
        chn_rep_done_s_r0 <= chn2_rep_done_s_w;
      end
      4'b0101:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn2_rep_done_s_w;
      end
      4'b0110:begin
        chn_rep_done_s_r0 <= chn1_rep_done_s_w & chn2_rep_done_s_w;
      end
      4'b0111:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn1_rep_done_s_w & chn2_rep_done_s_w;
      end
      4'b1000:begin
        chn_rep_done_s_r0 <= chn3_rep_done_s_w;
      end
      4'b1001:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1010:begin
        chn_rep_done_s_r0 <= chn1_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1011:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn1_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1100:begin
        chn_rep_done_s_r0 <= chn2_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1101:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn2_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1110:begin
        chn_rep_done_s_r0 <= chn1_rep_done_s_w & chn2_rep_done_s_w & chn3_rep_done_s_w;
      end
      4'b1111:begin
        chn_rep_done_s_r0 <= chn0_rep_done_s_w & chn1_rep_done_s_w & chn2_rep_done_s_w & chn3_rep_done_s_w;
      end
   endcase
end 
else begin
  chn_rep_done_s_r0 <= 1'b0;
end



assign chn0_rep_done_s = chn0_rep_done_s_w && (!chn0_rep_done_s_r);  //rising edge 
assign chn1_rep_done_s = chn1_rep_done_s_w && (!chn1_rep_done_s_r);
assign chn2_rep_done_s = chn2_rep_done_s_w && (!chn2_rep_done_s_r);
assign chn3_rep_done_s = chn3_rep_done_s_w && (!chn3_rep_done_s_r);
assign chn_rep_done_s  = chn_rep_done_s_r1 && (!chn_rep_done_s_r2);



  xpm_cdc_single #(
      .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst_ch0 (
      .dest_out(chn0_rep_done_s_w), // 1-bit output: src_in synchronized to the destination clock domain. This output is
      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(chn0_rep_done)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );
  
  
 
  xpm_cdc_single #(
      .DEST_SYNC_FF(6),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst_ch1 (
      .dest_out(chn1_rep_done_s_w), // 1-bit output: src_in synchronized to the destination clock domain. This output is
      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(chn1_rep_done)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );


  xpm_cdc_single #(
      .DEST_SYNC_FF(8),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst_ch2 (
      .dest_out(chn2_rep_done_s_w), // 1-bit output: src_in synchronized to the destination clock domain. This output is
      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(chn2_rep_done)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );

  xpm_cdc_single #(
      .DEST_SYNC_FF(10),   // DECIMAL; range: 2-10
      .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
   )
   xpm_cdc_single_inst_ch3 (
      .dest_out(chn3_rep_done_s_w), // 1-bit output: src_in synchronized to the destination clock domain. This output is
      .dest_clk(clk), // 1-bit input: Clock signal for the destination clock domain.
      .src_clk(),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
      .src_in(chn3_rep_done)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
   );





endmodule

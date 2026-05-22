`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/19 10:33:47
// Design Name: 
// Module Name: sync_signal
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
module sync_signal(
    input data_a,
    input clka,
    input rstn_a,
    input clkb,
    input rstn_b,
    output data_b
    );
    ////////////////////
wire    empty;
reg     rd_en;
fifo_generator_11 sync_fifo(
    .wr_clk (clka),
    .wr_rst (~rstn_a),
    .rd_clk (clkb),
    .rd_rst (~rstn_b),
    .din    (data_a),
    .wr_en  (rstn_a),
    .rd_en  (rd_en),
    .dout   (data_b),
    .empty  (empty)
    );
    
always@(posedge clkb or negedge rstn_b)
begin
   if(!rstn_b) 
    rd_en <= 1'b0;
  else if(empty==0 && rd_en ==0)
    rd_en <= 1'b1;   
  else
    rd_en <= 1'b0;   
end

endmodule
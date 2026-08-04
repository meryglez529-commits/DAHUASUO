`timescale 1ns / 1ps
module BUFG(input I, output O); assign O = I; endmodule
module sync_module(input data_in, input clk_in, output reg data_out);
always @(posedge clk_in) data_out <= data_in;
endmodule
module fifo_generator_4(
 input wr_clk,input rst,input rd_clk,input [34:0] din,input wr_en,input rd_en,
 output reg [34:0] dout,output prog_full,output prog_empty,output wr_rst_busy,output rd_rst_busy);
reg [34:0] mem [0:63]; integer wr_ptr=0,rd_ptr=0,count=0;
assign prog_full=(count>56); assign prog_empty=(count==0); assign wr_rst_busy=0; assign rd_rst_busy=0;
always @(posedge wr_clk or posedge rst) begin if(rst) begin wr_ptr<=0; count<=0; end else if(wr_en&&count<64) begin mem[wr_ptr]<=din; wr_ptr<=(wr_ptr+1)%64; count<=count+1; end end
always @(posedge rd_clk or posedge rst) begin if(rst) begin rd_ptr<=0; dout<=0; end else if(rd_en&&count>0) begin dout<=mem[rd_ptr]; rd_ptr<=(rd_ptr+1)%64; count<=count-1; end end
endmodule
module ila_1(input clk,input probe0,input [31:0] probe1,input [3:0] probe2,input probe3,input [31:0] probe4,input [15:0] probe5,input probe6); endmodule
module ila_2(input clk,input probe0,input [15:0] probe1,input [15:0] probe2); endmodule
module ila_3(input clk,input [3:0] probe0,input probe1,input [31:0] probe2,input [15:0] probe3,input probe4,input probe5); endmodule
module ila_12(input clk,input probe0,input [15:0] probe1,input probe2,input probe3,input probe4,input [15:0] probe5,input [3:0] probe6,input [15:0] probe7,input [23:0] probe8,input [23:0] probe9,input [15:0] probe10,input [31:0] probe11,input [15:0] probe12,input probe13,input [31:0] probe14,input [31:0] probe15); endmodule

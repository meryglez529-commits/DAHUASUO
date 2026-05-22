`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/06 09:18:15
// Design Name: 
// Module Name: LAN_TX_TOP
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


module LAN_TX_TOP#(
 parameter ILA_DEBUG = 1'b0
)(
   input                 fifo_wr_clk,
   input     [31:0]      wr_num,
   input     [7:0]       tx_fifo_din,
   input                 tx_fifo_wr_en,
   output    [9:0]       wr_data_count,
   output                wr_done,
//------ ETH
	input	 [47:0]  DES_MAC, 
	input	 [47:0]  SOR_MAC,  
	input	 [15:0]  FRAME_TYPE,
//------ IP                 
	input	 [15:0]  IP_VERSION,
	input	 [15:0]  IP_PAC_ID,
	input	 [31:0]  IP_INF,   
	input	 [31:0]  SOR_IP,   
	input	 [31:0]  DES_IP,   
//------ UDP                  
	input	 [15:0]  SOR_PORT,
	input	 [15:0]  DES_PORT,
    
   input                 tx_fifo_clock,
   input                 tx_fifo_resetn,
   
   output  [7:0]          tx_axis_fifo_tdata,
   output                 tx_axis_fifo_tvalid,
   output                 tx_axis_fifo_tlast,
   input                  tx_axis_fifo_tready

    );
 
wire wr_fifo_rden; 
wire wr_fifo_empty; 
wire wr_fifo_halffull; 
wire [9:0] wr_fifo_count; 
wire [7:0] wr_data;

reg rst = 1'b1;
reg [4:0] cnt = 0;
always@(posedge fifo_wr_clk)
    if(cnt < 5'd30)
        begin
            rst <= 1'b1;
            cnt <= cnt + 1'b1;
        end
    else
        begin
            rst <= 1'b0;
            cnt <= cnt;
        end

fifo_lan_tx inst_fifo_lan_tx (
  .rst(rst),                  // input wire rst
  .wr_clk(fifo_wr_clk),            // input wire wr_clk
  .rd_clk(tx_fifo_clock),            // input wire rd_clk
  .din(tx_fifo_din),                  // input wire [7 : 0] din
  .wr_en(tx_fifo_wr_en),              // input wire wr_en
  .rd_en(wr_fifo_rden),              // input wire rd_en
  .dout(wr_data),                // output wire [7 : 0] dout
  .full(),                // output wire full
  .almost_full(),      // output wire almost_full
  .empty(wr_fifo_empty),              // output wire empty
  .wr_data_count(wr_data_count),  // output wire [9 : 0] wr_data_count
  .rd_data_count(wr_fifo_count),  // output wire [9 : 0] rd_data_count
  .prog_full(wr_fifo_halffull),      // output wire prog_full
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);    
 
wire lan_eof_n; 
wire lan_vld_n; 
assign tx_axis_fifo_tvalid = !lan_vld_n;
assign tx_axis_fifo_tlast  = !lan_eof_n;
    
lan_tx#(
 .ILA_DEBUG(ILA_DEBUG)
)  lan_tx_inst (
   // Input Ports - Single Bit
   .clk                 (tx_fifo_clock), 
   .reset               (!tx_fifo_resetn),  
   //WRITE PORT
   .wr_num              (wr_num[31:0]),
   .wr_fifo_empty       (wr_fifo_empty),
   .wr_fifo_halffull    (wr_fifo_halffull), 
   .wr_fifo_count       (wr_fifo_count[9:0]),
   .wr_fifo_rden        (wr_fifo_rden),
   .wr_data             (wr_data[7:0]),  
   .wr_done             (wr_done), 
   
   //ETHERNET
   .DES_MAC         (DES_MAC[47:0]),
   .SOR_MAC         (SOR_MAC[47:0]),         
   .FRAME_TYPE      (FRAME_TYPE[15:0]),
   //IP
   .IP_VERSION      (IP_VERSION[15:0]),
   .IP_INF          (IP_INF[31:0]),     
   .IP_PAC_ID       (IP_PAC_ID[15:0]),  
   .DES_IP          (DES_IP[31:0]),
   .SOR_IP          (SOR_IP[31:0]),
   //UDP
   .DES_PORT         (DES_PORT[15:0]),      
   .SOR_PORT          (SOR_PORT[15:0]),   
   //USER PORT
   .lan_rdy_n           (!tx_axis_fifo_tready), 
   .lan_eof_n           (lan_eof_n),        
   .lan_sof_n           (),        
   .lan_vld_n           (lan_vld_n),        
   .lan_data            (tx_axis_fifo_tdata)      
);    
    
    
 
endmodule

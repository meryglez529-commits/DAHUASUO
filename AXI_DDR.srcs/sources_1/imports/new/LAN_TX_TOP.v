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
module LAN_TX_TOP(
    input           tx_fifo_clock,
    input           tx_fifo_resetn,
    input           RD_ACK_i,
    input           data_ACK_i,
    output          prog_full,
    input   [21:0]  wr_pack_num,
    input   [15:0]  wr_last_pack_num,
    input   [7:0]   tx_fifo_din,
    input           tx_fifo_wr_en,
    output          wr_done,
    //------ ETH//------ IP//------ UDP 
    input   [47:0]  DES_MAC, 
    input	[47:0]  SOR_MAC,  
    input	[15:0]  FRAME_TYPE,       
    input   [15:0]  IP_VERSION,
    input	[15:0]  IP_PAC_ID,
    input	[31:0]  IP_INF,   
    input	[31:0]  SOR_IP,   
    input   [31:0]  DES_IP,              
    input	[15:0]  SOR_PORT,
    input	[15:0]  DES_PORT,
    //AXI-4
    output  [7:0]   tx_axis_fifo_tdata,
    output          tx_axis_fifo_tvalid,
    output          tx_axis_fifo_tlast,
    input           tx_axis_fifo_tready
    );
    
    wire            wr_fifo_rden; 
    wire    [11:0]  data_count; 
    wire    [7:0]   wr_data;
fifo_lan_tx inst_fifo_lan_tx (
    .clk            (tx_fifo_clock),   
    .srst           (!tx_fifo_resetn),  
    .din            (tx_fifo_din),              
    .wr_en          (tx_fifo_wr_en),            
    .rd_en          (wr_fifo_rden),             
    .dout           (wr_data),                         
    .data_count     (data_count),
    .prog_full      (prog_full)              
    );    
 
    wire            lan_eof_n; 
    wire            lan_vld_n; 
    assign tx_axis_fifo_tvalid = !lan_vld_n;
    assign tx_axis_fifo_tlast  = !lan_eof_n;
lan_tx lan_tx_inst (
    // Input Ports - Single Bit
    .clk            (tx_fifo_clock), 
    .reset          (!tx_fifo_resetn), 
    .RD_ACK_i       (RD_ACK_i),
    .data_ACK_i     (data_ACK_i),  
    .wr_pack_num    (wr_pack_num),
    .wr_last_pack_num(wr_last_pack_num), 
    //WRITE PORT
    .data_count     (data_count),
    .wr_fifo_rden   (wr_fifo_rden),
    .wr_data        (wr_data[7:0]),  
    .wr_done        (wr_done), 
    //ETHERNET//IP//UDP
    .DES_MAC        (DES_MAC[47:0]),
    .SOR_MAC        (SOR_MAC[47:0]),         
    .FRAME_TYPE     (FRAME_TYPE[15:0]),
    .IP_VERSION     (IP_VERSION[15:0]),
    .IP_INF         (IP_INF[31:0]),     
    .IP_PAC_ID      (IP_PAC_ID[15:0]),  
    .DES_IP         (DES_IP[31:0]),
    .SOR_IP         (SOR_IP[31:0]),
    .DES_PORT       (DES_PORT[15:0]),      
    .SOR_PORT       (SOR_PORT[15:0]),   
    //USER PORT
    .lan_rdy_n      (!tx_axis_fifo_tready), 
    .lan_eof_n      (lan_eof_n),        
    .lan_sof_n      (),        
    .lan_vld_n      (lan_vld_n),        
    .lan_data       (tx_axis_fifo_tdata)      
    );    
    
endmodule
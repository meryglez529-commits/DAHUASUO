`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/05 14:47:26
// Design Name: 
// Module Name: ICMP_TOP
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


module ICMP_TOP(
    input                                axi_tclk,
    input                                axi_tresetn,
    input                                init_done,
    // data from the RX data path
    input       [7:0]                    rx_axis_tdata,
    input                                rx_axis_tvalid,
    input                                rx_axis_tlast,
    output                               rx_axis_tready,
    // data TO the TX data path
    output      [7:0]                    tx_axis_tdata,
    output                               tx_axis_tvalid,
    output                               tx_axis_tlast,
    input                                tx_axis_tready,
    
    output                               ICMP_pc_req_o,
    input                                ICMP_ACK_i,
    output                               tx_ICMP_busy,
    input     [47:0]                     SOR_MAC_UDP,
    input     [31:0]                     SOR_IP_UDP
    );
    assign rx_axis_tready = 1'b1;
  
  wire lan_vld_n; 
  wire lan_eof_n; 
  assign tx_axis_tvalid = !lan_vld_n;
  assign tx_axis_tlast  = !lan_eof_n;
  LAN_RX_TX_ICMP LAN_RX_TX_ICMP_inst(
			.clk(axi_tclk),
			.reset_n(axi_tresetn),
			.init_done(init_done),
      
			.lan_data_en(!rx_axis_tvalid),    //low is valid
			.lan_data_in(rx_axis_tdata),
            
            .ICMP_pc_req_o(ICMP_pc_req_o),
            .ICMP_ACK_i(ICMP_ACK_i),
            .tx_ICMP_busy(tx_ICMP_busy),
			.SOR_MAC_i(SOR_MAC_UDP),      //for board
			.SOR_IP_i(SOR_IP_UDP),       //for board
			
			.lan_rdy_n(!tx_axis_tready),
			.lan_data(tx_axis_tdata),
			.lan_vld_n(lan_vld_n),
			.lan_sof_n(),
			.lan_eof_n(lan_eof_n)
			);      
    
    

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/05 11:30:00
// Design Name: 
// Module Name: ARP_TOP
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
module ARP_TOP#(parameter ILA_DEBUG = 1'b0)(
    input           axi_tclk,
    input           axi_tresetn,
    input           init_done,
    // data from the RX data path
    input  [7:0]    rx_axis_tdata,
    input           rx_axis_tvalid,
    input           rx_axis_tlast,
    output          rx_axis_tready,
    // data TO the TX data path
    output  [7:0]   tx_axis_tdata,
    output          tx_axis_tvalid,
    output          tx_axis_tlast,
    input           tx_axis_tready,
    
    output          ARP_pc_req_o,
    input           ARP_ACK_i,
    output          tx_ARP_busy,
    input           ARP_req_en,
    output          ARP_resp_en,
    output  [47:0]  DES_MAC_ARP,
    output  [31:0]  DES_IP_ARP,
    output  [47:0]  SOR_MAC_UDP,
    output  [31:0]  SOR_IP_UDP  
    );
assign rx_axis_tready = 1'b1;
wire [47:0] DES_MAC_ARP_w;
wire [31:0] DES_IP_ARP_w;
wire        lan_rx_ARP_req_en;
wire [47:0] arp_data0;


reg  [47:0] DES_MAC_ARP_r;
reg  [31:0] DES_IP_ARP_r;
assign DES_MAC_ARP = DES_MAC_ARP_r;
assign DES_IP_ARP = DES_IP_ARP_r;
always@(posedge axi_tclk or negedge axi_tresetn)  //lock MAC AND IP
begin
    if(!axi_tresetn) begin
        DES_MAC_ARP_r <= 48'd0;
        DES_IP_ARP_r  <= 32'd0;  
    end
    else begin
        DES_MAC_ARP_r <= DES_MAC_ARP_w;
        DES_IP_ARP_r  <= DES_IP_ARP_w;
    end
end

LAN_RX_ARP#( .ILA_DEBUG(ILA_DEBUG) ) U_LAN_RX_ARP (
    .clk                (axi_tclk), 
    .reset_n            (axi_tresetn), 
    .init_done          (init_done), 
    .lan_data_in        (rx_axis_tdata), 
    .lan_data_en        (!rx_axis_tvalid), 
    .SOR_MAC_o          (SOR_MAC_UDP),      //板子 MAC地址
    .SOR_IP_o           (SOR_IP_UDP),       //板子 IP地址
    .DES_MAC_o          (DES_MAC_ARP_w),    //PC MAC地址			  			
    .DES_IP_o           (DES_IP_ARP_w),     //PC IP地址			
    .ARP_req_en         (lan_rx_ARP_req_en),//ARP请求，板子需给PC回复自己的物理地址  			
    .ARP_resp_en        (ARP_resp_en),      //ARP应答，PC回复给板子的应答信息
    .arp_data0          (arp_data0),        //修改设置IP地址
    .arp_data1          (),
    .arp_data2          ()
    ); 
	
wire        ARP_lan_eof_n;
wire        ARP_lan_vld_n;
assign tx_axis_tvalid = !ARP_lan_vld_n;
assign tx_axis_tlast  = !ARP_lan_eof_n;
    
LAN_TX_ARP U_LAN_TX_ARP (
    .clk                (axi_tclk), 
    .reset_n            (axi_tresetn), 
    .init_done          (init_done), 
    .ARP_pc_req_o       (ARP_pc_req_o),
    .ARP_ACK_i          (ARP_ACK_i),
    .ARP_req_en         (ARP_req_en),
    .ARP_resp_en        (lan_rx_ARP_req_en),
    .SOR_MAC_i          (SOR_MAC_UDP), 
    .DES_MAC_i          (DES_MAC_ARP_w), 
    .SOR_IP_i           (SOR_IP_UDP), 
    .DES_IP_i           (DES_IP_ARP_w),
    .arp_data0          (arp_data0),			
    .arp_data1          (48'h5347_5343_3234),		//设备名称 83_71_83_67_50_52_53_48  SGSC2450
    .arp_data2          ({16'h3530,DES_IP_ARP_r}),			
    .arp_data3          (DES_MAC_ARP_r),			
    .lan_rdy_n			(!tx_axis_tready), 
    .lan_data           (tx_axis_tdata), 
    .lan_sof_n			(), 
    .lan_eof_n			(ARP_lan_eof_n), 
    .lan_vld_n			(ARP_lan_vld_n), 
    .ARP_busy           (tx_ARP_busy)
    );    
    
endmodule
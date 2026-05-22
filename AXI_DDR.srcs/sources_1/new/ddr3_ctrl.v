`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/17 10:24:49
// Design Name: 
// Module Name: ddr3_ctrl
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
//output   [31:0]  remote_len,
//output           remote_wr_en,
//output   [7:0]   remote_wr_data,
//output           remote_rx_done
//////////////////////////////////////////////////////////////////////////////////
module ddr3_ctrl(
    input               eth_clk,
    input               eth_rstn,
    input               ui_clk,
    input               fdma_rstn,
    input               clk_50m,
    
    input               remote_rstn,
    input               remote_wr_en,
    input   [15:0]      remote_wr_data,
    input               remote_rx_done,
//user write ddr3 interface
    output              pkg_wr_areq,       
    input               pkg_wr_en,
    input               pkg_wr_last,
    output  [31:0]      pkg_wr_addr,
    output  [63:0]      pkg_wr_data,
    output  [31:0]      pkg_wr_size,
//user read ddr3 interface
    input   [63:0]      pkg_rd_data,
    input               pkg_rd_en,
    input               pkg_rd_last,
    output  [31:0]      pkg_rd_addr,
    output              pkg_rd_areq,
    output  [31:0]      pkg_rd_size,
//multiboot_cfg interface
    input               data_in_flag,
    output  [3:0]       data_in
    );
    
   
////------------------write ddr3--------------------------------------------       
  fdma_controller_write ddr3_wr(
    .ui_clk             (ui_clk),
    .fdma_rstn          (fdma_rstn),
    .eth_clk            (eth_clk),
    .eth_rstn           (eth_rstn),
    
    .remote_rstn        (remote_rstn),
    .remote_wr_en       (remote_wr_en),
    .remote_wr_data     (remote_wr_data),

    .pkg_wr_areq        (pkg_wr_areq),       
    .pkg_wr_en          (pkg_wr_en),  
    .pkg_wr_last        (pkg_wr_last),  
    .pkg_wr_addr        (pkg_wr_addr),  
    .pkg_wr_data        (pkg_wr_data),  
    .pkg_wr_size        (pkg_wr_size)
    );   
////------------------read ddr3--------------------------------------------  
fdma_controller_read ddr3_rd(
    .ui_clk             (ui_clk),
    .fdma_rstn          (fdma_rstn),
    .eth_clk            (eth_clk),
    .eth_rstn           (eth_rstn),
    
    .clk_50m            (clk_50m),
    .remote_en          (remote_rx_done),
    
    .pkg_rd_data        (pkg_rd_data),
    .pkg_rd_en          (pkg_rd_en),
    .pkg_rd_last        (pkg_rd_last),
    .pkg_rd_addr        (pkg_rd_addr),
    .pkg_rd_areq        (pkg_rd_areq),
    .pkg_rd_size        (pkg_rd_size),
    
    .data_in_flag       (data_in_flag),
    .data_in            (data_in)
    );  
    
endmodule
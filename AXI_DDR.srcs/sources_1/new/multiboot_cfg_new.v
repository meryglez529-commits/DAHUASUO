`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/22 09:11:56
// Design Name: 
// Module Name: multiboot_cfg
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
module multiboot_cfg_new(
    input           eth_clk,
    input           eth_rstn,
    input           clk_50m,
    //-------------ex signal,with command_monitor ------------
    input           qspi_cfg_en,
    input   [31:0]  remote_config_len,
    output  [31:0]  remote_result,
    output          remote_complete,
    input               read_flash_flag,
    input[7:0]          flash_type_in,
    output           write_rom_flag,
    output [7:0]     write_rom_data,
    //-------------QSPI_CFG_PIN-------------------------------
    inout           qspi_d0,
    inout           qspi_d1,  
    inout           qspi_d2, 
    inout           qspi_d3,
    output          qspi_csb,
    output          qspi_clk,
    //--------------------------------------------------------
    output          data_in_flag,
    input   [3:0]   data_in
    );
//--------------------------------------sync----------------------------------------------------------
  wire clk50m_rstn;
  sync_module sync1(.data_in(eth_rstn),.clk_in(clk_50m),.data_out(clk50m_rstn));  
 
  reg  [31:0] remote_config_len_reg[0:2];
  always @(posedge clk_50m or negedge clk50m_rstn)
  begin
    if(!clk50m_rstn)
        {remote_config_len_reg[2],remote_config_len_reg[1],remote_config_len_reg[0]} <= {32'd0,32'd0,32'd0}; 
    else 
        {remote_config_len_reg[2],remote_config_len_reg[1],remote_config_len_reg[0]} <= {remote_config_len_reg[1],remote_config_len_reg[0],remote_config_len}; 
  end
//-----------------------------------multiboot_cfg  top schematic------------------------------------------
  qspi_cfg qspi_cfg_inst(
    .inclk(clk_50m),
    .inReset_EnableB(clk50m_rstn),
    .qspi_cfg_en(qspi_cfg_en),
      //-------------ex -------------------
    .program_byte_count(remote_config_len_reg[2]),
    .data_in_flag(data_in_flag),
    .data_in(data_in),
    .remote_result(remote_result),
    .remote_complete(remote_complete),
//    .usr_irq_req(usr_irq_req),
//    .xdma_irq_ack(xdma_irq_ack_reg[2]), 
    .read_flash_flag (  read_flash_flag    ),
    .flash_type_in   (  flash_type_in      ),
    .write_rom_flag  (  write_rom_flag     ),
    .write_rom_data  (  write_rom_data     ),
      //-------------QSPI_CFG_PIN-------------------------------
    .qspi_d0(qspi_d0),
    .qspi_d1(qspi_d1),
    .qspi_d2(qspi_d2),
    .qspi_d3(qspi_d3),
    .qspi_csb(qspi_csb),
    .qspi_clk(qspi_clk)
    );
      
endmodule
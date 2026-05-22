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
module multiboot_cfg(
    input ui_clk,
    input clk_50m,
    input fdma_rstn,
    //-------------ex -------------------
    input [31:0] free_config_len,
    //-------------QSPI_CFG_PIN-------------------------------
    inout qspi_d0,
    inout qspi_d1,  
    inout qspi_d2, 
    inout qspi_d3,
    output qspi_csb,
    output qspi_clk,
  
    input [127:0] pkg_rd_data,
    input pkg_rd_en,
    input pkg_rd_last,
    output [31:0] pkg_rd_addr,
    output pkg_rd_areq,
    output [31:0] pkg_rd_size
    );
  
  wire data_in_flag;
  wire [3:0] data_in;
  wire program_done;
  reg [31:0] free_config_len_reg[0:2];
  
  reg qspi_cfg_en;
  always @(posedge clk_50m or negedge fdma_rstn)
  begin
    if(!fdma_rstn) begin
        {free_config_len_reg[2],free_config_len_reg[1],free_config_len_reg[0]} <= {32'd0,32'd0,32'd0};
        qspi_cfg_en <=1'b0; 
    end
    else begin
        {free_config_len_reg[2],free_config_len_reg[1],free_config_len_reg[0]} <= {free_config_len_reg[1],free_config_len_reg[0],free_config_len};
        if (free_config_len_reg[2] !== 0)
            qspi_cfg_en <=1'b1;
        else
            qspi_cfg_en <=1'b0;  
    end  
  end
  
  qspi_cfg qspi_cfg_inst(
    .inclk(clk_50m),
    .inReset_EnableB(fdma_rstn),
    .qspi_cfg_en(qspi_cfg_en),
      //-------------ex -------------------
    .program_byte_count(free_config_len_reg[2]),
    .data_in_flag(data_in_flag),
    .data_in(data_in),
    .program_done(program_done),
      //-------------QSPI_CFG_PIN-------------------------------
    .qspi_d0(qspi_d0),
    .qspi_d1(qspi_d1),
    .qspi_d2(qspi_d2),
    .qspi_d3(qspi_d3),
    .qspi_csb(qspi_csb),
    .qspi_clk(qspi_clk)
    );
    
  multiboot_fdma_controller_rd multiboot_fdma_controller_rd_inst(
    .ui_clk(ui_clk),
    .clk_50m(clk_50m),
    .rstn(qspi_cfg_en),
    .pkg_rd_data(pkg_rd_data),
    .pkg_rd_en(pkg_rd_en),
    .pkg_rd_last(pkg_rd_last),
    .pkg_rd_addr(pkg_rd_addr),
    .pkg_rd_areq(pkg_rd_areq),
    .pkg_rd_size(pkg_rd_size),
      
    .data_in_flag(data_in_flag),
    .data_in(data_in)
    );  
    
endmodule

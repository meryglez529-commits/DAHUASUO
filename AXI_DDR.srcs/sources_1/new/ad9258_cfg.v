`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/07 11:10:14
// Design Name: 
// Module Name: ad9258_cfg
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
// golden模式下直接使能adc的pdwn
/////////////////////////////////////////////////////////////////////////////////
  module ad9258_cfg(
    input clk10m,
    input rstn,
    output adc1_dea,    //新增
    output adc1_deb,    //新增
    output adc1_oeb,    //新增
    output adc1_pwdn,
    output adc1_csb,
    inout adc1_sdio,
    output adc1_sclk,
    output adc2_dea,    //新增
    output adc2_deb,    //新增
    output adc2_oeb,    //新增
    output adc2_pwdn,
    output adc2_csb,
    inout  adc2_sdio,
    output adc2_sclk,
    input [7:0] offset_adc1,
    input [7:0] offset_adc2,
    input [7:0] offset_adc3,
    input [7:0] offset_adc4
    );

  ad9258_config num1_ad9258_config(
    .clk10m(clk10m),
    .rstn(rstn),
    .adc_dea(adc1_dea),  
    .adc_deb(adc1_deb),  
    .adc_oeb(adc1_oeb),  
    .adc_pwdn(adc1_pwdn),  
    .adc_csb(adc1_csb),  
    .adc_sdio(adc1_sdio),  
    .adc_sclk(adc1_sclk),  
    .offset_adcA(offset_adc1),
    .offset_adcB(offset_adc2)
    );
  ad9258_config num2_ad9258_config(
    .clk10m(clk10m),
    .rstn(rstn),
    .adc_dea(adc2_dea),  
    .adc_deb(adc2_deb),  
    .adc_oeb(adc2_oeb),  
    .adc_pwdn(adc2_pwdn),  
    .adc_csb(adc2_csb),  
    .adc_sdio(adc2_sdio),  
    .adc_sclk(adc2_sclk),  
    .offset_adcA(offset_adc3),
    .offset_adcB(offset_adc4)
    );
endmodule     
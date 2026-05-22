`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/13 15:15:16
// Design Name: 
// Module Name: offset_dac_cfg
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
// goldenƒ£ Ω ‰»Î0
//////////////////////////////////////////////////////////////////////////////////
  module offset_dac_cfg(
    input clk10m,
    input rstn,
    output ADC1_SCL,
    inout  ADC1_SDA,
    output ADC2_SCL,
    inout  ADC2_SDA,
    input read_flag,
    input [15:0] offset_adc1,
    input [15:0] offset_adc2,
    input [15:0] offset_adc3,
    input [15:0] offset_adc4,
    input [15:0] offset_dacx,
    input [15:0] offset_dacy
    );    

  offset_cfg adc1234(
    .clk10m(clk10m),
    .rstn(rstn),
    .ADC_SCL(ADC1_SCL),
    .ADC_SDA(ADC1_SDA),
    .read_flag(read_flag),
    .channel1(offset_adc1),
    .channel2(offset_adc2),
    .channel3(offset_adc3),
    .channel4(offset_adc4)
    );
  offset_cfg dacxy(
    .clk10m(clk10m),
    .rstn(rstn),
    .ADC_SCL(ADC2_SCL),
    .ADC_SDA(ADC2_SDA),
    .read_flag(read_flag),
    .channel1(offset_dacx),
    .channel2(offset_dacy),
    .channel3(16'd0),
    .channel4(16'd0)
    );

endmodule
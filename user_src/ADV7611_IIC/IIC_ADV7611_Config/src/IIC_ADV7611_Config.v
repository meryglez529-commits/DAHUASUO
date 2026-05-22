`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/03/07 17:22:20
// Design Name: 
// Module Name: IIC_ADV7611_Config
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


module IIC_ADV7611_Config #(
	parameter	ADV_CLK_FREQ	=	100_000000,	//100 MHz
	parameter	ADV_I2C_FREQ	=	10_000		//10 KHz(< 400KHz)
)
(
 input ADV_CLK,
 input ADV_RST,//µÍµçÆ½¸´Î»
 output ADV_SCLK,
 inout ADV_SDAT
);
    
    
    wire I2C_EN;      
//----------------------------------------------
    //i2c timing controller module
    wire    [9:0]    i2c_config_index;
    wire    [23:0]i2c_config_data;
    wire    [9:0]    i2c_config_size;
    wire            i2c_config_done;
    wire        i2c_RW_flag;
    wire    [7:0]    i2c_rdata;        //i2c register data   
    
i2c_timing_ctrl
 #(
.CLK_FREQ    (ADV_CLK_FREQ),    //100 MHz
.I2C_FREQ    (ADV_I2C_FREQ)        //100 kHz(<= 400KHz)
  )
 u_i2c_timing_ctrl
  (
 //global clock
 .clk                (ADV_CLK),        //100MHz
 .rst_n                (I2C_EN),    //system reset
                               
//i2c interface
 .i2c_sclk            (ADV_SCLK),    //i2c clock
 .i2c_sdat            (ADV_SDAT),    //i2c data for bidirection
                   
//i2c config data
 .i2c_RW_flag(i2c_RW_flag),
 .i2c_config_index    (i2c_config_index),    //i2c config reg index, read 2 reg and write xx reg
 .i2c_config_data    (i2c_config_data),    //i2c config data
 .i2c_config_size    (i2c_config_size),    //i2c config data counte
 .i2c_config_done    (i2c_config_done),    //i2c config timing complete
 .i2c_rdata            (i2c_rdata)            //i2c register data while read i2c slave
 );
                   
//----------------------------------------------
 //I2C Configure Data of OV7725
//I2C_OV7725_RGB565_Config    u_I2C_OV7725_RGB565_Config
I2C_ADV7611_Config    u_I2C_ADV7611_Config
(
.clk             (ADV_CLK),
.rst_n           (ADV_RST),
.I2C_EN           (I2C_EN),
.I2C_RW_flag    (i2c_RW_flag),
.I2C_rdata        (i2c_rdata),
.I2C_config_done(i2c_config_done),
.LUT_INDEX        (i2c_config_index),
.LUT_DATA        (i2c_config_data),
.LUT_SIZE        (i2c_config_size)
);   
endmodule

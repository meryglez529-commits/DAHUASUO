`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/02/27 22:09:55
// Design Name: 
// Module Name: OV5640IIC
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


module OV5640IIC
#(
	parameter	CLK_FREQ	=	25_000_000,	//250 MHz
	parameter	I2C_FREQ	=	100_000		//10 KHz(< 400KHz)
)
(
  input clk,
  input rst_n,
  output cmos_scl,
  inout cmos_sda
 );
 
 wire   [9:0]	  i2c_config_index;
 wire   [23:0]   i2c_config_data;
 wire   [9:0]    i2c_config_size;      
 wire   [7:0]    i2c_rdata;        //i2c register data
 
 i2c_timing_ctrl
    #(
        .CLK_FREQ    (25_000_000),    //100 MHz
        .I2C_FREQ    (100_000)        //10 KHz(<= 400KHz)
    )
    u_i2c_timing_ctrl
    (
        .clk                (clk),
        .rst_n                (rst_n),
                
        .i2c_sclk(cmos_scl),         
        .i2c_sdat(cmos_sda),
    
        .i2c_config_index    (i2c_config_index),    //i2c config reg index, read 2 reg and write xx reg
        .i2c_config_data    ({8'h78, i2c_config_data}),    //i2c config data
        .i2c_config_size    (i2c_config_size),    //i2c config data counte
        .i2c_config_done    ()    //i2c config timing complete
    //    .i2c_rdata            (i2c_rdata)            //i2c register data while read i2c slave
    );
           
    //----------------------ov7725³õÊ¼»¯ÅäÖÃÄ£¿é---------------------------//
           
    I2C_OV5640_RGB565_Config    u_I2C_OV5640_RGB565_Config
    (
        .LUT_INDEX        (i2c_config_index),
        .LUT_DATA        (i2c_config_data),
        .LUT_SIZE        (i2c_config_size) 
     );  
    
    
    
endmodule

// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
// Date        : Fri Mar 29 11:10:03 2019
// Host        : 123tjy running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               f:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0_stub.v
// Design      : OV5640IIC_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "OV5640IIC,Vivado 2017.4" *)
module OV5640IIC_0(clk, rst_n, cmos_scl, cmos_sda)
/* synthesis syn_black_box black_box_pad_pin="clk,rst_n,cmos_scl,cmos_sda" */;
  input clk;
  input rst_n;
  output cmos_scl;
  inout cmos_sda;
endmodule

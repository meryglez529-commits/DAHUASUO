// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
// Date        : Fri Mar 29 20:38:11 2019
// Host        : 123tjy running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               F:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565_0_stub.v
// Design      : MSXBO_OVSensorRGB565_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "MSXBO_OVSensorRGB565,Vivado 2017.4" *)
module MSXBO_OVSensorRGB565_0(cmos_clk_i, rst_n_i, cmos_pclk_i, cmos_href_i, 
  cmos_vsync_i, cmos_data_i, cmos_xclk_o, rgb_o, de_o, vs_o, hs_o)
/* synthesis syn_black_box black_box_pad_pin="cmos_clk_i,rst_n_i,cmos_pclk_i,cmos_href_i,cmos_vsync_i,cmos_data_i[7:0],cmos_xclk_o,rgb_o[31:0],de_o,vs_o,hs_o" */;
  input cmos_clk_i;
  input rst_n_i;
  input cmos_pclk_i;
  input cmos_href_i;
  input cmos_vsync_i;
  input [7:0]cmos_data_i;
  output cmos_xclk_o;
  output [31:0]rgb_o;
  output de_o;
  output vs_o;
  output hs_o;
endmodule

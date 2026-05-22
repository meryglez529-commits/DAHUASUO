-- Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
-- Date        : Fri Mar 29 20:38:11 2019
-- Host        : 123tjy running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               F:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565_0_stub.vhdl
-- Design      : MSXBO_OVSensorRGB565_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MSXBO_OVSensorRGB565_0 is
  Port ( 
    cmos_clk_i : in STD_LOGIC;
    rst_n_i : in STD_LOGIC;
    cmos_pclk_i : in STD_LOGIC;
    cmos_href_i : in STD_LOGIC;
    cmos_vsync_i : in STD_LOGIC;
    cmos_data_i : in STD_LOGIC_VECTOR ( 7 downto 0 );
    cmos_xclk_o : out STD_LOGIC;
    rgb_o : out STD_LOGIC_VECTOR ( 31 downto 0 );
    de_o : out STD_LOGIC;
    vs_o : out STD_LOGIC;
    hs_o : out STD_LOGIC
  );

end MSXBO_OVSensorRGB565_0;

architecture stub of MSXBO_OVSensorRGB565_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "cmos_clk_i,rst_n_i,cmos_pclk_i,cmos_href_i,cmos_vsync_i,cmos_data_i[7:0],cmos_xclk_o,rgb_o[31:0],de_o,vs_o,hs_o";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "MSXBO_OVSensorRGB565,Vivado 2017.4";
begin
end;

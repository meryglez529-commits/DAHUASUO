-- Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
-- Date        : Fri Mar 29 11:10:03 2019
-- Host        : 123tjy running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               f:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0_stub.vhdl
-- Design      : OV5640IIC_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OV5640IIC_0 is
  Port ( 
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    cmos_scl : out STD_LOGIC;
    cmos_sda : inout STD_LOGIC
  );

end OV5640IIC_0;

architecture stub of OV5640IIC_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,rst_n,cmos_scl,cmos_sda";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "OV5640IIC,Vivado 2017.4";
begin
end;

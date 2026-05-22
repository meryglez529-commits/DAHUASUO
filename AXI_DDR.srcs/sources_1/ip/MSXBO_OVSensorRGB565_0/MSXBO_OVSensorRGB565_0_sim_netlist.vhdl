-- Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
-- Date        : Fri Mar 29 20:38:11 2019
-- Host        : 123tjy running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode funcsim
--               F:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565_0_sim_netlist.vhdl
-- Design      : MSXBO_OVSensorRGB565_0
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity MSXBO_OVSensorRGB565_0_MSXBO_OVSensorRGB565 is
  port (
    rgb_o : out STD_LOGIC_VECTOR ( 15 downto 0 );
    de_o : out STD_LOGIC;
    vs_o : out STD_LOGIC;
    hs_o : out STD_LOGIC;
    cmos_clk_i : in STD_LOGIC;
    rst_n_i : in STD_LOGIC;
    cmos_pclk_i : in STD_LOGIC;
    cmos_href_i : in STD_LOGIC;
    cmos_data_i : in STD_LOGIC_VECTOR ( 7 downto 0 );
    cmos_vsync_i : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of MSXBO_OVSensorRGB565_0_MSXBO_OVSensorRGB565 : entity is "MSXBO_OVSensorRGB565";
end MSXBO_OVSensorRGB565_0_MSXBO_OVSensorRGB565;

architecture STRUCTURE of MSXBO_OVSensorRGB565_0_MSXBO_OVSensorRGB565 is
  signal cmos_data_r : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal \cmos_fps[0]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[1]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[2]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[2]_i_2_n_0\ : STD_LOGIC;
  signal \cmos_fps[3]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[3]_i_2_n_0\ : STD_LOGIC;
  signal \cmos_fps[3]_i_3_n_0\ : STD_LOGIC;
  signal \cmos_fps[3]_i_4_n_0\ : STD_LOGIC;
  signal \cmos_fps[3]_i_5_n_0\ : STD_LOGIC;
  signal \cmos_fps[4]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[5]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps[6]_i_1_n_0\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[0]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[1]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[2]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[3]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[4]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[5]\ : STD_LOGIC;
  signal \cmos_fps_reg_n_0_[6]\ : STD_LOGIC;
  signal cmos_href_r : STD_LOGIC;
  signal cmos_vsync_r : STD_LOGIC;
  signal cmos_vsync_r_i_1_n_0 : STD_LOGIC;
  signal data_en : STD_LOGIC;
  signal data_en_i_1_n_0 : STD_LOGIC;
  signal href_cnt : STD_LOGIC;
  signal href_cnt_i_1_n_0 : STD_LOGIC;
  signal out_en : STD_LOGIC;
  signal out_en_i_1_n_0 : STD_LOGIC;
  signal p_0_in : STD_LOGIC;
  signal \rgb2[15]_i_1_n_0\ : STD_LOGIC;
  signal \^rgb_o\ : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \rst_n_reg_reg[3]_srl3_n_0\ : STD_LOGIC;
  signal \rst_n_reg_reg_n_0_[0]\ : STD_LOGIC;
  signal vsync_d : STD_LOGIC_VECTOR ( 1 downto 0 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \cmos_fps[3]_i_3\ : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \cmos_fps[3]_i_5\ : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \cmos_fps[4]_i_1\ : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of \cmos_fps[5]_i_1\ : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of data_en_i_1 : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of de_o_INST_0 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of href_cnt_i_1 : label is "soft_lutpair2";
  attribute srl_bus_name : string;
  attribute srl_bus_name of \rst_n_reg_reg[3]_srl3\ : label is "\inst/rst_n_reg_reg ";
  attribute srl_name : string;
  attribute srl_name of \rst_n_reg_reg[3]_srl3\ : label is "\inst/rst_n_reg_reg[3]_srl3 ";
  attribute SOFT_HLUTNM of vs_o_INST_0 : label is "soft_lutpair3";
begin
  rgb_o(15 downto 0) <= \^rgb_o\(15 downto 0);
\cmos_data_r_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(0),
      Q => cmos_data_r(0),
      R => '0'
    );
\cmos_data_r_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(1),
      Q => cmos_data_r(1),
      R => '0'
    );
\cmos_data_r_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(2),
      Q => cmos_data_r(2),
      R => '0'
    );
\cmos_data_r_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(3),
      Q => cmos_data_r(3),
      R => '0'
    );
\cmos_data_r_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(4),
      Q => cmos_data_r(4),
      R => '0'
    );
\cmos_data_r_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(5),
      Q => cmos_data_r(5),
      R => '0'
    );
\cmos_data_r_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(6),
      Q => cmos_data_r(6),
      R => '0'
    );
\cmos_data_r_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_data_i(7),
      Q => cmos_data_r(7),
      R => '0'
    );
\cmos_fps[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AAA8AAAAFFFFFFFF"
    )
        port map (
      I0 => \cmos_fps[3]_i_4_n_0\,
      I1 => \cmos_fps_reg_n_0_[4]\,
      I2 => \cmos_fps_reg_n_0_[5]\,
      I3 => \cmos_fps_reg_n_0_[6]\,
      I4 => \cmos_fps[3]_i_3_n_0\,
      I5 => \cmos_fps_reg_n_0_[0]\,
      O => \cmos_fps[0]_i_1_n_0\
    );
\cmos_fps[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F6FF6666F6FFF6FF"
    )
        port map (
      I0 => \cmos_fps_reg_n_0_[1]\,
      I1 => \cmos_fps_reg_n_0_[0]\,
      I2 => vsync_d(1),
      I3 => vsync_d(0),
      I4 => \cmos_fps[2]_i_2_n_0\,
      I5 => \cmos_fps[3]_i_3_n_0\,
      O => \cmos_fps[1]_i_1_n_0\
    );
\cmos_fps[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"A8FFFFFFFF888888"
    )
        port map (
      I0 => \cmos_fps[3]_i_4_n_0\,
      I1 => \cmos_fps[2]_i_2_n_0\,
      I2 => \cmos_fps_reg_n_0_[3]\,
      I3 => \cmos_fps_reg_n_0_[1]\,
      I4 => \cmos_fps_reg_n_0_[0]\,
      I5 => \cmos_fps_reg_n_0_[2]\,
      O => \cmos_fps[2]_i_1_n_0\
    );
\cmos_fps[2]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => \cmos_fps_reg_n_0_[6]\,
      I1 => \cmos_fps_reg_n_0_[5]\,
      I2 => \cmos_fps_reg_n_0_[4]\,
      O => \cmos_fps[2]_i_2_n_0\
    );
\cmos_fps[3]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FEFFFEFFFFFFFEFF"
    )
        port map (
      I0 => \cmos_fps_reg_n_0_[4]\,
      I1 => \cmos_fps_reg_n_0_[5]\,
      I2 => \cmos_fps_reg_n_0_[6]\,
      I3 => \cmos_fps[3]_i_3_n_0\,
      I4 => vsync_d(0),
      I5 => vsync_d(1),
      O => \cmos_fps[3]_i_1_n_0\
    );
\cmos_fps[3]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFAAA8AAAAFFFF"
    )
        port map (
      I0 => \cmos_fps[3]_i_4_n_0\,
      I1 => \cmos_fps_reg_n_0_[4]\,
      I2 => \cmos_fps_reg_n_0_[5]\,
      I3 => \cmos_fps_reg_n_0_[6]\,
      I4 => \cmos_fps_reg_n_0_[3]\,
      I5 => \cmos_fps[3]_i_5_n_0\,
      O => \cmos_fps[3]_i_2_n_0\
    );
\cmos_fps[3]_i_3\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7FFF"
    )
        port map (
      I0 => \cmos_fps_reg_n_0_[2]\,
      I1 => \cmos_fps_reg_n_0_[0]\,
      I2 => \cmos_fps_reg_n_0_[1]\,
      I3 => \cmos_fps_reg_n_0_[3]\,
      O => \cmos_fps[3]_i_3_n_0\
    );
\cmos_fps[3]_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => vsync_d(1),
      I1 => vsync_d(0),
      O => \cmos_fps[3]_i_4_n_0\
    );
\cmos_fps[3]_i_5\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
        port map (
      I0 => \cmos_fps_reg_n_0_[1]\,
      I1 => \cmos_fps_reg_n_0_[0]\,
      I2 => \cmos_fps_reg_n_0_[2]\,
      O => \cmos_fps[3]_i_5_n_0\
    );
\cmos_fps[4]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0082"
    )
        port map (
      I0 => p_0_in,
      I1 => \cmos_fps[3]_i_3_n_0\,
      I2 => \cmos_fps_reg_n_0_[4]\,
      I3 => \cmos_fps[3]_i_4_n_0\,
      O => \cmos_fps[4]_i_1_n_0\
    );
\cmos_fps[5]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"000082A0"
    )
        port map (
      I0 => p_0_in,
      I1 => \cmos_fps[3]_i_3_n_0\,
      I2 => \cmos_fps_reg_n_0_[5]\,
      I3 => \cmos_fps_reg_n_0_[4]\,
      I4 => \cmos_fps[3]_i_4_n_0\,
      O => \cmos_fps[5]_i_1_n_0\
    );
\cmos_fps[6]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000082A0A0A0"
    )
        port map (
      I0 => p_0_in,
      I1 => \cmos_fps[3]_i_3_n_0\,
      I2 => \cmos_fps_reg_n_0_[6]\,
      I3 => \cmos_fps_reg_n_0_[5]\,
      I4 => \cmos_fps_reg_n_0_[4]\,
      I5 => \cmos_fps[3]_i_4_n_0\,
      O => \cmos_fps[6]_i_1_n_0\
    );
\cmos_fps_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => \cmos_fps[3]_i_1_n_0\,
      D => \cmos_fps[0]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[0]\,
      R => \rgb2[15]_i_1_n_0\
    );
\cmos_fps_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => \cmos_fps[3]_i_1_n_0\,
      D => \cmos_fps[1]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[1]\,
      R => \rgb2[15]_i_1_n_0\
    );
\cmos_fps_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => \cmos_fps[3]_i_1_n_0\,
      D => \cmos_fps[2]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[2]\,
      R => \rgb2[15]_i_1_n_0\
    );
\cmos_fps_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => \cmos_fps[3]_i_1_n_0\,
      D => \cmos_fps[3]_i_2_n_0\,
      Q => \cmos_fps_reg_n_0_[3]\,
      R => \rgb2[15]_i_1_n_0\
    );
\cmos_fps_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => \cmos_fps[4]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[4]\,
      R => '0'
    );
\cmos_fps_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => \cmos_fps[5]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[5]\,
      R => '0'
    );
\cmos_fps_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => \cmos_fps[6]_i_1_n_0\,
      Q => \cmos_fps_reg_n_0_[6]\,
      R => '0'
    );
cmos_href_r_reg: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_href_i,
      Q => cmos_href_r,
      R => '0'
    );
cmos_vsync_r_i_1: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => cmos_vsync_i,
      O => cmos_vsync_r_i_1_n_0
    );
cmos_vsync_r_reg: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_vsync_r_i_1_n_0,
      Q => cmos_vsync_r,
      R => '0'
    );
data_en_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => href_cnt,
      I1 => p_0_in,
      O => data_en_i_1_n_0
    );
data_en_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => '1',
      D => data_en_i_1_n_0,
      Q => data_en,
      R => '0'
    );
de_o_INST_0: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => out_en,
      I1 => data_en,
      O => de_o
    );
href_cnt_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => cmos_href_r,
      I1 => p_0_in,
      I2 => href_cnt,
      O => href_cnt_i_1_n_0
    );
href_cnt_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => '1',
      D => href_cnt_i_1_n_0,
      Q => href_cnt,
      R => '0'
    );
hs_o_INST_0: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => out_en,
      I1 => cmos_href_r,
      O => hs_o
    );
out_en_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFEFFFF00000000"
    )
        port map (
      I0 => out_en,
      I1 => \cmos_fps_reg_n_0_[4]\,
      I2 => \cmos_fps_reg_n_0_[5]\,
      I3 => \cmos_fps_reg_n_0_[6]\,
      I4 => \cmos_fps[3]_i_3_n_0\,
      I5 => p_0_in,
      O => out_en_i_1_n_0
    );
out_en_reg: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => out_en_i_1_n_0,
      Q => out_en,
      R => '0'
    );
\rgb2[15]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => p_0_in,
      O => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(0),
      Q => \^rgb_o\(0),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(2),
      Q => \^rgb_o\(10),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(3),
      Q => \^rgb_o\(11),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(4),
      Q => \^rgb_o\(12),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(5),
      Q => \^rgb_o\(13),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(6),
      Q => \^rgb_o\(14),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(7),
      Q => \^rgb_o\(15),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(1),
      Q => \^rgb_o\(1),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(2),
      Q => \^rgb_o\(2),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(3),
      Q => \^rgb_o\(3),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(4),
      Q => \^rgb_o\(4),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(5),
      Q => \^rgb_o\(5),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(6),
      Q => \^rgb_o\(6),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => cmos_data_r(7),
      Q => \^rgb_o\(7),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(0),
      Q => \^rgb_o\(8),
      R => \rgb2[15]_i_1_n_0\
    );
\rgb2_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_pclk_i,
      CE => cmos_href_r,
      D => \^rgb_o\(1),
      Q => \^rgb_o\(9),
      R => \rgb2[15]_i_1_n_0\
    );
\rst_n_reg_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_clk_i,
      CE => '1',
      D => rst_n_i,
      Q => \rst_n_reg_reg_n_0_[0]\,
      R => '0'
    );
\rst_n_reg_reg[3]_srl3\: unisim.vcomponents.SRL16E
    generic map(
      INIT => X"0000"
    )
        port map (
      A0 => '0',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => cmos_clk_i,
      D => \rst_n_reg_reg_n_0_[0]\,
      Q => \rst_n_reg_reg[3]_srl3_n_0\
    );
\rst_n_reg_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => cmos_clk_i,
      CE => '1',
      D => \rst_n_reg_reg[3]_srl3_n_0\,
      Q => p_0_in,
      R => '0'
    );
vs_o_INST_0: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => out_en,
      I1 => cmos_vsync_r,
      O => vs_o
    );
\vsync_d_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => cmos_vsync_r,
      Q => vsync_d(0),
      R => '0'
    );
\vsync_d_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => cmos_pclk_i,
      CE => '1',
      D => vsync_d(0),
      Q => vsync_d(1),
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity MSXBO_OVSensorRGB565_0 is
  port (
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
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of MSXBO_OVSensorRGB565_0 : entity is true;
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of MSXBO_OVSensorRGB565_0 : entity is "MSXBO_OVSensorRGB565_0,MSXBO_OVSensorRGB565,{}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of MSXBO_OVSensorRGB565_0 : entity is "yes";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of MSXBO_OVSensorRGB565_0 : entity is "MSXBO_OVSensorRGB565,Vivado 2017.4";
end MSXBO_OVSensorRGB565_0;

architecture STRUCTURE of MSXBO_OVSensorRGB565_0 is
  signal \<const0>\ : STD_LOGIC;
  signal \^cmos_clk_i\ : STD_LOGIC;
  signal \^rgb_o\ : STD_LOGIC_VECTOR ( 23 downto 3 );
begin
  \^cmos_clk_i\ <= cmos_clk_i;
  cmos_xclk_o <= \^cmos_clk_i\;
  rgb_o(31) <= \<const0>\;
  rgb_o(30) <= \<const0>\;
  rgb_o(29) <= \<const0>\;
  rgb_o(28) <= \<const0>\;
  rgb_o(27) <= \<const0>\;
  rgb_o(26) <= \<const0>\;
  rgb_o(25) <= \<const0>\;
  rgb_o(24) <= \<const0>\;
  rgb_o(23 downto 19) <= \^rgb_o\(23 downto 19);
  rgb_o(18) <= \<const0>\;
  rgb_o(17) <= \<const0>\;
  rgb_o(16) <= \<const0>\;
  rgb_o(15 downto 10) <= \^rgb_o\(15 downto 10);
  rgb_o(9) <= \<const0>\;
  rgb_o(8) <= \<const0>\;
  rgb_o(7 downto 3) <= \^rgb_o\(7 downto 3);
  rgb_o(2) <= \<const0>\;
  rgb_o(1) <= \<const0>\;
  rgb_o(0) <= \<const0>\;
GND: unisim.vcomponents.GND
     port map (
      G => \<const0>\
    );
inst: entity work.MSXBO_OVSensorRGB565_0_MSXBO_OVSensorRGB565
     port map (
      cmos_clk_i => \^cmos_clk_i\,
      cmos_data_i(7 downto 0) => cmos_data_i(7 downto 0),
      cmos_href_i => cmos_href_i,
      cmos_pclk_i => cmos_pclk_i,
      cmos_vsync_i => cmos_vsync_i,
      de_o => de_o,
      hs_o => hs_o,
      rgb_o(15 downto 11) => \^rgb_o\(23 downto 19),
      rgb_o(10 downto 5) => \^rgb_o\(15 downto 10),
      rgb_o(4 downto 0) => \^rgb_o\(7 downto 3),
      rst_n_i => rst_n_i,
      vs_o => vs_o
    );
end STRUCTURE;

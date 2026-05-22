-- Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
-- Date        : Fri Mar 29 11:10:03 2019
-- Host        : 123tjy running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode funcsim
--               f:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0_sim_netlist.vhdl
-- Design      : OV5640IIC_0
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity OV5640IIC_0_i2c_timing_ctrl is
  port (
    cmos_scl : out STD_LOGIC;
    cmos_sda : inout STD_LOGIC;
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of OV5640IIC_0_i2c_timing_ctrl : entity is "i2c_timing_ctrl";
end OV5640IIC_0_i2c_timing_ctrl;

architecture STRUCTURE of OV5640IIC_0_i2c_timing_ctrl is
  signal \/i__n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[0]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[0]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[0]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[10]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[10]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[10]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[1]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[1]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[2]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[3]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[4]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[5]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[6]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[7]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[7]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[8]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[8]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[8]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[9]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state[9]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_onehot_current_state_reg_n_0_[0]\ : STD_LOGIC;
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[0]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[1]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[1]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[2]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[2]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[3]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[3]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[4]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[4]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[5]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[5]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[6]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[6]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[8]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[8]\ : signal is "yes";
  signal \FSM_onehot_current_state_reg_n_0_[9]\ : STD_LOGIC;
  attribute RTL_KEEP of \FSM_onehot_current_state_reg_n_0_[9]\ : signal is "yes";
  signal \RESETn_reg[0]__0_n_0\ : STD_LOGIC;
  signal \RESETn_reg[3]_srl3_n_0\ : STD_LOGIC;
  signal \clk_cnt[0]_i_1_n_0\ : STD_LOGIC;
  signal \clk_cnt[0]_i_3_n_0\ : STD_LOGIC;
  signal \clk_cnt[0]_i_4_n_0\ : STD_LOGIC;
  signal clk_cnt_reg : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \clk_cnt_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \clk_cnt_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_1\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_2\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_3\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \clk_cnt_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \clk_cnt_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \clk_cnt_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal current_state_reg : STD_LOGIC_VECTOR ( 2 downto 1 );
  signal data2 : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal \delay_cnt[0]_i_3_n_0\ : STD_LOGIC;
  signal \delay_cnt[0]_i_4_n_0\ : STD_LOGIC;
  signal \delay_cnt[0]_i_5_n_0\ : STD_LOGIC;
  signal delay_cnt_reg : STD_LOGIC_VECTOR ( 16 downto 0 );
  signal \delay_cnt_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \delay_cnt_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_1\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_2\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_3\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \delay_cnt_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \delay_cnt_reg[16]_i_1_n_7\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \delay_cnt_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \delay_cnt_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal i2c_ack : STD_LOGIC;
  signal i2c_ack1 : STD_LOGIC;
  signal i2c_ack10_out : STD_LOGIC;
  signal i2c_ack1_i_1_n_0 : STD_LOGIC;
  signal i2c_ack2 : STD_LOGIC;
  signal i2c_ack24_out : STD_LOGIC;
  signal i2c_ack2_i_1_n_0 : STD_LOGIC;
  signal i2c_ack2_i_2_n_0 : STD_LOGIC;
  signal i2c_ack2a : STD_LOGIC;
  signal i2c_ack2a1_out : STD_LOGIC;
  signal i2c_ack2a_i_1_n_0 : STD_LOGIC;
  signal i2c_ack3 : STD_LOGIC;
  signal i2c_ack3_i_1_n_0 : STD_LOGIC;
  signal i2c_ack3_i_2_n_0 : STD_LOGIC;
  signal i2c_ack_i_1_n_0 : STD_LOGIC;
  signal i2c_ack_i_2_n_0 : STD_LOGIC;
  signal i2c_ack_i_3_n_0 : STD_LOGIC;
  signal i2c_capture_en : STD_LOGIC;
  signal i2c_capture_en6_out : STD_LOGIC;
  signal i2c_capture_en_i_2_n_0 : STD_LOGIC;
  signal i2c_capture_en_i_3_n_0 : STD_LOGIC;
  signal \i2c_config_index[0]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[1]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[2]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[3]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[4]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[5]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[6]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[7]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_config_index[7]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_config_index_reg__0\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal i2c_config_index_reg_rep_i_10_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_11_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_12_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_13_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_14_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_1_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_2_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_3_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_4_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_5_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_6_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_7_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_8_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_i_9_n_0 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_30 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_31 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_32 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_33 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_34 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_35 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_36 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_45 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_46 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_47 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_48 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_49 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_50 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_51 : STD_LOGIC;
  signal i2c_config_index_reg_rep_n_52 : STD_LOGIC;
  signal i2c_ctrl_clk : STD_LOGIC;
  signal i2c_ctrl_clk_i_1_n_0 : STD_LOGIC;
  signal i2c_ctrl_clk_i_2_n_0 : STD_LOGIC;
  signal i2c_sdat_out : STD_LOGIC;
  signal i2c_sdat_out_i_1_n_0 : STD_LOGIC;
  signal i2c_sdat_out_i_2_n_0 : STD_LOGIC;
  signal i2c_sdat_out_i_3_n_0 : STD_LOGIC;
  signal i2c_sdat_out_i_5_n_0 : STD_LOGIC;
  signal i2c_sdat_out_i_6_n_0 : STD_LOGIC;
  signal i2c_sdat_out_reg_i_4_n_0 : STD_LOGIC;
  signal i2c_stream_cnt : STD_LOGIC;
  signal \i2c_stream_cnt[0]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[1]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[2]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_10_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_11_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_3_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_4_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_5_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_6_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_7_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_8_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt[3]_i_9_n_0\ : STD_LOGIC;
  signal \i2c_stream_cnt_reg_n_0_[0]\ : STD_LOGIC;
  signal \i2c_stream_cnt_reg_n_0_[1]\ : STD_LOGIC;
  signal \i2c_stream_cnt_reg_n_0_[2]\ : STD_LOGIC;
  signal \i2c_stream_cnt_reg_n_0_[3]\ : STD_LOGIC;
  signal i2c_transfer_en : STD_LOGIC;
  signal i2c_transfer_en7_out : STD_LOGIC;
  signal i2c_transfer_en_i_2_n_0 : STD_LOGIC;
  signal i2c_transfer_en_i_3_n_0 : STD_LOGIC;
  signal i2c_transfer_en_i_4_n_0 : STD_LOGIC;
  signal i2c_transfer_en_i_5_n_0 : STD_LOGIC;
  signal i2c_transfer_en_i_6_n_0 : STD_LOGIC;
  signal i2c_transfer_en_i_7_n_0 : STD_LOGIC;
  signal i2c_transfer_end : STD_LOGIC;
  attribute RTL_KEEP of i2c_transfer_end : signal is "yes";
  signal i2c_wdata : STD_LOGIC;
  signal \i2c_wdata[0]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[1]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[2]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[3]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[3]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_wdata[4]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[4]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_wdata[5]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[5]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_wdata[6]_i_1_n_0\ : STD_LOGIC;
  signal \i2c_wdata[6]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_wdata[7]_i_2_n_0\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[0]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[1]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[2]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[3]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[4]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[5]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[6]\ : STD_LOGIC;
  signal \i2c_wdata_reg_n_0_[7]\ : STD_LOGIC;
  signal p_0_in : STD_LOGIC;
  signal p_0_in1_in : STD_LOGIC;
  attribute RTL_KEEP of p_0_in1_in : signal is "yes";
  signal sel : STD_LOGIC;
  signal \NLW_clk_cnt_reg[12]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_delay_cnt_reg[16]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_delay_cnt_reg[16]_i_1_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 1 );
  signal NLW_i2c_config_index_reg_rep_CASCADEOUTA_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_CASCADEOUTB_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_DBITERR_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_INJECTDBITERR_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_INJECTSBITERR_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_SBITERR_UNCONNECTED : STD_LOGIC;
  signal NLW_i2c_config_index_reg_rep_DOADO_UNCONNECTED : STD_LOGIC_VECTOR ( 31 downto 23 );
  signal NLW_i2c_config_index_reg_rep_DOBDO_UNCONNECTED : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal NLW_i2c_config_index_reg_rep_DOPADOP_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_i2c_config_index_reg_rep_DOPBDOP_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_i2c_config_index_reg_rep_ECCPARITY_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal NLW_i2c_config_index_reg_rep_RDADDRECC_UNCONNECTED : STD_LOGIC_VECTOR ( 8 downto 0 );
  attribute FSM_ENCODED_STATES : string;
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[0]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP : string;
  attribute KEEP of \FSM_onehot_current_state_reg[0]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[10]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[10]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[1]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[1]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[2]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[2]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[3]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[3]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[4]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[4]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[5]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[5]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[6]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[6]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[7]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[7]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[8]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[8]\ : label is "yes";
  attribute FSM_ENCODED_STATES of \FSM_onehot_current_state_reg[9]\ : label is "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000";
  attribute KEEP of \FSM_onehot_current_state_reg[9]\ : label is "yes";
  attribute srl_bus_name : string;
  attribute srl_bus_name of \RESETn_reg[3]_srl3\ : label is "\inst/u_i2c_timing_ctrl/RESETn_reg ";
  attribute srl_name : string;
  attribute srl_name of \RESETn_reg[3]_srl3\ : label is "\inst/u_i2c_timing_ctrl/RESETn_reg[3]_srl3 ";
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of i2c_ack1_i_1 : label is "soft_lutpair9";
  attribute SOFT_HLUTNM of i2c_ack1_i_2 : label is "soft_lutpair4";
  attribute SOFT_HLUTNM of i2c_ack2_i_3 : label is "soft_lutpair4";
  attribute SOFT_HLUTNM of i2c_ack2a_i_1 : label is "soft_lutpair9";
  attribute SOFT_HLUTNM of \i2c_config_index[0]_i_1\ : label is "soft_lutpair8";
  attribute SOFT_HLUTNM of \i2c_config_index[1]_i_1\ : label is "soft_lutpair8";
  attribute SOFT_HLUTNM of \i2c_config_index[2]_i_1\ : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of \i2c_config_index[3]_i_1\ : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of \i2c_config_index[6]_i_1\ : label is "soft_lutpair6";
  attribute SOFT_HLUTNM of \i2c_config_index[7]_i_2\ : label is "soft_lutpair6";
  attribute \MEM.PORTA.DATA_BIT_LAYOUT\ : string;
  attribute \MEM.PORTA.DATA_BIT_LAYOUT\ of i2c_config_index_reg_rep : label is "p0_d23";
  attribute METHODOLOGY_DRC_VIOS : string;
  attribute METHODOLOGY_DRC_VIOS of i2c_config_index_reg_rep : label is "{SYNTH-6 {cell *THIS*}}";
  attribute RTL_RAM_BITS : integer;
  attribute RTL_RAM_BITS of i2c_config_index_reg_rep : label is 23552;
  attribute RTL_RAM_NAME : string;
  attribute RTL_RAM_NAME of i2c_config_index_reg_rep : label is "inst/u_i2c_timing_ctrl/i2c_config_index";
  attribute bram_addr_begin : integer;
  attribute bram_addr_begin of i2c_config_index_reg_rep : label is 0;
  attribute bram_addr_end : integer;
  attribute bram_addr_end of i2c_config_index_reg_rep : label is 1023;
  attribute bram_slice_begin : integer;
  attribute bram_slice_begin of i2c_config_index_reg_rep : label is 0;
  attribute bram_slice_end : integer;
  attribute bram_slice_end of i2c_config_index_reg_rep : label is 22;
  attribute SOFT_HLUTNM of i2c_config_index_reg_rep_i_12 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of i2c_config_index_reg_rep_i_13 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of i2c_sdat_out_i_2 : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of i2c_sdat_out_i_3 : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of \i2c_stream_cnt[0]_i_1\ : label is "soft_lutpair7";
  attribute SOFT_HLUTNM of \i2c_stream_cnt[1]_i_1\ : label is "soft_lutpair7";
  attribute SOFT_HLUTNM of \i2c_stream_cnt[2]_i_1\ : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \i2c_stream_cnt[3]_i_2\ : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \i2c_stream_cnt[3]_i_7\ : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of \i2c_wdata[7]_i_2\ : label is "soft_lutpair0";
begin
\/i_\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0001"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I1 => p_0_in1_in,
      I2 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \/i__n_0\
    );
\FSM_onehot_current_state[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000022220000222F"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I1 => \FSM_onehot_current_state[1]_i_2_n_0\,
      I2 => \FSM_onehot_current_state[8]_i_3_n_0\,
      I3 => \FSM_onehot_current_state[0]_i_2_n_0\,
      I4 => \FSM_onehot_current_state[0]_i_3_n_0\,
      I5 => current_state_reg(2),
      O => \FSM_onehot_current_state[0]_i_1_n_0\
    );
\FSM_onehot_current_state[0]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[9]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[8]\,
      O => \FSM_onehot_current_state[0]_i_2_n_0\
    );
\FSM_onehot_current_state[0]_i_3\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I1 => i2c_transfer_end,
      I2 => i2c_transfer_en,
      O => \FSM_onehot_current_state[0]_i_3_n_0\
    );
\FSM_onehot_current_state[10]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => p_0_in,
      O => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state[10]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"20"
    )
        port map (
      I0 => \FSM_onehot_current_state[10]_i_3_n_0\,
      I1 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \FSM_onehot_current_state[10]_i_2_n_0\
    );
\FSM_onehot_current_state[10]_i_3\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000001"
    )
        port map (
      I0 => p_0_in1_in,
      I1 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I4 => \FSM_onehot_current_state[8]_i_3_n_0\,
      O => \FSM_onehot_current_state[10]_i_3_n_0\
    );
\FSM_onehot_current_state[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => \FSM_onehot_current_state[1]_i_2_n_0\,
      I1 => \FSM_onehot_current_state_reg_n_0_[0]\,
      O => \FSM_onehot_current_state[1]_i_1_n_0\
    );
\FSM_onehot_current_state[1]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => i2c_transfer_en_i_2_n_0,
      I1 => i2c_transfer_en,
      I2 => i2c_config_index_reg_rep_i_11_n_0,
      O => \FSM_onehot_current_state[1]_i_2_n_0\
    );
\FSM_onehot_current_state[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4454"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[1]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I3 => \FSM_onehot_current_state[9]_i_2_n_0\,
      O => \FSM_onehot_current_state[2]_i_1_n_0\
    );
\FSM_onehot_current_state[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0200"
    )
        port map (
      I0 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I1 => \FSM_onehot_current_state_reg_n_0_[1]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[2]\,
      O => \FSM_onehot_current_state[3]_i_1_n_0\
    );
\FSM_onehot_current_state[4]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0100010001010100"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[1]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I4 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I5 => \FSM_onehot_current_state[9]_i_2_n_0\,
      O => \FSM_onehot_current_state[4]_i_1_n_0\
    );
\FSM_onehot_current_state[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"20"
    )
        port map (
      I0 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I1 => \FSM_onehot_current_state[8]_i_3_n_0\,
      I2 => \FSM_onehot_current_state_reg_n_0_[4]\,
      O => \FSM_onehot_current_state[5]_i_1_n_0\
    );
\FSM_onehot_current_state[6]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"10111010"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I1 => \FSM_onehot_current_state[8]_i_3_n_0\,
      I2 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I3 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I4 => \FSM_onehot_current_state_reg_n_0_[6]\,
      O => \FSM_onehot_current_state[6]_i_1_n_0\
    );
\FSM_onehot_current_state[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000002200000030"
    )
        port map (
      I0 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I1 => \FSM_onehot_current_state[8]_i_3_n_0\,
      I2 => \FSM_onehot_current_state[7]_i_2_n_0\,
      I3 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I4 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I5 => \FSM_onehot_current_state_reg_n_0_[6]\,
      O => \FSM_onehot_current_state[7]_i_1_n_0\
    );
\FSM_onehot_current_state[7]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => p_0_in1_in,
      I1 => i2c_transfer_en,
      O => \FSM_onehot_current_state[7]_i_2_n_0\
    );
\FSM_onehot_current_state[8]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"02020302"
    )
        port map (
      I0 => p_0_in1_in,
      I1 => \FSM_onehot_current_state[8]_i_2_n_0\,
      I2 => \FSM_onehot_current_state[8]_i_3_n_0\,
      I3 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I4 => \FSM_onehot_current_state[9]_i_2_n_0\,
      O => \FSM_onehot_current_state[8]_i_1_n_0\
    );
\FSM_onehot_current_state[8]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[5]\,
      O => \FSM_onehot_current_state[8]_i_2_n_0\
    );
\FSM_onehot_current_state[8]_i_3\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[1]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[3]\,
      O => \FSM_onehot_current_state[8]_i_3_n_0\
    );
\FSM_onehot_current_state[9]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I1 => \FSM_onehot_current_state[10]_i_3_n_0\,
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      O => \FSM_onehot_current_state[9]_i_1_n_0\
    );
\FSM_onehot_current_state[9]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00100000"
    )
        port map (
      I0 => \i2c_stream_cnt_reg_n_0_[1]\,
      I1 => \i2c_stream_cnt_reg_n_0_[0]\,
      I2 => i2c_transfer_en,
      I3 => \i2c_stream_cnt_reg_n_0_[2]\,
      I4 => \i2c_stream_cnt_reg_n_0_[3]\,
      O => \FSM_onehot_current_state[9]_i_2_n_0\
    );
\FSM_onehot_current_state_reg[0]\: unisim.vcomponents.FDSE
    generic map(
      INIT => '1'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[0]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[0]\,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[10]_i_2_n_0\,
      Q => i2c_transfer_end,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[1]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[1]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[2]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[2]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[3]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[3]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[4]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[4]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[5]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[5]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[6]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[6]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[7]_i_1_n_0\,
      Q => p_0_in1_in,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[8]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[8]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\FSM_onehot_current_state_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => clk,
      CE => i2c_transfer_en,
      D => \FSM_onehot_current_state[9]_i_1_n_0\,
      Q => \FSM_onehot_current_state_reg_n_0_[9]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\RESETn_reg[0]__0\: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
        port map (
      C => clk,
      CE => '1',
      D => rst_n,
      Q => \RESETn_reg[0]__0_n_0\,
      R => '0'
    );
\RESETn_reg[3]_srl3\: unisim.vcomponents.SRL16E
    generic map(
      INIT => X"0007"
    )
        port map (
      A0 => '0',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => clk,
      D => \RESETn_reg[0]__0_n_0\,
      Q => \RESETn_reg[3]_srl3_n_0\
    );
\RESETn_reg[4]__0\: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
        port map (
      C => clk,
      CE => '1',
      D => \RESETn_reg[3]_srl3_n_0\,
      Q => p_0_in,
      R => '0'
    );
\clk_cnt[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F8F0FFFFFFFFFFFF"
    )
        port map (
      I0 => clk_cnt_reg(7),
      I1 => clk_cnt_reg(6),
      I2 => i2c_transfer_en_i_4_n_0,
      I3 => \clk_cnt[0]_i_3_n_0\,
      I4 => i2c_transfer_en_i_2_n_0,
      I5 => p_0_in,
      O => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt[0]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FE00000000000000"
    )
        port map (
      I0 => clk_cnt_reg(0),
      I1 => clk_cnt_reg(1),
      I2 => clk_cnt_reg(2),
      I3 => clk_cnt_reg(4),
      I4 => clk_cnt_reg(3),
      I5 => clk_cnt_reg(5),
      O => \clk_cnt[0]_i_3_n_0\
    );
\clk_cnt[0]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => clk_cnt_reg(0),
      O => \clk_cnt[0]_i_4_n_0\
    );
\clk_cnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[0]_i_2_n_7\,
      Q => clk_cnt_reg(0),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \clk_cnt_reg[0]_i_2_n_0\,
      CO(2) => \clk_cnt_reg[0]_i_2_n_1\,
      CO(1) => \clk_cnt_reg[0]_i_2_n_2\,
      CO(0) => \clk_cnt_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \clk_cnt_reg[0]_i_2_n_4\,
      O(2) => \clk_cnt_reg[0]_i_2_n_5\,
      O(1) => \clk_cnt_reg[0]_i_2_n_6\,
      O(0) => \clk_cnt_reg[0]_i_2_n_7\,
      S(3 downto 1) => clk_cnt_reg(3 downto 1),
      S(0) => \clk_cnt[0]_i_4_n_0\
    );
\clk_cnt_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[8]_i_1_n_5\,
      Q => clk_cnt_reg(10),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[8]_i_1_n_4\,
      Q => clk_cnt_reg(11),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[12]_i_1_n_7\,
      Q => clk_cnt_reg(12),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \clk_cnt_reg[8]_i_1_n_0\,
      CO(3) => \NLW_clk_cnt_reg[12]_i_1_CO_UNCONNECTED\(3),
      CO(2) => \clk_cnt_reg[12]_i_1_n_1\,
      CO(1) => \clk_cnt_reg[12]_i_1_n_2\,
      CO(0) => \clk_cnt_reg[12]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \clk_cnt_reg[12]_i_1_n_4\,
      O(2) => \clk_cnt_reg[12]_i_1_n_5\,
      O(1) => \clk_cnt_reg[12]_i_1_n_6\,
      O(0) => \clk_cnt_reg[12]_i_1_n_7\,
      S(3 downto 0) => clk_cnt_reg(15 downto 12)
    );
\clk_cnt_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[12]_i_1_n_6\,
      Q => clk_cnt_reg(13),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[12]_i_1_n_5\,
      Q => clk_cnt_reg(14),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[12]_i_1_n_4\,
      Q => clk_cnt_reg(15),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[0]_i_2_n_6\,
      Q => clk_cnt_reg(1),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[0]_i_2_n_5\,
      Q => clk_cnt_reg(2),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[0]_i_2_n_4\,
      Q => clk_cnt_reg(3),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[4]_i_1_n_7\,
      Q => clk_cnt_reg(4),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \clk_cnt_reg[0]_i_2_n_0\,
      CO(3) => \clk_cnt_reg[4]_i_1_n_0\,
      CO(2) => \clk_cnt_reg[4]_i_1_n_1\,
      CO(1) => \clk_cnt_reg[4]_i_1_n_2\,
      CO(0) => \clk_cnt_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \clk_cnt_reg[4]_i_1_n_4\,
      O(2) => \clk_cnt_reg[4]_i_1_n_5\,
      O(1) => \clk_cnt_reg[4]_i_1_n_6\,
      O(0) => \clk_cnt_reg[4]_i_1_n_7\,
      S(3 downto 0) => clk_cnt_reg(7 downto 4)
    );
\clk_cnt_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[4]_i_1_n_6\,
      Q => clk_cnt_reg(5),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[4]_i_1_n_5\,
      Q => clk_cnt_reg(6),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[4]_i_1_n_4\,
      Q => clk_cnt_reg(7),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[8]_i_1_n_7\,
      Q => clk_cnt_reg(8),
      R => \clk_cnt[0]_i_1_n_0\
    );
\clk_cnt_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \clk_cnt_reg[4]_i_1_n_0\,
      CO(3) => \clk_cnt_reg[8]_i_1_n_0\,
      CO(2) => \clk_cnt_reg[8]_i_1_n_1\,
      CO(1) => \clk_cnt_reg[8]_i_1_n_2\,
      CO(0) => \clk_cnt_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \clk_cnt_reg[8]_i_1_n_4\,
      O(2) => \clk_cnt_reg[8]_i_1_n_5\,
      O(1) => \clk_cnt_reg[8]_i_1_n_6\,
      O(0) => \clk_cnt_reg[8]_i_1_n_7\,
      S(3 downto 0) => clk_cnt_reg(11 downto 8)
    );
\clk_cnt_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => \clk_cnt_reg[8]_i_1_n_6\,
      Q => clk_cnt_reg(9),
      R => \clk_cnt[0]_i_1_n_0\
    );
cmos_scl_INST_0: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFAEEEEEEEB"
    )
        port map (
      I0 => i2c_ctrl_clk,
      I1 => current_state_reg(1),
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      I4 => i2c_transfer_end,
      I5 => current_state_reg(2),
      O => cmos_scl
    );
cmos_scl_INST_0_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFFFFE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I2 => i2c_transfer_end,
      I3 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I4 => p_0_in1_in,
      O => current_state_reg(1)
    );
cmos_scl_INST_0_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I3 => p_0_in1_in,
      O => current_state_reg(2)
    );
cmos_sda_INST_0: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => i2c_sdat_out,
      I1 => \/i__n_0\,
      O => cmos_sda
    );
\delay_cnt[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000000077F7"
    )
        port map (
      I0 => delay_cnt_reg(13),
      I1 => delay_cnt_reg(14),
      I2 => \delay_cnt[0]_i_3_n_0\,
      I3 => \delay_cnt[0]_i_4_n_0\,
      I4 => delay_cnt_reg(16),
      I5 => delay_cnt_reg(15),
      O => sel
    );
\delay_cnt[0]_i_3\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0001"
    )
        port map (
      I0 => delay_cnt_reg(10),
      I1 => delay_cnt_reg(9),
      I2 => delay_cnt_reg(12),
      I3 => delay_cnt_reg(11),
      O => \delay_cnt[0]_i_3_n_0\
    );
\delay_cnt[0]_i_4\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8888888080808080"
    )
        port map (
      I0 => delay_cnt_reg(7),
      I1 => delay_cnt_reg(8),
      I2 => delay_cnt_reg(6),
      I3 => delay_cnt_reg(4),
      I4 => delay_cnt_reg(3),
      I5 => delay_cnt_reg(5),
      O => \delay_cnt[0]_i_4_n_0\
    );
\delay_cnt[0]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => delay_cnt_reg(0),
      O => \delay_cnt[0]_i_5_n_0\
    );
\delay_cnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[0]_i_2_n_7\,
      Q => delay_cnt_reg(0),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \delay_cnt_reg[0]_i_2_n_0\,
      CO(2) => \delay_cnt_reg[0]_i_2_n_1\,
      CO(1) => \delay_cnt_reg[0]_i_2_n_2\,
      CO(0) => \delay_cnt_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \delay_cnt_reg[0]_i_2_n_4\,
      O(2) => \delay_cnt_reg[0]_i_2_n_5\,
      O(1) => \delay_cnt_reg[0]_i_2_n_6\,
      O(0) => \delay_cnt_reg[0]_i_2_n_7\,
      S(3 downto 1) => delay_cnt_reg(3 downto 1),
      S(0) => \delay_cnt[0]_i_5_n_0\
    );
\delay_cnt_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[8]_i_1_n_5\,
      Q => delay_cnt_reg(10),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[8]_i_1_n_4\,
      Q => delay_cnt_reg(11),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[12]_i_1_n_7\,
      Q => delay_cnt_reg(12),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \delay_cnt_reg[8]_i_1_n_0\,
      CO(3) => \delay_cnt_reg[12]_i_1_n_0\,
      CO(2) => \delay_cnt_reg[12]_i_1_n_1\,
      CO(1) => \delay_cnt_reg[12]_i_1_n_2\,
      CO(0) => \delay_cnt_reg[12]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \delay_cnt_reg[12]_i_1_n_4\,
      O(2) => \delay_cnt_reg[12]_i_1_n_5\,
      O(1) => \delay_cnt_reg[12]_i_1_n_6\,
      O(0) => \delay_cnt_reg[12]_i_1_n_7\,
      S(3 downto 0) => delay_cnt_reg(15 downto 12)
    );
\delay_cnt_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[12]_i_1_n_6\,
      Q => delay_cnt_reg(13),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[12]_i_1_n_5\,
      Q => delay_cnt_reg(14),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[12]_i_1_n_4\,
      Q => delay_cnt_reg(15),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[16]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[16]_i_1_n_7\,
      Q => delay_cnt_reg(16),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[16]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \delay_cnt_reg[12]_i_1_n_0\,
      CO(3 downto 0) => \NLW_delay_cnt_reg[16]_i_1_CO_UNCONNECTED\(3 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 1) => \NLW_delay_cnt_reg[16]_i_1_O_UNCONNECTED\(3 downto 1),
      O(0) => \delay_cnt_reg[16]_i_1_n_7\,
      S(3 downto 1) => B"000",
      S(0) => delay_cnt_reg(16)
    );
\delay_cnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[0]_i_2_n_6\,
      Q => delay_cnt_reg(1),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[0]_i_2_n_5\,
      Q => delay_cnt_reg(2),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[0]_i_2_n_4\,
      Q => delay_cnt_reg(3),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[4]_i_1_n_7\,
      Q => delay_cnt_reg(4),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \delay_cnt_reg[0]_i_2_n_0\,
      CO(3) => \delay_cnt_reg[4]_i_1_n_0\,
      CO(2) => \delay_cnt_reg[4]_i_1_n_1\,
      CO(1) => \delay_cnt_reg[4]_i_1_n_2\,
      CO(0) => \delay_cnt_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \delay_cnt_reg[4]_i_1_n_4\,
      O(2) => \delay_cnt_reg[4]_i_1_n_5\,
      O(1) => \delay_cnt_reg[4]_i_1_n_6\,
      O(0) => \delay_cnt_reg[4]_i_1_n_7\,
      S(3 downto 0) => delay_cnt_reg(7 downto 4)
    );
\delay_cnt_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[4]_i_1_n_6\,
      Q => delay_cnt_reg(5),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[4]_i_1_n_5\,
      Q => delay_cnt_reg(6),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[4]_i_1_n_4\,
      Q => delay_cnt_reg(7),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[8]_i_1_n_7\,
      Q => delay_cnt_reg(8),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\delay_cnt_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \delay_cnt_reg[4]_i_1_n_0\,
      CO(3) => \delay_cnt_reg[8]_i_1_n_0\,
      CO(2) => \delay_cnt_reg[8]_i_1_n_1\,
      CO(1) => \delay_cnt_reg[8]_i_1_n_2\,
      CO(0) => \delay_cnt_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \delay_cnt_reg[8]_i_1_n_4\,
      O(2) => \delay_cnt_reg[8]_i_1_n_5\,
      O(1) => \delay_cnt_reg[8]_i_1_n_6\,
      O(0) => \delay_cnt_reg[8]_i_1_n_7\,
      S(3 downto 0) => delay_cnt_reg(11 downto 8)
    );
\delay_cnt_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => sel,
      D => \delay_cnt_reg[8]_i_1_n_6\,
      Q => delay_cnt_reg(9),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_ack1_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => i2c_ack2_i_2_n_0,
      I1 => i2c_ack10_out,
      I2 => i2c_ack1,
      O => i2c_ack1_i_1_n_0
    );
i2c_ack1_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00002002"
    )
        port map (
      I0 => i2c_capture_en,
      I1 => \i2c_stream_cnt[3]_i_6_n_0\,
      I2 => \i2c_stream_cnt[3]_i_5_n_0\,
      I3 => \i2c_stream_cnt[3]_i_4_n_0\,
      I4 => \i2c_stream_cnt[3]_i_3_n_0\,
      O => i2c_ack10_out
    );
i2c_ack1_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ack1_i_1_n_0,
      Q => i2c_ack1,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_ack2_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => i2c_ack2_i_2_n_0,
      I1 => i2c_ack24_out,
      I2 => i2c_ack2,
      O => i2c_ack2_i_1_n_0
    );
i2c_ack2_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"D"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_4_n_0\,
      I1 => cmos_sda,
      O => i2c_ack2_i_2_n_0
    );
i2c_ack2_i_3: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00002002"
    )
        port map (
      I0 => i2c_capture_en,
      I1 => \i2c_stream_cnt[3]_i_6_n_0\,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => \i2c_stream_cnt[3]_i_4_n_0\,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      O => i2c_ack24_out
    );
i2c_ack2_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ack2_i_1_n_0,
      Q => i2c_ack2,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_ack2a_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => i2c_ack2_i_2_n_0,
      I1 => i2c_ack2a1_out,
      I2 => i2c_ack2a,
      O => i2c_ack2a_i_1_n_0
    );
i2c_ack2a_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00008002"
    )
        port map (
      I0 => i2c_capture_en,
      I1 => \i2c_stream_cnt[3]_i_4_n_0\,
      I2 => \i2c_stream_cnt[3]_i_5_n_0\,
      I3 => \i2c_stream_cnt[3]_i_3_n_0\,
      I4 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => i2c_ack2a1_out
    );
i2c_ack2a_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ack2a_i_1_n_0,
      Q => i2c_ack2a,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_ack3_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFB00000008"
    )
        port map (
      I0 => i2c_ack2_i_2_n_0,
      I1 => i2c_capture_en,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_ack3_i_2_n_0,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      I5 => i2c_ack3,
      O => i2c_ack3_i_1_n_0
    );
i2c_ack3_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"55555555555556A6"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_4_n_0\,
      I1 => i2c_transfer_end,
      I2 => i2c_transfer_en,
      I3 => p_0_in1_in,
      I4 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I5 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => i2c_ack3_i_2_n_0
    );
i2c_ack3_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ack3_i_1_n_0,
      Q => i2c_ack3,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_ack_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFB00000008"
    )
        port map (
      I0 => i2c_ack_i_2_n_0,
      I1 => i2c_capture_en,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_ack_i_3_n_0,
      I4 => \i2c_stream_cnt[3]_i_4_n_0\,
      I5 => i2c_ack,
      O => i2c_ack_i_1_n_0
    );
i2c_ack_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFEFFFF"
    )
        port map (
      I0 => i2c_ack2a,
      I1 => i2c_ack1,
      I2 => i2c_ack3,
      I3 => i2c_ack2,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      O => i2c_ack_i_2_n_0
    );
i2c_ack_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"55555555555556A6"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_5_n_0\,
      I1 => i2c_transfer_end,
      I2 => i2c_transfer_en,
      I3 => p_0_in1_in,
      I4 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I5 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => i2c_ack_i_3_n_0
    );
i2c_ack_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ack_i_1_n_0,
      Q => i2c_ack,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_capture_en_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000200"
    )
        port map (
      I0 => i2c_transfer_en_i_2_n_0,
      I1 => i2c_transfer_en_i_4_n_0,
      I2 => clk_cnt_reg(7),
      I3 => clk_cnt_reg(6),
      I4 => i2c_capture_en_i_2_n_0,
      I5 => i2c_capture_en_i_3_n_0,
      O => i2c_capture_en6_out
    );
i2c_capture_en_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => clk_cnt_reg(0),
      I1 => clk_cnt_reg(1),
      O => i2c_capture_en_i_2_n_0
    );
i2c_capture_en_i_3: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7FFF"
    )
        port map (
      I0 => clk_cnt_reg(4),
      I1 => clk_cnt_reg(3),
      I2 => clk_cnt_reg(5),
      I3 => clk_cnt_reg(2),
      O => i2c_capture_en_i_3_n_0
    );
i2c_capture_en_reg: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => i2c_capture_en6_out,
      Q => i2c_capture_en,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index[0]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(0),
      O => \i2c_config_index[0]_i_1_n_0\
    );
\i2c_config_index[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"14"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(1),
      I2 => \i2c_config_index_reg__0\(0),
      O => \i2c_config_index[1]_i_1_n_0\
    );
\i2c_config_index[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BFEA"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(0),
      I2 => \i2c_config_index_reg__0\(1),
      I3 => \i2c_config_index_reg__0\(2),
      O => \i2c_config_index[2]_i_1_n_0\
    );
\i2c_config_index[3]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"BFFFEAAA"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(2),
      I2 => \i2c_config_index_reg__0\(1),
      I3 => \i2c_config_index_reg__0\(0),
      I4 => \i2c_config_index_reg__0\(3),
      O => \i2c_config_index[3]_i_1_n_0\
    );
\i2c_config_index[4]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"BFFFFFFFEAAAAAAA"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(3),
      I2 => \i2c_config_index_reg__0\(2),
      I3 => \i2c_config_index_reg__0\(1),
      I4 => \i2c_config_index_reg__0\(0),
      I5 => \i2c_config_index_reg__0\(4),
      O => \i2c_config_index[4]_i_1_n_0\
    );
\i2c_config_index[5]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FBFFFFFFAEAAAAAA"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(4),
      I2 => i2c_config_index_reg_rep_i_13_n_0,
      I3 => \i2c_config_index_reg__0\(2),
      I4 => \i2c_config_index_reg__0\(3),
      I5 => \i2c_config_index_reg__0\(5),
      O => \i2c_config_index[5]_i_1_n_0\
    );
\i2c_config_index[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"BE"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => i2c_config_index_reg_rep_i_10_n_0,
      I2 => \i2c_config_index_reg__0\(6),
      O => \i2c_config_index[6]_i_1_n_0\
    );
\i2c_config_index[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => i2c_transfer_end,
      I1 => i2c_transfer_en,
      I2 => i2c_ack,
      O => \i2c_config_index[7]_i_1_n_0\
    );
\i2c_config_index[7]_i_2\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFEA"
    )
        port map (
      I0 => i2c_config_index_reg_rep_i_11_n_0,
      I1 => \i2c_config_index_reg__0\(6),
      I2 => i2c_config_index_reg_rep_i_10_n_0,
      I3 => \i2c_config_index_reg__0\(7),
      O => \i2c_config_index[7]_i_2_n_0\
    );
\i2c_config_index_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[0]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(0),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[1]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(1),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[2]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(2),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[3]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(3),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[4]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(4),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[5]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(5),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[6]_i_1_n_0\,
      Q => \i2c_config_index_reg__0\(6),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_config_index_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => \i2c_config_index[7]_i_1_n_0\,
      D => \i2c_config_index[7]_i_2_n_0\,
      Q => \i2c_config_index_reg__0\(7),
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_config_index_reg_rep: unisim.vcomponents.RAMB36E1
    generic map(
      DOA_REG => 0,
      DOB_REG => 0,
      EN_ECC_READ => false,
      EN_ECC_WRITE => false,
      INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_08 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_09 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INITP_0F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_00 => X"003037130030341A003018FF003017FF00310303003008420030088200310311",
      INIT_01 => X"0037035A003704A0003621E000363312003632E20036310E0036303600310801",
      INIT_02 => X"003731120039010A00390610003905020037051A00370B600037170100371578",
      INIT_03 => X"003A1800003A134300471C5000371B200036205200302D600036013300360008",
      INIT_04 => X"003C0598003C0428003C013400362201003634400036360300363513003A19F8",
      INIT_05 => X"0038111000381000003C0B40003C0A9C003C091C003C0800003C0708003C0600",
      INIT_06 => X"00302E0000300E58003004FF003000000040051A004001020037086400381200",
      INIT_07 => X"003A1E26003A1B30003A1028003A0F30005000A700440E0000501F0100430060",
      INIT_08 => X"00580526005804120058030F0058020F0058011400580023003A1F14003A1160",
      INIT_09 => X"00580D0300580C0800580B0D00580A080058090500580805005807080058060C",
      INIT_0A => X"00581501005814000058130300581207005811090058100300580F0000580E00",
      INIT_0B => X"00581D0E00581C0800581B0600581A05005819080058180D0058170800581603",
      INIT_0C => X"00582526005824460058232800582215005821110058201100581F1700581E29",
      INIT_0D => X"00582D2400582C2400582B2200582A2400582926005828640058272600582608",
      INIT_0E => X"00583522005834240058332600583224005831420058304000582F2200582E06",
      INIT_0F => X"00583DCE00583C4200583B2800583A2600583924005838440058372600583622",
      INIT_10 => X"005187090051860900518524005184250051831400518200005181F2005180FF",
      INIT_11 => X"00518F5600518E3D00518D4200518CB200518BE000518A540051897500518809",
      INIT_12 => X"0051970100519603005195F0005194F00051937000519204005191F800519046",
      INIT_13 => X"0054800100519E3800519D8200519C0600519B0000519A040051991200519804",
      INIT_14 => X"005488870054877D005486710054856500548451005483280054821400548108",
      INIT_15 => X"0054901D00548FEA00548EDD00548DCD00548CB800548BAA00548A9A00548991",
      INIT_16 => X"0053886C0053877C005386880053857E0053840A005383080053825B0053811E",
      INIT_17 => X"00558A000055891000558410005583400055800600538B9800538A0100538910",
      INIT_18 => X"00530530005304080053030000530210005301300053000800501D4000558BF8",
      INIT_19 => X"003008020050250000530C0600530B0400530A30005309080053071600530608",
      INIT_1A => X"0038000000381531003814310038210300382045003C07070030366900303541",
      INIT_1B => X"00380805003807A9003806060038053F0038040A003803FA0038020000380100",
      INIT_1C => X"0038130400380FE400380E0200380D6400380C0700380BD000380A0200380900",
      INIT_1D => X"003A15E0003A1402003A03E0003A020200370C03003709520036122900361800",
      INIT_1E => X"0048371600460C2000460B370044070400471303003006C30030021C00400402",
      INIT_1F => X"000000000000000000000000003B0000003B0083003503000050018300382404",
      INIT_20 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_21 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_22 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_23 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_24 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_25 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_26 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_27 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_28 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_29 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_2F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_30 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_31 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_32 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_33 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_34 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_35 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_36 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_37 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_38 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_39 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_40 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_41 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_42 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_43 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_44 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_45 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_46 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_47 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_48 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_49 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_4F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_50 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_51 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_52 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_53 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_54 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_55 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_56 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_57 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_58 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_59 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_5F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_60 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_61 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_62 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_63 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_64 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_65 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_66 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_67 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_68 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_69 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_6F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_70 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_71 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_72 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_73 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_74 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_75 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_76 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_77 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_78 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_79 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_7F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_A => X"000000000",
      INIT_B => X"000000000",
      RAM_EXTENSION_A => "NONE",
      RAM_EXTENSION_B => "NONE",
      RAM_MODE => "TDP",
      RDADDR_COLLISION_HWCONFIG => "PERFORMANCE",
      READ_WIDTH_A => 36,
      READ_WIDTH_B => 0,
      RSTREG_PRIORITY_A => "RSTREG",
      RSTREG_PRIORITY_B => "RSTREG",
      SIM_COLLISION_CHECK => "ALL",
      SIM_DEVICE => "7SERIES",
      SRVAL_A => X"000000000",
      SRVAL_B => X"000000000",
      WRITE_MODE_A => "WRITE_FIRST",
      WRITE_MODE_B => "WRITE_FIRST",
      WRITE_WIDTH_A => 36,
      WRITE_WIDTH_B => 0
    )
        port map (
      ADDRARDADDR(15 downto 13) => B"100",
      ADDRARDADDR(12) => i2c_config_index_reg_rep_i_2_n_0,
      ADDRARDADDR(11) => i2c_config_index_reg_rep_i_3_n_0,
      ADDRARDADDR(10) => i2c_config_index_reg_rep_i_4_n_0,
      ADDRARDADDR(9) => i2c_config_index_reg_rep_i_5_n_0,
      ADDRARDADDR(8) => i2c_config_index_reg_rep_i_6_n_0,
      ADDRARDADDR(7) => i2c_config_index_reg_rep_i_7_n_0,
      ADDRARDADDR(6) => i2c_config_index_reg_rep_i_8_n_0,
      ADDRARDADDR(5) => i2c_config_index_reg_rep_i_9_n_0,
      ADDRARDADDR(4 downto 0) => B"00000",
      ADDRBWRADDR(15 downto 0) => B"1111111111111111",
      CASCADEINA => '1',
      CASCADEINB => '0',
      CASCADEOUTA => NLW_i2c_config_index_reg_rep_CASCADEOUTA_UNCONNECTED,
      CASCADEOUTB => NLW_i2c_config_index_reg_rep_CASCADEOUTB_UNCONNECTED,
      CLKARDCLK => clk,
      CLKBWRCLK => '0',
      DBITERR => NLW_i2c_config_index_reg_rep_DBITERR_UNCONNECTED,
      DIADI(31 downto 0) => B"00000000011111111111111111111111",
      DIBDI(31 downto 0) => B"11111111111111111111111111111111",
      DIPADIP(3 downto 0) => B"0000",
      DIPBDIP(3 downto 0) => B"1111",
      DOADO(31 downto 23) => NLW_i2c_config_index_reg_rep_DOADO_UNCONNECTED(31 downto 23),
      DOADO(22) => i2c_config_index_reg_rep_n_30,
      DOADO(21) => i2c_config_index_reg_rep_n_31,
      DOADO(20) => i2c_config_index_reg_rep_n_32,
      DOADO(19) => i2c_config_index_reg_rep_n_33,
      DOADO(18) => i2c_config_index_reg_rep_n_34,
      DOADO(17) => i2c_config_index_reg_rep_n_35,
      DOADO(16) => i2c_config_index_reg_rep_n_36,
      DOADO(15 downto 8) => data2(7 downto 0),
      DOADO(7) => i2c_config_index_reg_rep_n_45,
      DOADO(6) => i2c_config_index_reg_rep_n_46,
      DOADO(5) => i2c_config_index_reg_rep_n_47,
      DOADO(4) => i2c_config_index_reg_rep_n_48,
      DOADO(3) => i2c_config_index_reg_rep_n_49,
      DOADO(2) => i2c_config_index_reg_rep_n_50,
      DOADO(1) => i2c_config_index_reg_rep_n_51,
      DOADO(0) => i2c_config_index_reg_rep_n_52,
      DOBDO(31 downto 0) => NLW_i2c_config_index_reg_rep_DOBDO_UNCONNECTED(31 downto 0),
      DOPADOP(3 downto 0) => NLW_i2c_config_index_reg_rep_DOPADOP_UNCONNECTED(3 downto 0),
      DOPBDOP(3 downto 0) => NLW_i2c_config_index_reg_rep_DOPBDOP_UNCONNECTED(3 downto 0),
      ECCPARITY(7 downto 0) => NLW_i2c_config_index_reg_rep_ECCPARITY_UNCONNECTED(7 downto 0),
      ENARDEN => i2c_config_index_reg_rep_i_1_n_0,
      ENBWREN => '0',
      INJECTDBITERR => NLW_i2c_config_index_reg_rep_INJECTDBITERR_UNCONNECTED,
      INJECTSBITERR => NLW_i2c_config_index_reg_rep_INJECTSBITERR_UNCONNECTED,
      RDADDRECC(8 downto 0) => NLW_i2c_config_index_reg_rep_RDADDRECC_UNCONNECTED(8 downto 0),
      REGCEAREGCE => '0',
      REGCEB => '0',
      RSTRAMARSTRAM => '0',
      RSTRAMB => '0',
      RSTREGARSTREG => '0',
      RSTREGB => '0',
      SBITERR => NLW_i2c_config_index_reg_rep_SBITERR_UNCONNECTED,
      WEA(3 downto 0) => B"0000",
      WEBWE(7 downto 0) => B"00000000"
    );
i2c_config_index_reg_rep_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"40FF"
    )
        port map (
      I0 => i2c_ack,
      I1 => i2c_transfer_en,
      I2 => i2c_transfer_end,
      I3 => p_0_in,
      O => i2c_config_index_reg_rep_i_1_n_0
    );
i2c_config_index_reg_rep_i_10: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8000000000000000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(5),
      I1 => \i2c_config_index_reg__0\(3),
      I2 => \i2c_config_index_reg__0\(2),
      I3 => \i2c_config_index_reg__0\(1),
      I4 => \i2c_config_index_reg__0\(0),
      I5 => \i2c_config_index_reg__0\(4),
      O => i2c_config_index_reg_rep_i_10_n_0
    );
i2c_config_index_reg_rep_i_11: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00008880"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(6),
      I1 => \i2c_config_index_reg__0\(7),
      I2 => \i2c_config_index_reg__0\(0),
      I3 => \i2c_config_index_reg__0\(1),
      I4 => i2c_config_index_reg_rep_i_14_n_0,
      O => i2c_config_index_reg_rep_i_11_n_0
    );
i2c_config_index_reg_rep_i_12: unisim.vcomponents.LUT5
    generic map(
      INIT => X"80000000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(4),
      I1 => \i2c_config_index_reg__0\(0),
      I2 => \i2c_config_index_reg__0\(1),
      I3 => \i2c_config_index_reg__0\(2),
      I4 => \i2c_config_index_reg__0\(3),
      O => i2c_config_index_reg_rep_i_12_n_0
    );
i2c_config_index_reg_rep_i_13: unisim.vcomponents.LUT2
    generic map(
      INIT => X"7"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(0),
      I1 => \i2c_config_index_reg__0\(1),
      O => i2c_config_index_reg_rep_i_13_n_0
    );
i2c_config_index_reg_rep_i_14: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7FFF"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(3),
      I1 => \i2c_config_index_reg__0\(2),
      I2 => \i2c_config_index_reg__0\(5),
      I3 => \i2c_config_index_reg__0\(4),
      O => i2c_config_index_reg_rep_i_14_n_0
    );
i2c_config_index_reg_rep_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFEA0000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(7),
      I1 => i2c_config_index_reg_rep_i_10_n_0,
      I2 => \i2c_config_index_reg__0\(6),
      I3 => i2c_config_index_reg_rep_i_11_n_0,
      I4 => p_0_in,
      O => i2c_config_index_reg_rep_i_2_n_0
    );
i2c_config_index_reg_rep_i_3: unisim.vcomponents.LUT4
    generic map(
      INIT => X"F600"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(6),
      I1 => i2c_config_index_reg_rep_i_10_n_0,
      I2 => i2c_config_index_reg_rep_i_11_n_0,
      I3 => p_0_in,
      O => i2c_config_index_reg_rep_i_3_n_0
    );
i2c_config_index_reg_rep_i_4: unisim.vcomponents.LUT4
    generic map(
      INIT => X"F600"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(5),
      I1 => i2c_config_index_reg_rep_i_12_n_0,
      I2 => i2c_config_index_reg_rep_i_11_n_0,
      I3 => p_0_in,
      O => i2c_config_index_reg_rep_i_4_n_0
    );
i2c_config_index_reg_rep_i_5: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF9AAA00000000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(4),
      I1 => i2c_config_index_reg_rep_i_13_n_0,
      I2 => \i2c_config_index_reg__0\(2),
      I3 => \i2c_config_index_reg__0\(3),
      I4 => i2c_config_index_reg_rep_i_11_n_0,
      I5 => p_0_in,
      O => i2c_config_index_reg_rep_i_5_n_0
    );
i2c_config_index_reg_rep_i_6: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF6AAA00000000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(3),
      I1 => \i2c_config_index_reg__0\(0),
      I2 => \i2c_config_index_reg__0\(1),
      I3 => \i2c_config_index_reg__0\(2),
      I4 => i2c_config_index_reg_rep_i_11_n_0,
      I5 => p_0_in,
      O => i2c_config_index_reg_rep_i_6_n_0
    );
i2c_config_index_reg_rep_i_7: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FF6A0000"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(2),
      I1 => \i2c_config_index_reg__0\(1),
      I2 => \i2c_config_index_reg__0\(0),
      I3 => i2c_config_index_reg_rep_i_11_n_0,
      I4 => p_0_in,
      O => i2c_config_index_reg_rep_i_7_n_0
    );
i2c_config_index_reg_rep_i_8: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0600"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(0),
      I1 => \i2c_config_index_reg__0\(1),
      I2 => i2c_config_index_reg_rep_i_11_n_0,
      I3 => p_0_in,
      O => i2c_config_index_reg_rep_i_8_n_0
    );
i2c_config_index_reg_rep_i_9: unisim.vcomponents.LUT3
    generic map(
      INIT => X"D0"
    )
        port map (
      I0 => \i2c_config_index_reg__0\(0),
      I1 => i2c_config_index_reg_rep_i_11_n_0,
      I2 => p_0_in,
      O => i2c_config_index_reg_rep_i_9_n_0
    );
i2c_ctrl_clk_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000D9D8D8D8"
    )
        port map (
      I0 => clk_cnt_reg(7),
      I1 => i2c_capture_en_i_3_n_0,
      I2 => clk_cnt_reg(6),
      I3 => clk_cnt_reg(0),
      I4 => clk_cnt_reg(1),
      I5 => i2c_ctrl_clk_i_2_n_0,
      O => i2c_ctrl_clk_i_1_n_0
    );
i2c_ctrl_clk_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"F8FFFFFF"
    )
        port map (
      I0 => clk_cnt_reg(6),
      I1 => clk_cnt_reg(7),
      I2 => i2c_transfer_en_i_4_n_0,
      I3 => p_0_in,
      I4 => i2c_transfer_en_i_2_n_0,
      O => i2c_ctrl_clk_i_2_n_0
    );
i2c_ctrl_clk_reg: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => i2c_ctrl_clk_i_1_n_0,
      Q => i2c_ctrl_clk,
      R => '0'
    );
i2c_sdat_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FBBFBBBB08808888"
    )
        port map (
      I0 => i2c_sdat_out_i_2_n_0,
      I1 => i2c_transfer_en,
      I2 => \i2c_stream_cnt[3]_i_6_n_0\,
      I3 => i2c_sdat_out_i_3_n_0,
      I4 => \i2c_stream_cnt[3]_i_4_n_0\,
      I5 => i2c_sdat_out,
      O => i2c_sdat_out_i_1_n_0
    );
i2c_sdat_out_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FDFCF301"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_5_n_0\,
      I1 => \i2c_stream_cnt[3]_i_4_n_0\,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_sdat_out_reg_i_4_n_0,
      I4 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => i2c_sdat_out_i_2_n_0
    );
i2c_sdat_out_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_3_n_0\,
      I1 => \i2c_stream_cnt[3]_i_5_n_0\,
      O => i2c_sdat_out_i_3_n_0
    );
i2c_sdat_out_i_5: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => \i2c_wdata_reg_n_0_[4]\,
      I1 => \i2c_wdata_reg_n_0_[5]\,
      I2 => \i2c_stream_cnt_reg_n_0_[1]\,
      I3 => \i2c_wdata_reg_n_0_[6]\,
      I4 => \i2c_stream_cnt_reg_n_0_[0]\,
      I5 => \i2c_wdata_reg_n_0_[7]\,
      O => i2c_sdat_out_i_5_n_0
    );
i2c_sdat_out_i_6: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => \i2c_wdata_reg_n_0_[0]\,
      I1 => \i2c_wdata_reg_n_0_[1]\,
      I2 => \i2c_stream_cnt_reg_n_0_[1]\,
      I3 => \i2c_wdata_reg_n_0_[2]\,
      I4 => \i2c_stream_cnt_reg_n_0_[0]\,
      I5 => \i2c_wdata_reg_n_0_[3]\,
      O => i2c_sdat_out_i_6_n_0
    );
i2c_sdat_out_reg: unisim.vcomponents.FDSE
     port map (
      C => clk,
      CE => '1',
      D => i2c_sdat_out_i_1_n_0,
      Q => i2c_sdat_out,
      S => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_sdat_out_reg_i_4: unisim.vcomponents.MUXF7
     port map (
      I0 => i2c_sdat_out_i_5_n_0,
      I1 => i2c_sdat_out_i_6_n_0,
      O => i2c_sdat_out_reg_i_4_n_0,
      S => \i2c_stream_cnt_reg_n_0_[2]\
    );
\i2c_stream_cnt[0]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_7_n_0\,
      I1 => \i2c_stream_cnt_reg_n_0_[0]\,
      O => \i2c_stream_cnt[0]_i_1_n_0\
    );
\i2c_stream_cnt[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"28"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_7_n_0\,
      I1 => \i2c_stream_cnt_reg_n_0_[1]\,
      I2 => \i2c_stream_cnt_reg_n_0_[0]\,
      O => \i2c_stream_cnt[1]_i_1_n_0\
    );
\i2c_stream_cnt[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"2A80"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_7_n_0\,
      I1 => \i2c_stream_cnt_reg_n_0_[0]\,
      I2 => \i2c_stream_cnt_reg_n_0_[1]\,
      I3 => \i2c_stream_cnt_reg_n_0_[2]\,
      O => \i2c_stream_cnt[2]_i_1_n_0\
    );
\i2c_stream_cnt[3]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"A8AAAAAA"
    )
        port map (
      I0 => i2c_transfer_en,
      I1 => \i2c_stream_cnt[3]_i_3_n_0\,
      I2 => \i2c_stream_cnt[3]_i_4_n_0\,
      I3 => \i2c_stream_cnt[3]_i_5_n_0\,
      I4 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => i2c_stream_cnt
    );
\i2c_stream_cnt[3]_i_10\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => p_0_in1_in,
      I1 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I2 => i2c_transfer_end,
      O => \i2c_stream_cnt[3]_i_10_n_0\
    );
\i2c_stream_cnt[3]_i_11\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"0E"
    )
        port map (
      I0 => p_0_in1_in,
      I1 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I2 => i2c_transfer_en,
      O => \i2c_stream_cnt[3]_i_11_n_0\
    );
\i2c_stream_cnt[3]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"2AAA8000"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_7_n_0\,
      I1 => \i2c_stream_cnt_reg_n_0_[1]\,
      I2 => \i2c_stream_cnt_reg_n_0_[0]\,
      I3 => \i2c_stream_cnt_reg_n_0_[2]\,
      I4 => \i2c_stream_cnt_reg_n_0_[3]\,
      O => \i2c_stream_cnt[3]_i_2_n_0\
    );
\i2c_stream_cnt[3]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFEFEFFFEFFFE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I3 => p_0_in1_in,
      I4 => \FSM_onehot_current_state_reg_n_0_[3]\,
      I5 => i2c_transfer_en,
      O => \i2c_stream_cnt[3]_i_3_n_0\
    );
\i2c_stream_cnt[3]_i_4\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AEAEFEAEAEAEAEAE"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_8_n_0\,
      I1 => \i2c_stream_cnt[3]_i_9_n_0\,
      I2 => i2c_transfer_en,
      I3 => \FSM_onehot_current_state_reg_n_0_[0]\,
      I4 => i2c_config_index_reg_rep_i_11_n_0,
      I5 => i2c_transfer_en_i_2_n_0,
      O => \i2c_stream_cnt[3]_i_4_n_0\
    );
\i2c_stream_cnt[3]_i_5\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFFFB8"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_9_n_0\,
      I1 => i2c_transfer_en,
      I2 => \i2c_stream_cnt[3]_i_10_n_0\,
      I3 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I4 => \FSM_onehot_current_state_reg_n_0_[6]\,
      O => \i2c_stream_cnt[3]_i_5_n_0\
    );
\i2c_stream_cnt[3]_i_6\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FEFFFEEE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[9]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I2 => p_0_in1_in,
      I3 => i2c_transfer_en,
      I4 => i2c_transfer_end,
      O => \i2c_stream_cnt[3]_i_6_n_0\
    );
\i2c_stream_cnt[3]_i_7\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0154"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_4_n_0\,
      I1 => \i2c_stream_cnt[3]_i_3_n_0\,
      I2 => \i2c_stream_cnt[3]_i_5_n_0\,
      I3 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => \i2c_stream_cnt[3]_i_7_n_0\
    );
\i2c_stream_cnt[3]_i_8\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFF00FFFEFF00"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[6]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[4]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[2]\,
      I3 => \i2c_stream_cnt[3]_i_11_n_0\,
      I4 => \FSM_onehot_current_state[9]_i_2_n_0\,
      I5 => \FSM_onehot_current_state_reg_n_0_[8]\,
      O => \i2c_stream_cnt[3]_i_8_n_0\
    );
\i2c_stream_cnt[3]_i_9\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => \FSM_onehot_current_state_reg_n_0_[9]\,
      I1 => \FSM_onehot_current_state_reg_n_0_[5]\,
      I2 => \FSM_onehot_current_state_reg_n_0_[1]\,
      O => \i2c_stream_cnt[3]_i_9_n_0\
    );
\i2c_stream_cnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_stream_cnt,
      D => \i2c_stream_cnt[0]_i_1_n_0\,
      Q => \i2c_stream_cnt_reg_n_0_[0]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_stream_cnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_stream_cnt,
      D => \i2c_stream_cnt[1]_i_1_n_0\,
      Q => \i2c_stream_cnt_reg_n_0_[1]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_stream_cnt_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_stream_cnt,
      D => \i2c_stream_cnt[2]_i_1_n_0\,
      Q => \i2c_stream_cnt_reg_n_0_[2]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_stream_cnt_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_stream_cnt,
      D => \i2c_stream_cnt[3]_i_2_n_0\,
      Q => \i2c_stream_cnt_reg_n_0_[3]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
i2c_transfer_en_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000020000"
    )
        port map (
      I0 => i2c_transfer_en_i_2_n_0,
      I1 => clk_cnt_reg(0),
      I2 => clk_cnt_reg(1),
      I3 => clk_cnt_reg(2),
      I4 => i2c_transfer_en_i_3_n_0,
      I5 => i2c_transfer_en_i_4_n_0,
      O => i2c_transfer_en7_out
    );
i2c_transfer_en_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000020000000000"
    )
        port map (
      I0 => i2c_transfer_en_i_5_n_0,
      I1 => delay_cnt_reg(0),
      I2 => delay_cnt_reg(2),
      I3 => delay_cnt_reg(13),
      I4 => i2c_transfer_en_i_6_n_0,
      I5 => \delay_cnt[0]_i_3_n_0\,
      O => i2c_transfer_en_i_2_n_0
    );
i2c_transfer_en_i_3: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000001"
    )
        port map (
      I0 => clk_cnt_reg(7),
      I1 => clk_cnt_reg(6),
      I2 => clk_cnt_reg(3),
      I3 => clk_cnt_reg(5),
      I4 => clk_cnt_reg(4),
      O => i2c_transfer_en_i_3_n_0
    );
i2c_transfer_en_i_4: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFFFFE"
    )
        port map (
      I0 => clk_cnt_reg(12),
      I1 => clk_cnt_reg(15),
      I2 => clk_cnt_reg(11),
      I3 => clk_cnt_reg(8),
      I4 => i2c_transfer_en_i_7_n_0,
      O => i2c_transfer_en_i_4_n_0
    );
i2c_transfer_en_i_5: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000800"
    )
        port map (
      I0 => delay_cnt_reg(7),
      I1 => delay_cnt_reg(8),
      I2 => delay_cnt_reg(6),
      I3 => delay_cnt_reg(5),
      I4 => delay_cnt_reg(15),
      I5 => delay_cnt_reg(16),
      O => i2c_transfer_en_i_5_n_0
    );
i2c_transfer_en_i_6: unisim.vcomponents.LUT4
    generic map(
      INIT => X"EFFF"
    )
        port map (
      I0 => delay_cnt_reg(1),
      I1 => delay_cnt_reg(4),
      I2 => delay_cnt_reg(14),
      I3 => delay_cnt_reg(3),
      O => i2c_transfer_en_i_6_n_0
    );
i2c_transfer_en_i_7: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => clk_cnt_reg(14),
      I1 => clk_cnt_reg(13),
      I2 => clk_cnt_reg(9),
      I3 => clk_cnt_reg(10),
      O => i2c_transfer_en_i_7_n_0
    );
i2c_transfer_en_reg: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => '1',
      D => i2c_transfer_en7_out,
      Q => i2c_transfer_en,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000F8C83808"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_36,
      I1 => \i2c_stream_cnt[3]_i_5_n_0\,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => data2(0),
      I4 => i2c_config_index_reg_rep_n_52,
      I5 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => \i2c_wdata[0]_i_1_n_0\
    );
\i2c_wdata[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000F8C83808"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_35,
      I1 => \i2c_stream_cnt[3]_i_5_n_0\,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => data2(1),
      I4 => i2c_config_index_reg_rep_n_51,
      I5 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => \i2c_wdata[1]_i_1_n_0\
    );
\i2c_wdata[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000F8C83808"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_34,
      I1 => \i2c_stream_cnt[3]_i_5_n_0\,
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => data2(2),
      I4 => i2c_config_index_reg_rep_n_50,
      I5 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => \i2c_wdata[2]_i_1_n_0\
    );
\i2c_wdata[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => \i2c_wdata[3]_i_2_n_0\,
      I1 => p_0_in1_in,
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \i2c_wdata[3]_i_1_n_0\
    );
\i2c_wdata[3]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_49,
      I1 => data2(3),
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_config_index_reg_rep_n_33,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      I5 => \i2c_stream_cnt[3]_i_4_n_0\,
      O => \i2c_wdata[3]_i_2_n_0\
    );
\i2c_wdata[4]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => \i2c_wdata[4]_i_2_n_0\,
      I1 => p_0_in1_in,
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \i2c_wdata[4]_i_1_n_0\
    );
\i2c_wdata[4]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_48,
      I1 => data2(4),
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_config_index_reg_rep_n_32,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      I5 => \i2c_stream_cnt[3]_i_4_n_0\,
      O => \i2c_wdata[4]_i_2_n_0\
    );
\i2c_wdata[5]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => \i2c_wdata[5]_i_2_n_0\,
      I1 => p_0_in1_in,
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \i2c_wdata[5]_i_1_n_0\
    );
\i2c_wdata[5]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_47,
      I1 => data2(5),
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_config_index_reg_rep_n_31,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      I5 => \i2c_stream_cnt[3]_i_4_n_0\,
      O => \i2c_wdata[5]_i_2_n_0\
    );
\i2c_wdata[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => \i2c_wdata[6]_i_2_n_0\,
      I1 => p_0_in1_in,
      I2 => \FSM_onehot_current_state_reg_n_0_[8]\,
      I3 => \FSM_onehot_current_state_reg_n_0_[9]\,
      O => \i2c_wdata[6]_i_1_n_0\
    );
\i2c_wdata[6]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_46,
      I1 => data2(6),
      I2 => \i2c_stream_cnt[3]_i_3_n_0\,
      I3 => i2c_config_index_reg_rep_n_30,
      I4 => \i2c_stream_cnt[3]_i_5_n_0\,
      I5 => \i2c_stream_cnt[3]_i_4_n_0\,
      O => \i2c_wdata[6]_i_2_n_0\
    );
\i2c_wdata[7]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"CC80888C"
    )
        port map (
      I0 => \i2c_stream_cnt[3]_i_4_n_0\,
      I1 => i2c_transfer_en,
      I2 => \i2c_stream_cnt[3]_i_5_n_0\,
      I3 => \i2c_stream_cnt[3]_i_3_n_0\,
      I4 => \i2c_stream_cnt[3]_i_6_n_0\,
      O => i2c_wdata
    );
\i2c_wdata[7]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00B80000"
    )
        port map (
      I0 => i2c_config_index_reg_rep_n_45,
      I1 => \i2c_stream_cnt[3]_i_5_n_0\,
      I2 => data2(7),
      I3 => \i2c_stream_cnt[3]_i_6_n_0\,
      I4 => \i2c_stream_cnt[3]_i_3_n_0\,
      O => \i2c_wdata[7]_i_2_n_0\
    );
\i2c_wdata_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[0]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[0]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[1]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[1]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[2]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[2]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[3]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[3]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[4]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[4]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[5]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[5]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[6]_i_1_n_0\,
      Q => \i2c_wdata_reg_n_0_[6]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
\i2c_wdata_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => clk,
      CE => i2c_wdata,
      D => \i2c_wdata[7]_i_2_n_0\,
      Q => \i2c_wdata_reg_n_0_[7]\,
      R => \FSM_onehot_current_state[10]_i_1_n_0\
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity OV5640IIC_0_OV5640IIC is
  port (
    cmos_scl : out STD_LOGIC;
    cmos_sda : inout STD_LOGIC;
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of OV5640IIC_0_OV5640IIC : entity is "OV5640IIC";
end OV5640IIC_0_OV5640IIC;

architecture STRUCTURE of OV5640IIC_0_OV5640IIC is
begin
u_i2c_timing_ctrl: entity work.OV5640IIC_0_i2c_timing_ctrl
     port map (
      clk => clk,
      cmos_scl => cmos_scl,
      cmos_sda => cmos_sda,
      rst_n => rst_n
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity OV5640IIC_0 is
  port (
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    cmos_scl : out STD_LOGIC;
    cmos_sda : inout STD_LOGIC
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of OV5640IIC_0 : entity is true;
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of OV5640IIC_0 : entity is "OV5640IIC_0,OV5640IIC,{}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of OV5640IIC_0 : entity is "yes";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of OV5640IIC_0 : entity is "OV5640IIC,Vivado 2017.4";
end OV5640IIC_0;

architecture STRUCTURE of OV5640IIC_0 is
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of clk : signal is "XIL_INTERFACENAME clk, FREQ_HZ 100000000, PHASE 0.000";
  attribute X_INTERFACE_INFO of rst_n : signal is "xilinx.com:signal:reset:1.0 rst_n RST";
  attribute X_INTERFACE_PARAMETER of rst_n : signal is "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW";
begin
inst: entity work.OV5640IIC_0_OV5640IIC
     port map (
      clk => clk,
      cmos_scl => cmos_scl,
      cmos_sda => cmos_sda,
      rst_n => rst_n
    );
end STRUCTURE;

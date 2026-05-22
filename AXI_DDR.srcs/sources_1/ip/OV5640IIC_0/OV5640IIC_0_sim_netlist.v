// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
// Date        : Fri Mar 29 11:10:03 2019
// Host        : 123tjy running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               f:/MA703/A703_100T/07/AXI_DDR_5640/AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0_sim_netlist.v
// Design      : OV5640IIC_0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a100tfgg484-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "OV5640IIC_0,OV5640IIC,{}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) (* X_CORE_INFO = "OV5640IIC,Vivado 2017.4" *) 
(* NotValidForBitStream *)
module OV5640IIC_0
   (clk,
    rst_n,
    cmos_scl,
    cmos_sda);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, FREQ_HZ 100000000, PHASE 0.000" *) input clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *) input rst_n;
  output cmos_scl;
  inout cmos_sda;

  wire clk;
  wire cmos_scl;
  wire cmos_sda;
  wire rst_n;

  OV5640IIC_0_OV5640IIC inst
       (.clk(clk),
        .cmos_scl(cmos_scl),
        .cmos_sda(cmos_sda),
        .rst_n(rst_n));
endmodule

(* ORIG_REF_NAME = "OV5640IIC" *) 
module OV5640IIC_0_OV5640IIC
   (cmos_scl,
    cmos_sda,
    clk,
    rst_n);
  output cmos_scl;
  inout cmos_sda;
  input clk;
  input rst_n;

  wire clk;
  wire cmos_scl;
  wire cmos_sda;
  wire rst_n;

  OV5640IIC_0_i2c_timing_ctrl u_i2c_timing_ctrl
       (.clk(clk),
        .cmos_scl(cmos_scl),
        .cmos_sda(cmos_sda),
        .rst_n(rst_n));
endmodule

(* ORIG_REF_NAME = "i2c_timing_ctrl" *) 
module OV5640IIC_0_i2c_timing_ctrl
   (cmos_scl,
    cmos_sda,
    clk,
    rst_n);
  output cmos_scl;
  inout cmos_sda;
  input clk;
  input rst_n;

  wire \/i__n_0 ;
  wire \FSM_onehot_current_state[0]_i_1_n_0 ;
  wire \FSM_onehot_current_state[0]_i_2_n_0 ;
  wire \FSM_onehot_current_state[0]_i_3_n_0 ;
  wire \FSM_onehot_current_state[10]_i_1_n_0 ;
  wire \FSM_onehot_current_state[10]_i_2_n_0 ;
  wire \FSM_onehot_current_state[10]_i_3_n_0 ;
  wire \FSM_onehot_current_state[1]_i_1_n_0 ;
  wire \FSM_onehot_current_state[1]_i_2_n_0 ;
  wire \FSM_onehot_current_state[2]_i_1_n_0 ;
  wire \FSM_onehot_current_state[3]_i_1_n_0 ;
  wire \FSM_onehot_current_state[4]_i_1_n_0 ;
  wire \FSM_onehot_current_state[5]_i_1_n_0 ;
  wire \FSM_onehot_current_state[6]_i_1_n_0 ;
  wire \FSM_onehot_current_state[7]_i_1_n_0 ;
  wire \FSM_onehot_current_state[7]_i_2_n_0 ;
  wire \FSM_onehot_current_state[8]_i_1_n_0 ;
  wire \FSM_onehot_current_state[8]_i_2_n_0 ;
  wire \FSM_onehot_current_state[8]_i_3_n_0 ;
  wire \FSM_onehot_current_state[9]_i_1_n_0 ;
  wire \FSM_onehot_current_state[9]_i_2_n_0 ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[0] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[1] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[2] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[3] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[4] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[5] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[6] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[8] ;
  (* RTL_KEEP = "yes" *) wire \FSM_onehot_current_state_reg_n_0_[9] ;
  wire \RESETn_reg[0]__0_n_0 ;
  wire \RESETn_reg[3]_srl3_n_0 ;
  wire clk;
  wire \clk_cnt[0]_i_1_n_0 ;
  wire \clk_cnt[0]_i_3_n_0 ;
  wire \clk_cnt[0]_i_4_n_0 ;
  wire [15:0]clk_cnt_reg;
  wire \clk_cnt_reg[0]_i_2_n_0 ;
  wire \clk_cnt_reg[0]_i_2_n_1 ;
  wire \clk_cnt_reg[0]_i_2_n_2 ;
  wire \clk_cnt_reg[0]_i_2_n_3 ;
  wire \clk_cnt_reg[0]_i_2_n_4 ;
  wire \clk_cnt_reg[0]_i_2_n_5 ;
  wire \clk_cnt_reg[0]_i_2_n_6 ;
  wire \clk_cnt_reg[0]_i_2_n_7 ;
  wire \clk_cnt_reg[12]_i_1_n_1 ;
  wire \clk_cnt_reg[12]_i_1_n_2 ;
  wire \clk_cnt_reg[12]_i_1_n_3 ;
  wire \clk_cnt_reg[12]_i_1_n_4 ;
  wire \clk_cnt_reg[12]_i_1_n_5 ;
  wire \clk_cnt_reg[12]_i_1_n_6 ;
  wire \clk_cnt_reg[12]_i_1_n_7 ;
  wire \clk_cnt_reg[4]_i_1_n_0 ;
  wire \clk_cnt_reg[4]_i_1_n_1 ;
  wire \clk_cnt_reg[4]_i_1_n_2 ;
  wire \clk_cnt_reg[4]_i_1_n_3 ;
  wire \clk_cnt_reg[4]_i_1_n_4 ;
  wire \clk_cnt_reg[4]_i_1_n_5 ;
  wire \clk_cnt_reg[4]_i_1_n_6 ;
  wire \clk_cnt_reg[4]_i_1_n_7 ;
  wire \clk_cnt_reg[8]_i_1_n_0 ;
  wire \clk_cnt_reg[8]_i_1_n_1 ;
  wire \clk_cnt_reg[8]_i_1_n_2 ;
  wire \clk_cnt_reg[8]_i_1_n_3 ;
  wire \clk_cnt_reg[8]_i_1_n_4 ;
  wire \clk_cnt_reg[8]_i_1_n_5 ;
  wire \clk_cnt_reg[8]_i_1_n_6 ;
  wire \clk_cnt_reg[8]_i_1_n_7 ;
  wire cmos_scl;
  wire cmos_sda;
  wire [2:1]current_state_reg;
  wire [7:0]data2;
  wire \delay_cnt[0]_i_3_n_0 ;
  wire \delay_cnt[0]_i_4_n_0 ;
  wire \delay_cnt[0]_i_5_n_0 ;
  wire [16:0]delay_cnt_reg;
  wire \delay_cnt_reg[0]_i_2_n_0 ;
  wire \delay_cnt_reg[0]_i_2_n_1 ;
  wire \delay_cnt_reg[0]_i_2_n_2 ;
  wire \delay_cnt_reg[0]_i_2_n_3 ;
  wire \delay_cnt_reg[0]_i_2_n_4 ;
  wire \delay_cnt_reg[0]_i_2_n_5 ;
  wire \delay_cnt_reg[0]_i_2_n_6 ;
  wire \delay_cnt_reg[0]_i_2_n_7 ;
  wire \delay_cnt_reg[12]_i_1_n_0 ;
  wire \delay_cnt_reg[12]_i_1_n_1 ;
  wire \delay_cnt_reg[12]_i_1_n_2 ;
  wire \delay_cnt_reg[12]_i_1_n_3 ;
  wire \delay_cnt_reg[12]_i_1_n_4 ;
  wire \delay_cnt_reg[12]_i_1_n_5 ;
  wire \delay_cnt_reg[12]_i_1_n_6 ;
  wire \delay_cnt_reg[12]_i_1_n_7 ;
  wire \delay_cnt_reg[16]_i_1_n_7 ;
  wire \delay_cnt_reg[4]_i_1_n_0 ;
  wire \delay_cnt_reg[4]_i_1_n_1 ;
  wire \delay_cnt_reg[4]_i_1_n_2 ;
  wire \delay_cnt_reg[4]_i_1_n_3 ;
  wire \delay_cnt_reg[4]_i_1_n_4 ;
  wire \delay_cnt_reg[4]_i_1_n_5 ;
  wire \delay_cnt_reg[4]_i_1_n_6 ;
  wire \delay_cnt_reg[4]_i_1_n_7 ;
  wire \delay_cnt_reg[8]_i_1_n_0 ;
  wire \delay_cnt_reg[8]_i_1_n_1 ;
  wire \delay_cnt_reg[8]_i_1_n_2 ;
  wire \delay_cnt_reg[8]_i_1_n_3 ;
  wire \delay_cnt_reg[8]_i_1_n_4 ;
  wire \delay_cnt_reg[8]_i_1_n_5 ;
  wire \delay_cnt_reg[8]_i_1_n_6 ;
  wire \delay_cnt_reg[8]_i_1_n_7 ;
  wire i2c_ack;
  wire i2c_ack1;
  wire i2c_ack10_out;
  wire i2c_ack1_i_1_n_0;
  wire i2c_ack2;
  wire i2c_ack24_out;
  wire i2c_ack2_i_1_n_0;
  wire i2c_ack2_i_2_n_0;
  wire i2c_ack2a;
  wire i2c_ack2a1_out;
  wire i2c_ack2a_i_1_n_0;
  wire i2c_ack3;
  wire i2c_ack3_i_1_n_0;
  wire i2c_ack3_i_2_n_0;
  wire i2c_ack_i_1_n_0;
  wire i2c_ack_i_2_n_0;
  wire i2c_ack_i_3_n_0;
  wire i2c_capture_en;
  wire i2c_capture_en6_out;
  wire i2c_capture_en_i_2_n_0;
  wire i2c_capture_en_i_3_n_0;
  wire \i2c_config_index[0]_i_1_n_0 ;
  wire \i2c_config_index[1]_i_1_n_0 ;
  wire \i2c_config_index[2]_i_1_n_0 ;
  wire \i2c_config_index[3]_i_1_n_0 ;
  wire \i2c_config_index[4]_i_1_n_0 ;
  wire \i2c_config_index[5]_i_1_n_0 ;
  wire \i2c_config_index[6]_i_1_n_0 ;
  wire \i2c_config_index[7]_i_1_n_0 ;
  wire \i2c_config_index[7]_i_2_n_0 ;
  wire [7:0]i2c_config_index_reg__0;
  wire i2c_config_index_reg_rep_i_10_n_0;
  wire i2c_config_index_reg_rep_i_11_n_0;
  wire i2c_config_index_reg_rep_i_12_n_0;
  wire i2c_config_index_reg_rep_i_13_n_0;
  wire i2c_config_index_reg_rep_i_14_n_0;
  wire i2c_config_index_reg_rep_i_1_n_0;
  wire i2c_config_index_reg_rep_i_2_n_0;
  wire i2c_config_index_reg_rep_i_3_n_0;
  wire i2c_config_index_reg_rep_i_4_n_0;
  wire i2c_config_index_reg_rep_i_5_n_0;
  wire i2c_config_index_reg_rep_i_6_n_0;
  wire i2c_config_index_reg_rep_i_7_n_0;
  wire i2c_config_index_reg_rep_i_8_n_0;
  wire i2c_config_index_reg_rep_i_9_n_0;
  wire i2c_config_index_reg_rep_n_30;
  wire i2c_config_index_reg_rep_n_31;
  wire i2c_config_index_reg_rep_n_32;
  wire i2c_config_index_reg_rep_n_33;
  wire i2c_config_index_reg_rep_n_34;
  wire i2c_config_index_reg_rep_n_35;
  wire i2c_config_index_reg_rep_n_36;
  wire i2c_config_index_reg_rep_n_45;
  wire i2c_config_index_reg_rep_n_46;
  wire i2c_config_index_reg_rep_n_47;
  wire i2c_config_index_reg_rep_n_48;
  wire i2c_config_index_reg_rep_n_49;
  wire i2c_config_index_reg_rep_n_50;
  wire i2c_config_index_reg_rep_n_51;
  wire i2c_config_index_reg_rep_n_52;
  wire i2c_ctrl_clk;
  wire i2c_ctrl_clk_i_1_n_0;
  wire i2c_ctrl_clk_i_2_n_0;
  wire i2c_sdat_out;
  wire i2c_sdat_out_i_1_n_0;
  wire i2c_sdat_out_i_2_n_0;
  wire i2c_sdat_out_i_3_n_0;
  wire i2c_sdat_out_i_5_n_0;
  wire i2c_sdat_out_i_6_n_0;
  wire i2c_sdat_out_reg_i_4_n_0;
  wire i2c_stream_cnt;
  wire \i2c_stream_cnt[0]_i_1_n_0 ;
  wire \i2c_stream_cnt[1]_i_1_n_0 ;
  wire \i2c_stream_cnt[2]_i_1_n_0 ;
  wire \i2c_stream_cnt[3]_i_10_n_0 ;
  wire \i2c_stream_cnt[3]_i_11_n_0 ;
  wire \i2c_stream_cnt[3]_i_2_n_0 ;
  wire \i2c_stream_cnt[3]_i_3_n_0 ;
  wire \i2c_stream_cnt[3]_i_4_n_0 ;
  wire \i2c_stream_cnt[3]_i_5_n_0 ;
  wire \i2c_stream_cnt[3]_i_6_n_0 ;
  wire \i2c_stream_cnt[3]_i_7_n_0 ;
  wire \i2c_stream_cnt[3]_i_8_n_0 ;
  wire \i2c_stream_cnt[3]_i_9_n_0 ;
  wire \i2c_stream_cnt_reg_n_0_[0] ;
  wire \i2c_stream_cnt_reg_n_0_[1] ;
  wire \i2c_stream_cnt_reg_n_0_[2] ;
  wire \i2c_stream_cnt_reg_n_0_[3] ;
  wire i2c_transfer_en;
  wire i2c_transfer_en7_out;
  wire i2c_transfer_en_i_2_n_0;
  wire i2c_transfer_en_i_3_n_0;
  wire i2c_transfer_en_i_4_n_0;
  wire i2c_transfer_en_i_5_n_0;
  wire i2c_transfer_en_i_6_n_0;
  wire i2c_transfer_en_i_7_n_0;
  (* RTL_KEEP = "yes" *) wire i2c_transfer_end;
  wire i2c_wdata;
  wire \i2c_wdata[0]_i_1_n_0 ;
  wire \i2c_wdata[1]_i_1_n_0 ;
  wire \i2c_wdata[2]_i_1_n_0 ;
  wire \i2c_wdata[3]_i_1_n_0 ;
  wire \i2c_wdata[3]_i_2_n_0 ;
  wire \i2c_wdata[4]_i_1_n_0 ;
  wire \i2c_wdata[4]_i_2_n_0 ;
  wire \i2c_wdata[5]_i_1_n_0 ;
  wire \i2c_wdata[5]_i_2_n_0 ;
  wire \i2c_wdata[6]_i_1_n_0 ;
  wire \i2c_wdata[6]_i_2_n_0 ;
  wire \i2c_wdata[7]_i_2_n_0 ;
  wire \i2c_wdata_reg_n_0_[0] ;
  wire \i2c_wdata_reg_n_0_[1] ;
  wire \i2c_wdata_reg_n_0_[2] ;
  wire \i2c_wdata_reg_n_0_[3] ;
  wire \i2c_wdata_reg_n_0_[4] ;
  wire \i2c_wdata_reg_n_0_[5] ;
  wire \i2c_wdata_reg_n_0_[6] ;
  wire \i2c_wdata_reg_n_0_[7] ;
  wire p_0_in;
  (* RTL_KEEP = "yes" *) wire p_0_in1_in;
  wire rst_n;
  wire sel;
  wire [3:3]\NLW_clk_cnt_reg[12]_i_1_CO_UNCONNECTED ;
  wire [3:0]\NLW_delay_cnt_reg[16]_i_1_CO_UNCONNECTED ;
  wire [3:1]\NLW_delay_cnt_reg[16]_i_1_O_UNCONNECTED ;
  wire NLW_i2c_config_index_reg_rep_CASCADEOUTA_UNCONNECTED;
  wire NLW_i2c_config_index_reg_rep_CASCADEOUTB_UNCONNECTED;
  wire NLW_i2c_config_index_reg_rep_DBITERR_UNCONNECTED;
  wire NLW_i2c_config_index_reg_rep_INJECTDBITERR_UNCONNECTED;
  wire NLW_i2c_config_index_reg_rep_INJECTSBITERR_UNCONNECTED;
  wire NLW_i2c_config_index_reg_rep_SBITERR_UNCONNECTED;
  wire [31:23]NLW_i2c_config_index_reg_rep_DOADO_UNCONNECTED;
  wire [31:0]NLW_i2c_config_index_reg_rep_DOBDO_UNCONNECTED;
  wire [3:0]NLW_i2c_config_index_reg_rep_DOPADOP_UNCONNECTED;
  wire [3:0]NLW_i2c_config_index_reg_rep_DOPBDOP_UNCONNECTED;
  wire [7:0]NLW_i2c_config_index_reg_rep_ECCPARITY_UNCONNECTED;
  wire [8:0]NLW_i2c_config_index_reg_rep_RDADDRECC_UNCONNECTED;

  LUT4 #(
    .INIT(16'h0001)) 
    \/i_ 
       (.I0(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I1(p_0_in1_in),
        .I2(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\/i__n_0 ));
  LUT6 #(
    .INIT(64'h000022220000222F)) 
    \FSM_onehot_current_state[0]_i_1 
       (.I0(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I1(\FSM_onehot_current_state[1]_i_2_n_0 ),
        .I2(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .I3(\FSM_onehot_current_state[0]_i_2_n_0 ),
        .I4(\FSM_onehot_current_state[0]_i_3_n_0 ),
        .I5(current_state_reg[2]),
        .O(\FSM_onehot_current_state[0]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'hE)) 
    \FSM_onehot_current_state[0]_i_2 
       (.I0(\FSM_onehot_current_state_reg_n_0_[9] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[8] ),
        .O(\FSM_onehot_current_state[0]_i_2_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \FSM_onehot_current_state[0]_i_3 
       (.I0(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I1(i2c_transfer_end),
        .I2(i2c_transfer_en),
        .O(\FSM_onehot_current_state[0]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \FSM_onehot_current_state[10]_i_1 
       (.I0(p_0_in),
        .O(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h20)) 
    \FSM_onehot_current_state[10]_i_2 
       (.I0(\FSM_onehot_current_state[10]_i_3_n_0 ),
        .I1(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\FSM_onehot_current_state[10]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h00000001)) 
    \FSM_onehot_current_state[10]_i_3 
       (.I0(p_0_in1_in),
        .I1(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I4(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .O(\FSM_onehot_current_state[10]_i_3_n_0 ));
  LUT2 #(
    .INIT(4'h8)) 
    \FSM_onehot_current_state[1]_i_1 
       (.I0(\FSM_onehot_current_state[1]_i_2_n_0 ),
        .I1(\FSM_onehot_current_state_reg_n_0_[0] ),
        .O(\FSM_onehot_current_state[1]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h08)) 
    \FSM_onehot_current_state[1]_i_2 
       (.I0(i2c_transfer_en_i_2_n_0),
        .I1(i2c_transfer_en),
        .I2(i2c_config_index_reg_rep_i_11_n_0),
        .O(\FSM_onehot_current_state[1]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'h4454)) 
    \FSM_onehot_current_state[2]_i_1 
       (.I0(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[1] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I3(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .O(\FSM_onehot_current_state[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'h0200)) 
    \FSM_onehot_current_state[3]_i_1 
       (.I0(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I1(\FSM_onehot_current_state_reg_n_0_[1] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[2] ),
        .O(\FSM_onehot_current_state[3]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0100010001010100)) 
    \FSM_onehot_current_state[4]_i_1 
       (.I0(\FSM_onehot_current_state_reg_n_0_[1] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I4(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I5(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .O(\FSM_onehot_current_state[4]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h20)) 
    \FSM_onehot_current_state[5]_i_1 
       (.I0(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I1(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .I2(\FSM_onehot_current_state_reg_n_0_[4] ),
        .O(\FSM_onehot_current_state[5]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h10111010)) 
    \FSM_onehot_current_state[6]_i_1 
       (.I0(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I1(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .I2(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I3(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I4(\FSM_onehot_current_state_reg_n_0_[6] ),
        .O(\FSM_onehot_current_state[6]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000002200000030)) 
    \FSM_onehot_current_state[7]_i_1 
       (.I0(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I1(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .I2(\FSM_onehot_current_state[7]_i_2_n_0 ),
        .I3(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I4(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I5(\FSM_onehot_current_state_reg_n_0_[6] ),
        .O(\FSM_onehot_current_state[7]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    \FSM_onehot_current_state[7]_i_2 
       (.I0(p_0_in1_in),
        .I1(i2c_transfer_en),
        .O(\FSM_onehot_current_state[7]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h02020302)) 
    \FSM_onehot_current_state[8]_i_1 
       (.I0(p_0_in1_in),
        .I1(\FSM_onehot_current_state[8]_i_2_n_0 ),
        .I2(\FSM_onehot_current_state[8]_i_3_n_0 ),
        .I3(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I4(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .O(\FSM_onehot_current_state[8]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'hFE)) 
    \FSM_onehot_current_state[8]_i_2 
       (.I0(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[5] ),
        .O(\FSM_onehot_current_state[8]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'hFFFE)) 
    \FSM_onehot_current_state[8]_i_3 
       (.I0(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[1] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[3] ),
        .O(\FSM_onehot_current_state[8]_i_3_n_0 ));
  LUT3 #(
    .INIT(8'h80)) 
    \FSM_onehot_current_state[9]_i_1 
       (.I0(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I1(\FSM_onehot_current_state[10]_i_3_n_0 ),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .O(\FSM_onehot_current_state[9]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h00100000)) 
    \FSM_onehot_current_state[9]_i_2 
       (.I0(\i2c_stream_cnt_reg_n_0_[1] ),
        .I1(\i2c_stream_cnt_reg_n_0_[0] ),
        .I2(i2c_transfer_en),
        .I3(\i2c_stream_cnt_reg_n_0_[2] ),
        .I4(\i2c_stream_cnt_reg_n_0_[3] ),
        .O(\FSM_onehot_current_state[9]_i_2_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDSE #(
    .INIT(1'b1)) 
    \FSM_onehot_current_state_reg[0] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[0]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[0] ),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[10] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[10]_i_2_n_0 ),
        .Q(i2c_transfer_end),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[1] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[1]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[1] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[2] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[2]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[2] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[3] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[3]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[3] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[4] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[4]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[4] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[5] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[5]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[5] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[6] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[6]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[6] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[7] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[7]_i_1_n_0 ),
        .Q(p_0_in1_in),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[8] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[8]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[8] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* FSM_ENCODED_STATES = "I2C_IDLE:00000000001,I2C_WR_START:00000000010,I2C_WR_IDADDR:00000000100,I2C_WR_ACK1:00000001000,I2C_WR_REGADDR:00000010000,I2C_WR_ACK2:00000100000,I2C_WR_REGADDR2:00001000000,I2C_WR_ACK2A:00010000000,I2C_WR_REGDATA:00100000000,I2C_WR_ACK3:01000000000,I2C_WR_STOP:10000000000" *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \FSM_onehot_current_state_reg[9] 
       (.C(clk),
        .CE(i2c_transfer_en),
        .D(\FSM_onehot_current_state[9]_i_1_n_0 ),
        .Q(\FSM_onehot_current_state_reg_n_0_[9] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b1)) 
    \RESETn_reg[0]__0 
       (.C(clk),
        .CE(1'b1),
        .D(rst_n),
        .Q(\RESETn_reg[0]__0_n_0 ),
        .R(1'b0));
  (* srl_bus_name = "\inst/u_i2c_timing_ctrl/RESETn_reg " *) 
  (* srl_name = "\inst/u_i2c_timing_ctrl/RESETn_reg[3]_srl3 " *) 
  SRL16E #(
    .INIT(16'h0007)) 
    \RESETn_reg[3]_srl3 
       (.A0(1'b0),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(clk),
        .D(\RESETn_reg[0]__0_n_0 ),
        .Q(\RESETn_reg[3]_srl3_n_0 ));
  FDRE #(
    .INIT(1'b1)) 
    \RESETn_reg[4]__0 
       (.C(clk),
        .CE(1'b1),
        .D(\RESETn_reg[3]_srl3_n_0 ),
        .Q(p_0_in),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hF8F0FFFFFFFFFFFF)) 
    \clk_cnt[0]_i_1 
       (.I0(clk_cnt_reg[7]),
        .I1(clk_cnt_reg[6]),
        .I2(i2c_transfer_en_i_4_n_0),
        .I3(\clk_cnt[0]_i_3_n_0 ),
        .I4(i2c_transfer_en_i_2_n_0),
        .I5(p_0_in),
        .O(\clk_cnt[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFE00000000000000)) 
    \clk_cnt[0]_i_3 
       (.I0(clk_cnt_reg[0]),
        .I1(clk_cnt_reg[1]),
        .I2(clk_cnt_reg[2]),
        .I3(clk_cnt_reg[4]),
        .I4(clk_cnt_reg[3]),
        .I5(clk_cnt_reg[5]),
        .O(\clk_cnt[0]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \clk_cnt[0]_i_4 
       (.I0(clk_cnt_reg[0]),
        .O(\clk_cnt[0]_i_4_n_0 ));
  FDRE \clk_cnt_reg[0] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[0]_i_2_n_7 ),
        .Q(clk_cnt_reg[0]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  CARRY4 \clk_cnt_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\clk_cnt_reg[0]_i_2_n_0 ,\clk_cnt_reg[0]_i_2_n_1 ,\clk_cnt_reg[0]_i_2_n_2 ,\clk_cnt_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\clk_cnt_reg[0]_i_2_n_4 ,\clk_cnt_reg[0]_i_2_n_5 ,\clk_cnt_reg[0]_i_2_n_6 ,\clk_cnt_reg[0]_i_2_n_7 }),
        .S({clk_cnt_reg[3:1],\clk_cnt[0]_i_4_n_0 }));
  FDRE \clk_cnt_reg[10] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[8]_i_1_n_5 ),
        .Q(clk_cnt_reg[10]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[11] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[8]_i_1_n_4 ),
        .Q(clk_cnt_reg[11]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[12] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[12]_i_1_n_7 ),
        .Q(clk_cnt_reg[12]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  CARRY4 \clk_cnt_reg[12]_i_1 
       (.CI(\clk_cnt_reg[8]_i_1_n_0 ),
        .CO({\NLW_clk_cnt_reg[12]_i_1_CO_UNCONNECTED [3],\clk_cnt_reg[12]_i_1_n_1 ,\clk_cnt_reg[12]_i_1_n_2 ,\clk_cnt_reg[12]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\clk_cnt_reg[12]_i_1_n_4 ,\clk_cnt_reg[12]_i_1_n_5 ,\clk_cnt_reg[12]_i_1_n_6 ,\clk_cnt_reg[12]_i_1_n_7 }),
        .S(clk_cnt_reg[15:12]));
  FDRE \clk_cnt_reg[13] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[12]_i_1_n_6 ),
        .Q(clk_cnt_reg[13]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[14] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[12]_i_1_n_5 ),
        .Q(clk_cnt_reg[14]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[15] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[12]_i_1_n_4 ),
        .Q(clk_cnt_reg[15]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[1] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[0]_i_2_n_6 ),
        .Q(clk_cnt_reg[1]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[2] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[0]_i_2_n_5 ),
        .Q(clk_cnt_reg[2]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[3] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[0]_i_2_n_4 ),
        .Q(clk_cnt_reg[3]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[4] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[4]_i_1_n_7 ),
        .Q(clk_cnt_reg[4]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  CARRY4 \clk_cnt_reg[4]_i_1 
       (.CI(\clk_cnt_reg[0]_i_2_n_0 ),
        .CO({\clk_cnt_reg[4]_i_1_n_0 ,\clk_cnt_reg[4]_i_1_n_1 ,\clk_cnt_reg[4]_i_1_n_2 ,\clk_cnt_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\clk_cnt_reg[4]_i_1_n_4 ,\clk_cnt_reg[4]_i_1_n_5 ,\clk_cnt_reg[4]_i_1_n_6 ,\clk_cnt_reg[4]_i_1_n_7 }),
        .S(clk_cnt_reg[7:4]));
  FDRE \clk_cnt_reg[5] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[4]_i_1_n_6 ),
        .Q(clk_cnt_reg[5]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[6] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[4]_i_1_n_5 ),
        .Q(clk_cnt_reg[6]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[7] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[4]_i_1_n_4 ),
        .Q(clk_cnt_reg[7]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  FDRE \clk_cnt_reg[8] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[8]_i_1_n_7 ),
        .Q(clk_cnt_reg[8]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  CARRY4 \clk_cnt_reg[8]_i_1 
       (.CI(\clk_cnt_reg[4]_i_1_n_0 ),
        .CO({\clk_cnt_reg[8]_i_1_n_0 ,\clk_cnt_reg[8]_i_1_n_1 ,\clk_cnt_reg[8]_i_1_n_2 ,\clk_cnt_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\clk_cnt_reg[8]_i_1_n_4 ,\clk_cnt_reg[8]_i_1_n_5 ,\clk_cnt_reg[8]_i_1_n_6 ,\clk_cnt_reg[8]_i_1_n_7 }),
        .S(clk_cnt_reg[11:8]));
  FDRE \clk_cnt_reg[9] 
       (.C(clk),
        .CE(1'b1),
        .D(\clk_cnt_reg[8]_i_1_n_6 ),
        .Q(clk_cnt_reg[9]),
        .R(\clk_cnt[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFFFAEEEEEEEB)) 
    cmos_scl_INST_0
       (.I0(i2c_ctrl_clk),
        .I1(current_state_reg[1]),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .I4(i2c_transfer_end),
        .I5(current_state_reg[2]),
        .O(cmos_scl));
  LUT5 #(
    .INIT(32'hFFFFFFFE)) 
    cmos_scl_INST_0_i_1
       (.I0(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I2(i2c_transfer_end),
        .I3(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I4(p_0_in1_in),
        .O(current_state_reg[1]));
  LUT4 #(
    .INIT(16'hFFFE)) 
    cmos_scl_INST_0_i_2
       (.I0(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I3(p_0_in1_in),
        .O(current_state_reg[2]));
  LUT2 #(
    .INIT(4'h8)) 
    cmos_sda_INST_0
       (.I0(i2c_sdat_out),
        .I1(\/i__n_0 ),
        .O(cmos_sda));
  LUT6 #(
    .INIT(64'h00000000000077F7)) 
    \delay_cnt[0]_i_1 
       (.I0(delay_cnt_reg[13]),
        .I1(delay_cnt_reg[14]),
        .I2(\delay_cnt[0]_i_3_n_0 ),
        .I3(\delay_cnt[0]_i_4_n_0 ),
        .I4(delay_cnt_reg[16]),
        .I5(delay_cnt_reg[15]),
        .O(sel));
  LUT4 #(
    .INIT(16'h0001)) 
    \delay_cnt[0]_i_3 
       (.I0(delay_cnt_reg[10]),
        .I1(delay_cnt_reg[9]),
        .I2(delay_cnt_reg[12]),
        .I3(delay_cnt_reg[11]),
        .O(\delay_cnt[0]_i_3_n_0 ));
  LUT6 #(
    .INIT(64'h8888888080808080)) 
    \delay_cnt[0]_i_4 
       (.I0(delay_cnt_reg[7]),
        .I1(delay_cnt_reg[8]),
        .I2(delay_cnt_reg[6]),
        .I3(delay_cnt_reg[4]),
        .I4(delay_cnt_reg[3]),
        .I5(delay_cnt_reg[5]),
        .O(\delay_cnt[0]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \delay_cnt[0]_i_5 
       (.I0(delay_cnt_reg[0]),
        .O(\delay_cnt[0]_i_5_n_0 ));
  FDRE \delay_cnt_reg[0] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[0]_i_2_n_7 ),
        .Q(delay_cnt_reg[0]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  CARRY4 \delay_cnt_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\delay_cnt_reg[0]_i_2_n_0 ,\delay_cnt_reg[0]_i_2_n_1 ,\delay_cnt_reg[0]_i_2_n_2 ,\delay_cnt_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\delay_cnt_reg[0]_i_2_n_4 ,\delay_cnt_reg[0]_i_2_n_5 ,\delay_cnt_reg[0]_i_2_n_6 ,\delay_cnt_reg[0]_i_2_n_7 }),
        .S({delay_cnt_reg[3:1],\delay_cnt[0]_i_5_n_0 }));
  FDRE \delay_cnt_reg[10] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[8]_i_1_n_5 ),
        .Q(delay_cnt_reg[10]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[11] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[8]_i_1_n_4 ),
        .Q(delay_cnt_reg[11]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[12] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[12]_i_1_n_7 ),
        .Q(delay_cnt_reg[12]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  CARRY4 \delay_cnt_reg[12]_i_1 
       (.CI(\delay_cnt_reg[8]_i_1_n_0 ),
        .CO({\delay_cnt_reg[12]_i_1_n_0 ,\delay_cnt_reg[12]_i_1_n_1 ,\delay_cnt_reg[12]_i_1_n_2 ,\delay_cnt_reg[12]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\delay_cnt_reg[12]_i_1_n_4 ,\delay_cnt_reg[12]_i_1_n_5 ,\delay_cnt_reg[12]_i_1_n_6 ,\delay_cnt_reg[12]_i_1_n_7 }),
        .S(delay_cnt_reg[15:12]));
  FDRE \delay_cnt_reg[13] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[12]_i_1_n_6 ),
        .Q(delay_cnt_reg[13]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[14] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[12]_i_1_n_5 ),
        .Q(delay_cnt_reg[14]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[15] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[12]_i_1_n_4 ),
        .Q(delay_cnt_reg[15]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[16] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[16]_i_1_n_7 ),
        .Q(delay_cnt_reg[16]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  CARRY4 \delay_cnt_reg[16]_i_1 
       (.CI(\delay_cnt_reg[12]_i_1_n_0 ),
        .CO(\NLW_delay_cnt_reg[16]_i_1_CO_UNCONNECTED [3:0]),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_delay_cnt_reg[16]_i_1_O_UNCONNECTED [3:1],\delay_cnt_reg[16]_i_1_n_7 }),
        .S({1'b0,1'b0,1'b0,delay_cnt_reg[16]}));
  FDRE \delay_cnt_reg[1] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[0]_i_2_n_6 ),
        .Q(delay_cnt_reg[1]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[2] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[0]_i_2_n_5 ),
        .Q(delay_cnt_reg[2]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[3] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[0]_i_2_n_4 ),
        .Q(delay_cnt_reg[3]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[4] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[4]_i_1_n_7 ),
        .Q(delay_cnt_reg[4]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  CARRY4 \delay_cnt_reg[4]_i_1 
       (.CI(\delay_cnt_reg[0]_i_2_n_0 ),
        .CO({\delay_cnt_reg[4]_i_1_n_0 ,\delay_cnt_reg[4]_i_1_n_1 ,\delay_cnt_reg[4]_i_1_n_2 ,\delay_cnt_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\delay_cnt_reg[4]_i_1_n_4 ,\delay_cnt_reg[4]_i_1_n_5 ,\delay_cnt_reg[4]_i_1_n_6 ,\delay_cnt_reg[4]_i_1_n_7 }),
        .S(delay_cnt_reg[7:4]));
  FDRE \delay_cnt_reg[5] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[4]_i_1_n_6 ),
        .Q(delay_cnt_reg[5]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[6] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[4]_i_1_n_5 ),
        .Q(delay_cnt_reg[6]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[7] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[4]_i_1_n_4 ),
        .Q(delay_cnt_reg[7]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \delay_cnt_reg[8] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[8]_i_1_n_7 ),
        .Q(delay_cnt_reg[8]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  CARRY4 \delay_cnt_reg[8]_i_1 
       (.CI(\delay_cnt_reg[4]_i_1_n_0 ),
        .CO({\delay_cnt_reg[8]_i_1_n_0 ,\delay_cnt_reg[8]_i_1_n_1 ,\delay_cnt_reg[8]_i_1_n_2 ,\delay_cnt_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\delay_cnt_reg[8]_i_1_n_4 ,\delay_cnt_reg[8]_i_1_n_5 ,\delay_cnt_reg[8]_i_1_n_6 ,\delay_cnt_reg[8]_i_1_n_7 }),
        .S(delay_cnt_reg[11:8]));
  FDRE \delay_cnt_reg[9] 
       (.C(clk),
        .CE(sel),
        .D(\delay_cnt_reg[8]_i_1_n_6 ),
        .Q(delay_cnt_reg[9]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    i2c_ack1_i_1
       (.I0(i2c_ack2_i_2_n_0),
        .I1(i2c_ack10_out),
        .I2(i2c_ack1),
        .O(i2c_ack1_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT5 #(
    .INIT(32'h00002002)) 
    i2c_ack1_i_2
       (.I0(i2c_capture_en),
        .I1(\i2c_stream_cnt[3]_i_6_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_3_n_0 ),
        .O(i2c_ack10_out));
  FDSE i2c_ack1_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ack1_i_1_n_0),
        .Q(i2c_ack1),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'hB8)) 
    i2c_ack2_i_1
       (.I0(i2c_ack2_i_2_n_0),
        .I1(i2c_ack24_out),
        .I2(i2c_ack2),
        .O(i2c_ack2_i_1_n_0));
  LUT2 #(
    .INIT(4'hD)) 
    i2c_ack2_i_2
       (.I0(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I1(cmos_sda),
        .O(i2c_ack2_i_2_n_0));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT5 #(
    .INIT(32'h00002002)) 
    i2c_ack2_i_3
       (.I0(i2c_capture_en),
        .I1(\i2c_stream_cnt[3]_i_6_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .O(i2c_ack24_out));
  FDSE i2c_ack2_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ack2_i_1_n_0),
        .Q(i2c_ack2),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    i2c_ack2a_i_1
       (.I0(i2c_ack2_i_2_n_0),
        .I1(i2c_ack2a1_out),
        .I2(i2c_ack2a),
        .O(i2c_ack2a_i_1_n_0));
  LUT5 #(
    .INIT(32'h00008002)) 
    i2c_ack2a_i_2
       (.I0(i2c_capture_en),
        .I1(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(i2c_ack2a1_out));
  FDSE i2c_ack2a_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ack2a_i_1_n_0),
        .Q(i2c_ack2a),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFFFB00000008)) 
    i2c_ack3_i_1
       (.I0(i2c_ack2_i_2_n_0),
        .I1(i2c_capture_en),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_ack3_i_2_n_0),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I5(i2c_ack3),
        .O(i2c_ack3_i_1_n_0));
  LUT6 #(
    .INIT(64'h55555555555556A6)) 
    i2c_ack3_i_2
       (.I0(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I1(i2c_transfer_end),
        .I2(i2c_transfer_en),
        .I3(p_0_in1_in),
        .I4(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I5(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(i2c_ack3_i_2_n_0));
  FDSE i2c_ack3_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ack3_i_1_n_0),
        .Q(i2c_ack3),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFFFB00000008)) 
    i2c_ack_i_1
       (.I0(i2c_ack_i_2_n_0),
        .I1(i2c_capture_en),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_ack_i_3_n_0),
        .I4(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I5(i2c_ack),
        .O(i2c_ack_i_1_n_0));
  LUT5 #(
    .INIT(32'hFFFEFFFF)) 
    i2c_ack_i_2
       (.I0(i2c_ack2a),
        .I1(i2c_ack1),
        .I2(i2c_ack3),
        .I3(i2c_ack2),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .O(i2c_ack_i_2_n_0));
  LUT6 #(
    .INIT(64'h55555555555556A6)) 
    i2c_ack_i_3
       (.I0(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I1(i2c_transfer_end),
        .I2(i2c_transfer_en),
        .I3(p_0_in1_in),
        .I4(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I5(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(i2c_ack_i_3_n_0));
  FDSE i2c_ack_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ack_i_1_n_0),
        .Q(i2c_ack),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000000000200)) 
    i2c_capture_en_i_1
       (.I0(i2c_transfer_en_i_2_n_0),
        .I1(i2c_transfer_en_i_4_n_0),
        .I2(clk_cnt_reg[7]),
        .I3(clk_cnt_reg[6]),
        .I4(i2c_capture_en_i_2_n_0),
        .I5(i2c_capture_en_i_3_n_0),
        .O(i2c_capture_en6_out));
  LUT2 #(
    .INIT(4'hE)) 
    i2c_capture_en_i_2
       (.I0(clk_cnt_reg[0]),
        .I1(clk_cnt_reg[1]),
        .O(i2c_capture_en_i_2_n_0));
  LUT4 #(
    .INIT(16'h7FFF)) 
    i2c_capture_en_i_3
       (.I0(clk_cnt_reg[4]),
        .I1(clk_cnt_reg[3]),
        .I2(clk_cnt_reg[5]),
        .I3(clk_cnt_reg[2]),
        .O(i2c_capture_en_i_3_n_0));
  FDRE i2c_capture_en_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_capture_en6_out),
        .Q(i2c_capture_en),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT2 #(
    .INIT(4'hB)) 
    \i2c_config_index[0]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[0]),
        .O(\i2c_config_index[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT3 #(
    .INIT(8'h14)) 
    \i2c_config_index[1]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[1]),
        .I2(i2c_config_index_reg__0[0]),
        .O(\i2c_config_index[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT4 #(
    .INIT(16'hBFEA)) 
    \i2c_config_index[2]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[0]),
        .I2(i2c_config_index_reg__0[1]),
        .I3(i2c_config_index_reg__0[2]),
        .O(\i2c_config_index[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT5 #(
    .INIT(32'hBFFFEAAA)) 
    \i2c_config_index[3]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[2]),
        .I2(i2c_config_index_reg__0[1]),
        .I3(i2c_config_index_reg__0[0]),
        .I4(i2c_config_index_reg__0[3]),
        .O(\i2c_config_index[3]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hBFFFFFFFEAAAAAAA)) 
    \i2c_config_index[4]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[3]),
        .I2(i2c_config_index_reg__0[2]),
        .I3(i2c_config_index_reg__0[1]),
        .I4(i2c_config_index_reg__0[0]),
        .I5(i2c_config_index_reg__0[4]),
        .O(\i2c_config_index[4]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFBFFFFFFAEAAAAAA)) 
    \i2c_config_index[5]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[4]),
        .I2(i2c_config_index_reg_rep_i_13_n_0),
        .I3(i2c_config_index_reg__0[2]),
        .I4(i2c_config_index_reg__0[3]),
        .I5(i2c_config_index_reg__0[5]),
        .O(\i2c_config_index[5]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT3 #(
    .INIT(8'hBE)) 
    \i2c_config_index[6]_i_1 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg_rep_i_10_n_0),
        .I2(i2c_config_index_reg__0[6]),
        .O(\i2c_config_index[6]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h08)) 
    \i2c_config_index[7]_i_1 
       (.I0(i2c_transfer_end),
        .I1(i2c_transfer_en),
        .I2(i2c_ack),
        .O(\i2c_config_index[7]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT4 #(
    .INIT(16'hFFEA)) 
    \i2c_config_index[7]_i_2 
       (.I0(i2c_config_index_reg_rep_i_11_n_0),
        .I1(i2c_config_index_reg__0[6]),
        .I2(i2c_config_index_reg_rep_i_10_n_0),
        .I3(i2c_config_index_reg__0[7]),
        .O(\i2c_config_index[7]_i_2_n_0 ));
  FDRE \i2c_config_index_reg[0] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[0]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[0]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[1] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[1]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[1]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[2] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[2]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[2]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[3] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[3]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[3]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[4] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[4]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[4]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[5] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[5]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[5]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[6] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[6]_i_1_n_0 ),
        .Q(i2c_config_index_reg__0[6]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_config_index_reg[7] 
       (.C(clk),
        .CE(\i2c_config_index[7]_i_1_n_0 ),
        .D(\i2c_config_index[7]_i_2_n_0 ),
        .Q(i2c_config_index_reg__0[7]),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  (* \MEM.PORTA.DATA_BIT_LAYOUT  = "p0_d23" *) 
  (* METHODOLOGY_DRC_VIOS = "{SYNTH-6 {cell *THIS*}}" *) 
  (* RTL_RAM_BITS = "23552" *) 
  (* RTL_RAM_NAME = "inst/u_i2c_timing_ctrl/i2c_config_index" *) 
  (* bram_addr_begin = "0" *) 
  (* bram_addr_end = "1023" *) 
  (* bram_slice_begin = "0" *) 
  (* bram_slice_end = "22" *) 
  RAMB36E1 #(
    .DOA_REG(0),
    .DOB_REG(0),
    .EN_ECC_READ("FALSE"),
    .EN_ECC_WRITE("FALSE"),
    .INITP_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_07(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_08(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_09(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INITP_0F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_00(256'h003037130030341A003018FF003017FF00310303003008420030088200310311),
    .INIT_01(256'h0037035A003704A0003621E000363312003632E20036310E0036303600310801),
    .INIT_02(256'h003731120039010A00390610003905020037051A00370B600037170100371578),
    .INIT_03(256'h003A1800003A134300471C5000371B200036205200302D600036013300360008),
    .INIT_04(256'h003C0598003C0428003C013400362201003634400036360300363513003A19F8),
    .INIT_05(256'h0038111000381000003C0B40003C0A9C003C091C003C0800003C0708003C0600),
    .INIT_06(256'h00302E0000300E58003004FF003000000040051A004001020037086400381200),
    .INIT_07(256'h003A1E26003A1B30003A1028003A0F30005000A700440E0000501F0100430060),
    .INIT_08(256'h00580526005804120058030F0058020F0058011400580023003A1F14003A1160),
    .INIT_09(256'h00580D0300580C0800580B0D00580A080058090500580805005807080058060C),
    .INIT_0A(256'h00581501005814000058130300581207005811090058100300580F0000580E00),
    .INIT_0B(256'h00581D0E00581C0800581B0600581A05005819080058180D0058170800581603),
    .INIT_0C(256'h00582526005824460058232800582215005821110058201100581F1700581E29),
    .INIT_0D(256'h00582D2400582C2400582B2200582A2400582926005828640058272600582608),
    .INIT_0E(256'h00583522005834240058332600583224005831420058304000582F2200582E06),
    .INIT_0F(256'h00583DCE00583C4200583B2800583A2600583924005838440058372600583622),
    .INIT_10(256'h005187090051860900518524005184250051831400518200005181F2005180FF),
    .INIT_11(256'h00518F5600518E3D00518D4200518CB200518BE000518A540051897500518809),
    .INIT_12(256'h0051970100519603005195F0005194F00051937000519204005191F800519046),
    .INIT_13(256'h0054800100519E3800519D8200519C0600519B0000519A040051991200519804),
    .INIT_14(256'h005488870054877D005486710054856500548451005483280054821400548108),
    .INIT_15(256'h0054901D00548FEA00548EDD00548DCD00548CB800548BAA00548A9A00548991),
    .INIT_16(256'h0053886C0053877C005386880053857E0053840A005383080053825B0053811E),
    .INIT_17(256'h00558A000055891000558410005583400055800600538B9800538A0100538910),
    .INIT_18(256'h00530530005304080053030000530210005301300053000800501D4000558BF8),
    .INIT_19(256'h003008020050250000530C0600530B0400530A30005309080053071600530608),
    .INIT_1A(256'h0038000000381531003814310038210300382045003C07070030366900303541),
    .INIT_1B(256'h00380805003807A9003806060038053F0038040A003803FA0038020000380100),
    .INIT_1C(256'h0038130400380FE400380E0200380D6400380C0700380BD000380A0200380900),
    .INIT_1D(256'h003A15E0003A1402003A03E0003A020200370C03003709520036122900361800),
    .INIT_1E(256'h0048371600460C2000460B370044070400471303003006C30030021C00400402),
    .INIT_1F(256'h000000000000000000000000003B0000003B0083003503000050018300382404),
    .INIT_20(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_21(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_22(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_23(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_24(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_25(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_26(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_27(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_28(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_29(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_2F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_30(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_31(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_32(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_33(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_34(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_35(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_36(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_37(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_38(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_39(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_3F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_40(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_41(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_42(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_43(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_44(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_45(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_46(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_47(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_48(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_49(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_4F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_50(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_51(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_52(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_53(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_54(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_55(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_56(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_57(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_58(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_59(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_5F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_60(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_61(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_62(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_63(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_64(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_65(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_66(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_67(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_68(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_69(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_6F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_70(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_71(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_72(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_73(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_74(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_75(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_76(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_77(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_78(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_79(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7A(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7B(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7C(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7D(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7E(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_7F(256'h0000000000000000000000000000000000000000000000000000000000000000),
    .INIT_A(36'h000000000),
    .INIT_B(36'h000000000),
    .RAM_EXTENSION_A("NONE"),
    .RAM_EXTENSION_B("NONE"),
    .RAM_MODE("TDP"),
    .RDADDR_COLLISION_HWCONFIG("PERFORMANCE"),
    .READ_WIDTH_A(36),
    .READ_WIDTH_B(0),
    .RSTREG_PRIORITY_A("RSTREG"),
    .RSTREG_PRIORITY_B("RSTREG"),
    .SIM_COLLISION_CHECK("ALL"),
    .SIM_DEVICE("7SERIES"),
    .SRVAL_A(36'h000000000),
    .SRVAL_B(36'h000000000),
    .WRITE_MODE_A("WRITE_FIRST"),
    .WRITE_MODE_B("WRITE_FIRST"),
    .WRITE_WIDTH_A(36),
    .WRITE_WIDTH_B(0)) 
    i2c_config_index_reg_rep
       (.ADDRARDADDR({1'b1,1'b0,1'b0,i2c_config_index_reg_rep_i_2_n_0,i2c_config_index_reg_rep_i_3_n_0,i2c_config_index_reg_rep_i_4_n_0,i2c_config_index_reg_rep_i_5_n_0,i2c_config_index_reg_rep_i_6_n_0,i2c_config_index_reg_rep_i_7_n_0,i2c_config_index_reg_rep_i_8_n_0,i2c_config_index_reg_rep_i_9_n_0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ADDRBWRADDR({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CASCADEINA(1'b1),
        .CASCADEINB(1'b0),
        .CASCADEOUTA(NLW_i2c_config_index_reg_rep_CASCADEOUTA_UNCONNECTED),
        .CASCADEOUTB(NLW_i2c_config_index_reg_rep_CASCADEOUTB_UNCONNECTED),
        .CLKARDCLK(clk),
        .CLKBWRCLK(1'b0),
        .DBITERR(NLW_i2c_config_index_reg_rep_DBITERR_UNCONNECTED),
        .DIADI({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .DIBDI({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .DIPADIP({1'b0,1'b0,1'b0,1'b0}),
        .DIPBDIP({1'b1,1'b1,1'b1,1'b1}),
        .DOADO({NLW_i2c_config_index_reg_rep_DOADO_UNCONNECTED[31:23],i2c_config_index_reg_rep_n_30,i2c_config_index_reg_rep_n_31,i2c_config_index_reg_rep_n_32,i2c_config_index_reg_rep_n_33,i2c_config_index_reg_rep_n_34,i2c_config_index_reg_rep_n_35,i2c_config_index_reg_rep_n_36,data2,i2c_config_index_reg_rep_n_45,i2c_config_index_reg_rep_n_46,i2c_config_index_reg_rep_n_47,i2c_config_index_reg_rep_n_48,i2c_config_index_reg_rep_n_49,i2c_config_index_reg_rep_n_50,i2c_config_index_reg_rep_n_51,i2c_config_index_reg_rep_n_52}),
        .DOBDO(NLW_i2c_config_index_reg_rep_DOBDO_UNCONNECTED[31:0]),
        .DOPADOP(NLW_i2c_config_index_reg_rep_DOPADOP_UNCONNECTED[3:0]),
        .DOPBDOP(NLW_i2c_config_index_reg_rep_DOPBDOP_UNCONNECTED[3:0]),
        .ECCPARITY(NLW_i2c_config_index_reg_rep_ECCPARITY_UNCONNECTED[7:0]),
        .ENARDEN(i2c_config_index_reg_rep_i_1_n_0),
        .ENBWREN(1'b0),
        .INJECTDBITERR(NLW_i2c_config_index_reg_rep_INJECTDBITERR_UNCONNECTED),
        .INJECTSBITERR(NLW_i2c_config_index_reg_rep_INJECTSBITERR_UNCONNECTED),
        .RDADDRECC(NLW_i2c_config_index_reg_rep_RDADDRECC_UNCONNECTED[8:0]),
        .REGCEAREGCE(1'b0),
        .REGCEB(1'b0),
        .RSTRAMARSTRAM(1'b0),
        .RSTRAMB(1'b0),
        .RSTREGARSTREG(1'b0),
        .RSTREGB(1'b0),
        .SBITERR(NLW_i2c_config_index_reg_rep_SBITERR_UNCONNECTED),
        .WEA({1'b0,1'b0,1'b0,1'b0}),
        .WEBWE({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}));
  LUT4 #(
    .INIT(16'h40FF)) 
    i2c_config_index_reg_rep_i_1
       (.I0(i2c_ack),
        .I1(i2c_transfer_en),
        .I2(i2c_transfer_end),
        .I3(p_0_in),
        .O(i2c_config_index_reg_rep_i_1_n_0));
  LUT6 #(
    .INIT(64'h8000000000000000)) 
    i2c_config_index_reg_rep_i_10
       (.I0(i2c_config_index_reg__0[5]),
        .I1(i2c_config_index_reg__0[3]),
        .I2(i2c_config_index_reg__0[2]),
        .I3(i2c_config_index_reg__0[1]),
        .I4(i2c_config_index_reg__0[0]),
        .I5(i2c_config_index_reg__0[4]),
        .O(i2c_config_index_reg_rep_i_10_n_0));
  LUT5 #(
    .INIT(32'h00008880)) 
    i2c_config_index_reg_rep_i_11
       (.I0(i2c_config_index_reg__0[6]),
        .I1(i2c_config_index_reg__0[7]),
        .I2(i2c_config_index_reg__0[0]),
        .I3(i2c_config_index_reg__0[1]),
        .I4(i2c_config_index_reg_rep_i_14_n_0),
        .O(i2c_config_index_reg_rep_i_11_n_0));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT5 #(
    .INIT(32'h80000000)) 
    i2c_config_index_reg_rep_i_12
       (.I0(i2c_config_index_reg__0[4]),
        .I1(i2c_config_index_reg__0[0]),
        .I2(i2c_config_index_reg__0[1]),
        .I3(i2c_config_index_reg__0[2]),
        .I4(i2c_config_index_reg__0[3]),
        .O(i2c_config_index_reg_rep_i_12_n_0));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT2 #(
    .INIT(4'h7)) 
    i2c_config_index_reg_rep_i_13
       (.I0(i2c_config_index_reg__0[0]),
        .I1(i2c_config_index_reg__0[1]),
        .O(i2c_config_index_reg_rep_i_13_n_0));
  LUT4 #(
    .INIT(16'h7FFF)) 
    i2c_config_index_reg_rep_i_14
       (.I0(i2c_config_index_reg__0[3]),
        .I1(i2c_config_index_reg__0[2]),
        .I2(i2c_config_index_reg__0[5]),
        .I3(i2c_config_index_reg__0[4]),
        .O(i2c_config_index_reg_rep_i_14_n_0));
  LUT5 #(
    .INIT(32'hFFEA0000)) 
    i2c_config_index_reg_rep_i_2
       (.I0(i2c_config_index_reg__0[7]),
        .I1(i2c_config_index_reg_rep_i_10_n_0),
        .I2(i2c_config_index_reg__0[6]),
        .I3(i2c_config_index_reg_rep_i_11_n_0),
        .I4(p_0_in),
        .O(i2c_config_index_reg_rep_i_2_n_0));
  LUT4 #(
    .INIT(16'hF600)) 
    i2c_config_index_reg_rep_i_3
       (.I0(i2c_config_index_reg__0[6]),
        .I1(i2c_config_index_reg_rep_i_10_n_0),
        .I2(i2c_config_index_reg_rep_i_11_n_0),
        .I3(p_0_in),
        .O(i2c_config_index_reg_rep_i_3_n_0));
  LUT4 #(
    .INIT(16'hF600)) 
    i2c_config_index_reg_rep_i_4
       (.I0(i2c_config_index_reg__0[5]),
        .I1(i2c_config_index_reg_rep_i_12_n_0),
        .I2(i2c_config_index_reg_rep_i_11_n_0),
        .I3(p_0_in),
        .O(i2c_config_index_reg_rep_i_4_n_0));
  LUT6 #(
    .INIT(64'hFFFF9AAA00000000)) 
    i2c_config_index_reg_rep_i_5
       (.I0(i2c_config_index_reg__0[4]),
        .I1(i2c_config_index_reg_rep_i_13_n_0),
        .I2(i2c_config_index_reg__0[2]),
        .I3(i2c_config_index_reg__0[3]),
        .I4(i2c_config_index_reg_rep_i_11_n_0),
        .I5(p_0_in),
        .O(i2c_config_index_reg_rep_i_5_n_0));
  LUT6 #(
    .INIT(64'hFFFF6AAA00000000)) 
    i2c_config_index_reg_rep_i_6
       (.I0(i2c_config_index_reg__0[3]),
        .I1(i2c_config_index_reg__0[0]),
        .I2(i2c_config_index_reg__0[1]),
        .I3(i2c_config_index_reg__0[2]),
        .I4(i2c_config_index_reg_rep_i_11_n_0),
        .I5(p_0_in),
        .O(i2c_config_index_reg_rep_i_6_n_0));
  LUT5 #(
    .INIT(32'hFF6A0000)) 
    i2c_config_index_reg_rep_i_7
       (.I0(i2c_config_index_reg__0[2]),
        .I1(i2c_config_index_reg__0[1]),
        .I2(i2c_config_index_reg__0[0]),
        .I3(i2c_config_index_reg_rep_i_11_n_0),
        .I4(p_0_in),
        .O(i2c_config_index_reg_rep_i_7_n_0));
  LUT4 #(
    .INIT(16'h0600)) 
    i2c_config_index_reg_rep_i_8
       (.I0(i2c_config_index_reg__0[0]),
        .I1(i2c_config_index_reg__0[1]),
        .I2(i2c_config_index_reg_rep_i_11_n_0),
        .I3(p_0_in),
        .O(i2c_config_index_reg_rep_i_8_n_0));
  LUT3 #(
    .INIT(8'hD0)) 
    i2c_config_index_reg_rep_i_9
       (.I0(i2c_config_index_reg__0[0]),
        .I1(i2c_config_index_reg_rep_i_11_n_0),
        .I2(p_0_in),
        .O(i2c_config_index_reg_rep_i_9_n_0));
  LUT6 #(
    .INIT(64'h00000000D9D8D8D8)) 
    i2c_ctrl_clk_i_1
       (.I0(clk_cnt_reg[7]),
        .I1(i2c_capture_en_i_3_n_0),
        .I2(clk_cnt_reg[6]),
        .I3(clk_cnt_reg[0]),
        .I4(clk_cnt_reg[1]),
        .I5(i2c_ctrl_clk_i_2_n_0),
        .O(i2c_ctrl_clk_i_1_n_0));
  LUT5 #(
    .INIT(32'hF8FFFFFF)) 
    i2c_ctrl_clk_i_2
       (.I0(clk_cnt_reg[6]),
        .I1(clk_cnt_reg[7]),
        .I2(i2c_transfer_en_i_4_n_0),
        .I3(p_0_in),
        .I4(i2c_transfer_en_i_2_n_0),
        .O(i2c_ctrl_clk_i_2_n_0));
  FDRE i2c_ctrl_clk_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_ctrl_clk_i_1_n_0),
        .Q(i2c_ctrl_clk),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hFBBFBBBB08808888)) 
    i2c_sdat_out_i_1
       (.I0(i2c_sdat_out_i_2_n_0),
        .I1(i2c_transfer_en),
        .I2(\i2c_stream_cnt[3]_i_6_n_0 ),
        .I3(i2c_sdat_out_i_3_n_0),
        .I4(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I5(i2c_sdat_out),
        .O(i2c_sdat_out_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT5 #(
    .INIT(32'hFDFCF301)) 
    i2c_sdat_out_i_2
       (.I0(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I1(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_sdat_out_reg_i_4_n_0),
        .I4(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(i2c_sdat_out_i_2_n_0));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT2 #(
    .INIT(4'h1)) 
    i2c_sdat_out_i_3
       (.I0(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I1(\i2c_stream_cnt[3]_i_5_n_0 ),
        .O(i2c_sdat_out_i_3_n_0));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    i2c_sdat_out_i_5
       (.I0(\i2c_wdata_reg_n_0_[4] ),
        .I1(\i2c_wdata_reg_n_0_[5] ),
        .I2(\i2c_stream_cnt_reg_n_0_[1] ),
        .I3(\i2c_wdata_reg_n_0_[6] ),
        .I4(\i2c_stream_cnt_reg_n_0_[0] ),
        .I5(\i2c_wdata_reg_n_0_[7] ),
        .O(i2c_sdat_out_i_5_n_0));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    i2c_sdat_out_i_6
       (.I0(\i2c_wdata_reg_n_0_[0] ),
        .I1(\i2c_wdata_reg_n_0_[1] ),
        .I2(\i2c_stream_cnt_reg_n_0_[1] ),
        .I3(\i2c_wdata_reg_n_0_[2] ),
        .I4(\i2c_stream_cnt_reg_n_0_[0] ),
        .I5(\i2c_wdata_reg_n_0_[3] ),
        .O(i2c_sdat_out_i_6_n_0));
  FDSE i2c_sdat_out_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_sdat_out_i_1_n_0),
        .Q(i2c_sdat_out),
        .S(\FSM_onehot_current_state[10]_i_1_n_0 ));
  MUXF7 i2c_sdat_out_reg_i_4
       (.I0(i2c_sdat_out_i_5_n_0),
        .I1(i2c_sdat_out_i_6_n_0),
        .O(i2c_sdat_out_reg_i_4_n_0),
        .S(\i2c_stream_cnt_reg_n_0_[2] ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \i2c_stream_cnt[0]_i_1 
       (.I0(\i2c_stream_cnt[3]_i_7_n_0 ),
        .I1(\i2c_stream_cnt_reg_n_0_[0] ),
        .O(\i2c_stream_cnt[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT3 #(
    .INIT(8'h28)) 
    \i2c_stream_cnt[1]_i_1 
       (.I0(\i2c_stream_cnt[3]_i_7_n_0 ),
        .I1(\i2c_stream_cnt_reg_n_0_[1] ),
        .I2(\i2c_stream_cnt_reg_n_0_[0] ),
        .O(\i2c_stream_cnt[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'h2A80)) 
    \i2c_stream_cnt[2]_i_1 
       (.I0(\i2c_stream_cnt[3]_i_7_n_0 ),
        .I1(\i2c_stream_cnt_reg_n_0_[0] ),
        .I2(\i2c_stream_cnt_reg_n_0_[1] ),
        .I3(\i2c_stream_cnt_reg_n_0_[2] ),
        .O(\i2c_stream_cnt[2]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'hA8AAAAAA)) 
    \i2c_stream_cnt[3]_i_1 
       (.I0(i2c_transfer_en),
        .I1(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(i2c_stream_cnt));
  LUT3 #(
    .INIT(8'hFE)) 
    \i2c_stream_cnt[3]_i_10 
       (.I0(p_0_in1_in),
        .I1(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I2(i2c_transfer_end),
        .O(\i2c_stream_cnt[3]_i_10_n_0 ));
  LUT3 #(
    .INIT(8'h0E)) 
    \i2c_stream_cnt[3]_i_11 
       (.I0(p_0_in1_in),
        .I1(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I2(i2c_transfer_en),
        .O(\i2c_stream_cnt[3]_i_11_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT5 #(
    .INIT(32'h2AAA8000)) 
    \i2c_stream_cnt[3]_i_2 
       (.I0(\i2c_stream_cnt[3]_i_7_n_0 ),
        .I1(\i2c_stream_cnt_reg_n_0_[1] ),
        .I2(\i2c_stream_cnt_reg_n_0_[0] ),
        .I3(\i2c_stream_cnt_reg_n_0_[2] ),
        .I4(\i2c_stream_cnt_reg_n_0_[3] ),
        .O(\i2c_stream_cnt[3]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFEFEFFFEFFFE)) 
    \i2c_stream_cnt[3]_i_3 
       (.I0(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I3(p_0_in1_in),
        .I4(\FSM_onehot_current_state_reg_n_0_[3] ),
        .I5(i2c_transfer_en),
        .O(\i2c_stream_cnt[3]_i_3_n_0 ));
  LUT6 #(
    .INIT(64'hAEAEFEAEAEAEAEAE)) 
    \i2c_stream_cnt[3]_i_4 
       (.I0(\i2c_stream_cnt[3]_i_8_n_0 ),
        .I1(\i2c_stream_cnt[3]_i_9_n_0 ),
        .I2(i2c_transfer_en),
        .I3(\FSM_onehot_current_state_reg_n_0_[0] ),
        .I4(i2c_config_index_reg_rep_i_11_n_0),
        .I5(i2c_transfer_en_i_2_n_0),
        .O(\i2c_stream_cnt[3]_i_4_n_0 ));
  LUT5 #(
    .INIT(32'hFFFFFFB8)) 
    \i2c_stream_cnt[3]_i_5 
       (.I0(\i2c_stream_cnt[3]_i_9_n_0 ),
        .I1(i2c_transfer_en),
        .I2(\i2c_stream_cnt[3]_i_10_n_0 ),
        .I3(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I4(\FSM_onehot_current_state_reg_n_0_[6] ),
        .O(\i2c_stream_cnt[3]_i_5_n_0 ));
  LUT5 #(
    .INIT(32'hFEFFFEEE)) 
    \i2c_stream_cnt[3]_i_6 
       (.I0(\FSM_onehot_current_state_reg_n_0_[9] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I2(p_0_in1_in),
        .I3(i2c_transfer_en),
        .I4(i2c_transfer_end),
        .O(\i2c_stream_cnt[3]_i_6_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT4 #(
    .INIT(16'h0154)) 
    \i2c_stream_cnt[3]_i_7 
       (.I0(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I1(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(\i2c_stream_cnt[3]_i_7_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFF00FFFEFF00)) 
    \i2c_stream_cnt[3]_i_8 
       (.I0(\FSM_onehot_current_state_reg_n_0_[6] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[4] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[2] ),
        .I3(\i2c_stream_cnt[3]_i_11_n_0 ),
        .I4(\FSM_onehot_current_state[9]_i_2_n_0 ),
        .I5(\FSM_onehot_current_state_reg_n_0_[8] ),
        .O(\i2c_stream_cnt[3]_i_8_n_0 ));
  LUT3 #(
    .INIT(8'hFE)) 
    \i2c_stream_cnt[3]_i_9 
       (.I0(\FSM_onehot_current_state_reg_n_0_[9] ),
        .I1(\FSM_onehot_current_state_reg_n_0_[5] ),
        .I2(\FSM_onehot_current_state_reg_n_0_[1] ),
        .O(\i2c_stream_cnt[3]_i_9_n_0 ));
  FDRE \i2c_stream_cnt_reg[0] 
       (.C(clk),
        .CE(i2c_stream_cnt),
        .D(\i2c_stream_cnt[0]_i_1_n_0 ),
        .Q(\i2c_stream_cnt_reg_n_0_[0] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_stream_cnt_reg[1] 
       (.C(clk),
        .CE(i2c_stream_cnt),
        .D(\i2c_stream_cnt[1]_i_1_n_0 ),
        .Q(\i2c_stream_cnt_reg_n_0_[1] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_stream_cnt_reg[2] 
       (.C(clk),
        .CE(i2c_stream_cnt),
        .D(\i2c_stream_cnt[2]_i_1_n_0 ),
        .Q(\i2c_stream_cnt_reg_n_0_[2] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_stream_cnt_reg[3] 
       (.C(clk),
        .CE(i2c_stream_cnt),
        .D(\i2c_stream_cnt[3]_i_2_n_0 ),
        .Q(\i2c_stream_cnt_reg_n_0_[3] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000000020000)) 
    i2c_transfer_en_i_1
       (.I0(i2c_transfer_en_i_2_n_0),
        .I1(clk_cnt_reg[0]),
        .I2(clk_cnt_reg[1]),
        .I3(clk_cnt_reg[2]),
        .I4(i2c_transfer_en_i_3_n_0),
        .I5(i2c_transfer_en_i_4_n_0),
        .O(i2c_transfer_en7_out));
  LUT6 #(
    .INIT(64'h0000020000000000)) 
    i2c_transfer_en_i_2
       (.I0(i2c_transfer_en_i_5_n_0),
        .I1(delay_cnt_reg[0]),
        .I2(delay_cnt_reg[2]),
        .I3(delay_cnt_reg[13]),
        .I4(i2c_transfer_en_i_6_n_0),
        .I5(\delay_cnt[0]_i_3_n_0 ),
        .O(i2c_transfer_en_i_2_n_0));
  LUT5 #(
    .INIT(32'h00000001)) 
    i2c_transfer_en_i_3
       (.I0(clk_cnt_reg[7]),
        .I1(clk_cnt_reg[6]),
        .I2(clk_cnt_reg[3]),
        .I3(clk_cnt_reg[5]),
        .I4(clk_cnt_reg[4]),
        .O(i2c_transfer_en_i_3_n_0));
  LUT5 #(
    .INIT(32'hFFFFFFFE)) 
    i2c_transfer_en_i_4
       (.I0(clk_cnt_reg[12]),
        .I1(clk_cnt_reg[15]),
        .I2(clk_cnt_reg[11]),
        .I3(clk_cnt_reg[8]),
        .I4(i2c_transfer_en_i_7_n_0),
        .O(i2c_transfer_en_i_4_n_0));
  LUT6 #(
    .INIT(64'h0000000000000800)) 
    i2c_transfer_en_i_5
       (.I0(delay_cnt_reg[7]),
        .I1(delay_cnt_reg[8]),
        .I2(delay_cnt_reg[6]),
        .I3(delay_cnt_reg[5]),
        .I4(delay_cnt_reg[15]),
        .I5(delay_cnt_reg[16]),
        .O(i2c_transfer_en_i_5_n_0));
  LUT4 #(
    .INIT(16'hEFFF)) 
    i2c_transfer_en_i_6
       (.I0(delay_cnt_reg[1]),
        .I1(delay_cnt_reg[4]),
        .I2(delay_cnt_reg[14]),
        .I3(delay_cnt_reg[3]),
        .O(i2c_transfer_en_i_6_n_0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    i2c_transfer_en_i_7
       (.I0(clk_cnt_reg[14]),
        .I1(clk_cnt_reg[13]),
        .I2(clk_cnt_reg[9]),
        .I3(clk_cnt_reg[10]),
        .O(i2c_transfer_en_i_7_n_0));
  FDRE i2c_transfer_en_reg
       (.C(clk),
        .CE(1'b1),
        .D(i2c_transfer_en7_out),
        .Q(i2c_transfer_en),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h00000000F8C83808)) 
    \i2c_wdata[0]_i_1 
       (.I0(i2c_config_index_reg_rep_n_36),
        .I1(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(data2[0]),
        .I4(i2c_config_index_reg_rep_n_52),
        .I5(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(\i2c_wdata[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h00000000F8C83808)) 
    \i2c_wdata[1]_i_1 
       (.I0(i2c_config_index_reg_rep_n_35),
        .I1(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(data2[1]),
        .I4(i2c_config_index_reg_rep_n_51),
        .I5(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(\i2c_wdata[1]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h00000000F8C83808)) 
    \i2c_wdata[2]_i_1 
       (.I0(i2c_config_index_reg_rep_n_34),
        .I1(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(data2[2]),
        .I4(i2c_config_index_reg_rep_n_50),
        .I5(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(\i2c_wdata[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'h0002)) 
    \i2c_wdata[3]_i_1 
       (.I0(\i2c_wdata[3]_i_2_n_0 ),
        .I1(p_0_in1_in),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\i2c_wdata[3]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    \i2c_wdata[3]_i_2 
       (.I0(i2c_config_index_reg_rep_n_49),
        .I1(data2[3]),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_config_index_reg_rep_n_33),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I5(\i2c_stream_cnt[3]_i_4_n_0 ),
        .O(\i2c_wdata[3]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'h0002)) 
    \i2c_wdata[4]_i_1 
       (.I0(\i2c_wdata[4]_i_2_n_0 ),
        .I1(p_0_in1_in),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\i2c_wdata[4]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    \i2c_wdata[4]_i_2 
       (.I0(i2c_config_index_reg_rep_n_48),
        .I1(data2[4]),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_config_index_reg_rep_n_32),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I5(\i2c_stream_cnt[3]_i_4_n_0 ),
        .O(\i2c_wdata[4]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'h0002)) 
    \i2c_wdata[5]_i_1 
       (.I0(\i2c_wdata[5]_i_2_n_0 ),
        .I1(p_0_in1_in),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\i2c_wdata[5]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    \i2c_wdata[5]_i_2 
       (.I0(i2c_config_index_reg_rep_n_47),
        .I1(data2[5]),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_config_index_reg_rep_n_31),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I5(\i2c_stream_cnt[3]_i_4_n_0 ),
        .O(\i2c_wdata[5]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'h0002)) 
    \i2c_wdata[6]_i_1 
       (.I0(\i2c_wdata[6]_i_2_n_0 ),
        .I1(p_0_in1_in),
        .I2(\FSM_onehot_current_state_reg_n_0_[8] ),
        .I3(\FSM_onehot_current_state_reg_n_0_[9] ),
        .O(\i2c_wdata[6]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
    \i2c_wdata[6]_i_2 
       (.I0(i2c_config_index_reg_rep_n_46),
        .I1(data2[6]),
        .I2(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I3(i2c_config_index_reg_rep_n_30),
        .I4(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I5(\i2c_stream_cnt[3]_i_4_n_0 ),
        .O(\i2c_wdata[6]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'hCC80888C)) 
    \i2c_wdata[7]_i_1 
       (.I0(\i2c_stream_cnt[3]_i_4_n_0 ),
        .I1(i2c_transfer_en),
        .I2(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I3(\i2c_stream_cnt[3]_i_3_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_6_n_0 ),
        .O(i2c_wdata));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'h00B80000)) 
    \i2c_wdata[7]_i_2 
       (.I0(i2c_config_index_reg_rep_n_45),
        .I1(\i2c_stream_cnt[3]_i_5_n_0 ),
        .I2(data2[7]),
        .I3(\i2c_stream_cnt[3]_i_6_n_0 ),
        .I4(\i2c_stream_cnt[3]_i_3_n_0 ),
        .O(\i2c_wdata[7]_i_2_n_0 ));
  FDRE \i2c_wdata_reg[0] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[0]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[0] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[1] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[1]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[1] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[2] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[2]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[2] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[3] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[3]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[3] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[4] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[4]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[4] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[5] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[5]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[5] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[6] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[6]_i_1_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[6] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
  FDRE \i2c_wdata_reg[7] 
       (.C(clk),
        .CE(i2c_wdata),
        .D(\i2c_wdata[7]_i_2_n_0 ),
        .Q(\i2c_wdata_reg_n_0_[7] ),
        .R(\FSM_onehot_current_state[10]_i_1_n_0 ));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif

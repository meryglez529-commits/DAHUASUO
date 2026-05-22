//Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2017.4 (win64) Build 2086221 Fri Dec 15 20:55:39 MST 2017
//Date        : Fri Mar 22 19:59:22 2019
//Host        : 123tjy running 64-bit major release  (build 9200)
//Command     : generate_target system_wrapper.bd
//Design      : system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module system_top
(  
output [14:0]DDR3_addr,
output [2:0]DDR3_ba,
output DDR3_cas_n,
output [0:0]DDR3_ck_n,
output [0:0]DDR3_ck_p,
output [0:0]DDR3_cke,
output [0:0]DDR3_cs_n,
output [7:0]DDR3_dm,
inout [63:0]DDR3_dq,
inout [7:0]DDR3_dqs_n,
inout [7:0]DDR3_dqs_p,
output [0:0]DDR3_odt,
output DDR3_ras_n,
output DDR3_reset_n,
output DDR3_we_n,
//--------------hdmi input----------------------
input  hdmi_clk,
input [23:0]hdmi_data,
input  hdmi_de,
output hdmi_rst,
input  hdmi_vs,
output iic_scl,
inout  iic_sda,
//--------------PCIE---------------------
input  [3:0]pcie_mgt_rxn,
input  [3:0]pcie_mgt_rxp,
output [3:0]pcie_mgt_txn,
output [3:0]pcie_mgt_txp,
input pcie_resetn,
input [0:0]pcie_sys_clk_clk_n,
input [0:0]pcie_sys_clk_clk_p
//---------------system clk in-----------------
);

assign hdmi_rst = 1'b1;
//(*mark_debug = "true"*) (* KEEP = "TRUE" *)
wire ui_rstn;
(*mark_debug = "true"*) wire pkg_wr_areq;
(*mark_debug = "true"*)wire pkg_wr_en;
(*mark_debug = "true"*)wire pkg_wr_last;
(*mark_debug = "true"*)wire [31 :0]pkg_wr_addr;
(*mark_debug = "true"*)wire [127:0]pkg_wr_data;
(*mark_debug = "true"*)wire [31 :0]pkg_wr_size;

wire ui_clk;
reg  W0_FS_i;
wire  W0_wclk_i;
reg  W0_wren_i;
reg  [31:0]W0_data_i;
wire rst_o;
reg[6:0]wr_buf;
wire hdmi_clk90;
clk_wiz_0 clk_wiz_inst
(
    .clk_out1(hdmi_clk90),  
    .clk_in1(hdmi_clk)
); 
assign W0_wclk_i = hdmi_clk90;
     
always@(posedge W0_wclk_i)begin
W0_data_i <= {hdmi_data,8'hff};
W0_wren_i <= hdmi_de;
W0_FS_i   <= hdmi_vs;
end

//---------------------------image decode----------------------------    
IIC_ADV7611_Config_0 IIC_ADV7611_Config_inst (
  .ADV_CLK(ui_clk),    // input wire ADV_CLK
  .ADV_RST(ui_rstn),    // input wire ADV_RST
  .ADV_SCLK(iic_scl),  // output wire ADV_SCLK
  .ADV_SDAT(iic_sda)  // inout wire ADV_SDAT
);
//---------------------------image decode----------------------------    
Delay_rst_0 Delay_rst_inst (
  .clk_i(ui_clk),    // input wire clk_i
  .rstn_i(ui_rstn),  // input wire rstn_i
  .rst_o(rst_o)    // output wire rst_o
);

//---------------fdma image buf controller---------------------------  
fdma_controller # ( 
.BUF_SIZE(3),
.H_CNT (1920  ),
.V_CNT (1080  )
) fdma_controller_u0
(
    //FDAM signals
  .ui_clk(ui_clk),
  .ui_rstn(rst_o),
	//Sensor video 
  .W0_FS_i(W0_FS_i),
  .W0_wclk_i(W0_wclk_i),
  .W0_wren_i(W0_wren_i),
  .W0_data_i(W0_data_i), 
         
  .pkg_wr_areq(pkg_wr_areq),    
  .pkg_wr_en(pkg_wr_en),
  .pkg_wr_last(pkg_wr_last),
  .pkg_wr_addr(pkg_wr_addr),
  .pkg_wr_data(pkg_wr_data),
  .pkg_wr_size(pkg_wr_size),
  .W0_Fbuf()
    
 );

//---------------bd design------------------------------------   
system system_i
       (.DDR3_addr(DDR3_addr),
        .DDR3_ba(DDR3_ba),
        .DDR3_cas_n(DDR3_cas_n),
        .DDR3_ck_n(DDR3_ck_n),
        .DDR3_ck_p(DDR3_ck_p),
        .DDR3_cke(DDR3_cke),
        .DDR3_cs_n(DDR3_cs_n),
        .DDR3_dm(DDR3_dm),
        .DDR3_dq(DDR3_dq),
        .DDR3_dqs_n(DDR3_dqs_n),
        .DDR3_dqs_p(DDR3_dqs_p),
        .DDR3_odt(DDR3_odt),
        .DDR3_ras_n(DDR3_ras_n),
        .DDR3_reset_n(DDR3_reset_n),
        .DDR3_we_n(DDR3_we_n),
        
        .fdma_rstn(ui_rstn),
        .pkg_wr_addr(pkg_wr_addr),
        .pkg_wr_data(pkg_wr_data),
        .pkg_wr_areq(pkg_wr_areq),
        .pkg_wr_en  (pkg_wr_en),
        .pkg_wr_last(pkg_wr_last),
        .pkg_wr_size(pkg_wr_size),   
        
        .pkg_rd_addr(32'd0),
        .pkg_rd_data(),
        .pkg_rd_areq(1'b0),  
        .pkg_rd_en  (),   
        .pkg_rd_last(),
        .pkg_rd_size(32'd256),        
                   

        .pcie_mgt_rxn(pcie_mgt_rxn),
        .pcie_mgt_rxp(pcie_mgt_rxp),
        .pcie_mgt_txn(pcie_mgt_txn),
        .pcie_mgt_txp(pcie_mgt_txp),
        .pcie_resetn(pcie_resetn),
        .pcie_sys_clk_clk_n(pcie_sys_clk_clk_n),
        .pcie_sys_clk_clk_p(pcie_sys_clk_clk_p),
                
        .clk_100m(),
        .ui_clk(ui_clk)
        );
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/02/04 20:36:43
// Design Name: 
// Module Name: ETHERNET_TOP
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


module ETHERNET_TOP#(
 parameter ILA_DEBUG = 1'b0
)(
      input        gtrefclk_p,                // differential clock
      input        gtrefclk_n,                // differential clock
      
      output       txp,                   // Differential +ve of serial transmission from PMA to PMD.
      output       txn,                   // Differential -ve of serial transmission from PMA to PMD.
      input        rxp,                   // Differential +ve for serial reception from PMD to PMA.
      input        rxn,                   // Differential -ve for serial reception from PMD to PMA.

      input        clk_config,
      input        locked,
      output       PHY_RESETn,
      output       PHY_INTn,
      output       PHY_MDC,
      inout        PHY_MDIO,
      output       txp_sgmii,                   // Differential +ve of serial transmission from PMA to PMD.
      output       txn_sgmii,                   // Differential -ve of serial transmission from PMA to PMD.
      input        rxp_sgmii,                   // Differential +ve for serial reception from PMD to PMA.
      input        rxn_sgmii,                   // Differential -ve for serial reception from PMD to PMA.
      // asynchronous reset
      input         glbl_rst,
      input         independent_clock_bufg, //50M
      output  reg      link_up   = 1'b0,
      output  reg      sync_done = 1'b0,
      output  reg      resetdone = 1'b0,
      
      //eprom
      input         READ_DONE, 
      input  [47:0] FPGA_MAC,  
      input  [31:0] FPGA_IP,   
      //
      output user_axis_clk_out,   
      output user_axis_resetn_out,
      //--------- reg of AWG -----------------------
      input           chn0_rep_done,
      input           chn1_rep_done,
      input           chn2_rep_done,
      input           chn3_rep_done,

      input    [31:0]  reg0x0000_i,
      input    [31:0]  reg0x0001_i,
      input    [31:0]  reg0x0002_i,
      input    [31:0]  reg0x0003_i,
      input    [31:0]  reg0x0004_i,
      input    [31:0]  reg0x0005_i,
      input    [31:0]  reg0x0006_i,
      input    [31:0]  reg0x0007_i,
      input    [31:0]  reg0x0008_i,
      input    [31:0]  reg0x0009_i,
      input    [31:0]  reg0x000A_i,
      input    [31:0]  reg0x000B_i,
      
      output           reg_clk,
      output           reg_valid,
      output   [31:0]  reg0x0010_o,  // W/R
      output   [31:0]  reg0x0011_o,  
      output   [31:0]  reg0x0012_o,  
      output   [31:0]  reg0x0013_o,  
      output   [31:0]  reg0x0014_o,  
      output   [31:0]  reg0x0015_o,  
      output   [31:0]  reg0x0016_o,  
      output   [31:0]  reg0x0017_o,  
      output   [31:0]  reg0x0018_o,  
      output   [31:0]  reg0x0019_o,  
      output   [31:0]  reg0x0020_o,  
      output   [31:0]  reg0x0021_o,  
      output   [31:0]  reg0x0022_o,  
      output   [31:0]  reg0x0023_o,  
      output   [31:0]  reg0x0024_o,  
      //--------- reg of DDS -----------------------
       output   [31:0]   reg0x0040_o,  
       output   [31:0]   reg0x0041_o,
       output   [31:0]   reg0x0042_o,  
       output   [31:0]   reg0x0043_o,  
       output   [31:0]   reg0x0044_o,  
       output   [31:0]   reg0x0049_o,  
       output   [31:0]   reg0x004A_o,  
       output   [31:0]   reg0x004B_o,  
       output   [31:0]   reg0x004C_o,
       output   [31:0]   reg0x0051_o,
       output   [31:0]   reg0x0052_o,
       output   [31:0]   reg0x0055_o,
       output   [31:0]   reg0x0056_o
       );


wire        link_up_sfp;
wire        sync_done_sfp;
wire        resetdone_sfp;
wire        user_axis_clk_sfp;
wire        user_axis_resetn_sfp;
// Receiver (AXI-S) Interface
wire [7:0]  rx_axis_fifo_tdata_sfp;
wire        rx_axis_fifo_tvalid_sfp;
wire        rx_axis_fifo_tlast_sfp;
// Transmitter (AXI-S) Interface
reg  [7:0]  tx_axis_fifo_tdata_sfp = 0;
reg         tx_axis_fifo_tvalid_sfp = 0;
reg         tx_axis_fifo_tlast_sfp = 0;
wire        tx_axis_fifo_tready_sfp;  

//wire resetdone;    
wire gtrefclk_out;   
wire userclk_out;    
wire userclk2_out;  
wire rxuserclk_out;  
wire rxuserclk2_out; 
wire pma_reset_out;  
wire mmcm_locked_out;
//AWG_TEMAC_example_design #(
// .ILA_DEBUG(1'b0)
//) AWG_TEMAC_example_design_inst (
//   // Input Ports - Single Bit
//   .glbl_rst                (glbl_rst),             
//   .gtrefclk_in             (gtrefclk_out   ),
//   .userclk_in              (userclk_out    ),
//   .userclk2_in             (userclk2_out   ),
//   .rxuserclk_in            (rxuserclk_out  ),
//   .rxuserclk2_in           (rxuserclk2_out ),
//   .pma_reset_in            (pma_reset_out  ),
//   .mmcm_locked_in          (mmcm_locked_out),       
//   .independent_clock_bufg  (independent_clock_bufg),
    
//   .txn                     (txn),                  
//   .txp                     (txp), 
//   .rxn                     (rxn),                  
//   .rxp                     (rxp), 
//   .sync_done               (sync_done_sfp), 
//   .link_up                 (link_up_sfp), 
//   .resetdone               (resetdone_sfp), 
   
//   .user_axis_clk           (user_axis_clk_sfp),        
//   .user_axis_resetn        (user_axis_resetn_sfp),              
//   .tx_axis_fifo_tlast      (tx_axis_fifo_tlast_sfp),   
//   .tx_axis_fifo_tvalid     (tx_axis_fifo_tvalid_sfp),  
//   .tx_axis_fifo_tdata      (tx_axis_fifo_tdata_sfp[7:0]),
//   .tx_axis_fifo_tready     (tx_axis_fifo_tready_sfp),
                 
//   .rx_axis_fifo_tlast      (rx_axis_fifo_tlast_sfp),   
//   .rx_axis_fifo_tvalid     (rx_axis_fifo_tvalid_sfp), 
//   .rx_axis_fifo_tdata      (rx_axis_fifo_tdata_sfp[7:0]), 
//   .rx_axis_fifo_tready     (1'b1)            
//);    

wire        link_up_sgmii;
wire        sync_done_sgmii;
wire        resetdone_sgmii;

wire        user_axis_clk_sgmii;
wire        user_axis_resetn_sgmii;
// Receiver (AXI-S) Interface
wire [7:0]  rx_axis_fifo_tdata_sgmii;
wire        rx_axis_fifo_tvalid_sgmii;
wire        rx_axis_fifo_tlast_sgmii;
// Transmitter (AXI-S) Interface
reg  [7:0]  tx_axis_fifo_tdata_sgmii = 0;
reg         tx_axis_fifo_tvalid_sgmii = 0;
reg         tx_axis_fifo_tlast_sgmii = 0;
wire        tx_axis_fifo_tready_sgmii;  
SGMII_TEMAC_example_design #(
 .ILA_DEBUG(1'b1)
) SGMII_TEMAC_example_design_inst (
   // Input Ports - Single Bit
   .glbl_rst                (glbl_rst),    

   .gtrefclk_n              (gtrefclk_n),           
   .gtrefclk_p              (gtrefclk_p),  

   .gtrefclk_out            (gtrefclk_out),      
   .userclk_out             (userclk_out),
   .userclk2_out            (userclk2_out),
   .rxuserclk_out           (rxuserclk_out),
   .rxuserclk2_out          (rxuserclk2_out),
   .pma_reset_out           (pma_reset_out),    
   .mmcm_locked_out         (mmcm_locked_out),  
      
   .independent_clock_bufg  (independent_clock_bufg),
   .PHY_RESETn(PHY_RESETn),
   .PHY_INTn(PHY_INTn),
   .PHY_MDC(PHY_MDC),
   .PHY_MDIO(PHY_MDIO),
   .clk_config(clk_config),
   .locked(locked),
    
   .txn                     (txn_sgmii),                  
   .txp                     (txp_sgmii), 
   .rxn                     (rxn_sgmii),                  
   .rxp                     (rxp_sgmii), 
   .sync_done               (sync_done_sgmii), 
   .link_up                 (link_up_sgmii), 
   .resetdone               (resetdone_sgmii), 
   
   .user_axis_clk           (user_axis_clk_sgmii),        
   .user_axis_resetn        (user_axis_resetn_sgmii),              
   .tx_axis_fifo_tlast      (tx_axis_fifo_tlast_sgmii),   
   .tx_axis_fifo_tvalid     (tx_axis_fifo_tvalid_sgmii),  
   .tx_axis_fifo_tdata      (tx_axis_fifo_tdata_sgmii[7:0]),
   .tx_axis_fifo_tready     (tx_axis_fifo_tready_sgmii),
                 
   .rx_axis_fifo_tlast      (rx_axis_fifo_tlast_sgmii),   
   .rx_axis_fifo_tvalid     (rx_axis_fifo_tvalid_sgmii), 
   .rx_axis_fifo_tdata      (rx_axis_fifo_tdata_sgmii[7:0]), 
   .rx_axis_fifo_tready     (1'b1)            
);

wire        user_axis_clk;
wire        user_axis_resetn;
// Receiver (AXI-S) Interface
reg [7:0]  rx_axis_fifo_tdata;
reg        rx_axis_fifo_tvalid;
reg        rx_axis_fifo_tlast;
// Transmitter (AXI-S) Interface
wire  [7:0]  tx_axis_fifo_tdata;
wire         tx_axis_fifo_tvalid;
wire         tx_axis_fifo_tlast;
reg          tx_axis_fifo_tready; 

assign user_axis_clk = user_axis_clk_sgmii;

assign user_axis_resetn = link_up_sfp? user_axis_resetn_sfp : user_axis_resetn_sgmii;

assign user_axis_clk_out    = user_axis_clk;
assign user_axis_resetn_out = user_axis_resetn;

always@(posedge user_axis_clk)
 if(0) begin
   link_up   <= link_up_sfp;
   sync_done <= sync_done_sfp;
   resetdone <= resetdone_sfp;

   rx_axis_fifo_tdata  <= rx_axis_fifo_tdata_sfp ;
   rx_axis_fifo_tvalid <= rx_axis_fifo_tvalid_sfp;
   rx_axis_fifo_tlast  <= rx_axis_fifo_tlast_sfp ;

   tx_axis_fifo_tdata_sfp  <= tx_axis_fifo_tdata ;
   tx_axis_fifo_tvalid_sfp <= tx_axis_fifo_tvalid;
   tx_axis_fifo_tlast_sfp  <= tx_axis_fifo_tlast ;
   tx_axis_fifo_tready     <= tx_axis_fifo_tready_sfp; 
 end
 else begin
   link_up   <= link_up_sgmii;
   sync_done <= sync_done_sgmii;
   resetdone <= resetdone_sgmii;

   rx_axis_fifo_tdata  <= rx_axis_fifo_tdata_sgmii ;
   rx_axis_fifo_tvalid <= rx_axis_fifo_tvalid_sgmii;
   rx_axis_fifo_tlast  <= rx_axis_fifo_tlast_sgmii ;

   tx_axis_fifo_tdata_sgmii  <= tx_axis_fifo_tdata ;
   tx_axis_fifo_tvalid_sgmii <= tx_axis_fifo_tvalid;
   tx_axis_fifo_tlast_sgmii  <= tx_axis_fifo_tlast ;
   tx_axis_fifo_tready       <= tx_axis_fifo_tready_sgmii; 
 end

    
//ETHERTNET PARAMETER
wire     [47:0] DES_MAC_UDP;
wire     [47:0] SOR_MAC_UDP;
wire     [15:0] FRAME_TYPE_UDP;	 
wire     [15:0] IP_VERSION_UDP;
wire     [15:0] IP_PAC_ID_UDP;
wire     [31:0] IP_INF_UDP;
wire     [31:0] SOR_IP_UDP;
wire     [31:0] DES_IP_UDP;	 
wire     [15:0] SOR_PORT_UDP;
wire     [15:0] DES_PORT_UDP; 
wire     [15:0] DES_PORT_UDP_RX;  
wire     [15:0] DES_PORT_UDP_RX0;  
wire     [15:0] DES_PORT_UDP_RX1;  
wire     [15:0] DES_PORT_UDP_RX2;  
wire     [15:0] DES_PORT_UDP_RX3;   
wire     [15:0] DES_PORT_UDP_RX4;  
wire     [15:0] DES_PORT_UDP_RX5;  
wire     [15:0] DES_PORT_UDP_RX6;  
wire     [15:0] DES_PORT_UDP_RX7;  
wire     [15:0] DES_PORT_UDP_RX8;  
wire     [15:0] DES_PORT_UDP_RX9;  
wire     [15:0] DES_PORT_UDP_TX0;  
wire     [15:0] DES_PORT_UDP_TX1;  
wire     [15:0] DES_PORT_UDP_TX2;  
 
//assign SOR_MAC_UDP  	   = 48'hDA0102030405;  //
assign FRAME_TYPE_UDP	   = 16'h0800;
assign IP_VERSION_UDP	   = 16'h4500;
assign IP_PAC_ID_UDP 	   = 16'h0000; 	 	    //identification
assign IP_INF_UDP		   = 32'h0000FF11;      //Flags/Fragment/Time2live/Protocol
//assign SOR_IP_UDP		   = 32'hC0A80104;      //192.168.1.4
assign SOR_PORT_UDP 	   = 16'h7D00;          //FPGA 32000

assign DES_PORT_UDP_RX       = 16'h1BBC;           //7100  rx_test port
assign DES_PORT_UDP_RX0 	   = 16'h7D00;          //32000  write and read reg
assign DES_PORT_UDP_RX1 	   = 16'h7D01;          //32001  load waveform data to DDR3
assign DES_PORT_UDP_RX2 	   = 16'h7D02;          //32002  load waveform addr 
assign DES_PORT_UDP_RX3 	   = 16'h7D03;          //32003  load SEQ waveform addr 
assign DES_PORT_UDP_RX4 	   = 16'h7D04;          //32004  load marker data 
assign DES_PORT_UDP_RX5 	   = 16'h7D05;          //32005  load marker addr 
assign DES_PORT_UDP_RX6 	   = 16'h7D06;          //32006  load SEQ marker addr 
assign DES_PORT_UDP_RX7 	   = 16'h7D07;          //32007  load en data
assign DES_PORT_UDP_RX8 	   = 16'h7D08;          //32008  load SEQ addr
assign DES_PORT_UDP_RX9 	   = 16'h7D09;          //32009  load config files

assign DES_PORT_UDP_TX0 	   = 16'h7D00;          //32000  read resp 
assign DES_PORT_UDP_TX1 	   = 16'h7D03;          //32003  TX_DATA
assign DES_PORT_UDP_TX2 	   = 16'h1BBC;          //32003  TX_TEST_PORT
    
    //----------------------------------------------------------------------------
  //  ARP pattern generator
  //----------------------------------------------------------------------------
   wire  [7:0]          tx_axis_ARP_tdata; 
   wire                 tx_axis_ARP_tvalid;
   wire                 tx_axis_ARP_tlast;
   wire                 ARP_req_en;
   wire                 ARP_resp_en;
   
   wire PC_LOCKED;
   wire [31:0] reg0x0025_o;
   assign PC_LOCKED = reg0x0025_o[0];
   wire ARP_pc_req;   //use
   wire ARP_ACK;
  wire tx_ARP_busy;
  ARP_TOP#(
 .ILA_DEBUG(1'b1)
) ARP_TOP_INST(                                         
        .axi_tclk(user_axis_clk),      
        .axi_tresetn(user_axis_resetn),   
        .init_done(resetdone), 
        .PC_LOCKED(PC_LOCKED), 
        
        .READ_DONE(READ_DONE), 
        .FPGA_MAC(FPGA_MAC[47:0]),
        .FPGA_IP(FPGA_IP[31:0]),   
                      
        .rx_axis_tdata(rx_axis_fifo_tdata), 
        .rx_axis_tvalid(rx_axis_fifo_tvalid),
        .rx_axis_tlast(rx_axis_fifo_tlast), 
        .rx_axis_tready(),
                      
        .tx_axis_tdata(tx_axis_ARP_tdata), 
        .tx_axis_tvalid(tx_axis_ARP_tvalid),
        .tx_axis_tlast(tx_axis_ARP_tlast), 
        .tx_axis_tready(tx_axis_fifo_tready),
        
        .ARP_pc_req_o(ARP_pc_req),
        .ARP_ACK_i(ARP_ACK),
        .tx_ARP_busy(tx_ARP_busy),  
        .ARP_req_en(ARP_req_en),
        .ARP_resp_en(ARP_resp_en),
        .DES_MAC_ARP(DES_MAC_UDP),
        .DES_IP_ARP(DES_IP_UDP),          
        .SOR_MAC_UDP(SOR_MAC_UDP),  //DA0102030405 
        .SOR_IP_UDP(SOR_IP_UDP)     //default 192.168.1.8    c0 A8 01 08
        );
        
    //----------------------------------------------------------------------------
  //  ICMP pattern generator
  //----------------------------------------------------------------------------
  
   wire  [7:0]          tx_axis_ICMP_tdata; 
   wire                 tx_axis_ICMP_tvalid;
   wire                 tx_axis_ICMP_tlast;     
   wire                 tx_ICMP_busy; 
   
   wire                 ICMP_pc_req; //use
   wire                 ICMP_ACK;
  ICMP_TOP ICMP_TOP_INST(
    .axi_tclk(user_axis_clk),
    .axi_tresetn(user_axis_resetn),
    .init_done(resetdone),
    
    .rx_axis_tdata(rx_axis_fifo_tdata),
    .rx_axis_tvalid(rx_axis_fifo_tvalid),
    .rx_axis_tlast(rx_axis_fifo_tlast),
    .rx_axis_tready(),
    
    .tx_axis_tdata(tx_axis_ICMP_tdata),
    .tx_axis_tvalid(tx_axis_ICMP_tvalid),
    .tx_axis_tlast(tx_axis_ICMP_tlast),
    .tx_axis_tready(tx_axis_fifo_tready),
    
    .ICMP_pc_req_o(ICMP_pc_req),
    .ICMP_ACK_i(ICMP_ACK), 
    .tx_ICMP_busy(tx_ICMP_busy),
    .SOR_MAC_UDP(SOR_MAC_UDP),
    .SOR_IP_UDP(SOR_IP_UDP)
    );  
   
   //----------------------------------------------------------------------------
  //  UDP pattern generator
  //----------------------------------------------------------------------------
   wire  [7:0]          tx_axis_UDP_tdata; 
   wire                 tx_axis_UDP_tvalid;
   wire                 tx_axis_UDP_tlast; 
   
   wire [31:0] wr_num;
//   assign wr_num = 32'd1000;
   wire       tx_fifo_wr_en ;
   wire [7:0] tx_fifo_din ;
   wire [9:0] wr_data_count;
   
   wire wr_done;
 LAN_TX_TOP#(
 .ILA_DEBUG(1'b0)
) LAN_TX_TOP_inst (
   // Input Ports - Single Bit
   .fifo_wr_clk             (user_axis_clk), //  TEST
   .wr_num                  (wr_num[31:0]),                           
   .tx_fifo_wr_en           (tx_fifo_wr_en), 
   .tx_fifo_din             (tx_fifo_din[7:0]),  
   .wr_data_count           (wr_data_count),   
   .wr_done                 (wr_done),     
   // ETH     
   .DES_MAC                 (48'hFFFF_FFFF_FFFF),  //DES_MAC_UDP[47:0]   GUANGBO
   .SOR_MAC                 (SOR_MAC_UDP[47:0]),           
   .FRAME_TYPE              (FRAME_TYPE_UDP[15:0]),
   //IP
   .IP_VERSION              (IP_VERSION_UDP[15:0]),     
   .IP_INF                  (IP_INF_UDP[31:0]),         
   .IP_PAC_ID               (IP_PAC_ID_UDP[15:0]),      
   .DES_IP                  (32'hFFFF_FFFF),       //DES_IP_UDP[31:0]   GUANGBO
   .SOR_IP                  (SOR_IP_UDP[31:0]), 
   //UDP          
   .DES_PORT                (DES_PORT_UDP[15:0]),       
   .SOR_PORT                (SOR_PORT_UDP[15:0]),       

   .tx_fifo_clock           (user_axis_clk),        
   .tx_fifo_resetn          (user_axis_resetn),
   .tx_axis_fifo_tready     (tx_axis_fifo_tready),
   .tx_axis_fifo_tlast      (tx_axis_UDP_tlast),   
   .tx_axis_fifo_tvalid     (tx_axis_UDP_tvalid),  
   .tx_axis_fifo_tdata      (tx_axis_UDP_tdata[7:0])        
); 

//   assign tx_axis_fifo_tdata  = tx_ARP_busy? tx_axis_ARP_tdata:(tx_ICMP_busy? tx_axis_ICMP_tdata:tx_axis_UDP_tdata); 
//   assign tx_axis_fifo_tvalid = tx_ARP_busy? tx_axis_ARP_tvalid:(tx_ICMP_busy? tx_axis_ICMP_tvalid:tx_axis_UDP_tvalid);
//   assign tx_axis_fifo_tlast  = tx_ARP_busy? tx_axis_ARP_tlast:(tx_ICMP_busy? tx_axis_ICMP_tlast:tx_axis_UDP_tlast);  
     
  //----------------------------------------------------------------------------
  //  UDP pattern receive
  //----------------------------------------------------------------------------  
 wire [15:0] LAN_DATA_NUM;
 wire        lan_data_valid;
 wire [7:0]  lan_data_out;
 wire [3:0]  LAN_RX_TYPE; 
ETH_LAN_RX#(
 .ILA_DEBUG(1'b1)
) ETH_LAN_RX_INST(
			.clk(user_axis_clk),
			.reset_n(user_axis_resetn),
			.init_done(resetdone),
      
			.lan_data_en(!rx_axis_fifo_tvalid),
			.lan_data_in(rx_axis_fifo_tdata),
			.rx_axis_fifo_tlast(rx_axis_fifo_tlast),
      
		    .SOR_MAC_i(SOR_MAC_UDP),      //for board
		    .SOR_IP_i(SOR_IP_UDP),       //for board
		    .SOR_PORT_UDP_i(SOR_PORT_UDP),
		    .DES_PORT_UDP_RX_i(DES_PORT_UDP_RX), //test port
        .DES_PORT_UDP_RX0_i(DES_PORT_UDP_RX0), //write and read reg port
        .DES_PORT_UDP_RX1_i(DES_PORT_UDP_RX1),
        .DES_PORT_UDP_RX2_i(DES_PORT_UDP_RX2),
        .DES_PORT_UDP_RX3_i(DES_PORT_UDP_RX3),
        .DES_PORT_UDP_RX4_i(DES_PORT_UDP_RX4),
        .DES_PORT_UDP_RX5_i(DES_PORT_UDP_RX5),
        .DES_PORT_UDP_RX6_i(DES_PORT_UDP_RX6),
        .DES_PORT_UDP_RX7_i(DES_PORT_UDP_RX7),
        .DES_PORT_UDP_RX8_i(DES_PORT_UDP_RX8),
        .DES_PORT_UDP_RX9_i(DES_PORT_UDP_RX9),
        .LAN_DATA_NUM(LAN_DATA_NUM),
        .LAN_RX_TYPE(LAN_RX_TYPE),
			  .lan_data_valid(lan_data_valid),   //64 byte data valid
			  .lan_data_out(lan_data_out)     //64 byte data     
);

//----------------------------------------------------------------------------
  //  test  //ceshi huifa
  //----------------------------------------------------------------------------  
 wire [15:0] LAN_DATA_NUM_test;
 wire        lan_data_valid_test;
 wire [7:0]  lan_data_out_test;
TEST_TX_RESP TEST_TX_RESP_inst (   
   // Input Ports        
   .tx_fifo_clock        (user_axis_clk),    
   .reset_n              (user_axis_resetn),  
   .lan_data_valid_i     (lan_data_valid),  
   .lan_data_i           (lan_data_out[7:0]),   
   .LAN_DATA_NUM_i       (LAN_DATA_NUM[15:0]),
   .LAN_RX_TYPE_i        (LAN_RX_TYPE[3:0]),
   // Output Ports 
   .LAN_DATA_NUM_o      (LAN_DATA_NUM_test),    //[15:0]
   .lan_data_valid_o    (lan_data_valid_test), 
   .lan_data_out_o      (lan_data_out_test)     //[7:0]
);
 
 //----------------------------------------------------------------------------
  // write or read reg 
  //---------------------------------------------------------------------------- 
  wire RD_REG_req;
  wire RD_ACK;
  wire [15:0] LAN_DATA_NUM_rd;
  wire        lan_data_valid_rd;
  wire [7:0]  lan_data_rd;
  
//  wire   [31:0]  reg0x0010_o;  // W/R
//  wire   [31:0]  reg0x0011_o;  
//  wire   [31:0]  reg0x0012_o;  
//  wire   [31:0]  reg0x0013_o;  
//  wire   [31:0]  reg0x0014_o;  
//  wire   [31:0]  reg0x0015_o;  
//  wire   [31:0]  reg0x0016_o;  
//  wire   [31:0]  reg0x0017_o;  
//  wire   [31:0]  reg0x0018_o;  
//  wire   [31:0]  reg0x0019_o;  
//  wire   [31:0]  reg0x0020_o;  
//  wire   [31:0]  reg0x0021_o;  
//  wire   [31:0]  reg0x0022_o;    
//  wire   [31:0]  reg0x0040_o;  
//  wire   [31:0]  reg0x0041_o;  
//  wire   [31:0]  reg0x0042_o;  
//  wire   [31:0]  reg0x0043_o;  
//  wire   [31:0]  reg0x0044_o;  
//  wire   [31:0]  reg0x0049_o;  
//  wire   [31:0]  reg0x004A_o;  
//  wire   [31:0]  reg0x004B_o;  
//  wire   [31:0]  reg0x004C_o;
//  wire   [31:0]  reg0x0051_o;
//  wire   [31:0]  reg0x0052_o;
//  wire   [31:0]  reg0x0055_o;
//  wire   [31:0]  reg0x0056_o;

wire   [31:0]  reg0x0026_o;

(* dont_touch="true" *)reg sys_rst0 = 1'b0;
(* dont_touch="true" *)reg sys_rst1 = 1'b0;
(* dont_touch="true" *)reg sys_rst2 = 1'b0;
(* dont_touch="true" *)reg sys_rst3 = 1'b0;
(* dont_touch="true" *)reg cfg_rst  = 1'b0;
always@(posedge user_axis_clk)begin
  sys_rst0 <= reg0x0026_o[0]; 
  sys_rst1 <= reg0x0026_o[1]; 
  sys_rst2 <= reg0x0026_o[2]; 
  sys_rst3 <= reg0x0026_o[3]; 
  cfg_rst  <= reg0x0026_o[4]; 
end
   
 WR_RD_REG_TOP#(
 .ILA_DEBUG(1'b1)
) WR_RD_REG_TOP_inst (

   .tx_fifo_clock        (user_axis_clk),          
   .reset_n              (user_axis_resetn),           
      
     
   .lan_data_valid_i     (lan_data_valid),
   .lan_data_i           (lan_data_out[7:0]),   
   .LAN_DATA_NUM_i       (LAN_DATA_NUM[15:0]),
   .LAN_RX_TYPE_i        (LAN_RX_TYPE[3:0]),
    
   .RD_ACK_i             (RD_ACK),
   .RD_REG_req_o         (RD_REG_req),
   .LAN_DATA_NUM_o       (LAN_DATA_NUM_rd[15:0]),
   .lan_data_valid_o     (lan_data_valid_rd),    
   .lan_data_o           (lan_data_rd[7:0]),  

   .chn0_rep_done(chn0_rep_done),
  .chn1_rep_done(chn1_rep_done),
  .chn2_rep_done(chn2_rep_done),
  .chn3_rep_done(chn3_rep_done),
   
   .reg0x0000_i    (reg0x0000_i), 
   .reg0x0001_i    (reg0x0001_i), 
   .reg0x0002_i    (reg0x0002_i), 
   .reg0x0003_i    (reg0x0003_i), 
   .reg0x0004_i    (reg0x0004_i), 
   .reg0x0005_i    (reg0x0005_i), 
   .reg0x0006_i    (reg0x0006_i), 
   .reg0x0007_i    (reg0x0007_i), 
   .reg0x0008_i    (reg0x0008_i), 
   .reg0x0009_i    (reg0x0009_i), 
   .reg0x000A_i    (reg0x000A_i), 
   .reg0x000B_i    (reg0x000B_i), 
   
   .reg_clk        (reg_clk),
   .reg_valid      (reg_valid),
   .reg0x0010_o    (reg0x0010_o[31:0]), 
   .reg0x0011_o    (reg0x0011_o[31:0]), 
   .reg0x0012_o    (reg0x0012_o[31:0]), 
   .reg0x0013_o    (reg0x0013_o[31:0]), 
   .reg0x0014_o    (reg0x0014_o[31:0]), 
   .reg0x0015_o    (reg0x0015_o[31:0]), 
   .reg0x0016_o    (reg0x0016_o[31:0]), 
   .reg0x0017_o    (reg0x0017_o[31:0]), 
   .reg0x0018_o    (reg0x0018_o[31:0]), 
   .reg0x0019_o    (reg0x0019_o[31:0]), 
   .reg0x0020_o    (reg0x0020_o[31:0]), 
   .reg0x0021_o    (reg0x0021_o[31:0]), 
   .reg0x0022_o    (reg0x0022_o[31:0]), 
   .reg0x0023_o    (reg0x0023_o[31:0]), 
   .reg0x0024_o    (reg0x0024_o[31:0]), 
   .reg0x0025_o    (reg0x0025_o[31:0]), 
   .reg0x0026_o    (reg0x0026_o[31:0]), 
   .reg0x0040_o    (reg0x0040_o[31:0]), 
   .reg0x0041_o    (reg0x0041_o[31:0]), 
   .reg0x0042_o    (reg0x0042_o[31:0]), 
   .reg0x0043_o    (reg0x0043_o[31:0]), 
   .reg0x0044_o    (reg0x0044_o[31:0]), 
   .reg0x0049_o    (reg0x0049_o[31:0]),
   .reg0x004A_o    (reg0x004A_o[31:0]), 
   .reg0x004B_o    (reg0x004B_o[31:0]), 
   .reg0x004C_o    (reg0x004C_o[31:0]), 
   .reg0x0051_o    (reg0x0051_o[31:0]), 
   .reg0x0052_o    (reg0x0052_o[31:0]), 
   .reg0x0055_o    (reg0x0055_o[31:0]), 
   .reg0x0056_o    (reg0x0056_o[31:0]) 
);  
//----------------------------------------------------------------------------
  //write or read EPROM
  //---------------------------------------------------------------------------- 
wire RD_EPROM_ACK;
wire RD_EPROM_req;
wire [15:0] LAN_DATA_NUM_EPROM;
wire        lan_data_valid_EPROM;
wire [7:0]  lan_data_EPROM;
//----------------------------------------------------------------------------
  // test tx data
  //---------------------------------------------------------------------------- 
 wire data_en;
 wire data_req;
 wire data_ACK;
 wire [15:0] data_wr_num;
 wire [7:0] data_tx_data;
 wire       data_tx_valid;
 wire       tx_data_done;
 LAN_TX_FREAME LAN_TX_FREAME_inst(
          .tx_clk(user_axis_clk),
          .resetn(user_axis_resetn),  
          
          .wr_data_count(wr_data_count),
          .tx_data_done(tx_data_done),
          .data_en(data_en),
          .data_req_o(data_req),
          .data_ACK_i(data_ACK),
          .data_wr_num_o(data_wr_num),         //data port input [15:0]
          .data_tx_data_o(data_tx_data),     //[7:0]
          .data_tx_valid_o(data_tx_valid)
    );
  
 //----------------------------------------------------------------------------
  // ETHERNET Arbitrator
  //----------------------------------------------------------------------------  
  LAN_TX_MUX LAN_TX_MUX_inst(
    .fifo_wr_clk_i         (user_axis_clk),
    .resetn_i               (user_axis_resetn),
	  //UDP
	.tx_fifo_full_i        (),    //UDP port
	.wr_done_i             (wr_done),
    .wr_num_o              (wr_num),
    .tx_fifo_din_o         (tx_fifo_din),
    .tx_fifo_wr_en_o       (tx_fifo_wr_en),
    .DES_PORT_o            (DES_PORT_UDP),
    //TEST
    .test_wr_num_i         (LAN_DATA_NUM_test),    //test port input
    .test_tx_data_i        (lan_data_out_test),
    .test_tx_valid_i       (lan_data_valid_test),
    .test_port             (DES_PORT_UDP_TX2),
    //READ REG
    .RD_REG_req_i          (RD_REG_req),
    .RD_ACK_o              (RD_ACK),
    .read_resp_wr_num_i    (LAN_DATA_NUM_rd),    //read reg resp port input
    .read_resp_tx_data_i   (lan_data_rd),
    .read_resp_tx_valid_i  (lan_data_valid_rd),
    .read_resp_port        (DES_PORT_UDP_TX0),
    //
    .RD_EPROM_ACK(RD_EPROM_ACK),
    .RD_EPROM_req(RD_EPROM_req),
    .LAN_DATA_NUM_EPROM(LAN_DATA_NUM_EPROM),
    .lan_data_valid_EPROM(lan_data_valid_EPROM),
    .lan_data_EPROM(lan_data_EPROM),   //DES_PORT_UDP_TX0
    //TX_DATA
    .tx_data_done          (tx_data_done),
    .data_req_i            (data_req),
    .data_ACK_o            (data_ACK),
    .data_wr_num_i         (data_wr_num),         //data port input
    .data_tx_data_i        (data_tx_data),
    .data_tx_valid_i       (data_tx_valid),
    .data_port             (DES_PORT_UDP_TX1),
    //ARP
    .ARP_pc_req_i          (ARP_pc_req),
    .ARP_ACK_o             (ARP_ACK),
    .tx_axis_ARP_tdata     (tx_axis_ARP_tdata), 
    .tx_axis_ARP_tvalid    (tx_axis_ARP_tvalid),
    .tx_axis_ARP_tlast     (tx_axis_ARP_tlast),
    //PING
    .ICMP_pc_req_i         (ICMP_pc_req),
    .ICMP_ACK_o            (ICMP_ACK),
    .tx_axis_ICMP_tdata    (tx_axis_ICMP_tdata), 
    .tx_axis_ICMP_tvalid   (tx_axis_ICMP_tvalid),
    .tx_axis_ICMP_tlast    (tx_axis_ICMP_tlast),
    //UDP
    .tx_axis_UDP_tdata     (tx_axis_UDP_tdata),
    .tx_axis_UDP_tvalid    (tx_axis_UDP_tvalid),
    .tx_axis_UDP_tlast     (tx_axis_UDP_tlast),
    //ETH_FIFO
    .tx_axis_fifo_tdata    (tx_axis_fifo_tdata),
    .tx_axis_fifo_tvalid   (tx_axis_fifo_tvalid),
    .tx_axis_fifo_tlast    (tx_axis_fifo_tlast)
     
    ); 

generate  
  if(ILA_DEBUG) begin:ila_debug   
   vio_ethernet_top inst0(
  .clk(user_axis_clk),                // input wire clk
  .probe_out0(ARP_req_en),  // output wire [0 : 0] probe_out0
  .probe_out1(data_en)  // output wire [0 : 0] probe_out1
);   
end
else begin
    assign ARP_req_en = 1'b0;
    assign data_en    = 1'b0;
end
endgenerate  
    
endmodule

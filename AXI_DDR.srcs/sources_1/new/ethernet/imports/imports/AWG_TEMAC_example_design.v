//------------------------------------------------------------------------------
// File       : AWG_TEMAC_example_design.v
// Author     : Xilinx Inc.
// -----------------------------------------------------------------------------
// (c) Copyright 2004-2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// -----------------------------------------------------------------------------
// Description:  This is the Verilog example design for the Tri-Mode
//               Ethernet MAC core. It is intended that this example design
//               can be quickly adapted and downloaded onto an FPGA to provide
//               a real hardware test environment.
//
//               This level:
//
//               * Instantiates the FIFO Block wrapper, containing the
//                 block level wrapper and an RX and TX FIFO with an
//                 AXI-S interface;
//
//               * Instantiates a simple AXI-S example design,
//                 providing an address swap and a simple
//                 loopback function;
//
//               * Instantiates transmitter clocking circuitry
//                   -the User side of the FIFOs are clocked at gtx_clk
//                    at all times
//
//               * Instantiates a state machine which drives the configuration
//                 vector to bring the TEMAC up in the correct state
//
//               * Serializes the Statistics vectors to prevent logic being
//                 optimized out
//
//               * Ties unused inputs off to reduce the number of IO
//
//               Please refer to the Datasheet, Getting Started Guide, and
//               the Tri-Mode Ethernet MAC User Gude for further information.
//
//    --------------------------------------------------
//    | EXAMPLE DESIGN WRAPPER                         |
//    |                                                |
//    |                                                |
//    |   -------------------     -------------------  |
//    |   |                 |     |                 |  |
//    |   |    Clocking     |     |     Resets      |  |
//    |   |                 |     |                 |  |
//    |   -------------------     -------------------  |
//    |           -------------------------------------|
//    |           |FIFO BLOCK WRAPPER                  |
//    |           |                                    |
//    |           |                                    |
//    |           |              ----------------------|
//    |           |              | SUPPORT LEVEL       |
//    | --------  |              |                     |
//    | |      |  |              |                     |
//    | | CNFG |->|------------->|                     |
//    | | VEC  |  |              |                     |
//    | | SM   |  |              |                     |
//    | |      |<-|<-------------|                     |
//    | |      |  |              |                     |
//    | --------  |              |                     |
//    |           |              |                     |
//    | --------  |  ----------  |                     |
//    | |      |  |  |        |  |                     |
//    | |      |->|->|        |->|                     |
//    | | PAT  |  |  |        |  |                     |
//    | | GEN  |  |  |        |  |                     |
//    | |(ADDR |  |  |  AXI-S |  |                     |
//    | | SWAP)|  |  |  FIFO  |  |                     |
//    | |      |  |  |        |  |                     |
//    | |      |  |  |        |  |                     |
//    | |      |  |  |        |  |                     |
//    | |      |<-|<-|        |<-|                     |
//    | |      |  |  |        |  |                     |
//    | --------  |  ----------  |                     |
//    |           |              |                     |
//    |           |              ----------------------|
//    |           -------------------------------------|
//    --------------------------------------------------

//------------------------------------------------------

`timescale 1 ps/1 ps


//------------------------------------------------------------------------------
// The module declaration for the example_design level wrapper.
//------------------------------------------------------------------------------

(* DowngradeIPIdentifiedWarnings = "yes" *)
module AWG_TEMAC_example_design#(
 parameter ILA_DEBUG = 1'b0
)
   (
      // input        gtrefclk_p,                // differential clock
      // input        gtrefclk_n,                // differential clock
      // output       gtrefclk_out,
      input        gtrefclk_in,   
      input        userclk_in,    
      input        userclk2_in,   
      input        rxuserclk_in,  
      input        rxuserclk2_in, 
      input        pma_reset_in,  
      input        mmcm_locked_in,
      
      output       txp,                   // Differential +ve of serial transmission from PMA to PMD.
      output       txn,                   // Differential -ve of serial transmission from PMA to PMD.
      input        rxp,                   // Differential +ve for serial reception from PMD to PMA.
      input        rxn,                   // Differential -ve for serial reception from PMD to PMA.
      
      input            independent_clock_bufg, //50M
      output       reg link_up = 1'b0,
      output       reg sync_done = 1'b0,
      output       reg resetdone = 1'b0,
      
      // asynchronous reset
      input         glbl_rst,
      
      //---------------------------------------- 
      output        user_axis_clk,
      output        user_axis_resetn,
      // Receiver (AXI-S) Interface
      output [7:0]  rx_axis_fifo_tdata,
      output        rx_axis_fifo_tvalid,
      input         rx_axis_fifo_tready,
      output        rx_axis_fifo_tlast,
      // Transmitter (AXI-S) Interface
      input  [7:0]  tx_axis_fifo_tdata,
      input         tx_axis_fifo_tvalid,
      output        tx_axis_fifo_tready,
      input         tx_axis_fifo_tlast
 
      // Serialised statistics vectors
      //------------------------------
//      output        tx_statistics_s,
//      output        rx_statistics_s,

//      // Serialised Pause interface controls
//      //------------------------------------
//      input         pause_req_s,

//      // Main example design controls
//      //-----------------------------
//      input  [1:0]  mac_speed,
//      input         update_speed,
//      //input         serial_command, // tied to pause_req_s
//      input         config_board,
//      output        serial_response,
//      input         gen_tx_data,
//      input         chk_tx_data,
//      input         reset_error,
//      output        frame_error,
//      output        frame_errorn,
//      output        activity_flash,
//      output        activity_flashn

    );
    
    wire         pause_req_s;  //SW3
    assign      pause_req_s = 1'b0;
    
    wire  [1:0]  mac_speed;     //SW6[1] SW7[0]
    wire         update_speed;  //BUTTON SW6
    assign mac_speed    = 2'b10;
    assign update_speed = 1'b0;
    wire         reset_error;  //BUTTON SW5
    assign reset_error = 1'b0;
    
    wire        tx_statistics_s;
    wire        rx_statistics_s;

   //----------------------------------------------------------------------------
   // internal signals used in this top level wrapper.
   //----------------------------------------------------------------------------

   // example design clocks
   wire                 userclk2;
   wire                 gtx_clk_bufg;
   
   wire                 s_axi_aclk;
   assign gtx_clk_bufg = userclk2;
   assign s_axi_aclk   = userclk2;
   
   wire                 rx_mac_aclk;
   wire                 tx_mac_aclk;
   // resets (and reset generation)
   wire                 vector_resetn;
   wire                 chk_resetn;
   
   wire                 gtx_resetn;
   
   wire                 rx_reset;
   wire                 tx_reset;

   wire                 glbl_rst_intn;
// GMII Interface
   wire  [7:0]          gmii_txd_int;
   wire                 gmii_tx_en_int;
   wire                 gmii_tx_er_int;
   wire   [7:0]         gmii_rxd_int;
   wire                 gmii_rx_dv_int;
   wire                 gmii_rx_er_int;

//   // USER side RX AXI-S interface
   wire                 rx_fifo_clock;
   wire                 rx_fifo_resetn;
   
//   wire  [7:0]          rx_axis_fifo_tdata;
//   wire                 rx_axis_fifo_tvalid;
//   wire                 rx_axis_fifo_tlast;
//   wire                 rx_axis_fifo_tready;

//   // USER side TX AXI-S interface
   wire                 tx_fifo_clock;
   wire                 tx_fifo_resetn;
   
//   wire  [7:0]          tx_axis_fifo_tdata;
   
//   wire                 tx_axis_fifo_tvalid;
//   wire                 tx_axis_fifo_tlast;
//   wire                 tx_axis_fifo_tready;

   // RX Statistics serialisation signals
   wire                 rx_statistics_valid;
   reg                  rx_statistics_valid_reg;
   wire  [27:0]         rx_statistics_vector;
   reg   [27:0]         rx_stats;
   reg   [29:0]         rx_stats_shift;
   reg                  rx_stats_toggle = 0;
   wire                 rx_stats_toggle_sync;
   reg                  rx_stats_toggle_sync_reg = 0;

   // TX Statistics serialisation signals
   wire                 tx_statistics_valid;
   reg                  tx_statistics_valid_reg;
   wire  [31:0]         tx_statistics_vector;
   reg   [31:0]         tx_stats;
   reg   [33:0]         tx_stats_shift;
   reg                  tx_stats_toggle = 0;
   wire                 tx_stats_toggle_sync;
   reg                  tx_stats_toggle_sync_reg = 0;

   // Pause interface DESerialisation
   reg   [18:0]         pause_shift;
   reg                  pause_req;
   reg   [15:0]         pause_val;

   wire  [79:0]         rx_configuration_vector;
   wire  [79:0]         tx_configuration_vector;

   wire                 int_frame_error;
   wire                 int_activity_flash;

   // set board defaults - only updated when reprogrammed
   reg                  enable_address_swap = 1;

   // signal tie offs
   wire  [7:0]          tx_ifg_delay = 0;    // not used in this example

//   assign activity_flash  = int_activity_flash;
//   assign activity_flashn = !int_activity_flash;

//  assign serial_response = 0;

//  assign frame_error  = int_frame_error;
//  assign frame_errorn = !int_frame_error;
  
//  // when the config_board button is pushed capture and hold the
//  // state of the gne/chek tx_data inputs.  These values will persist until the
//  // board is reprogrammed or config_board is pushed again
//  always @(posedge gtx_clk_bufg)
//  begin
//     if (config_board) begin
//        enable_address_swap   <= gen_tx_data;
//     end
//  end

//wire userclk2;
  
//  // Clock logic assumes only 125MHz is available
   
//  AWG_TEMAC_example_design_clocks example_clocks
//   (
//      .gtx_clk          (gtx_clk),
      
      

//      // clock outputs
//      .gtx_clk_bufg     (gtx_clk_bufg),
//      .s_axi_aclk       (s_axi_aclk)
//   );

  //----------------------------------------------------------------------------
  // Generate the user side clocks for the axi fifos
  //----------------------------------------------------------------------------
   
  assign tx_fifo_clock = gtx_clk_bufg;
  assign rx_fifo_clock = gtx_clk_bufg;
  assign user_axis_clk = gtx_clk_bufg;
   

//  //----------------------------------------------------------------------------
//  // Pipeline the gmii_tx outputs - this is only necessary for the example design
//  // and can be removed when connected internally
//  //----------------------------------------------------------------------------

//  always @(posedge gtx_clk_bufg)
//  begin
//     gmii_txd        <= gmii_txd_int;
//     gmii_tx_en      <= gmii_tx_en_int;
//     gmii_tx_er      <= gmii_tx_er_int;
//     gmii_rxd_int    <= gmii_rxd;
//     gmii_rx_dv_int  <= gmii_rx_dv;
//     gmii_rx_er_int  <= gmii_rx_er;
//  end


  //----------------------------------------------------------------------------
  // Generate resets required for the fifo side signals etc
  //----------------------------------------------------------------------------
   wire reset_done;
   AWG_TEMAC_example_design_resets example_resets
   (
      // clocks
      .s_axi_aclk       (s_axi_aclk),
      .gtx_clk          (gtx_clk_bufg),

      // asynchronous resets
      .glbl_rst         (glbl_rst || (!reset_done)),
      .reset_error      (reset_error),
      .rx_reset         (rx_reset),
      .tx_reset         (tx_reset),

      // asynchronous reset output
  
      .glbl_rst_intn    (glbl_rst_intn),
      // synchronous reset outputs
   
   
      .gtx_resetn       (gtx_resetn),
   
      .vector_resetn    (vector_resetn),
      .chk_resetn       (chk_resetn)
   );


   // generate the user side resets for the axi fifos
   
   assign tx_fifo_resetn   = gtx_resetn;
   assign rx_fifo_resetn   = gtx_resetn;
   assign user_axis_resetn = gtx_resetn;
   

  //----------------------------------------------------------------------------
  // Serialize the stats vectors
  // This is a single bit approach, retimed onto gtx_clk
  // this code is only present to prevent code being stripped..
  //----------------------------------------------------------------------------

  // RX STATS

  // first capture the stats on the appropriate clock
  always @(posedge rx_mac_aclk)
  begin
     rx_statistics_valid_reg <= rx_statistics_valid;
     if (!rx_statistics_valid_reg & rx_statistics_valid) begin
        rx_stats <= rx_statistics_vector;
        rx_stats_toggle <= !rx_stats_toggle;
     end
  end

  AWG_TEMAC_sync_block rx_stats_sync (
     .clk              (gtx_clk_bufg),
     .data_in          (rx_stats_toggle),
     .data_out         (rx_stats_toggle_sync)
  );

  always @(posedge gtx_clk_bufg)
  begin
     rx_stats_toggle_sync_reg <= rx_stats_toggle_sync;
  end

  // when an update is rxd load shifter (plus start/stop bit)
  // shifter always runs (no power concerns as this is an example design)
  always @(posedge gtx_clk_bufg)
  begin
     if (rx_stats_toggle_sync_reg != rx_stats_toggle_sync) begin
        rx_stats_shift <= {1'b1, rx_stats, 1'b1};
     end
     else begin
        rx_stats_shift <= {rx_stats_shift[28:0], 1'b0};
     end
  end

  assign rx_statistics_s = rx_stats_shift[29];

  // TX STATS

  // first capture the stats on the appropriate clock
  always @(posedge tx_mac_aclk)
  begin
     tx_statistics_valid_reg <= tx_statistics_valid;
     if (!tx_statistics_valid_reg & tx_statistics_valid) begin
        tx_stats <= tx_statistics_vector;
        tx_stats_toggle <= !tx_stats_toggle;
     end
  end

  AWG_TEMAC_sync_block tx_stats_sync (
     .clk              (gtx_clk_bufg),
     .data_in          (tx_stats_toggle),
     .data_out         (tx_stats_toggle_sync)
  );

  always @(posedge gtx_clk_bufg)
  begin
     tx_stats_toggle_sync_reg <= tx_stats_toggle_sync;
  end

  // when an update is txd load shifter (plus start bit)
  // shifter always runs (no power concerns as this is an example design)
  always @(posedge gtx_clk_bufg)
  begin
     if (tx_stats_toggle_sync_reg != tx_stats_toggle_sync) begin
        tx_stats_shift <= {1'b1, tx_stats, 1'b1};
     end
     else begin
        tx_stats_shift <= {tx_stats_shift[32:0], 1'b0};
     end
  end

  assign tx_statistics_s = tx_stats_shift[33];

  //----------------------------------------------------------------------------
  // DSerialize the Pause interface
  // This is a single bit approachtimed on gtx_clk
  // this code is only present to prevent code being stripped..
  //----------------------------------------------------------------------------
  // the serialised pause info has a start bit followed by the quanta and a stop bit
  // capture the quanta when the start bit hits the msb and the stop bit is in the lsb
  always @(posedge gtx_clk_bufg)
  begin
     pause_shift <= {pause_shift[17:0], pause_req_s};
  end

  always @(posedge gtx_clk_bufg)
  begin
     if (pause_shift[18] == 1'b0 & pause_shift[17] == 1'b1 & pause_shift[0] == 1'b1) begin
        pause_req <= 1'b1;
        pause_val <= pause_shift[16:1];
     end
     else begin
        pause_req <= 1'b0;
        pause_val <= 0;
     end
  end

  //----------------------------------------------------------------------------
  // Instantiate the Config vector controller Controller
  //----------------------------------------------------------------------------
   AWG_TEMAC_config_vector_sm config_vector_controller (
   
      .gtx_clk                      (gtx_clk_bufg),
   
      .gtx_resetn                   (vector_resetn),

      .mac_speed                    (mac_speed),
      .update_speed                 (update_speed),   // may need glitch protection on this..

      .rx_configuration_vector      (rx_configuration_vector),
      .tx_configuration_vector      (tx_configuration_vector)
   );


  //----------------------------------------------------------------------------
  // Instantiate the TRIMAC core fifo block wrapper
  //----------------------------------------------------------------------------
  wire        speedis100;
  wire        speedis10100;
  AWG_TEMAC_fifo_block trimac_fifo_block (
      .gtx_clk                      (gtx_clk_bufg),
      
       
      // asynchronous reset
      .glbl_rstn                    (glbl_rst_intn),
      .rx_axi_rstn                  (1'b1),
      .tx_axi_rstn                  (1'b1),

      // Receiver Statistics Interface
      //---------------------------------------
      .rx_mac_aclk                  (rx_mac_aclk),
      .rx_reset                     (rx_reset),
      .rx_statistics_vector         (rx_statistics_vector),
      .rx_statistics_valid          (rx_statistics_valid),

      // Receiver (AXI-S) Interface
      //----------------------------------------
      .rx_fifo_clock                (rx_fifo_clock),
      .rx_fifo_resetn               (rx_fifo_resetn),
      .rx_axis_fifo_tdata           (rx_axis_fifo_tdata),
      .rx_axis_fifo_tvalid          (rx_axis_fifo_tvalid),
      .rx_axis_fifo_tready          (rx_axis_fifo_tready),
      .rx_axis_fifo_tlast           (rx_axis_fifo_tlast),
       
      // Transmitter Statistics Interface
      //------------------------------------------
      .tx_mac_aclk                  (tx_mac_aclk),
      .tx_reset                     (tx_reset),
      .tx_ifg_delay                 (tx_ifg_delay),
      .tx_statistics_vector         (tx_statistics_vector),
      .tx_statistics_valid          (tx_statistics_valid),

      // Transmitter (AXI-S) Interface
      //-------------------------------------------
      .tx_fifo_clock                (tx_fifo_clock),
      .tx_fifo_resetn               (tx_fifo_resetn),
      .tx_axis_fifo_tdata           (tx_axis_fifo_tdata),
      .tx_axis_fifo_tvalid          (tx_axis_fifo_tvalid),
      .tx_axis_fifo_tready          (tx_axis_fifo_tready),
      .tx_axis_fifo_tlast           (tx_axis_fifo_tlast),
       
      // MAC Control Interface
      //------------------------
      .pause_req                    (pause_req),
      .pause_val                    (pause_val),

      // GMII Interface
      //-----------------
      .gmii_txd                     (gmii_txd_int),
      .gmii_tx_en                   (gmii_tx_en_int),
      .gmii_tx_er                   (gmii_tx_er_int),
      .gmii_rxd                     (gmii_rxd_int),
      .gmii_rx_dv                   (gmii_rx_dv_int),
      .gmii_rx_er                   (gmii_rx_er_int),
      .speedis100                   (speedis100),
      .speedis10100                 (speedis10100),
      // Configuration Vectors
      //-----------------------
      .rx_configuration_vector      (rx_configuration_vector),
      .tx_configuration_vector      (tx_configuration_vector)
   );


  //----------------------------------------------------------------------------
  //  Instantiate the address swapping module and simple pattern generator
  //----------------------------------------------------------------------------
  wire[15:0] an_adv_config_vector;
  wire       an_restart_config;
//  wire       signal_detect;
  
  wire [4:0] configuration_vector;
  wire [15:0] status_vector;
  
  wire gtpowergood;
  wire pma_reset_out;
   AWG_PHY_GTx_support core_support_i
   (
      // .gtrefclk_p              (gtrefclk_p),
      // .gtrefclk_n              (gtrefclk_n),
      // .gtrefclk_out            (gtrefclk_out),

      .gtrefclk_in             (gtrefclk_in   ),
      .userclk_in              (userclk_in    ),
      .userclk2_in             (userclk2_in   ),
      .rxuserclk_in            (rxuserclk_in  ),
      .rxuserclk2_in           (rxuserclk2_in ),
      .pma_reset_in            (pma_reset_in  ),
      .mmcm_locked_in          (mmcm_locked_in),  
      
      .txp                     (txp),
      .txn                     (txn),
      .rxp                     (rxp),
      .rxn                     (rxn),
      .mmcm_locked_out         (),
      .userclk_out             (),
      .userclk2_out            (userclk2),
      .rxuserclk_out           (),
      .rxuserclk2_out          (),
      .independent_clock_bufg  (independent_clock_bufg),
      .pma_reset_out           (pma_reset_out),
      .resetdone               (reset_done),
      
      .gmii_txd              (gmii_txd_int),
      .gmii_tx_en            (gmii_tx_en_int),
      .gmii_tx_er            (gmii_tx_er_int),
      .gmii_rxd              (gmii_rxd_int),
      .gmii_rx_dv            (gmii_rx_dv_int),
      .gmii_rx_er            (gmii_rx_er_int),
      .gmii_isolate          (),
      .configuration_vector  (configuration_vector),
      .an_interrupt          (),
      .an_adv_config_vector  (an_adv_config_vector),
      .an_restart_config     (an_restart_config),
      .status_vector         (status_vector),
      .reset                 (glbl_rst),
      .gtpowergood           (gtpowergood),
      .signal_detect         (1'b1)
      );
   
 assign  an_adv_config_vector = 16'b0000_0000_0010_0001;//1001_1000_0000_0001
 assign  an_restart_config    = 1'b0;
 assign  configuration_vector = 5'b10000; //[4]:Auto-Negotiation Enable/Disable Auto-negotiation in the simulation:
 always@(posedge userclk2)
    begin
        link_up   <= status_vector[0];
        sync_done <= status_vector[1];
        resetdone <= reset_done;
    end
    
    
generate    
    if(ILA_DEBUG) begin:ila_debug   
    ila_TEMAC_example_top ila_TEMAC_example_top_inst (
	.clk(userclk2), // input wire clk
	.probe0(link_up), // input wire [0:0]  probe0  
	.probe1(sync_done), // input wire [0:0]  probe1 
	.probe2(resetdone), // input wire [0:0]  probe2 
	.probe3(gmii_txd_int), // input wire [7:0]  probe3 
	.probe4(gmii_tx_en_int), // input wire [0:0]  probe4 
	.probe5(gmii_tx_er_int), // input wire [0:0]  probe5 
	.probe6(gmii_rxd_int), // input wire [7:0]  probe6 
	.probe7(gmii_rx_dv_int), // input wire [0:0]  probe7 
	.probe8(gmii_rx_er_int), // input wire [0:0]  probe8
	.probe9(rx_axis_fifo_tdata), // input wire [7:0]  probe9 
	.probe10(rx_axis_fifo_tvalid), // input wire [0:0]  probe10 
	.probe11(rx_axis_fifo_tready), // input wire [0:0]  probe11 
	.probe12(rx_axis_fifo_tlast), // input wire [0:0]  probe12 
	.probe13(tx_axis_fifo_tdata), // input wire [7:0]  probe13 
	.probe14(tx_axis_fifo_tvalid), // input wire [0:0]  probe14 
	.probe15(tx_axis_fifo_tready), // input wire [0:0]  probe15 
	.probe16(tx_axis_fifo_tlast) // input wire [0:0]  probe16
);
end
endgenerate 



endmodule

//AWG_TEMAC_example_design AWG_TEMAC_example_design_inst (
//   // Input Ports - Single Bit
//   .glbl_rst                (glbl_rst),             
//   .gtrefclk_n              (gtrefclk_n),           
//   .gtrefclk_p              (gtrefclk_p),           
//   .independent_clock_bufg  (independent_clock_bufg),
    
//   .txn                     (txn),                  
//   .txp                     (txp), 
//   .rxn                     (rxn),                  
//   .rxp                     (rxp), 
//   .sync_done               (sync_done), 
//   .link_up                 (link_up), 
   
//   .user_axis_clk           (user_axis_clk),        
//   .user_axis_resetn        (user_axis_resetn),              
//   .tx_axis_fifo_tlast      (tx_axis_fifo_tlast),   
//   .tx_axis_fifo_tvalid     (tx_axis_fifo_tvalid),  
//   .tx_axis_fifo_tdata      (tx_axis_fifo_tdata[7:0]),
//   .tx_axis_fifo_tready     (tx_axis_fifo_tready),
                 
//   .rx_axis_fifo_tlast      (rx_axis_fifo_tlast),   
//   .rx_axis_fifo_tvalid     (rx_axis_fifo_tvalid), 
//   .rx_axis_fifo_tdata      (rx_axis_fifo_tdata[7:0]), 
//   .rx_axis_fifo_tready     (rx_axis_fifo_tready)            
//);


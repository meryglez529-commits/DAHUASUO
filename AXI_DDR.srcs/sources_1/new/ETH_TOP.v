`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/02/11 10:07:21
// Design Name: 
// Module Name: AWG_TOP
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
//------------------------------------------------------------------------------
// 0. 读这个顶层，先记住一句话
//
// ETH_TOP 做的事只有一件：
//   把板级外设、以太网命令、DDR 缓存、ADC 采集和 DAC 扫描拼成一台
//   “以太网控制的扫描采集设备”。
//
// 这个文件本身不适合当算法文件读。它主要回答三类问题：
//   1) 外部管脚接到哪个业务模块；
//   2) 哪些时钟域承载哪些数据；
//   3) 两条 DDR 用户通道分别服务哪条业务链路。
//
// 先把主数据单位记牢：
//   - DAC 链路：一拍输出两个 16bit 扫描位置点 DAX/DAY，并产生 adc_tri。
//   - ADC 链路：4 路 AD9258 样本被平均、打包成 64bit，再经 DDR 和 UDP 回传。
//   - 远程升级链路：以太网收到的配置数据先写 DDR，再读出给 multiboot/QSPI。
//------------------------------------------------------------------------------
module ETH_TOP(
    //SYSTEM SIGNAL
    input           sys_clk,    //100M
    output          FPGA_50M,
    //-------------------dac_gain----------------------
    output          AOUT1_CON,   
    output          AOUT2_CON,
    //------------------adc_gain------------------------
    output          AIN4_PD,
    output          AIN4_RELAY2,
    output          AIN4_RELAY1,
    output          AIN3_PD,
    output          AIN3_RELAY2,
    output          AIN3_RELAY1,
    output          AIN2_PD,
    output          AIN2_RELAY2,
    output          AIN2_RELAY1,
    output          AIN1_PD,
    output          AIN1_RELAY2,
    output          AIN1_RELAY1,
    //------------------ad9517 pin-----------------------
    input           pll_ld,
    input           pll_sdo,
    output          pll_csn,
    output          pll_sclk,
    output          pll_sdio,
    output          pll_ref_sel,
    output          pll_resetn,
 //-------------------ad9747 pin-------------------
   input            dac_sdo,
   output           dac_sclk,
   output           dac_sdio,
   output           dac_csb,
   input            dac_dco,
   output           dac_reset,
   output [15:0]    dac_p1d,
   output [15:0]    dac_p2d,
 //-------------------ad9258----------------------------------------
    output          adc1_dea,    //锟斤拷锟斤拷
    output          adc1_deb,    //锟斤拷锟斤拷
    output          adc1_oeb,    //锟斤拷锟斤拷
    output          adc1_pwdn,
    output          adc1_csb,
    inout           adc1_sdio,
    output          adc1_sclk,
    input           adc1_ora,
    input           adc1_orb,
    input           adc1_dcoa,
    input           adc1_dcob,
    input  [15:0]   adc1_da,
    input  [15:0]   adc1_db,
    output          adc2_dea,    //锟斤拷锟斤拷
    output          adc2_deb,    //锟斤拷锟斤拷
    output          adc2_oeb,    //锟斤拷锟斤拷
    output          adc2_pwdn,
    output          adc2_csb,
    inout           adc2_sdio,
    output          adc2_sclk,
    input           adc2_ora,
    input           adc2_orb,
    input           adc2_dcoa,
    input           adc2_dcob,
    input  [15:0]   adc2_da,
    input  [15:0]   adc2_db, 
    //-------------------Ethernet------------------------
    input           gtrefclk_p, //125M
    input           gtrefclk_n,
    output          PHY_RESETn,
    output          PHY_INTn,
    output          PHY_MDC,
    inout           PHY_MDIO,
    output          txp_sgmii,                   // Differential +ve of serial transmission from PMA to PMD.
    output          txn_sgmii,                   // Differential -ve of serial transmission from PMA to PMD.
    input           rxp_sgmii,                   // Differential +ve for serial reception from PMD to PMA.
    input           rxn_sgmii,                    // Differential -ve for serial reception from PMD to PMA
    //-------------------ddr3---------------------------
    output  [14:0]  DDR3_addr,
    output  [2:0]   DDR3_ba,
    output          DDR3_cas_n,
    output  [0:0]   DDR3_ck_n,
    output  [0:0]   DDR3_ck_p,
    output  [0:0]   DDR3_cke,
    output  [0:0]   DDR3_cs_n,
    output  [7:0]   DDR3_dm,
    inout   [63:0]  DDR3_dq,
    inout   [7:0]   DDR3_dqs_n,
    inout   [7:0]   DDR3_dqs_p,
    output  [0:0]   DDR3_odt,
    output          DDR3_ras_n,
    output          DDR3_reset_n,
    output          DDR3_we_n,
    //--------------QSPI FLASHX4---------------------- 
    inout           qspi_d0,
    inout           qspi_d1,  
    inout           qspi_d2, 
    inout           qspi_d3,
    output          qspi_csb,
  //------------------offset dac-------------------------
    output          ADC1_SCL,
    inout           ADC1_SDA,
    output          ADC2_SCL,
    inout           ADC2_SDA,
   //----------------baseboard signal----------------------
    output  [7:0]   LED, 
    output  [1:0]   FAN,
    input           UART_RX,
    output          UART_TX,
    output          UART_EN,
    output          FRAM_SCL,
    inout           FRAM_SDA,
    output          TRIGGER_OUT,
    input           TRIGGER_IN,
    output          TRIG_CLOCK,
    output          TRIGGER_H,
    output          TRIG_V,
    output          TRIG_BLANK
    );
    
//------------------------------------------------------------------------------
// 1. 上位机寄存器解码后的控制面
//
// command_monitor_new 在 eth_clk 域把 UDP 寄存器写转换成这些控制信号。
// 后面的 ADC、DAC、FRAM、offset DAC 和远程升级模块都消费这里的参数。
//
// 注意区分两个维度：
//   image_row/image_column/image_point 描述空间点数；
//   adc_channel/adc_sample/row_repeat 描述每个空间点携带几个通道、平均多少点。
//------------------------------------------------------------------------------
    wire [31:0]     remote_result;
    wire            clk_sel;
    wire [20:0]     adc_len_single;
    wire [3:0]      adc_channel;
    wire [31:0]     adc_sample;
    wire [31:0]     dac_sample;
    wire [1:0]      adc1_gain;
    wire [1:0]      adc2_gain;
    wire [1:0]      adc3_gain;
    wire [1:0]      adc4_gain;
    wire [1:0]      dacx_gain;
    wire [1:0]      dacy_gain;
    wire [15:0]     image_row;
    wire [15:0]     image_column;
    wire [15:0]     dacx_strat_level;
    wire [15:0]     dacx_end_level;
    wire [63:0]     dacx_step;
    wire [15:0]     dacx_tk_point;
    wire [15:0]     dacx_recovery_time;
    wire [15:0]     dacy_strat_level;
    wire [15:0]     dacy_end_level;
    wire [63:0]     dacy_step;
    wire [31:0]     frame_waiting_time;
    wire [31:0]     dax_fall_time;
    wire [23:0]     adc_interval;
    wire [3:0]      scan_mode;
    wire [3:0]      scan_state;  

    wire            wr_offset_flag;
    wire [31:0]     offset_adc1_adc2;
    wire [31:0]     offset_adc3_adc4;
    wire [31:0]     offset_dacx_dacy;
    wire [31:0]     image_point;
    wire [15:0]     row_repeat;
    wire [15:0]     row_m;
    wire [15:0]     row_n;
    wire [31:0]     pc_ack;
    wire [15:0]     sync1_pixel_tri_wigth;
    wire [15:0]     sync2_pixel_tri_wigth;
    wire [31:0]     adc_acq_delay;
    wire            ultrafast_mode;
    wire [31:0]     acq_dead_time;
    wire            sync_pixel_tri;
    wire            sync_pixel_tri1;
    wire            sync_pixel_tri2;
    wire [31:0]     ultrafast_line_rec;
    wire [15:0]    sync_sig_delay1;
    wire [15:0]    sync_sig_delay2;
//******************************************
//--------------------PLL-------------------
//******************************************
//------------------------------------------------------------------------------
// 2. 时钟骨架
//
// sys_clk 是板级 100MHz 输入。这里生成三路本地时钟：
//   clk200m：送 MIG/DDR 作为系统和参考时钟来源；
//   clk50m ：给以太网配置、板外 FPGA_50M 和部分低速逻辑；
//   clk10m ：给 AD9517/AD9747/AD9258/FRAM/offset DAC 等慢速配置状态机。
//
// 业务数据不都在同一时钟域：
//   ADC 原始采样在各自 adc*_dco 域；
//   DDR/FDMA 数据在 ui_clk 域；
//   UDP 寄存器和发包控制在 eth_clk 域；
//   DAC 输出锁存在 dac_dco 域。
//------------------------------------------------------------------------------
    wire            ui_clk;
    wire            fdma_rstn;
    wire            clk200m; 
    wire            clk10m;
    wire            clk50m;
    wire            locked;
sysclk P0(
    .clk_in1        (sys_clk), 
    .clk_out1       (clk200m),     
    .clk_out2       (clk10m),     
    .clk_out3       (clk50m),
    .locked         (locked)
    ); 
//******************************************
//---------------rst_delay------------------
//******************************************
// 外设配置需要等 PLL 和芯片电源/时钟稳定后再释放复位；这些延时只控制配置启动顺序，
// 不承载 ADC/DAC 主数据。
    wire            rstn_fram;
    wire            rstn_offdac;
    wire            rstn_pll;
    wire            rstn_adc_dac;
time_delay U00(
    .clk10m         (clk10m),
    .rstn           (locked),
    .rstn_fram      (rstn_fram),         //delay 104ms
    .rstn_offdac    (rstn_offdac),       //delay 104ms
    .rstn_pll       (rstn_pll),          //delay 104ms
    .rstn_adc_dac   (rstn_adc_dac)       //delay 420ms
    );
//******************************************
//---------------ad9517cfg------------------
//******************************************
// AD9517/AD9747/AD9258 这几个 cfg 模块只负责芯片初始化和配置脚，不传输主采样数据。
// 读主链路时先把它们当成“让外设进入工作状态”的支撑模块。
ad9517_cfg U0(
    .clk10m         (clk10m),
    .rstn           (rstn_pll),
    .clk_sel        (1'b0),
    .pll_ld         (pll_ld),
    .pll_sdo        (pll_sdo),
    .pll_csn        (pll_csn),
    .pll_sclk       (pll_sclk),
    .pll_sdio       (pll_sdio),
    .pll_ref_sel    (pll_ref_sel),
    .pll_resetn     (pll_resetn)
    );    
//******************************************
//---------------ad9747cfg------------------
//******************************************
ad9747_cfg U1(
    .clk10m         (clk10m),
    .rstn           (rstn_adc_dac),
    .dacx_gain      (dacx_gain[0]),
    .dacy_gain      (dacy_gain[0]),
    .dac_sdo        (dac_sdo),
    .dac_sclk       (dac_sclk),
    .dac_sdio       (dac_sdio),
    .dac_csb        (dac_csb),
    .dac_reset      (dac_reset)
    );
//******************************************
//---------------ad9258cfg------------------
//******************************************
ad9258_cfg U2(
    .clk10m         (clk10m),
    .rstn           (rstn_adc_dac),
    .adc1_dea       (adc1_dea),    //锟斤拷锟斤拷
    .adc1_deb       (adc1_deb),    //锟斤拷锟斤拷
    .adc1_oeb       (adc1_oeb),    //锟斤拷锟斤拷
    .adc1_pwdn      (adc1_pwdn),
    .adc1_csb       (adc1_csb),
    .adc1_sdio      (adc1_sdio),
    .adc1_sclk      (adc1_sclk),
    .adc2_dea       (adc2_dea),    //锟斤拷锟斤拷
    .adc2_deb       (adc2_deb),    //锟斤拷锟斤拷
    .adc2_oeb       (adc2_oeb),    //锟斤拷锟斤拷
    .adc2_pwdn      (adc2_pwdn),
    .adc2_csb       (adc2_csb),
    .adc2_sdio      (adc2_sdio),
    .adc2_sclk      (adc2_sclk),
    .offset_adc1    (8'd0),
    .offset_adc2    (8'd0),
    .offset_adc3    (8'd0),
    .offset_adc4    (8'd0)
    ); 
//******************************************
//--------------ETHERNET TOP---------------
//******************************************
//------------------------------------------------------------------------------
// 3. 以太网同时承载控制面和数据面
//
// ETHERNET_TOP 输出三类接口：
//   - WR_REG/RD_REG：上位机读写寄存器，进入 command_monitor_new；
//   - data_*      ：ADC 采集数据上传，来自 LAN_TX_FREAME；
//   - remote_*    ：远程升级/配置文件接收，后面写入 DDR 再送 QSPI。
//
// 所以看到 eth_clk 时不要直接认为它只属于网口。它也是寄存器控制面的时钟。
//------------------------------------------------------------------------------
    wire            link_up;   
    wire            sync_done;  
    wire            resetdone;   
    wire            eth_clk;  
    wire            eth_rstn;
    wire            WR_REG_VALID;           //锟斤拷写锟侥达拷锟斤拷锟斤拷锟斤拷锟斤拷锟侥接匡拷
    wire    [15:0]  WR_REG_ADDR;
    wire    [31:0]  WR_REG_DATA;
    wire            RD_REG_VALID;
    wire    [15:0]  RD_REG_ADDR;
    wire    [31:0]  RD_REG_DATA;
    
    wire            prog_full;                          //ADC锟缴硷拷锟斤拷锟斤拷锟酵革拷锟斤拷锟斤拷模锟斤拷锟斤拷锟斤拷洗锟?
    wire            data_req;                
    wire            data_ACK;
    wire    [21:0]  data_wr_pack_num;
    wire    [15:0]  data_wr_last_pack_num;
    wire    [7:0]   data_tx_data;
    wire            data_tx_valid;
    wire            tx_data_done;
    wire    [31:0]  remote_len;
    wire            remote_wr_en;
    wire    [15:0]  remote_wr_data;
    wire            remote_rx_done;
    wire            remote_complete;
    
    wire            remote_rstn;
ETHERNET_TOP#(.ILA_DEBUG(1'b0)) U02(
    .gtrefclk_p     (gtrefclk_p),              //125M
    .gtrefclk_n     (gtrefclk_n),
    .clk_config     (clk50m),
    .locked         (locked),
    .PHY_RESETn     (PHY_RESETn),
    .PHY_INTn       (PHY_INTn),
    .PHY_MDC        (PHY_MDC),
    .PHY_MDIO       (PHY_MDIO),
    .txp_sgmii      (txp_sgmii),                    // Differential +ve of serial transmission from PMA to PMD.
    .txn_sgmii      (txn_sgmii),                    // Differential -ve of serial transmission from PMA to PMD.
    .rxp_sgmii      (rxp_sgmii),                    // Differential +ve for serial reception from PMD to PMA.
    .rxn_sgmii      (rxn_sgmii),                    // Differential -ve for serial reception from PMD to PMA.
    // asynchronous reset
    .glbl_rst               (!locked),              //active high
    .independent_clock_bufg (clk50m),               //50M   
    .link_up                (link_up),    
    .sync_done              (sync_done),  
    .resetdone              (resetdone),     
    //锟斤拷写锟侥达拷锟斤拷锟接匡拷锟斤拷锟斤拷
    .user_axis_clk          (eth_clk),   
    .user_axis_resetn       (eth_rstn),
    .WR_REG_VALID           (WR_REG_VALID),
    .WR_REG_ADDR            (WR_REG_ADDR),
    .WR_REG_DATA            (WR_REG_DATA),
    .RD_REG_VALID           (RD_REG_VALID),
    .RD_REG_ADDR            (RD_REG_ADDR),
    .RD_REG_DATA            (RD_REG_DATA),
    //ADC锟缴硷拷锟斤拷锟斤拷锟酵革拷锟斤拷锟节斤拷锟叫凤拷锟斤拷模锟斤拷
    .prog_full              (prog_full),
    .data_req               (data_req),
    .data_ACK               (data_ACK),
    .data_wr_pack_num       (data_wr_pack_num),
    .data_wr_last_pack_num  (data_wr_last_pack_num),
    .data_tx_data           (data_tx_data),
    .data_tx_valid          (data_tx_valid),
    .tx_data_done           (tx_data_done),
    //远锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟酵筹拷
    .remote_len             (remote_len),
    .remote_wr_en           (remote_wr_en),
    .remote_wr_data         (remote_wr_data),
    .remote_rx_done         (remote_rx_done),
    .remote_rstn            (remote_rstn),
    .remote_complete        (remote_complete)
    ); 
//******************************************
//---------------DDR3锟斤拷写------------------
//******************************************
//------------------------------------------------------------------------------
// 4. DDR3 wrapper 有两套用户侧 FDMA 通道
//
// system_wrapper 里有两个 MSXBO_FDMA master，最终都访问同一片 MIG DDR3：
//   pkg_*  ：远程升级/配置链路使用，由 ddr3_ctrl 驱动；
//   pkg1_* ：ADC 采集回传链路使用，由 adcdata_config 驱动。
//
// 这两个名字只差一个数字，读代码时最容易混。判断方法：
//   带 1 的 pkg1_* 一律跟 ADC 数据上传有关；
//   不带 1 的 pkg_* 一律跟 remote/multiboot 有关。
//------------------------------------------------------------------------------
    wire            aux_reset;
    vio_1 vio_inst(.clk(ui_clk), .probe_out0(aux_reset) );
    //remote
    wire [31:0]     pkg_rd_addr;
    wire            pkg_rd_areq;
    wire [63:0]     pkg_rd_data;
    wire            pkg_rd_en;
    wire            pkg_rd_last;
    wire [31:0]     pkg_rd_size;
    wire [31:0]     pkg_wr_addr;
    wire            pkg_wr_areq;
    wire [63:0]     pkg_wr_data;
    wire            pkg_wr_en;
    wire            pkg_wr_last;
    wire [31:0]     pkg_wr_size;
    //adcdata tx
    wire [31:0]     pkg1_rd_addr;
    wire            pkg1_rd_areq;
    wire [63:0]     pkg1_rd_data;
    wire            pkg1_rd_en;
    wire            pkg1_rd_last;
    wire [31:0]     pkg1_rd_size;
    wire [31:0]     pkg1_wr_addr;
    wire            pkg1_wr_areq;
    wire [63:0]     pkg1_wr_data;
    wire            pkg1_wr_en;
    wire            pkg1_wr_last;
    wire [31:0]     pkg1_wr_size;
system_wrapper U3 (
    .clk200m        (clk200m),
    .mig_rstn       (locked),
    .DDR3_addr      (DDR3_addr),
    .DDR3_ba        (DDR3_ba),
    .DDR3_cas_n     (DDR3_cas_n),
    .DDR3_ck_n      (DDR3_ck_n),
    .DDR3_ck_p      (DDR3_ck_p),
    .DDR3_cke       (DDR3_cke),
    .DDR3_cs_n      (DDR3_cs_n),
    .DDR3_dm        (DDR3_dm),
    .DDR3_dq        (DDR3_dq),
    .DDR3_dqs_n     (DDR3_dqs_n),
    .DDR3_dqs_p     (DDR3_dqs_p),
    .DDR3_odt       (DDR3_odt),
    .DDR3_ras_n     (DDR3_ras_n),
    .DDR3_reset_n   (DDR3_reset_n),
    .DDR3_we_n      (DDR3_we_n),
    .ui_clk         (ui_clk),        //200m
    .fdma_rstn      (fdma_rstn),
    .aux_reset      (aux_reset),
    .pkg_rd_addr    (pkg_rd_addr),
    .pkg_rd_areq    (pkg_rd_areq),
    .pkg_rd_data    (pkg_rd_data),
    .pkg_rd_en      (pkg_rd_en),
    .pkg_rd_last    (pkg_rd_last),
    .pkg_rd_size    (pkg_rd_size),
    .pkg_wr_addr    (pkg_wr_addr),
    .pkg_wr_areq    (pkg_wr_areq),
    .pkg_wr_data    (pkg_wr_data),
    .pkg_wr_en      (pkg_wr_en),
    .pkg_wr_last    (pkg_wr_last),
    .pkg_wr_size    (pkg_wr_size),
    .pkg1_rd_addr    (pkg1_rd_addr),
    .pkg1_rd_areq    (pkg1_rd_areq),
    .pkg1_rd_data    (pkg1_rd_data),
    .pkg1_rd_en      (pkg1_rd_en),
    .pkg1_rd_last    (pkg1_rd_last),
    .pkg1_rd_size    (pkg1_rd_size),
    .pkg1_wr_addr    (pkg1_wr_addr),
    .pkg1_wr_areq    (pkg1_wr_areq),
    .pkg1_wr_data    (pkg1_wr_data),
    .pkg1_wr_en      (pkg1_wr_en),
    .pkg1_wr_last    (pkg1_wr_last),
    .pkg1_wr_size    (pkg1_wr_size)
    ); 
//******************************************
//-----------------指锟斤拷锟斤拷锟?-----------------
//****************************************** 
//------------------------------------------------------------------------------
// 5. 寄存器控制面
//
// command_monitor_new 是上位机命令到硬件参数的唯一集中解码点。
// 它不搬运 ADC/DAC 样本，只产生“怎么采、怎么扫、发多少、增益多少、是否升级”
// 这些控制量。后面的业务模块再把这些控制量同步到自己的时钟域使用。
//------------------------------------------------------------------------------
command_monitor_new U4( 
    .eth_clk        (eth_clk),
    .eth_rst        (~eth_rstn),
    .wr_reg_valid   (WR_REG_VALID),
    .wr_reg_addr    (WR_REG_ADDR),
    .wr_reg_data    (WR_REG_DATA),
    .rd_reg_valid   (RD_REG_VALID),
    .rd_reg_addr    (RD_REG_ADDR),
    .rd_reg_data    (RD_REG_DATA),

    .remote_result  (remote_result),
    .clk_sel        (clk_sel),
    .adc_len_single (adc_len_single),       //21
    .adc_channel    (adc_channel),          //4
    .adc_sample     (adc_sample),           //16
    .dac_sample     (dac_sample),           //16
    .adc1_gain      (adc1_gain),            //2
    .adc2_gain      (adc2_gain),            //2
    .adc3_gain      (adc3_gain),            //2
    .adc4_gain      (adc4_gain),            //2
    .dacx_gain      (dacx_gain),            //2
    .dacy_gain      (dacy_gain),            //2
    .image_row      (image_row),            //16
    .image_column   (image_column),         //16
    .dacx_strat_level   (dacx_strat_level), //16
    .dacx_end_level     (dacx_end_level),   //16
    .dacx_step          (dacx_step),        //16
    .dacx_tk_point      (dacx_tk_point),    //16
    .dacx_recovery_time (dacx_recovery_time),       //16
    .dacy_strat_level   (dacy_strat_level),         //16
    .dacy_end_level     (dacy_end_level),           //16
    .dacy_step          (dacy_step),                //16
    .frame_waiting_time (frame_waiting_time),       //32
    .dax_fall_time      (dax_fall_time),
    .adc_interval       (adc_interval),             //24
    .scan_mode          (scan_mode),                //4
    .scan_state         (scan_state),               //4
    .remote_rstn        (remote_rstn),              //1
    .wr_offset_flag     (wr_offset_flag),           //1
    .offset_adc1_adc2   (offset_adc1_adc2),         //32
    .offset_adc3_adc4   (offset_adc3_adc4),         //32
    .offset_dacx_dacy   (offset_dacx_dacy),         //32
    .image_point        (image_point),               //16
    .row_repeat         (row_repeat),
    .row_m              (row_m),
    .row_n              (row_n),
    .sync1_pixel_tri_wigth(sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth(sync2_pixel_tri_wigth),
    .adc_acq_delay      (adc_acq_delay),
    .ultrafast_line_rec (ultrafast_line_rec),
    .ultrafast_mode     (ultrafast_mode),
    .acq_dead_time      (acq_dead_time),
    .sync_sig_delay1        (sync_sig_delay1),
    .sync_sig_delay2        (sync_sig_delay2),
    .pc_ack_r           (pc_ack)
    ); 
//******************************************
//-----------adc锟斤拷锟捷采硷拷锟较达拷----------------
//******************************************  
//------------------------------------------------------------------------------
// 6. DL2：ADC 采集 -> DDR -> 以太网上传
//
// 这条链路的真实数据是 AD9258 的采样值。顶层在这里做三件关键连接：
//   1) 4 路 ADC 数据和 4 个 DCO 送入 adcdata_config；
//   2) adcdata_config 使用 pkg1_* 这一路 FDMA 读写 DDR；
//   3) DDR 读出的采样数据通过 data_* 接口交给 ETHERNET_TOP 发 UDP。
//
// 注意数据位宽变化：
//   顶层只取 adc*_d*[15:2] 这 14bit，adcdata_config 内部再补 0 成 16bit 处理。
//   后续 adcdata_get 会按 adc_channel 把若干个 16bit 样本打包成 64bit。
//------------------------------------------------------------------------------
    wire            adc_tri;   
    assign TRIGGER_OUT = sync_pixel_tri2;
    wire          read_flag;
adcdata_config U5(
    .eth_clk        (eth_clk),
    .eth_rstn       (eth_rstn), 
    .ui_clk         (ui_clk),
    .fdma_rstn      (fdma_rstn),
    .adc1_dcoa      (adc1_dcoa),
    .adc1_dcob      (adc1_dcob),
    .adc2_dcoa      (adc2_dcoa),
    .adc2_dcob      (adc2_dcob),
    // 只取 AD9258 的 [15:2] 进入数字采集链；低 2bit 在顶层被丢弃。
    .adc1_da        (adc1_da[15:2]),
    .adc1_db        (adc1_db[15:2]),
    .adc2_da        (adc2_da[15:2]),
    .adc2_db        (adc2_db[15:2]),
    .row_repeat     (row_repeat),
    .adc_tri        (adc_tri),       
    .image_point    (image_point),
    .adc_len_single (adc_len_single),    
    .adc_channel    (adc_channel),
    .adc_sample     (adc_sample),
    .image_column   (image_column),
    .adc_interval   (adc_interval),
    .ultrafast_mode (ultrafast_mode),
    .acq_dead_time  (acq_dead_time),
    .adc_acq_delay  (adc_acq_delay),
    .scan_state     (scan_state[0]),   
    .pc_ack         (pc_ack),
    //ADC锟缴硷拷锟斤拷锟斤拷锟酵革拷锟斤拷锟节斤拷锟叫凤拷锟斤拷模锟斤拷
    .prog_full              (prog_full),
    .data_req               (data_req),
    .data_ACK               (data_ACK),
    .data_wr_pack_num       (data_wr_pack_num),
    .data_wr_last_pack_num  (data_wr_last_pack_num),
    .data_tx_data           (data_tx_data),
    .data_tx_valid          (data_tx_valid),
    .tx_data_done           (tx_data_done),
    .LED                    (LED[3:0]),
    //////
    .pkg_wr_areq            (pkg1_wr_areq),       
    .pkg_wr_en              (pkg1_wr_en),
    .pkg_wr_last            (pkg1_wr_last),
    .pkg_wr_addr            (pkg1_wr_addr),
    .pkg_wr_data            (pkg1_wr_data),
    .pkg_wr_size            (pkg1_wr_size),
    .pkg_rd_data            (pkg1_rd_data),
    .pkg_rd_en              (pkg1_rd_en),
    .pkg_rd_last            (pkg1_rd_last),
    .pkg_rd_addr            (pkg1_rd_addr),
    .pkg_rd_areq            (pkg1_rd_areq),
    .pkg_rd_size            (pkg1_rd_size)
    ); 
//******************************************
//---------------dac锟斤拷锟捷回凤拷----------------
//******************************************     
//------------------------------------------------------------------------------
// 7. DL1：DAC 扫描输出，同时给 DL2 产生采样触发
//
// dacdata_config 根据寄存器参数生成 DAX/DAY 两路 16bit 扫描点。
// 它还输出 adc_tri，作为上面 ADC 采集链的触发窗口。
//
// 换句话说：
//   DAC 链路决定“扫描到哪里”和“什么时候采”；
//   ADC 链路负责“采到什么”和“如何回传”。
//------------------------------------------------------------------------------
    wire [15:0]     DAX_DATA;
    wire [15:0]     DAY_DATA;
    // 板级模拟链路要求 DAC 码值取反输出，所以顶层把内部 DAX/DAY 映射成 65535-data。
    assign dac_p1d = 65535 - DAX_DATA;
    assign dac_p2d = 65535 - DAY_DATA;
dacdata_config U6(
    .eth_clk            (eth_clk),
    .eth_rstn           (eth_rstn), 
    .ui_clk             (ui_clk),
    .dac_dco            (dac_dco),
    .dac_sample         (dac_sample),
    .image_row          (image_row),
    .dacx_strat_level   (dacx_strat_level),
    .dacx_end_level     (dacx_end_level),   
    .dacx_step          (dacx_step),
    .dacx_tk_point      (dacx_tk_point),
    .dacx_recovery_time (dacx_recovery_time),
    .dacy_strat_level   (dacy_strat_level),
    .dacy_end_level     (dacy_end_level),   //16
    .dacy_step          (dacy_step),
    .frame_waiting_time (frame_waiting_time),
    .dax_fall_time      (dax_fall_time),
    .scan_mode          (scan_mode),
    .ultrafast_mode     (ultrafast_mode),
    .ultrafast_line_rec (ultrafast_line_rec),
    .sync_sig_delay1        (sync_sig_delay1),
    .sync_sig_delay2        (sync_sig_delay2),
    .scan_state         (scan_state[0]),              
    .row_repeat         (row_repeat),           //new function
    .sync1_pixel_tri_wigth(sync1_pixel_tri_wigth),
    .sync2_pixel_tri_wigth(sync2_pixel_tri_wigth),
    .row_m              (row_m),                //new function
    .row_n              (row_n),                //new function
    .clk_sel						( clk_sel),
    .TRIGGER_IN					(TRIGGER_IN),

    .sync_pixel_tri1    (sync_pixel_tri1),
    .sync_pixel_tri2    (sync_pixel_tri2),       
    .adc_tri            (adc_tri),  
    .DAX_DATA           (DAX_DATA),
    .DAY_DATA           (DAY_DATA)   
    );  
    
//******************************************
//---------------multiboot------------------
//****************************************** 
//------------------------------------------------------------------------------
// 8. 远程升级/QSPI 控制面
//
// remote_* 数据从以太网进来，不直接写 QSPI。它先经过 ddr3_ctrl 写入 DDR，
// 再由 multiboot_cfg_new 配合 STARTUPE2 驱动配置 Flash/CCLK。
// 这条链路和 ADC 回传共用 DDR 物理资源，但使用不带 1 的 pkg_* 用户通道。
//------------------------------------------------------------------------------
  wire              qspi_clk;
  wire              data_in_flag;
  wire  [3:0]       data_in;
  wire  [7:0]       flash_type_out;
  wire   write_rom_flag; 
  wire  [7:0]       write_rom_data;
  multiboot_cfg_new U7(
    .eth_clk            (eth_clk),
    .eth_rstn           (eth_rstn),
    .clk_50m            (clk50m),
    .qspi_cfg_en        (remote_rx_done),
    .remote_config_len  (remote_len),
    .remote_result      (remote_result),
    .remote_complete    (remote_complete),
    .read_flash_flag (  read_flag    ),    
    .flash_type_in   (  flash_type_out      ),    
    .write_rom_flag  (  write_rom_flag     ),    
    .write_rom_data  (  write_rom_data     ),    
    .qspi_d0            (qspi_d0),
    .qspi_d1            (qspi_d1),
    .qspi_d2            (qspi_d2),
    .qspi_d3            (qspi_d3),
    .qspi_csb           (qspi_csb),
    .qspi_clk           (qspi_clk),
    .data_in_flag       (data_in_flag),
    .data_in            (data_in)
    );
  
  STARTUPE2  STARTUPE2_inst(
    .CFGCLK(), // 1-bit output: Configuration main clock output
    .CFGMCLK(), // 1-bit output: Configuration internal oscillator clock output
    .EOS(), // 1-bit output: Active high output signal indicating the End Of Startup.
    .PREQ(), // 1-bit output: PROGRAM request to fabric output
    .CLK(0), // 1-bit input: User start-up clock input
    .GSR(0), // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
    .GTS(0), // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
    .KEYCLEARB(1), // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
    .PACK(1), // 1-bit input: PROGRAM acknowledge input
    .USRCCLKO(qspi_clk), // 1-bit input: User CCLK input
    .USRCCLKTS(0), // 1-bit input: User CCLK 3-state enable input
    .USRDONEO(1), // 1-bit input: User DONE pin output control
    .USRDONETS(1) // 1-bit input: User DONE 3-state enable outpu
    ); 
    
//******************************************
//---------------DDR3锟斤拷锟斤拷------------------
//****************************************** 
// 远程升级链路的 DDR 读写控制器。注意这里接的是 pkg_*，不是 ADC 使用的 pkg1_*。
wire remote_en;
ddr3_ctrl U07(
    .eth_clk                (eth_clk),
    .eth_rstn               (eth_rstn),
    .ui_clk                 (ui_clk),
    .fdma_rstn              (fdma_rstn),
    .clk_50m                (clk50m),
    
    .remote_rstn            (remote_rstn),
    .remote_wr_en           (remote_wr_en),
    .remote_wr_data         (remote_wr_data),
    .remote_rx_done         (remote_rx_done),
    //user write ddr3 interface
    .pkg_wr_areq            (pkg_wr_areq),       
    .pkg_wr_en              (pkg_wr_en),
    .pkg_wr_last            (pkg_wr_last),
    .pkg_wr_addr            (pkg_wr_addr),
    .pkg_wr_data            (pkg_wr_data),
    .pkg_wr_size            (pkg_wr_size),
    //user read ddr3 interface
    .pkg_rd_data            (pkg_rd_data),
    .pkg_rd_en              (pkg_rd_en),
    .pkg_rd_last            (pkg_rd_last),
    .pkg_rd_addr            (pkg_rd_addr),
    .pkg_rd_areq            (pkg_rd_areq),
    .pkg_rd_size            (pkg_rd_size),
    //multiboot_cfg interface
    .data_in_flag           (data_in_flag),
    .data_in                (data_in)
    );
//******************************************
//---------------FRAM锟斤拷锟斤拷------------------
//****************************************** 
//------------------------------------------------------------------------------
// 9. 非易失参数和模拟偏置
//
// FRAM 保存/读取 offset 参数；offset_dac_cfg 再把这些偏置值写到板级偏置 DAC/I2C。
// 它们影响模拟前端基线和偏置，但不改变 DL2 的数字打包格式。
//------------------------------------------------------------------------------
  wire [15:0]   offset_adc1;
  wire [15:0]   offset_adc2;
  wire [15:0]   offset_adc3;
  wire [15:0]   offset_adc4;
  wire [15:0]   offset_dacx;
  wire [15:0]   offset_dacy;
  fram_cfg U8(
    .ui_clk             (eth_clk),
    .rstn               (eth_rstn),
    .clk10m             (clk10m),
    .rstn_buf           (rstn_fram),
    .FRAM_SCL           (FRAM_SCL),
    .FRAM_SDA           (FRAM_SDA),
    .wr_offset_flag     (wr_offset_flag),
    .offset_adc1_adc2   (offset_adc1_adc2),
    .offset_adc3_adc4   (offset_adc3_adc4),
    .offset_dacx_dacy   (offset_dacx_dacy),
    .read_flag          (read_flag),
    .offset_adc1        (offset_adc1),
    .offset_adc2        (offset_adc2),
    .offset_adc3        (offset_adc3),
    .offset_adc4        (offset_adc4),
    .offset_dacx        (offset_dacx),
    .offset_dacy        (offset_dacy),
    .write_rom_flag      (write_rom_flag   ),
    .flash_type_in      ( write_rom_data  ),
    .flash_type_out      ( flash_type_out  )
    ); 
//******************************************
//-----------偏锟斤拷DAC锟斤拷锟斤拷锟斤拷------------------
//****************************************** 
  offset_dac_cfg U9( 
    .clk10m             (clk10m),
    .rstn               (rstn_offdac),
    .ADC1_SCL           (ADC1_SCL),
    .ADC1_SDA           (ADC1_SDA),
    .ADC2_SCL           (ADC2_SCL),
    .ADC2_SDA           (ADC2_SDA),
    .read_flag          (read_flag),
    .offset_adc1        (offset_adc1),
    .offset_adc2        (offset_adc2),
    .offset_adc3        (offset_adc3),
    .offset_adc4        (offset_adc4),
    .offset_dacx        (offset_dacx),
    .offset_dacy        (offset_dacy)
    );
//******************************************
//AIN AOUT通锟斤拷锟斤拷锟芥，LED,锟斤拷锟饺癸拷锟界，锟斤拷锟斤拷锟斤拷pin锟斤拷锟斤拷
//****************************************** 
//------------------------------------------------------------------------------
// 10. 板级离散输出
//
// 这一段把寄存器控制量翻译成板级继电器、量程、风扇、触发和 LED。
// 这些 assign 是硬件管脚策略，不是数据路径。调 ADC 量程或 DAC 量程时看这里；
// 调采样数据格式、DDR 包长或 UDP payload 时不要从这里下手。
//------------------------------------------------------------------------------
    assign AOUT1_CON    = (dacx_gain[1])? 1'b1:1'b0;                                           //锟斤拷锟斤拷DAC锟斤拷锟斤拷锟斤拷,5V10V-->>1;   1.25V2.5V-->>0
    assign AOUT2_CON    = (dacy_gain[1])? 1'b1:1'b0;  
    assign {AIN1_PD,AIN2_PD,AIN3_PD,AIN4_PD} = 4'd0;                                       //锟斤拷锟斤拷模锟斤拷通锟斤拷锟斤拷锟斤拷锟脚猴拷
    assign {AIN1_RELAY1,AIN1_RELAY2} = {~(adc1_gain[1] | adc1_gain[0]), adc1_gain[0]};    //锟斤拷锟斤拷ADC锟斤拷锟斤拷锟斤拷   1/2:00/5V;    01/2.5V;     1X/5V
    assign {AIN2_RELAY1,AIN2_RELAY2} = {~(adc2_gain[1] | adc2_gain[0]), adc2_gain[0]};
    assign {AIN3_RELAY1,AIN3_RELAY2} = {~(adc3_gain[1] | adc3_gain[0]), adc3_gain[0]};
    assign {AIN4_RELAY1,AIN4_RELAY2} = {~(adc4_gain[1] | adc4_gain[0]), adc4_gain[0]};       
    assign FAN          = 2'b01;                  //锟截闭凤拷锟斤拷
    assign UART_TX      = 1'b1;
    assign UART_EN      = 1'b1;
    assign TRIG_CLOCK   = 1'b0;
    assign TRIGGER_H    = 1'b0;
    assign TRIG_V       = 1'b0;
    assign TRIG_BLANK   = sync_pixel_tri1;   
    assign LED[7:4]     = {pll_ld,pll_ld,pll_ld,pll_ld};
// FPGA_50M 是把内部 clk50m 通过 ODDR 翻到输出管脚，供板级其它器件使用。
ODDR ODDR_CLK0 (
    .Q          (FPGA_50M),
    .C          (clk50m),
    .CE         (1'b1), 
    .D1         (1'b1), 
    .D2         (1'b0), 
    .R          (!locked), 
    .S          (1'b0)
    );
//******************************************
//-------------------ila--------------------
//****************************************** 
//  ila_3 command_ila(
//    .clk        (eth_clk),
//    .probe0     (adc_len_single),   //21
//    .probe1     (adc_channel),      //4
//    .probe2     (adc_sample),       //16
//    .probe3     (dac_sample),       //16
//    .probe4     (image_row),        //16
//    .probe5     (adc1_gain),        //2
//    .probe6     (adc2_gain),        //2
//    .probe7     (adc3_gain),        //2
//    .probe8     (adc4_gain),        //2
//    .probe9     (dacx_gain),        //2
//    .probe10    (dacy_gain),        //2
//    .probe11    (dacx_strat_level), //16
//    .probe12    (dacx_end_level),   //16
//    .probe13    (dacx_tk_point),    //16
//    .probe14    (dacx_recovery_time),   //16
//    .probe15    (dacy_strat_level),     //16
//    .probe16    (dacy_end_level),       //16
//    .probe17    (dacy_step),            //16     
//    .probe18    (adc_interval),         //24
//    .probe19    (scan_mode),            //4
//    .probe20    (scan_state),           //4
//    .probe21    (dacx_step),            //16
//    .probe22    (remote_result),        //32
//    .probe23    (image_point)           //16
//    );                
    
 ila_8 reg_ila(
    .clk        (eth_clk),
    .probe0     (WR_REG_VALID),
    .probe1     (WR_REG_ADDR),
    .probe2     (WR_REG_DATA),
    .probe3     (RD_REG_VALID),
    .probe4     (RD_REG_ADDR),
    .probe5     (RD_REG_DATA),
    .probe6     (eth_rstn),
    .probe7     (remote_wr_en),
    .probe8     (remote_wr_data),
    .probe9     (remote_rx_done),
    .probe10    (remote_complete),
    .probe11    (remote_len)
    );  
    
endmodule

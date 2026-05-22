`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ETHERNET_TOP
//
// 一句话概括：
//   ETHERNET_TOP 是以太网子系统的顶层集成模块，负责 SGMII 物理层、MAC、
//   UDP/IP/ARP/ICMP 协议栈、寄存器读写（DL4）、ADC 数据上传（DL2 回传）、
//   remote 固件升级数据接收（DL3）的完整链路。
//
// 主要功能：
//   1. SGMII PHY/MAC：通过 SGMII_TEMAC_example_design 实现千兆以太网物理层和 MAC 层。
//   2. ARP/ICMP：响应 ARP 请求和 ICMP ping，维护网络可达性。
//   3. UDP 接收分流：ETH_LAN_RX 根据目标端口将 UDP payload 分成 4 类：
//        - 端口 32000 (0x7D00)：寄存器读写（LAN_RX_TYPE=1）
//        - 端口 32002 (0x7D02)：保留
//        - 端口 32003 (0x7D03)：保留
//        - 端口 32004 (0x7D04)：remote 固件升级数据（LAN_RX_TYPE=4）
//   4. 寄存器读写（DL4）：WR_RD_REG_TOP 解析端口 32000 的 payload，输出
//        WR_REG_VALID/ADDR/DATA 和 RD_REG_VALID/ADDR，供 command_monitor_new 解码。
//   5. ADC 数据上传（DL2 回传）：从 data_tx_data/data_tx_valid 接收 ADC 采集数据，
//        通过 LAN_TX_MUX 仲裁后从端口 32001 (0x7D01) 发送回 PC。
//   6. remote 数据接收（DL3）：upgrade_data_rx 解析端口 32004 的固件升级数据，
//        输出 remote_wr_en/remote_wr_data 供 ddr3_ctrl 写入 DDR 后烧录 QSPI。
//   7. 发送仲裁：LAN_TX_MUX 在读寄存器响应、ADC 数据、ARP、ICMP 之间仲裁，
//        优先级：读寄存器 > ADC 数据 > ARP > ICMP。
//
// 时钟域：
//   user_axis_clk：SGMII MAC 用户时钟，通常来自 TEMAC 的 userclk2_out，
//                  所有 UDP/寄存器/数据上传逻辑都在这个域。
//
// 上下游关系：
//   上游：PC 通过 SGMII 发送 UDP 包（寄存器配置、remote 数据）。
//   下游：
//     - WR_REG_*/RD_REG_* → command_monitor_new（DL4 控制链路）
//     - remote_wr_en/remote_wr_data → ddr3_ctrl（DL3 固件升级）
//     - data_tx_data/data_tx_valid ← adcdata_config（DL2 数据回传）
//
//////////////////////////////////////////////////////////////////////////////////
module ETHERNET_TOP#( parameter ILA_DEBUG = 1'b0 )(
    //--------------------------------------------------------------------------
    // SGMII 物理层接口
    //--------------------------------------------------------------------------
    input           gtrefclk_p,                // SGMII 差分参考时钟正端，125 MHz
    input           gtrefclk_n,                // SGMII 差分参考时钟负端
    input           clk_config,                // PHY 配置时钟，通常 50 MHz
    input           locked,                    // 系统时钟 PLL 锁定指示
    output          PHY_RESETn,                // PHY 复位，低有效
    output          PHY_INTn,                  // PHY 中断（当前设计未使用）
    output          PHY_MDC,                   // MDIO 时钟
    inout           PHY_MDIO,                  // MDIO 数据
    output          txp_sgmii,                 // SGMII 发送差分正端
    output          txn_sgmii,                 // SGMII 发送差分负端
    input           rxp_sgmii,                 // SGMII 接收差分正端
    input           rxn_sgmii,                 // SGMII 接收差分负端

    //--------------------------------------------------------------------------
    // 系统控制和状态
    //--------------------------------------------------------------------------
    input           glbl_rst,                  // 全局异步复位
    input           independent_clock_bufg,    // 独立时钟，50 MHz，用于 PHY 初始化
    output          link_up,                   // 链路建立指示
    output          sync_done,                 // SGMII 同步完成
    output          resetdone,                 // MAC/PHY 复位完成

    //--------------------------------------------------------------------------
    // DL4：寄存器读写接口（UDP 端口 32000）
    //--------------------------------------------------------------------------
    output          user_axis_clk,             // MAC 用户时钟，所有 UDP 逻辑的时钟域
    output          user_axis_resetn,          // user_axis_clk 域的复位，高有效
    output          WR_REG_VALID,              // 写寄存器有效，1 拍脉冲
    output  [15:0]  WR_REG_ADDR,               // 写寄存器地址
    output  [31:0]  WR_REG_DATA,               // 写寄存器数据
    output          RD_REG_VALID,              // 读寄存器有效，1 拍脉冲
    output  [15:0]  RD_REG_ADDR,               // 读寄存器地址
    input   [31:0]  RD_REG_DATA,               // 读寄存器返回数据（来自 command_monitor_new）

    //--------------------------------------------------------------------------
    // DL2 回传：ADC 数据上传接口（UDP 端口 32001）
    //--------------------------------------------------------------------------
    output          data_ACK,                  // 数据上传应答，允许 adcdata_config 继续发送
    input           data_req,                  // 数据上传请求，来自 adcdata_config
    output          prog_full,                 // UDP 发送 FIFO 快满标志
    input   [21:0]  data_wr_pack_num,          // 本次上传的包数量
    input   [15:0]  data_wr_last_pack_num,     // 最后一包的字节数
    input   [7:0]   data_tx_data,              // ADC 数据字节流
    input           data_tx_valid,             // ADC 数据字节有效
    output          tx_data_done,              // 本次上传完成

    //--------------------------------------------------------------------------
    // DL3：remote 固件升级数据接收接口（UDP 端口 32004）
    //--------------------------------------------------------------------------
    output   [31:0]  remote_len,               // remote 数据总长度（字节）
    output           remote_wr_en,             // remote 数据写使能
    output   [15:0]  remote_wr_data,           // remote 数据 16-bit
    output           remote_rx_done,           // remote 数据接收完成
    input            remote_rstn,              // remote 链路复位使能（来自 command_monitor_new）
    input            remote_complete           // remote 数据处理完成（来自 ddr3_ctrl）
    );
    //--------------------------------------------------------------------------
    // SGMII MAC/PHY 内部时钟和状态
    //--------------------------------------------------------------------------
    wire        gtrefclk_out;                  // GT 参考时钟输出
    wire        userclk_out;                   // MAC 用户时钟 1
    wire        userclk2_out;                  // MAC 用户时钟 2（通常是 user_axis_clk 的来源）
    wire        rxuserclk_out;                 // 接收用户时钟 1
    wire        rxuserclk2_out;                // 接收用户时钟 2
    wire        pma_reset_out;                 // PMA 复位输出
    wire        mmcm_locked_out;               // MMCM 锁定指示

    //--------------------------------------------------------------------------
    // MAC 层 AXI-Stream 接口（连接 UDP 协议栈）
    //--------------------------------------------------------------------------
    // 接收侧：从 MAC 到 UDP 协议栈
    wire [7:0]  rx_axis_fifo_tdata;            // 接收数据字节
    wire        rx_axis_fifo_tvalid;           // 接收数据有效
    wire        rx_axis_fifo_tlast;            // 接收帧结束

    // 发送侧：从 UDP 协议栈到 MAC
    wire [7:0]  tx_axis_fifo_tdata;            // 发送数据字节
    wire        tx_axis_fifo_tvalid;           // 发送数据有效
    wire        tx_axis_fifo_tlast;            // 发送帧结束
    wire        tx_axis_fifo_tready;           // MAC 发送就绪 
    //==========================================================================
    // 1. SGMII MAC/PHY 实例：SGMII_TEMAC_example_design
    //
    // 功能：实现千兆以太网 SGMII 物理层和 MAC 层，包含 GT 收发器、PCS/PMA、
    //      TEMAC、MDIO 配置接口。输出 AXI-Stream 接口供上层 UDP 协议栈使用。
    //==========================================================================
SGMII_TEMAC_example_design #( .ILA_DEBUG(1'b1))  SGMII_TEMAC_example_design_inst(
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
   .PHY_RESETn              (PHY_RESETn),
   .PHY_INTn                (PHY_INTn),
   .PHY_MDC                 (PHY_MDC),
   .PHY_MDIO                (PHY_MDIO),
   .clk_config              (clk_config),
   .locked                  (locked),
    
   .txn                     (txn_sgmii),                  
   .txp                     (txp_sgmii), 
   .rxn                     (rxn_sgmii),                  
   .rxp                     (rxp_sgmii), 
   .sync_done               (sync_done), 
   .link_up                 (link_up), 
   .resetdone               (resetdone), 
   
   .user_axis_clk           (user_axis_clk),        
   .user_axis_resetn        (user_axis_resetn),              
   .tx_axis_fifo_tlast      (tx_axis_fifo_tlast),   
   .tx_axis_fifo_tvalid     (tx_axis_fifo_tvalid),  
   .tx_axis_fifo_tdata      (tx_axis_fifo_tdata),
   .tx_axis_fifo_tready     (tx_axis_fifo_tready),
                 
   .rx_axis_fifo_tlast      (rx_axis_fifo_tlast),   
   .rx_axis_fifo_tvalid     (rx_axis_fifo_tvalid), 
   .rx_axis_fifo_tdata      (rx_axis_fifo_tdata), 
   .rx_axis_fifo_tready     (1'b1)            
    );

    //==========================================================================
    // UDP/IP 协议参数和端口分配
    //==========================================================================
    wire [47:0] DES_MAC_UDP;                   // 目标 MAC 地址（从 ARP 学习）
    wire [47:0] SOR_MAC_UDP;                   // 本机 MAC 地址（由 ARP_TOP 配置）
    wire [31:0] SOR_IP_UDP;                    // 本机 IP 地址（由 ARP_TOP 配置，默认 192.168.1.8）
    wire [31:0] DES_IP_UDP;                    // 目标 IP 地址（从 ARP 学习）
    wire [15:0] SOR_PORT_UDP;                  // FPGA 源端口（固定 32000）
    wire [15:0] DES_PORT_UDP;                  // 当前发送的目标端口（由 LAN_TX_MUX 选择）

    // UDP 接收端口分配（ETH_LAN_RX 根据这些端口分流 payload）
    wire [15:0] DES_PORT_UDP_RX0;              // 32000：寄存器读写（LAN_RX_TYPE=1）
    wire [15:0] DES_PORT_UDP_RX1;              // 32002：保留
    wire [15:0] DES_PORT_UDP_RX2;              // 32003：保留
    wire [15:0] DES_PORT_UDP_RX3;              // 32004：remote 固件升级数据（LAN_RX_TYPE=4）

    // UDP 发送端口分配
    wire [15:0] DES_PORT_UDP_TX0;              // 32000：读寄存器响应
    wire [15:0] DES_PORT_UDP_TX1;              // 32001：ADC 数据上传

    assign SOR_PORT_UDP         = 16'h7D00;    // FPGA 源端口：32000
    assign DES_PORT_UDP_RX0     = 16'h7D00;    // 32000：寄存器读写
    assign DES_PORT_UDP_RX1     = 16'h7D02;    // 32002：保留
    assign DES_PORT_UDP_RX2     = 16'h7D03;    // 32003：保留
    assign DES_PORT_UDP_RX3     = 16'h7D04;    // 32004：remote 固件升级
    assign DES_PORT_UDP_TX0     = 16'h7D00;    // 32000：读寄存器响应
    assign DES_PORT_UDP_TX1     = 16'h7D01;    // 32001：ADC 数据上传
    //==========================================================================
    // 2. ARP 协议模块：ARP_TOP
    //
    // 功能：响应 ARP 请求，学习 PC 的 MAC/IP 地址，维护地址映射表。
    //      输出 DES_MAC_UDP 和 DES_IP_UDP 供 UDP 发送使用。
    //==========================================================================
wire [7:0]  tx_axis_ARP_tdata;                 // ARP 响应帧数据
wire        tx_axis_ARP_tvalid;                // ARP 响应帧有效
wire        tx_axis_ARP_tlast;                 // ARP 响应帧结束
wire        ARP_req_en;                        // ARP 请求使能（VIO 调试用）
wire        ARP_resp_en;                       // ARP 响应使能（VIO 调试用）
wire        ARP_pc_req;                        // ARP 请求发送标志
wire        ARP_ACK;                           // ARP 发送应答（来自 LAN_TX_MUX）
wire        tx_ARP_busy;                       // ARP 发送忙
ARP_TOP#( .ILA_DEBUG(1'b1) ) ARP_TOP_INST(                                         
    .axi_tclk           (user_axis_clk),      
    .axi_tresetn        (user_axis_resetn),   
    .init_done          (resetdone), 
                  
    .rx_axis_tdata      (rx_axis_fifo_tdata), 
    .rx_axis_tvalid     (rx_axis_fifo_tvalid),
    .rx_axis_tlast      (rx_axis_fifo_tlast), 
    .rx_axis_tready     (),
                  
    .tx_axis_tdata      (tx_axis_ARP_tdata), 
    .tx_axis_tvalid     (tx_axis_ARP_tvalid),
    .tx_axis_tlast      (tx_axis_ARP_tlast), 
    .tx_axis_tready     (tx_axis_fifo_tready),
    
    .ARP_pc_req_o       (ARP_pc_req),
    .ARP_ACK_i          (ARP_ACK),
    .tx_ARP_busy        (tx_ARP_busy),  
    .ARP_req_en         (ARP_req_en),
    .ARP_resp_en        (ARP_resp_en),
    .DES_MAC_ARP        (DES_MAC_UDP),
    .DES_IP_ARP         (DES_IP_UDP),          
    .SOR_MAC_UDP        (SOR_MAC_UDP),  //DA0102030405 
    .SOR_IP_UDP         (SOR_IP_UDP)     //default 192.168.1.8    c0 A8 01 08
    );    
    //==========================================================================
    // 3. ICMP 协议模块：ICMP_TOP
    //
    // 功能：响应 ICMP ping 请求，维护网络可达性。
    //==========================================================================
wire [7:0]  tx_axis_ICMP_tdata;                // ICMP 响应帧数据
wire        tx_axis_ICMP_tvalid;               // ICMP 响应帧有效
wire        tx_axis_ICMP_tlast;                // ICMP 响应帧结束
wire        tx_ICMP_busy;                      // ICMP 发送忙
wire        ICMP_pc_req;                       // ICMP 请求发送标志
wire        ICMP_ACK;                          // ICMP 发送应答（来自 LAN_TX_MUX）
ICMP_TOP ICMP_TOP_INST(
    .axi_tclk           (user_axis_clk),
    .axi_tresetn        (user_axis_resetn),
    .init_done          (resetdone),
    
    .rx_axis_tdata      (rx_axis_fifo_tdata),
    .rx_axis_tvalid     (rx_axis_fifo_tvalid),
    .rx_axis_tlast      (rx_axis_fifo_tlast),
    .rx_axis_tready     (),
    
    .tx_axis_tdata      (tx_axis_ICMP_tdata),
    .tx_axis_tvalid     (tx_axis_ICMP_tvalid),
    .tx_axis_tlast      (tx_axis_ICMP_tlast),
    .tx_axis_tready     (tx_axis_fifo_tready),
    
    .ICMP_pc_req_o      (ICMP_pc_req),
    .ICMP_ACK_i         (ICMP_ACK), 
    .tx_ICMP_busy       (tx_ICMP_busy),
    .SOR_MAC_UDP        (SOR_MAC_UDP),
    .SOR_IP_UDP         (SOR_IP_UDP)
    );  
    //==========================================================================
    // 4. UDP 发送模块：LAN_TX_TOP
    //
    // 功能：将上层 payload 字节流封装成 UDP/IP/MAC 帧，输出到 MAC 发送接口。
    //      接收来自 LAN_TX_MUX 的仲裁后的 payload 和端口号。
    //==========================================================================
wire [7:0]  tx_axis_UDP_tdata;                 // UDP 帧数据
wire        tx_axis_UDP_tvalid;                // UDP 帧有效
wire        tx_axis_UDP_tlast;                 // UDP 帧结束
wire [21:0] wr_pack_num;                       // 本次发送的包数量（来自 LAN_TX_MUX）
wire [15:0] wr_last_pack_num;                  // 最后一包的字节数（来自 LAN_TX_MUX）
wire        tx_fifo_wr_en;                     // payload FIFO 写使能（来自 LAN_TX_MUX）
wire [7:0]  tx_fifo_din;                       // payload FIFO 写数据（来自 LAN_TX_MUX）
wire        wr_done;                           // 本次发送完成
wire        RD_ACK;                            // 读寄存器响应发送应答（来自 LAN_TX_MUX）
 LAN_TX_TOP LAN_TX_TOP_inst (
    // Input Ports - Single Bit    
    .RD_ACK_i                (RD_ACK),
    .data_ACK_i              (data_ACK),
    .prog_full               (prog_full), 
    .wr_pack_num             (wr_pack_num),  
    .wr_last_pack_num        (wr_last_pack_num),                    
    .tx_fifo_wr_en           (tx_fifo_wr_en), 
    .tx_fifo_din             (tx_fifo_din[7:0]),  
    .wr_done                 (wr_done),     
    // ETH     
//    .DES_MAC                 (48'hFFFF_FFFF_FFFF),  //DES_MAC_UDP[47:0]   GUANGBO
    .DES_MAC                 (DES_MAC_UDP),  //DES_MAC_UDP[47:0]   GUANGBO
    .SOR_MAC                 (SOR_MAC_UDP[47:0]),           
    .FRAME_TYPE              (16'h0800),
    //IP
    .IP_VERSION              (16'h4500),     
    .IP_INF                  (32'h0000FF11),        //Flags/Fragment/Time2live/Protocol     
    .IP_PAC_ID               (16'h0000),            //identification
//    .DES_IP                  (32'hFFFF_FFFF),       //DES_IP_UDP[31:0]   GUANGBO
    .DES_IP                  (DES_IP_UDP),       //DES_IP_UDP[31:0]   GUANGBO
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
    //==========================================================================
    // 5. UDP 接收分流模块：ETH_LAN_RX
    //
    // 功能：从 MAC 接收 AXI-Stream 帧，解析 MAC/IP/UDP 头，根据目标端口
    //      将 payload 分流到不同的业务模块：
    //        - 端口 32000 → LAN_RX_TYPE=1 → 寄存器读写
    //        - 端口 32004 → LAN_RX_TYPE=4 → remote 固件升级
    //      输出 payload 字节流和类型标志。
    //==========================================================================
wire [15:0] LAN_DATA_NUM;                      // UDP payload 长度（字节）
wire        lan_data_valid;                    // payload 字节有效
wire [7:0]  lan_data_out;                      // payload 字节数据
wire [3:0]  LAN_RX_TYPE;                       // payload 类型：1=寄存器，4=remote 
ETH_LAN_RX#( .ILA_DEBUG(1'b1) ) ETH_LAN_RX_INST(
    .clk(user_axis_clk),
    .reset_n(user_axis_resetn),
    .init_done(resetdone),
    
    .lan_data_en(!rx_axis_fifo_tvalid),
    .lan_data_in(rx_axis_fifo_tdata),
    .rx_axis_fifo_tlast(rx_axis_fifo_tlast),
    
    .SOR_MAC_i(SOR_MAC_UDP),                //for board
    .SOR_IP_i(SOR_IP_UDP),                  //for board
    .SOR_PORT_UDP_i(SOR_PORT_UDP),
    .DES_PORT_UDP_RX0_i(DES_PORT_UDP_RX0),  //write and read reg port
    .DES_PORT_UDP_RX1_i(DES_PORT_UDP_RX1),
    .DES_PORT_UDP_RX2_i(DES_PORT_UDP_RX2),
    .DES_PORT_UDP_RX3_i(DES_PORT_UDP_RX3),
    .LAN_DATA_NUM(LAN_DATA_NUM),
    .LAN_RX_TYPE(LAN_RX_TYPE),
    .lan_data_valid(lan_data_valid),        //64 byte data valid
    .lan_data_out(lan_data_out)             //64 byte data     
    );             
        
    //==========================================================================
    // 6. remote 固件升级数据接收模块：upgrade_data_rx
    //
    // 功能：解析 LAN_RX_TYPE=4 的 payload（端口 32004），输出 remote 数据
    //      供 ddr3_ctrl 写入 DDR，最终烧录到 QSPI Flash。
    //==========================================================================
upgrade_data_rx upgrade_data_rx_inst(
    .clk                (user_axis_clk),
    .rstn               (user_axis_resetn),
    .LAN_RX_TYPE_i      (LAN_RX_TYPE[3:0]),    
    .lan_data_valid_i   (lan_data_valid), 
    .lan_data_i         (lan_data_out[7:0]),  
    
    .remote_len         (remote_len),
    .remote_wr_en       (remote_wr_en),
    .remote_wr_data     (remote_wr_data),
    .remote_rx_done     (remote_rx_done),
    .remote_rstn        (remote_rstn),
    .remote_complete    (remote_complete)
    );

    //==========================================================================
    // 7. 寄存器读写解析模块：WR_RD_REG_TOP（DL4 核心）
    //
    // 功能：解析 LAN_RX_TYPE=1 的 payload（端口 32000），拆包成寄存器读写命令：
    //        - 写命令格式：55 55 AA AA 00 01 00 06 [ADDR] [DATA]
    //        - 读命令格式：55 55 AA AA 00 02 00 02 [ADDR]
    //      输出 WR_REG_VALID/ADDR/DATA 和 RD_REG_VALID/ADDR 供 command_monitor_new。
    //      同时生成读寄存器响应 payload（14 字节）供 LAN_TX_MUX 发送。
    //==========================================================================
wire        RD_REG_req;                        // 读寄存器响应请求（发给 LAN_TX_MUX）
wire        lan_data_valid_rd;                 // 读寄存器响应 payload 有效
wire [7:0]  lan_data_rd;                       // 读寄存器响应 payload 字节
 
 WR_RD_REG_TOP#( .ILA_DEBUG(1'b1)) WR_RD_REG_TOP_inst (
    .tx_fifo_clock      (user_axis_clk),          
    .reset_n            (user_axis_resetn),  
    .WR_REG_VALID       (WR_REG_VALID),
    .WR_REG_ADDR        (WR_REG_ADDR),
    .WR_REG_DATA        (WR_REG_DATA),
    .RD_REG_VALID       (RD_REG_VALID),
    .RD_REG_ADDR        (RD_REG_ADDR),
    .RD_REG_DATA        (RD_REG_DATA),
             
    .lan_data_valid_i   (lan_data_valid),
    .lan_data_i         (lan_data_out[7:0]),   
    .LAN_DATA_NUM_i     (LAN_DATA_NUM[15:0]),
    .LAN_RX_TYPE_i      (LAN_RX_TYPE[3:0]),
    
    .RD_ACK_i           (RD_ACK),
    .RD_REG_req_o       (RD_REG_req),
    .lan_data_valid_o   (lan_data_valid_rd),    
    .lan_data_o         (lan_data_rd[7:0])
    );  
    //==========================================================================
    // 8. 发送仲裁模块：LAN_TX_MUX
    //
    // 功能：在多个发送源之间仲裁，选择一路 payload 送给 LAN_TX_TOP 封装发送：
    //        优先级：读寄存器响应 > ADC 数据上传 > ARP > ICMP
    //      同时选择对应的目标端口号（DES_PORT_UDP）。
    //
    // 发送源：
    //   1. 读寄存器响应（RD_REG_req）：14 字节，端口 32000
    //   2. ADC 数据上传（data_req）：可变长度，端口 32001
    //   3. ARP 响应（ARP_pc_req）：ARP 帧
    //   4. ICMP 响应（ICMP_pc_req）：ICMP 帧
    //==========================================================================
LAN_TX_MUX LAN_TX_MUX_inst(
    .fifo_wr_clk_i         (user_axis_clk),
    .resetn_i              (user_axis_resetn),
	  //UDP
	.wr_done_i             (wr_done),
    .wr_pack_num_o         (wr_pack_num),  
    .wr_last_pack_num_o    (wr_last_pack_num),  
    .tx_fifo_din_o         (tx_fifo_din),
    .tx_fifo_wr_en_o       (tx_fifo_wr_en),
    .DES_PORT_o            (DES_PORT_UDP),
    //READ REG
    .RD_REG_req_i          (RD_REG_req),
    .RD_ACK_o              (RD_ACK),
    .read_resp_tx_data_i   (lan_data_rd),
    .read_resp_tx_valid_i  (lan_data_valid_rd),
    .read_resp_port        (DES_PORT_UDP_TX0),
    //TX_DATA
    .tx_data_done          (tx_data_done),
    .data_req_i            (data_req),
    .data_ACK_o            (data_ACK),
    .data_wr_pack_num_i    (data_wr_pack_num),  
    .data_wr_last_pack_num_i(data_wr_last_pack_num),  
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

    //==========================================================================
    // 9. VIO 调试接口：用于手动触发 ARP 请求
    //==========================================================================
vio_ethernet_top inst0(
    .clk(user_axis_clk),                       // input wire clk
    .probe_out0(ARP_req_en)                    // output wire [0 : 0] probe_out0
    );

endmodule

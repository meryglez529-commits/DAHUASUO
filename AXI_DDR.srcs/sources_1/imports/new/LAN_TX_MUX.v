`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/11 11:32:38
// Design Name: 
// Module Name: LAN_TX_MUX
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
// 0. 读这个模块，先记住一句话
//
// LAN_TX_MUX 做的事只有一件：
//   在多个“想从网口发出去”的源之间选一路，把对应 payload/端口/帧流交给后级发送。
//
// 这里有两类输出要分清：
//   UDP payload FIFO 接口：
//     wr_pack_num_o、wr_last_pack_num_o、tx_fifo_wr_en_o、tx_fifo_din_o、DES_PORT_o。
//     它告诉 LAN_TX_TOP 这次 UDP 要发多少包、最后一包多少字节、payload 字节是什么、目标端口是什么。
//   AXI-Stream 帧接口：
//     tx_axis_fifo_tdata/tvalid/tlast。
//     它在 UDP、ARP、ICMP 三类完整以太网发送流之间选择一路送往后级 MAC 发送。
//
// 对 DL4 寄存器读回来说，关键路径是：
//   LAN_RD_REG.RD_REG_req_o -> 本模块 S_RD_REG
//     -> wr_last_pack_num_o=14, DES_PORT_o=read_resp_port(32000)
//     -> read_resp_tx_data_i/read_resp_tx_valid_i 写入 UDP payload FIFO
//------------------------------------------------------------------------------
module LAN_TX_MUX(
    input               fifo_wr_clk_i,
    input               resetn_i,
    //UDP port   
    output  reg [21:0]  wr_pack_num_o,
    output  reg [15:0]  wr_last_pack_num_o,
    output  reg [7:0]   tx_fifo_din_o = 0,
    output  reg         tx_fifo_wr_en_o = 0,
    output  reg [15:0]  DES_PORT_o = 0,
    //read reg resp port input
    input               RD_REG_req_i,
    output  reg         RD_ACK_o =0,  
    input       [7:0]   read_resp_tx_data_i,
    input               read_resp_tx_valid_i,
    input       [15:0]  read_resp_port,
    //tx data port input
    output  reg         tx_data_done = 0,
    input               data_req_i,
    output  reg         data_ACK_o,
    input       [21:0]  data_wr_pack_num_i,
    input       [15:0]  data_wr_last_pack_num_i,      
    input       [7:0]   data_tx_data_i,
    input               data_tx_valid_i,
    input       [15:0]  data_port,
    //arp
    input               ARP_pc_req_i,
    output  reg         ARP_ACK_o,
    input       [7:0]   tx_axis_ARP_tdata, 
    input               tx_axis_ARP_tvalid,
    input               tx_axis_ARP_tlast,
    //icmp
    input               ICMP_pc_req_i,
    output  reg         ICMP_ACK_o = 0,
    input       [7:0]   tx_axis_ICMP_tdata, 
    input               tx_axis_ICMP_tvalid,
    input               tx_axis_ICMP_tlast,
    //user port
    input               wr_done_i,
    input       [7:0]   tx_axis_UDP_tdata,
    input               tx_axis_UDP_tvalid,
    input               tx_axis_UDP_tlast,
    output  reg [7:0]   tx_axis_fifo_tdata = 0,
    output  reg         tx_axis_fifo_tvalid = 0,
    output  reg         tx_axis_fifo_tlast = 0
    );
    
    //--------------------------------------------------------------------------
    // 1. 发送源优先级
    //
    // S_IDLE 中的 if/else 顺序就是仲裁优先级：
    //   读寄存器响应 > ADC 数据上传 > ARP > ICMP
    //
    // 这意味着 PC 高频读寄存器时，会先抢到一次发送机会；
    // ADC 数据上传仍会在读回包发完后继续竞争发送口。
    //--------------------------------------------------------------------------
    reg [3:0] state;   
    parameter S_IDLE    = 4'b0001;
    parameter S_ARP     = 4'b0011;
    parameter S_ICMP    = 4'b0100;
    parameter S_RD_REG  = 4'b0101;
    parameter S_TX_DATA = 4'b0110;
always@(posedge fifo_wr_clk_i) 
begin
    if(!resetn_i) begin
       wr_pack_num_o    <= 0;
       wr_last_pack_num_o<= 0;
       tx_fifo_din_o    <= 0;
       tx_fifo_wr_en_o  <= 0;
       DES_PORT_o       <= 0;
       RD_ACK_o         <= 0;
       data_ACK_o       <= 0;
       ARP_ACK_o        <= 0;
       ICMP_ACK_o       <= 0;
       state            <= S_IDLE;
    end
    else case(state)
    S_IDLE: 
    begin
        // UDP 类发送源在 wr_done_i 未拉高的周期进入对应发送状态；
        // 进入后一直等待 wr_done_i 表示本轮 UDP 发送完成。
        // 读回包固定 14 字节，代码顺序上优先于 ADC 数据上传。
        if(RD_REG_req_i && !wr_done_i) begin          //read reg     
            RD_ACK_o    <= 1'b1;
            state       <= S_RD_REG; end 
        else if(data_req_i && !wr_done_i) begin      //read data
            tx_data_done<= 1'b0;
            data_ACK_o  <= 1'b1;
            state       <= S_TX_DATA;  end
        else if(ARP_pc_req_i) begin                 //ARP
            ARP_ACK_o   <= 1'b1;
            state       <= S_ARP; end
        else if(ICMP_pc_req_i) begin                //PING
            ICMP_ACK_o  <= 1'b1;
            state       <= S_ICMP; end
        else
            state <= S_IDLE;
    end
    S_RD_REG:
    begin
        // 读寄存器响应：
        //   一次只发 1 个 UDP payload，最后一包长度固定 14 字节。
        //   read_resp_port 在顶层接 DES_PORT_UDP_TX0，即 0x7D00/32000。
        //   RD_ACK_o 保持到 wr_done_i，LAN_RD_REG 在 ACK 上升沿后开始吐 14 个字节。
        wr_pack_num_o <= 22'd1;
        wr_last_pack_num_o <= 16'd14; 
        tx_fifo_wr_en_o <= read_resp_tx_valid_i;
        tx_fifo_din_o   <= read_resp_tx_data_i;
        DES_PORT_o      <= read_resp_port;
        
        tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
        tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
        tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
        if(wr_done_i) begin
            state <= S_IDLE;
            RD_ACK_o <= 1'b0;
        end
        else
            state <= S_RD_REG;  
    end
    S_TX_DATA:
    begin
        // ADC/业务数据上传：
        //   包数量、最后一包长度和目标端口都由上游数据发送模块给出。
        //   顶层把 data_port 接到 DES_PORT_UDP_TX1，即 0x7D01/32001。
        //   tx_data_done 在 wr_done_i 到来时打一拍，通知上游本轮发送完成。
        wr_pack_num_o <= data_wr_pack_num_i;
        wr_last_pack_num_o <= data_wr_last_pack_num_i;
        tx_fifo_wr_en_o <= data_tx_valid_i;
        tx_fifo_din_o   <= data_tx_data_i;
        DES_PORT_o      <= data_port;
        
        tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
        tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
        tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
        if(wr_done_i) begin
            tx_data_done <= 1'b1;
            state <= S_IDLE;
            data_ACK_o      <= 1'b0;
        end
        else
            state <= S_TX_DATA;                    
    end
    S_ARP:
    begin
        // ARP 不是 UDP payload，不使用 tx_fifo_din_o 这组 payload FIFO 接口。
        // 这里直接把 ARP 模块已经生成好的 AXI-Stream 帧转接到后级。
        tx_axis_fifo_tdata  <= tx_axis_ARP_tdata;
        tx_axis_fifo_tvalid <= tx_axis_ARP_tvalid;
        tx_axis_fifo_tlast  <= tx_axis_ARP_tlast;
        if(ARP_pc_req_i)
            state <= S_ARP;  
        else begin
            state <= S_IDLE;
            ARP_ACK_o <= 1'b0;
        end
    end
    S_ICMP:
    begin
        // ICMP/PING 同样是完整帧流转接；请求保持期间一直停在 S_ICMP。
        tx_axis_fifo_tdata  <= tx_axis_ICMP_tdata;
        tx_axis_fifo_tvalid <= tx_axis_ICMP_tvalid;
        tx_axis_fifo_tlast  <= tx_axis_ICMP_tlast;
        if(ICMP_pc_req_i)
            state <= S_ICMP;  
        else begin
            state <= S_IDLE;
            ICMP_ACK_o <= 1'b0;
        end
    end
    default:
    begin
        tx_fifo_din_o    <= 0;
        tx_fifo_wr_en_o  <= 0;
        DES_PORT_o       <= 0;
        RD_ACK_o         <= 0;
        data_ACK_o       <= 0;
        ARP_ACK_o        <= 0;
        ICMP_ACK_o       <= 0;
        state            <= S_IDLE; 
    end
    endcase
end
endmodule

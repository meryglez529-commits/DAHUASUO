`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/11 15:15:52
// Design Name: 
// Module Name: LAN_RD_REG
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
// LAN_RD_REG 做的事只有一件：
//   把 command_monitor_new 查出来的 16-bit 地址 + 32-bit 数据，打包成 PC 能识别的
//   14 字节“读寄存器响应 payload”。
//
// 它不查寄存器表，也不负责 UDP 头：
//   REG_ADDR/REG_DATA 已经由 WR_RD_REG_TOP 和 command_monitor_new 准备好。
//   本模块只生成 payload 字节流，并用 RD_REG_req_o 请求 LAN_TX_MUX 给它一次发送机会。
//
// 在 DL4 读回链路中的位置：
//   RD_REG_VALID/RD_REG_ADDR -> command_monitor_new -> RD_REG_DATA
//     -> WR_RD_REG_TOP 延迟 3 拍
//     -> LAN_RD_REG 打包 14 字节 payload
//     -> LAN_TX_MUX 仲裁后发回 UDP 32000 端口
//------------------------------------------------------------------------------
module LAN_RD_REG(
    input                   tx_fifo_clock,
    input                   reset_n,
    
    input                   REG_VALID,
    input           [15:0]  REG_ADDR, 
    input           [31:0]  REG_DATA,
    
    output  reg             RD_REG_req_o = 0,
    input                   RD_ACK_i,
    output  reg             lan_data_valid_o = 0,
    output  reg     [7:0]   lan_data_o = 0
    );
    
    reg [15:0] REG_ADDR_r;
    reg [31:0] REG_DATA_r;

    //--------------------------------------------------------------------------
    // 1. 固定响应格式：14 字节，大端字节序
    //
    // PC 读寄存器请求是 10 字节：
    //   55 55 AA AA 00 02 00 02 ADDR[15:0]
    //
    // FPGA 读回响应是 14 字节：
    //   55 55 AA AA 00 03 00 06 ADDR[15:0] DATA[31:0]
    //
    // packet_array 不是 RAM，只是把“第 N 个要发送的字节”写成一个查表形式。
    // REG_ADDR_r/REG_DATA_r 在收到 REG_VALID 时锁存，避免发送过程中上游变化影响本包。
    //--------------------------------------------------------------------------
    wire [7:0] packet_array [13:0];
    assign packet_array[0] = 8'h55;
    assign packet_array[1] = 8'h55;
    assign packet_array[2] = 8'hAA;
    assign packet_array[3] = 8'hAA;
    assign packet_array[4] = 8'h00;
    assign packet_array[5] = 8'h03;
    assign packet_array[6] = 8'h00;
    assign packet_array[7] = 8'h06;
    assign packet_array[8] = REG_ADDR_r[15:8];
    assign packet_array[9] = REG_ADDR_r[7:0];
    assign packet_array[10] = REG_DATA_r[31:24];
    assign packet_array[11] = REG_DATA_r[23:16];
    assign packet_array[12] = REG_DATA_r[15:8];
    assign packet_array[13] = REG_DATA_r[7:0];
   
    //--------------------------------------------------------------------------
    // 2. 发送许可握手：检测 RD_ACK_i 的上升沿
    //
    // RD_REG_req_o 拉高表示“我有一包读回 payload 要发”。
    // LAN_TX_MUX 选中读回通道后拉高 RD_ACK_i。
    // 这里用 r0/r1 做上升沿检测，只在 ACK 新来的那一拍进入发送状态。
    //--------------------------------------------------------------------------
    reg  RD_ACK_r0;
    reg  RD_ACK_r1;
always@(posedge tx_fifo_clock or negedge reset_n)
begin
    if(!reset_n)
        begin RD_ACK_r0 <= 1'b0;     RD_ACK_r1 <= 1'b0; end
    else 
        begin RD_ACK_r0 <= RD_ACK_i; RD_ACK_r1 <= RD_ACK_r0; end
end
    
    //--------------------------------------------------------------------------
    // 3. 读回发送状态机：锁存 -> 请求仲裁 -> 连续吐 14 个字节
    //
    // 状态 0：等待 REG_VALID。收到后锁存地址/数据，并保持 RD_REG_req_o=1。
    // 状态 1：等待 LAN_TX_MUX 的 RD_ACK_i 上升沿。
    // 状态 2：每拍输出 packet_array[byte_cnt]，共 14 拍。
    //
    // 数据单位要分清：
    //   REG_DATA 是 32-bit 寄存器值；
    //   lan_data_o 是 8-bit payload 字节；
    //   byte_cnt 计的是“读回 payload 的字节序号”，不是寄存器地址。
    //--------------------------------------------------------------------------
    reg [2:0] fsm_r;
    reg [4:0] byte_cnt;
always@(posedge tx_fifo_clock or negedge reset_n)
begin
    if(!reset_n) begin
        fsm_r       <= 0;
        byte_cnt    <= 0;
        REG_ADDR_r  <= 16'd0;
        REG_DATA_r  <= 32'd0;
        RD_REG_req_o    <= 0;
    end
    else 
        case(fsm_r)
        0:begin
            if(REG_VALID) begin
                REG_ADDR_r <= REG_ADDR;
                REG_DATA_r <= REG_DATA;
                RD_REG_req_o <= 1'b1;   //request
                fsm_r <= 1;
            end
            else begin
                RD_REG_req_o <= 1'b0;   //request
                fsm_r <= 0; 
            end
        end
        1:begin
            if(RD_ACK_r0 && !RD_ACK_r1) //waiting for ack
                fsm_r <= 2;
            else
                fsm_r <= 1; 
        end
        2:begin
            if(byte_cnt < 5'd14) begin
                lan_data_valid_o <= 1'b1;
                lan_data_o <= packet_array[byte_cnt];
                byte_cnt <= byte_cnt +1'b1;
                fsm_r <= 2;
            end
            else begin
                lan_data_valid_o <= 1'b0;
                lan_data_o       <= 0;
                byte_cnt         <= 0;
                fsm_r            <= 0;
                RD_REG_req_o     <= 0;
            end
        end
        default:begin
            fsm_r    <= 0;
            byte_cnt <= 0;
        end
        endcase   
end
     
endmodule

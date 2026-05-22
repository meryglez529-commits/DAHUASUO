`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       PANDA
// 
// Create Date:    10:06:24 11/28/2014 
// Design Name: 
// Module Name:    LAN_TX_ARP 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module LAN_TX_ARP#( parameter ILA_DEBUG = 1'b0 )(
    input               clk,
    input               reset_n,
    input               init_done,
    input               ARP_req_en,
    input               ARP_resp_en,
    input               ARP_ACK_i,
    output reg          ARP_pc_req_o,
    input       [47:0]  SOR_MAC_i,
    input       [47:0]  DES_MAC_i,
    input       [31:0]  SOR_IP_i,
    input       [31:0]  DES_IP_i,
    
    input       [47:0]  arp_data0,
    input       [47:0]  arp_data1,
    input       [47:0]  arp_data2,
    input       [47:0]  arp_data3,
    
    input               lan_rdy_n,
    output reg  [7:0]   lan_data,
    output reg         lan_vld_n,
    output              lan_sof_n,
    output reg         lan_eof_n,
    output reg         ARP_busy
    );
//*********************************************************//
/***** register declaration ******/
//*********************************************************//
reg  [47:0] DES_MAC;
reg  [31:0] DES_IP; 
reg  [15:0] ARP_TYPE;
always @(posedge clk or negedge reset_n)
begin
    if(!reset_n)
        begin
          ARP_TYPE <= 16'h0000;
          DES_MAC  <= 48'hFF_FF_FF_FF_FF_FF;
          DES_IP   <= 32'hC0_A8_01_64;
        end
    else if(ARP_req_en)
        begin
          ARP_TYPE <= 16'h0001;             //ARP request 广播包
          DES_MAC  <= 48'hFF_FF_FF_FF_FF_FF;
          DES_IP   <= 32'hC0_A8_01_64;      //192.168.1.100 ben di to arp pc ip
        end
    else if(ARP_resp_en)
        begin
          ARP_TYPE <= 16'h0002;             //ARP response 单播包
          DES_MAC  <= DES_MAC_i;
          DES_IP   <= DES_IP_i;
        end
   else
       begin
          ARP_TYPE <= ARP_TYPE; 
          DES_MAC  <= DES_MAC;
          DES_IP   <= DES_IP; 
       end
end

reg   [31:0]   SOR_IP_r;
always@(posedge clk or negedge reset_n)
begin
   if(!reset_n)
        SOR_IP_r <= SOR_IP_i;
   else if(!lan_eof_n)
        SOR_IP_r <= SOR_IP_i;
   else
        SOR_IP_r <= SOR_IP_r;  
end
//*********************************************************//
/*****  Begin Design Instance  *****/
//*********************************************************//
wire    lan_tx_ARP_en;
assign lan_tx_ARP_en = ARP_req_en | ARP_resp_en;
reg     lan_tx_ARP_en_r0;
reg     lan_tx_ARP_en_r1;
wire    lan_tx_ARP_enable;
assign lan_tx_ARP_enable = lan_tx_ARP_en_r0 && !lan_tx_ARP_en_r1;//rising edge
always @(posedge clk or negedge reset_n)
begin
    if(!reset_n) begin
        lan_tx_ARP_en_r0 <= 1'b0;
        lan_tx_ARP_en_r1 <= 1'b0;
    end
    else begin
        lan_tx_ARP_en_r0 <= lan_tx_ARP_en;
        lan_tx_ARP_en_r1 <= lan_tx_ARP_en_r0;
    end
end
	
wire [7:0]  ctrl_array [65:0];
wire [15:0] FRAME_TYPE;
wire [15:0] HW_TYPE;
wire [15:0] PROTOCOL_TYPE;
wire [7:0]  ADDR_HW_LEN;
wire [7:0]  ADDR_PRO_LEN;
assign  FRAME_TYPE      = 16'h0806; 
assign  HW_TYPE         = 16'h0001;    
assign  PROTOCOL_TYPE   = 16'h0800;   
assign  ADDR_HW_LEN     = 8'h06; 
assign  ADDR_PRO_LEN    = 8'h04;  
//ARP FRAME 60Byte
assign  ctrl_array[0]  = DES_MAC[47:40];        //PC MAC 地址
assign  ctrl_array[1]  = DES_MAC[39:32];
assign  ctrl_array[2]  = DES_MAC[31:24];
assign  ctrl_array[3]  = DES_MAC[23:16];
assign  ctrl_array[4]  = DES_MAC[15:8];
assign  ctrl_array[5]  = DES_MAC[7:0];
assign  ctrl_array[6]  = SOR_MAC_i[47:40];      //板子 MAC 地址
assign  ctrl_array[7]  = SOR_MAC_i[39:32];
assign  ctrl_array[8]  = SOR_MAC_i[31:24];
assign  ctrl_array[9]  = SOR_MAC_i[23:16];
assign  ctrl_array[10] = SOR_MAC_i[15:8];
assign  ctrl_array[11] = SOR_MAC_i[7:0];
assign  ctrl_array[12] = FRAME_TYPE[15:8];      //帧类型
assign  ctrl_array[13] = FRAME_TYPE[7:0];
assign  ctrl_array[14] = HW_TYPE[15:8];
assign  ctrl_array[15] = HW_TYPE[7:0];
assign  ctrl_array[16] = PROTOCOL_TYPE[15:8];   //协议类型
assign  ctrl_array[17] = PROTOCOL_TYPE[7:0];
assign  ctrl_array[18] = ADDR_HW_LEN;           //硬件地址长度
assign  ctrl_array[19] = ADDR_PRO_LEN;          //协议地址长度
assign  ctrl_array[20] = ARP_TYPE[15:8];        //ARP请求or应答
assign  ctrl_array[21] = ARP_TYPE[7:0];
assign  ctrl_array[22] = SOR_MAC_i[47:40];      //板子 MAC 地址
assign  ctrl_array[23] = SOR_MAC_i[39:32];
assign  ctrl_array[24] = SOR_MAC_i[31:24];
assign  ctrl_array[25] = SOR_MAC_i[23:16];
assign  ctrl_array[26] = SOR_MAC_i[15:8];
assign  ctrl_array[27] = SOR_MAC_i[7:0];
assign  ctrl_array[28] = SOR_IP_r[31:24];       //板子 IP 地址
assign  ctrl_array[29] = SOR_IP_r[23:16];   
assign  ctrl_array[30] = SOR_IP_r[15:8];
assign  ctrl_array[31] = SOR_IP_r[7:0];
assign  ctrl_array[32] = DES_MAC[47:40];        //PC MAC 地址
assign  ctrl_array[33] = DES_MAC[39:32];
assign  ctrl_array[34] = DES_MAC[31:24];
assign  ctrl_array[35] = DES_MAC[23:16];
assign  ctrl_array[36] = DES_MAC[15:8];
assign  ctrl_array[37] = DES_MAC[7:0];
assign  ctrl_array[38] = DES_IP[31:24];         //PC IP 地址
assign  ctrl_array[39] = DES_IP[23:16];
assign  ctrl_array[40] = DES_IP[15:8];
assign  ctrl_array[41] = DES_IP[7:0];
assign  ctrl_array[42] = {arp_data0[47:40]};    //修改设备IP地址，原码返回
assign  ctrl_array[43] = {arp_data0[39:32]};
assign  ctrl_array[44] = {arp_data0[31:24]};
assign  ctrl_array[45] = {arp_data0[23:16]};
assign  ctrl_array[46] = {arp_data0[15:8]};
assign  ctrl_array[47] = {arp_data0[7:0]};
assign  ctrl_array[48] = {arp_data1[47:40]};    //设备名称
assign  ctrl_array[49] = {arp_data1[39:32]};
assign  ctrl_array[50] = {arp_data1[31:24]};
assign  ctrl_array[51] = {arp_data1[23:16]};
assign  ctrl_array[52] = {arp_data1[15:8]}; 
assign  ctrl_array[53] = {arp_data1[7:0]};  
assign  ctrl_array[54] = {arp_data2[47:40]};
assign  ctrl_array[55] = {arp_data2[39:32]};
assign  ctrl_array[56] = {arp_data2[31:24]};    //当前连接的主机IP
assign  ctrl_array[57] = {arp_data2[23:16]};
assign  ctrl_array[58] = {arp_data2[15:8]}; 
assign  ctrl_array[59] = {arp_data2[7:0]}; 
assign  ctrl_array[60] = {arp_data3[47:40]};    //当前连接的主机MAC
assign  ctrl_array[61] = {arp_data3[39:32]};
assign  ctrl_array[62] = {arp_data3[31:24]};
assign  ctrl_array[63] = {arp_data3[23:16]};
assign  ctrl_array[64] = {arp_data3[15:8]}; 
assign  ctrl_array[65] = {arp_data3[7:0]}; 


reg         ARP_ACK_r0;
reg         ARP_ACK_r1;	
always @(posedge clk or negedge reset_n)
begin
    if(!reset_n)begin
        ARP_ACK_r0 <= 1'b1;
        ARP_ACK_r1 <= 1'b1;
    end
    else begin
        ARP_ACK_r0 <= ARP_ACK_i;
        ARP_ACK_r1 <= ARP_ACK_r0;
    end
end
               
reg  [6:0]  cnt_byte;
assign  lan_sof_n     = ((!lan_rdy_n) && (cnt_byte == 1)) ? 0 : 1;
reg  [2:0]  state;
localparam   idle    = 3'b001;
localparam   ARP_tx  = 3'b010;	
localparam   ARP_tx_wait  = 3'b011;	
always @(posedge clk or negedge reset_n)
begin
    if(!reset_n)begin
        cnt_byte    <= 7'd0;
        lan_data    <= 8'h00;
        lan_vld_n   <= 1;
        lan_eof_n   <= 1;
        ARP_busy    <= 0;
        ARP_pc_req_o <= 0;
        state       <= idle;
    end
    else begin
        case(state)
        idle:   
        begin
            cnt_byte    <= 7'd0;
            lan_data    <= 8'h00;
            lan_vld_n   <= 1;
            lan_eof_n   <= 1;
            ARP_busy    <= 0;
            if(init_done && lan_tx_ARP_enable)begin
                ARP_busy <= 1;
                ARP_pc_req_o <= 1'b1;
                state    <= ARP_tx_wait;
            end
            else begin
                ARP_busy <= 0;
                ARP_pc_req_o <= 0;
                state    <= idle;
            end
        end
        ARP_tx_wait:
        begin
            if(ARP_ACK_r0 && !ARP_ACK_r1)
                state <= ARP_tx;
            else
                state <= ARP_tx_wait; 
        end	
        ARP_tx:
        begin
            if(cnt_byte == 7'd65)begin
                lan_eof_n <= 0;
                lan_data  <= ctrl_array[cnt_byte];
                lan_vld_n <= 0;
                state     <= idle;
            end
            else begin
                cnt_byte  <= cnt_byte + 1'b1;
                lan_data  <= ctrl_array[cnt_byte];
                lan_vld_n <= 0;
                state     <= ARP_tx;
            end
        end
		default:
		begin
            cnt_byte    <= 7'd0;
            lan_data    <= 8'h00;
            lan_vld_n   <= 1;
            lan_eof_n   <= 1;
            ARP_busy    <= 0;
            state       <= idle;
        end
        endcase
	end
end
//-------------------ila------------------------------------
//generate    
//    if(ILA_DEBUG) begin:ila_debug 	
//        ARP_TX_ILA inst_ARP_TX_ILA (
//        .clk(clk), // input wire clk
//        .probe0(lan_data), // input wire [7:0]  probe0  
//        .probe1(lan_vld_n), // input wire [0:0]  probe1 
//        .probe2(lan_sof_n), // input wire [0:0]  probe2 
//        .probe3(lan_eof_n), // input wire [0:0]  probe3 
//        .probe4(ARP_busy), // input wire [0:0]  probe4 
//        .probe5(ARP_resp_en), // input wire [0:0]  probe5 
//        .probe6(lan_tx_ARP_en), // input wire [0:0]  probe6 
//        .probe7(state), // input wire [1:0]  probe7 
//        .probe8(cnt_byte), // input wire [5:0]  probe8 
//        .probe9(DES_MAC), // input wire [47:0]  probe9 
//        .probe10(SOR_MAC_i), // input wire [47:0]  probe10 
//        .probe11(DES_IP), // input wire [31:0]  probe11 
//        .probe12(SOR_IP_i), // input wire [31:0]  probe12
//        .probe13(ARP_pc_req_o), // input wire [0:0]  probe12
//        .probe14(ARP_ACK_i) // input wire [0:0]  probe12
//    );
//    end
//endgenerate 
endmodule

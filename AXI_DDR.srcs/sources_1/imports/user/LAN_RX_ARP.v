`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       PANDA 
// 
// Create Date:    10:44:16 11/28/2014 
// Design Name: 
// Module Name:    LAN_RX_ARP 
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
module LAN_RX_ARP#( parameter ILA_DEBUG = 1'b0 )(
    input               clk,
    input               reset_n,
    input               init_done,
    
    input               lan_data_en,
    input        [7:0]  lan_data_in,
    
    output       [47:0] SOR_MAC_o,      //for board
    output       [31:0] SOR_IP_o,       //for board
    
    output  reg [47:0]  DES_MAC_o,      //for board
    output  reg [31:0]  DES_IP_o,       //for board
    
    output  reg         ARP_req_en,
    output  reg         ARP_resp_en,
    output  reg [47:0]  arp_data0,
    output  reg [47:0]  arp_data1,
    output  reg [47:0]  arp_data2
    );
/////////////////////////////////////////////////////////////	
//---------------����IP����----------------------------------
reg         rx_success;
reg  [31:0] SOR_IP_r;       //DEFAULT IP    192.168.1.8 
reg  [47:0] SOR_MAC_r;      //DEFAULT MAC   DA0102030405 
assign SOR_IP_o  = SOR_IP_r;
assign SOR_MAC_o = SOR_MAC_r;
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)begin
       SOR_IP_r <= 32'hC0A80108;
       SOR_MAC_r <= 48'h5C857EEE0000;
    end
    else 
        if(rx_success==1 && arp_data0[47:32] == 16'h5A5A) 
            SOR_IP_r <= arp_data0[31:0];
        else
            SOR_IP_r <= SOR_IP_r;
end
/////////////////////////////////////////////////////////////
//-------------------------ARPЭ����ս���-------------------
reg         lan_data_en_r;
reg  [7:0]  lan_data_in_r;
reg  [7:0]  lan_data_in_2r;
reg  [7:0]  lan_data_in_3r;
reg  [7:0]  lan_data_in_4r;
reg  [7:0]  lan_data_in_5r;
wire        lan_data_en_p;
wire [47:0] judge_array;
assign  lan_data_en_p   = !lan_data_en && lan_data_en_r;
assign  judge_array     = {lan_data_in_5r,lan_data_in_4r,lan_data_in_3r,lan_data_in_2r,lan_data_in_r,lan_data_in};	
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)begin
        lan_data_en_r     <= 1'd0;
        lan_data_in_r     <= 8'd0;
        lan_data_in_2r    <= 8'd0;
        lan_data_in_3r    <= 8'd0;
        lan_data_in_4r    <= 8'd0;
        lan_data_in_5r    <= 8'd0;
    end
    else begin
        lan_data_en_r     <= lan_data_en;
        lan_data_in_r     <= lan_data_in;
        lan_data_in_2r    <= lan_data_in_r;
        lan_data_in_3r    <= lan_data_in_2r;
        lan_data_in_4r    <= lan_data_in_3r;
        lan_data_in_5r    <= lan_data_in_4r;
    end
end	
	
reg  [4:0] state;		
localparam  idle                  = 5'b00001;      //1
localparam  start                 = 5'b00010;      //2
localparam  frame_type_judge      = 5'b00011;      //3
localparam  ARP_resolution        = 5'b00100;      //4	
localparam  ARP_req_success       = 5'b00101;      //5  	
reg   [5:0]    ARP_packet_time_cnt;
reg   [3:0]    start_wait_cnt;
reg   [15:0]   FRAME_TYPE;          //֡����
reg   [15:0]   HW_TYPE;             //Ӳ������
reg   [15:0]   PROTOCOL_TYPE;       //Э������
reg   [7:0]    MAC_LENGTH;          //Ӳ����ַ����
reg   [7:0]    IP_LENGTH;           //Э���ַ����
reg   [15:0]   ARP_TYPE;            //OP�ֶ�
reg   [47:0]   SOR_MAC;             //PC MAC��ַ
reg   [31:0]   SOR_IP;              //PC IP��ַ
reg   [31:0]   DES_IP;              //���� MAC��ַ
reg   [47:0]   DES_MAC;             //���� IP��ַ   
always@(posedge clk or negedge reset_n)
begin
    if(!reset_n)begin
        state                   <= idle;
        ARP_packet_time_cnt     <= 6'd0;
        start_wait_cnt          <= 4'b0;
        rx_success              <= 1'b0;
        FRAME_TYPE              <= 16'd0;
        HW_TYPE                 <= 16'd0;
        PROTOCOL_TYPE           <= 16'd0;
        MAC_LENGTH              <= 8'd6;
        IP_LENGTH               <= 8'd4;
        ARP_TYPE                <= 16'd0;
        SOR_MAC                 <= 48'd0;
        SOR_IP                  <= 32'd0;
        DES_MAC                 <= 48'd0;
        DES_IP                  <= 32'd0;
        
        DES_MAC_o               <= 48'd0;
        DES_IP_o                <= 32'd5;
        ARP_req_en              <= 1'b0;
        ARP_resp_en             <= 1'b0;
        arp_data0               <= 48'd0;
        arp_data1               <= 48'd0;
        arp_data2               <= 48'd0;
    end
    else begin
        case(state)
        idle:                                  //1   
        begin                                
            ARP_packet_time_cnt     <= 6'd0;
            start_wait_cnt          <= 4'b0;
            rx_success              <= 1'b0;
            ARP_req_en              <= 1'b0;
            ARP_resp_en             <= 1'b0;
            if(init_done && lan_data_en_p)//20151222
                state <= start;
            else 
                state <= idle;
        end		
        start:                                 //2
        begin
            if(lan_data_en == 0)
                if(start_wait_cnt == 4'd11)begin
                    start_wait_cnt <= 0;
                    state <= frame_type_judge;
                end
                else begin
                    start_wait_cnt <= start_wait_cnt + 1;
                    state <= start;
                end
            else
                state <= idle;
        end		
        frame_type_judge:                        //3
        begin
            if(judge_array[15:0] == 16'h0806)
                state <= ARP_resolution;
            else
                state <= idle;
        end      
        ARP_resolution:                          //4
        begin
            if(ARP_packet_time_cnt == 6'd45)begin
                ARP_packet_time_cnt <= 6'd0;
                arp_data2           <= judge_array;
                state               <= ARP_req_success;
            end
            else begin
                ARP_packet_time_cnt <= ARP_packet_time_cnt + 1'b1;
                case(ARP_packet_time_cnt)
                6'd3:   begin
                            if(judge_array == 48'h080600010800)begin
                                FRAME_TYPE      <= {judge_array[47:32]};
                                HW_TYPE         <= {judge_array[31:16]};
                                PROTOCOL_TYPE   <= {judge_array[15:0]};
                            end
                            else
                                state    <= idle;
                        end
                6'd7:   begin
                            if(judge_array[15:0] == 16'h0001 || 16'h0002)begin
                                MAC_LENGTH      <= {judge_array[31:24]};
                                IP_LENGTH       <= {judge_array[23:16]};
                                ARP_TYPE        <= {judge_array[15:0]};
                            end
                            else
                                state    <= idle;
                        end
                6'd13:  begin SOR_MAC <= judge_array; end       
                6'd17:  begin SOR_IP <= {judge_array[31:0]}; end
                6'd23:  begin DES_MAC <= judge_array; end      
                6'd27:  begin DES_IP <= {judge_array[31:0]}; end
                6'd33:  begin arp_data0 <= judge_array; end
                6'd39:  begin arp_data1 <= judge_array; end
                default:begin state <= state; end
                endcase
            end
        end								
        ARP_req_success:                         //5
        begin
            state <= idle;
            if(((ARP_TYPE == 16'h0001) && (DES_IP == SOR_IP_r))|| ((ARP_TYPE == 16'h0001) && (arp_data0 == 48'h55AA_55AA_55AA))) 
                //if(arp_data1[47:16]==32'h53475343) 
                begin
                    ARP_req_en <= 1'b1;
                    DES_MAC_o  <= SOR_MAC;
                    DES_IP_o   <= SOR_IP;
                    rx_success  <= 1'b1;
                end
/*                 else begin
                    DES_MAC_o       <= DES_MAC_o;
                    DES_IP_o        <= DES_IP_o;
                    rx_success      <= 1'b0;
                end   */
            else if((ARP_TYPE == 16'h0002) && (DES_IP == SOR_IP_r) && (DES_MAC == SOR_MAC_r)) begin
                ARP_resp_en <= 1'b1;
                DES_MAC_o       <= SOR_MAC;
                DES_IP_o        <= SOR_IP;
                rx_success  <= 1'b1;
            end
            else begin
                DES_MAC_o       <= DES_MAC_o;
                DES_IP_o        <= DES_IP_o;
                rx_success      <= 1'b0;
            end
        end
        default: 
        begin
            ARP_packet_time_cnt     <= 6'd0;
            start_wait_cnt          <= 4'b0;
            rx_success              <= 1'b0;
            arp_data0               <= 48'd0;
            arp_data1               <= 48'd0;
            arp_data2               <= 48'd0;
            state                   <= idle;
        end
        endcase
	end
end
	
//*********************************************************//
				  /***** chipscope ******/
//*********************************************************//
generate    
    if(ILA_DEBUG) begin:ila_debug   
    ARP_RX_ILA inst_ARP_RX_ILA (
        .clk(clk), // input wire clk
        .probe0(lan_data_en), // input wire [0:0]  probe0  
        .probe1(lan_data_in), // input wire [7:0]  probe1 
        .probe2(state), // input wire [4:0]  probe2 
        .probe3(judge_array), // input wire [47:0]  probe3 
        .probe4(start_wait_cnt), // input wire [3:0]  probe4 
        .probe5(ARP_packet_time_cnt), // input wire [5:0]  probe5 
        .probe6(FRAME_TYPE), // input wire [15:0]  probe6 
        .probe7(DES_MAC_o), // input wire [47:0]  probe7 
        .probe8(ARP_TYPE), // input wire [15:0]  probe8 
        .probe9(DES_IP), // input wire [31:0]  probe9 
        .probe10(DES_IP_o), // input wire [31:0]  probe10 
        .probe11(PROTOCOL_TYPE), // input wire [15:0]  probe11 
        .probe12(rx_success), // input wire [0:0]  probe12 
        .probe13(ARP_req_en), // input wire [0:0]  probe13 
        .probe14(ARP_resp_en), // input wire [0:0]  probe14
        .probe15(arp_data0), // input wire [47:0]  probe15
        .probe16(arp_data1), // input wire [47:0]  probe16
        .probe17(arp_data2), // input wire [47:0]  probe17
        .probe18(SOR_IP_o) // input wire [31:0]  probe18
        ); 
end
endgenerate 
			
endmodule
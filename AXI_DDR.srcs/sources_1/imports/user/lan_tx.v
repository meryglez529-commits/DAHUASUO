`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:40:43 07/01/2014 
// Design Name: 
// Module Name:    lan_tx 
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
module lan_tx(
    input           clk,
    input           reset,	
    input           data_ACK_i,
    input           RD_ACK_i,
    input   [21:0]  wr_pack_num,
    input   [15:0]  wr_last_pack_num,
    input   [11:0]  data_count, 
    output          wr_fifo_rden,
    input	[7:0]   wr_data,
    output   reg    wr_done = 0,
    //------ ETH//IP//UDP---------
    input   [47:0]  DES_MAC, 
    input   [47:0]  SOR_MAC,  
    input   [15:0]  FRAME_TYPE,        
    input   [15:0]  IP_VERSION,
    input   [15:0]  IP_PAC_ID,
    input   [31:0]  IP_INF,   
    input   [31:0]  SOR_IP,   
    input   [31:0]  DES_IP,                
    input   [15:0]  SOR_PORT,
    input   [15:0]  DES_PORT,
    //------- AXI_4---------------                             
    input           lan_rdy_n,     // Ready
    output          lan_sof_n,     // Start of frame
    output          lan_eof_n,     // End of frame
    output          lan_vld_n,     // Data valid
    output  [7:0]   lan_data       // Data
    );
//*********************************************************//
				  /***** register declaration ******/
//*********************************************************//
//  wire    [31:0]  wr_num_tmp;           
//  wire    [21:0]  wr_pack_num;
//  wire    [10:0]  wr_last_pack_num; 
//	assign  wr_num_tmp       = wr_num - 1;
//	assign  wr_pack_num      = wr_num_tmp[31:9] + 1;    
//	assign  wr_last_pack_num = wr_num - (512*(wr_pack_num-1));
    
    
    reg     [15:0]  wr_dword_count;
    reg     [15:0]  wr_cnt;
    reg     [21:0]  wr_packet;
    reg     [5:0]   wrdat_sta;
            
    wire            lan_sof_n_wr;
    wire            lan_eof_n_wr;
   

    reg     [1:0]   cnt_wait;
    reg             wr_fifo_rden_d;
    reg             lan_rdy_n_d;
//---------zhao	
	wire   [7:0]   head_array [41:0];
	reg    [7:0]	head_data;
	reg    [7:0]	head_cnt;
	reg  	        head_valid;

	reg   [9:0]    cnt_wr;
	reg   [3:0]    cnt_ctrl_dword;
	reg   [7:0]    packet_cnt;
	reg   [31:0]   cnt_delay;

	wire  [15:0]   IP_packet_length;
	wire  [15:0]   UDP_packet_length;
	wire  [15:0]   UDP_checksum;	
	wire  [15:0]   IP_head_checksum;	
	wire  [19:0]   IP_head_checksum_1;
	wire  [16:0]   IP_head_checksum_2;

	wire  [15:0]   IP_VERSION_NEW; 
	wire  [15:0]   IP_packet_length_NEW; 
	wire  [15:0]   SOR_IP_NEW_H;      
	wire  [15:0]   SOR_IP_NEW_L;   
	wire  [15:0]   DES_IP_NEW_H;       
	wire  [15:0]   DES_IP_NEW_L; 
	reg    [15:0]   packet_ID;
//*********************************************************//
             /*****  parameter declaration  *****/
//*********************************************************//
	localparam   WR_IDLE     = 6'b000001;  //1
	localparam   WR_START    = 6'b000010;  //2
	localparam   WR_WAIT     = 6'b000011;  //3
	localparam   WR_HEAD     = 6'b000100;  //4
	localparam   WR_PACKET   = 6'b000101;  //5
	localparam   WR_DELAY    = 6'b000110;  //6
	localparam   WR_END      = 6'b000111;  //7
	localparam   TX_DONE     = 6'b001000;  //8

	localparam   HEAD_LENGTH = 8'd42;	
	localparam	 P2P_DELAY   = 32'h00000008;  //packet 2 packet delay
    
//*********************************************************//
             /*****  Begin Design Instance  *****/
//*********************************************************//
	assign  IP_VERSION_NEW       = {IP_VERSION[15:8],IP_VERSION[7:0]};
	assign  IP_packet_length_NEW = {IP_packet_length[15:8],IP_packet_length[7:0]};
	assign  SOR_IP_NEW_H         = {SOR_IP[31:24],SOR_IP[23:16]};
	assign  SOR_IP_NEW_L         = {SOR_IP[15:8], SOR_IP[7:0]  };
	assign  DES_IP_NEW_H         = {DES_IP[31:24],DES_IP[23:16]};
	assign  DES_IP_NEW_L         = {DES_IP[15:8], DES_IP[7:0]  };

	assign  IP_packet_length     = wr_dword_count + 10'd28;
	assign  UDP_packet_length    = wr_dword_count + 10'd8;

	assign  IP_head_checksum_1   = (IP_VERSION_NEW	+ IP_packet_length_NEW	+ packet_ID[15:0] + 
									IP_INF[31:16] + IP_INF[15:0] + SOR_IP_NEW_H	+
									SOR_IP_NEW_L + DES_IP_NEW_H  + DES_IP_NEW_L);
                                    
	assign  IP_head_checksum_2   = IP_head_checksum_1[15:0] + IP_head_checksum_1[19:16];
	assign  IP_head_checksum     = 16'hffff - (IP_head_checksum_2[15:0]+IP_head_checksum_2[16]);
	assign  UDP_checksum         = 16'd0;


//------ ETH//IP//UDP
	assign  head_array [5]		=	DES_MAC[7:0];
	assign  head_array [4]		=	DES_MAC[15:8];
	assign  head_array [3]		=	DES_MAC[23:16];
	assign  head_array [2]		=	DES_MAC[31:24];
	assign  head_array [1]		=	DES_MAC[39:32];
	assign  head_array [0]		=	DES_MAC[47:40];
	assign  head_array [11]		=	SOR_MAC[7:0];
	assign  head_array [10]		=	SOR_MAC[15:8];
	assign  head_array [9]		=	SOR_MAC[23:16];
	assign  head_array [8]		=	SOR_MAC[31:24];
	assign  head_array [7]		=	SOR_MAC[39:32];
	assign  head_array [6]		=	SOR_MAC[47:40];
	assign  head_array [13]		=	FRAME_TYPE[7:0];
	assign  head_array [12]		=	FRAME_TYPE[15:8];	
	assign  head_array [14]		=	IP_VERSION[15:8];
	assign  head_array [15]		=	IP_VERSION[7:0];
	assign  head_array [16]		=	IP_packet_length[15:8];
	assign  head_array [17]		=	IP_packet_length[7:0];
	assign  head_array [18]		=	packet_ID[15:8];
	assign  head_array [19]		=	packet_ID[7:0];
	assign  head_array [23]		=	IP_INF[7:0];
	assign  head_array [22]		=	IP_INF[15:8];	
	assign  head_array [21]		=	IP_INF[23:16];
	assign  head_array [20]		=	IP_INF[31:24];
	assign  head_array [25]		=	IP_head_checksum[7:0];					//ip checksum
	assign  head_array [24]		=	IP_head_checksum[15:8];					//ip checksum
	assign  head_array [29]		=	SOR_IP[7:0];
	assign  head_array [28]		=	SOR_IP[15:8];
	assign  head_array [27]		=	SOR_IP[23:16];
	assign  head_array [26]		=	SOR_IP[31:24];
	assign  head_array [33]		=	DES_IP[7:0];
	assign  head_array [32]		=	DES_IP[15:8];
	assign  head_array [31]		=	DES_IP[23:16];
	assign  head_array [30]		=	DES_IP[31:24];
	assign  head_array [35]		=	SOR_PORT[7:0];
	assign  head_array [34]		=	SOR_PORT[15:8];
	assign  head_array [37]		=   DES_PORT[7:0];
	assign  head_array [36]		=   DES_PORT[15:8];
	assign  head_array [39]		=	UDP_packet_length[7:0];
	assign  head_array [38]		=	UDP_packet_length[15:8];
	assign  head_array [41]		=	UDP_checksum[7:0];
	assign  head_array [40]		=	UDP_checksum[15:8];
	
	
	//SWRITE
	assign  lan_sof_n      = ((!lan_rdy_n)&&(head_cnt==1)) ? 0 : 1;
	assign  lan_eof_n      = ((!lan_rdy_n)&&(wr_cnt==(wr_dword_count))&&(wr_cnt != 0)) ? 0 : 1;
	// lan Output Signal
	assign  lan_vld_n	    = (lan_rdy_n_d | (!wr_fifo_rden_d)) & head_valid;
	assign  wr_fifo_rden    = ((wrdat_sta == WR_PACKET) & (!lan_rdy_n) );
	assign  lan_data	    = ((wrdat_sta == WR_HEAD))?  head_data: wr_data; //wr_data---fifo_data
	// Response Signal
//	assign  iresp_rdy_n		= 0;
/*************** machine swrite *********************/
always@(posedge clk or posedge reset)
begin
    if(reset) begin
        lan_rdy_n_d           <= 1'b0;
        wr_fifo_rden_d        <= 1'b0;
    end
    else begin
        lan_rdy_n_d           <= lan_rdy_n;
        wr_fifo_rden_d        <= wr_fifo_rden;
    end
end
	
//Swrite Data control
reg [3:0] done_cnt = 0;
always@(posedge clk or posedge reset)
begin
    if (reset)begin
        packet_ID       <= 0;
        cnt_wait          <= 0;
        wr_dword_count	<= 16'h07FF;
        wr_cnt 			<= 0;
        head_cnt          <= 0;
        wr_packet 		<= 0;
        wr_done   		<= 0;
        wrdat_sta 		<= WR_IDLE;
        head_data         <= 0;
        head_valid        <= 1;
        cnt_delay			<= 32'h00000000;
        done_cnt          <= 0;
    end
    else 
        case(wrdat_sta)
        WR_IDLE:
        begin
            if(RD_ACK_i==1 && data_count >= wr_last_pack_num && wr_last_pack_num != 0) begin
                wrdat_sta   <= WR_START;
                packet_ID   <= 16'd0;	
            end
            else if(data_ACK_i==1 && data_count > 0) begin
                wrdat_sta   <= WR_START;
                packet_ID   <= {wr_packet[15:8], wr_packet[7:0]};
                if(wr_packet < 64999)
                    wr_packet   <= wr_packet + 1;
                else
                    wr_packet   <= 0;    
            end
            else
                wrdat_sta   <= WR_IDLE;
        end
        WR_START:
        begin	
            wrdat_sta      <= WR_WAIT;
//            if(wr_packet == (wr_pack_num-1)&& wr_last_pack_num != 0)   // The Last Packet (wr_last_pack_num != 0 aviod zhengshubei)
            wr_dword_count <= wr_last_pack_num;
//            else
//                wr_dword_count <= 522;
        end
        WR_WAIT:
        begin
            wr_cnt <= 0;
            if(cnt_wait == 1)begin
                wrdat_sta <= WR_HEAD;
                cnt_wait  <= 0;
            end
            else begin
                wrdat_sta <= WR_WAIT;
                cnt_wait  <= cnt_wait + 1;
            end
        end
        WR_HEAD: 
        begin
            if(!lan_rdy_n) begin
                if(head_cnt == 42)begin
                    head_cnt	   <= 4'd0;
                    wrdat_sta      <= WR_PACKET;
                    head_valid     <= 1'b1;
                end
                else begin
                    head_data	   <= head_array[head_cnt];
                    head_cnt 	   <= head_cnt + 1;
                    wrdat_sta      <= WR_HEAD;
                    head_valid     <= 1'b0;
                end
            end
            else begin
                head_data	   <= head_data;
                head_cnt 	   <= head_cnt;
                wrdat_sta      <= WR_HEAD;
                head_valid     <= 1'b1;
            end
        end
        WR_PACKET:
        begin
            if(!lan_rdy_n)begin
                wr_cnt <= wr_cnt + 1;
                if(wr_cnt < wr_dword_count - 1)						
                    wrdat_sta    <= WR_PACKET; 
                else
                    wrdat_sta    <= WR_DELAY;
            end
            else begin
                wr_cnt       <= wr_cnt;
                wrdat_sta    <= WR_PACKET;
            end
        end	
        WR_DELAY:
        begin
            wr_cnt <= 0;
            if(cnt_delay == P2P_DELAY)begin
                wrdat_sta <= WR_END;
                cnt_delay <= 0;
            end
            else begin
                wrdat_sta <= WR_DELAY;
                cnt_delay <= cnt_delay + 1'b1;
            end
        end		
        WR_END:
        begin              
//            if(wr_packet == wr_pack_num)begin  // All Packet Finished, To End
                wr_dword_count	<= 0;
//                wr_packet		<= 0;
                wr_done			<= 1'b1;
                wrdat_sta       <= TX_DONE; 
//            end
//            else begin
//                wr_dword_count	<= wr_dword_count;
////                wr_packet		<= wr_packet;
//                wr_done	    <= wr_done; 
//                wrdat_sta <= WR_IDLE;  
//            end
        end
        TX_DONE:
        begin
            if(done_cnt < 4'd4) begin
                wr_done   <= 1'b1;
                wrdat_sta <= TX_DONE; 
                done_cnt <= done_cnt + 1'b1;
            end
            else begin
                wr_done   <= 1'b0;
                wrdat_sta <= WR_IDLE; 
                done_cnt <= 0;
            end
        end
        default:
        begin
            wr_cnt       <= 0;
//            wr_packet    <= 0;
            wr_done      <= 0;
            wrdat_sta    <= WR_IDLE;
        end
    endcase
end
/**************	
LAN_TX_ILA inst_LAN_TX_ILA (
    .clk(clk),              // input wire clk
    .probe0(wrdat_sta),     // input wire [5:0]  probe0  
    .probe1(lan_rdy_n),     // input wire [0:0]  probe1 
    .probe2(lan_sof_n),     // input wire [0:0]  probe2 
    .probe3(lan_vld_n),     // input wire [0:0]  probe3 
    .probe4(lan_eof_n),     // input wire [0:0]  probe4 
    .probe5(lan_data),      // input wire [7:0]  probe5 
    .probe6(wr_done),       // input wire [0:0]  probe6 
    .probe7(wr_fifo_rden),  // input wire [0:0]  probe7 
    .probe8(wr_data),       // input wire [7:0]  probe8 
    .probe9(head_valid),    // input wire [0:0]  probe9 
    .probe10(SOR_IP),       // input wire [31:0]  probe10 
    .probe11(wr_cnt),       // input wire [10:0]  probe11 
    .probe12(wr_dword_count),   // input wire [10:0]  probe12 
    .probe13(wr_pack_num),      // input wire [21:0]  probe13 
    .probe14(wr_last_pack_num), // input wire [10:0]  probe14 
    .probe15(wr_packet),        // input wire [21:0]  probe15 
    .probe16(IP_packet_length), // input wire [15:0]  probe16 
    .probe17(data_count[9:0]),  // input wire [9:0]  probe17 
    .probe18(cnt_delay)         // input wire [31:0]  probe18 
    );
**************/

endmodule

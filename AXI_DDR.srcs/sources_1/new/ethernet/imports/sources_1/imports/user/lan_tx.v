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
module lan_tx#(
 parameter ILA_DEBUG = 1'b0
)(

	input            clk,
	input            reset,	
	input	 [31:0]  wr_num,
	input	 [7:0]   wr_data,
	input            wr_fifo_empty,
	output           wr_fifo_rden,
	input			 wr_fifo_halffull,
	input    [9:0]   wr_fifo_count,  //[10:0]
	output   reg     wr_done = 0,
	                               
	input            lan_rdy_n,     // Ready
	output           lan_sof_n,     // Start of frame
	output           lan_eof_n,     // End of frame
	output           lan_vld_n,     // Data valid
	output	 [7:0]   lan_data,      // Data
//------ ETH
	input	 [47:0]  DES_MAC, 
	input	 [47:0]  SOR_MAC,  
	input	 [15:0]  FRAME_TYPE,
//------ IP                 
	input	 [15:0]  IP_VERSION,
	input	 [15:0]  IP_PAC_ID,
	input	 [31:0]  IP_INF,   
	input	 [31:0]  SOR_IP,   
	input	 [31:0]  DES_IP,   
//------ UDP                  
	input	 [15:0]  SOR_PORT,
	input	 [15:0]  DES_PORT
     
);

//*********************************************************//
				  /***** register declaration ******/
//*********************************************************//
//	reg 		[31:0]			   wr_num;
	wire 		[31:0]			   wr_num_tmp; //zhao
	
	reg         [10:0]             wr_dword_count;
	reg         [10:0]             wr_cnt;
	reg         [21:0]             wr_packet;
//	reg                            wr_done;
	reg         [5:0]              wrdat_sta;
                            
	wire                           lan_sof_n_wr;
	wire                           lan_eof_n_wr;
                              
	wire        [21:0]             wr_pack_num;
	wire        [10:0]             wr_last_pack_num;
	                               
//	reg         [0:PULSE_WIDTH -1] data_cnt;

	reg         [1:0]              cnt_wait;
	reg                            wr_fifo_rden_d;
	reg                            lan_rdy_n_d;
//---------zhao	
	wire   [7:0]    head_array [41:0];
	reg    [7:0]	head_data;
	reg    [7:0]	head_cnt;
	reg  	        head_valid;
//----------
//	reg   [2:0]    cnt_wait;
	reg   [9:0]    cnt_wr;
	reg   [3:0]    cnt_ctrl_dword;
	reg   [7:0]    packet_cnt;
	reg   [31:0]   cnt_delay;
	reg            wr_fifo_halffull_1ff;
	reg            wr_fifo_halffull_2ff;
//	wire  [31:0]   packet_ID;
	
	wire  [15:0]   IP_packet_length;
	wire  [15:0]   UDP_packet_length;
	wire  [15:0]   UDP_checksum;	
	wire  [15:0]   IP_head_checksum;	
	wire  [19:0]   IP_head_checksum_1;
	wire  [16:0]   IP_head_checksum_2;

	wire  [15:0]  IP_VERSION_NEW; 
	wire  [15:0]  IP_packet_length_NEW; 
	wire  [15:0]  SOR_IP_NEW_H;      
	wire  [15:0]  SOR_IP_NEW_L;   
	wire  [15:0]  DES_IP_NEW_H;       
	wire  [15:0]  DES_IP_NEW_L; 
	wire  [15:0]  packet_ID;
	

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
	localparam	P2P_DELAY   = 32'h00000008;  //packet 2 packet delay
    
//*********************************************************//
             /*****  Begin Design Instance  *****/
//*********************************************************//
	assign  IP_VERSION_NEW       = {IP_VERSION[15:8],IP_VERSION[7:0]};
	assign  IP_packet_length_NEW = {IP_packet_length[15:8],IP_packet_length[7:0]};
	assign  SOR_IP_NEW_H         = {SOR_IP[31:24],SOR_IP[23:16]};
	assign  SOR_IP_NEW_L         = {SOR_IP[15:8], SOR_IP[7:0]  };
	assign  DES_IP_NEW_H         = {DES_IP[31:24],DES_IP[23:16]};
	assign  DES_IP_NEW_L         = {DES_IP[15:8], DES_IP[7:0]  };
	//assign  packet_ID			 = {IP_PAC_ID[15:8], IP_PAC_ID[7:0] };
	assign  packet_ID			 = {wr_packet[15:8], wr_packet[7:0] };		
//	assign  tx_data_num          = wr_dword_count + 11'd42;
	
	assign  IP_packet_length     = wr_dword_count + 10'd28;
	assign  UDP_packet_length    = wr_dword_count + 10'd8;

	assign  IP_head_checksum_1   = (IP_VERSION_NEW	+ IP_packet_length_NEW	+ packet_ID[15:0] + 
									IP_INF[31:16] + IP_INF[15:0] + SOR_IP_NEW_H	+
									SOR_IP_NEW_L + DES_IP_NEW_H  + DES_IP_NEW_L);
                                    
	assign  IP_head_checksum_2   = IP_head_checksum_1[15:0] + IP_head_checksum_1[19:16];
	assign  IP_head_checksum     = 16'hffff - (IP_head_checksum_2[15:0]+IP_head_checksum_2[16]);
	assign  UDP_checksum         = 16'd0;

	assign  wr_num_tmp  		 = wr_num - 1;
	assign  wr_pack_num          = wr_num_tmp[31:9] + 1;     // wr_num_tmp/512 
	assign  wr_last_pack_num     = wr_num - (512*(wr_pack_num-1));
//	assign  wr_last_pack_num     = wr_num - (1024*(wr_pack_num-1));

//------ ETH
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
//------	IP
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
//------  UDP
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
//	assign  lan_tid_wr        = wr_packet;
//  assign  lan_byte_count_wr = 8*wr_dword_count;
	
	// lan Output Signal
	assign  lan_vld_n	    = (lan_rdy_n_d | (!wr_fifo_rden_d)) & head_valid;
	assign  wr_fifo_rden    = ((wrdat_sta == WR_PACKET) & (!lan_rdy_n) & (!wr_fifo_empty));
    
	assign  lan_data	    = ((wrdat_sta == WR_HEAD))?  head_data: wr_data; //wr_data---fifo_data
	// Response Signal
//	assign  iresp_rdy_n		= 0;
	 
     
  /*************** machine swrite *********************/
	always@(posedge clk or posedge reset)begin
		 if (reset)begin
			  lan_rdy_n_d           <= 1'b0;
			  wr_fifo_rden_d        <= 1'b0;
			  wr_fifo_halffull_1ff  <= 1'b0;
			  wr_fifo_halffull_2ff  <= 1'b0;
		 end
		 else begin
			  lan_rdy_n_d           <= lan_rdy_n;
			  wr_fifo_rden_d        <= wr_fifo_rden;
			  wr_fifo_halffull_1ff  <= wr_fifo_halffull;
			  wr_fifo_halffull_2ff  <= wr_fifo_halffull_1ff;
		 end
	end
	
//Swrite Data control
    reg [3:0] done_cnt = 0;
	always@(posedge clk or posedge reset)begin
		 if (reset)begin
		      cnt_wait          <= 0;
			  wr_dword_count	<= 12'h7FF;
			  wr_cnt 			<= 0;
			  head_cnt          <= 0;
			  wr_packet 		<= 0;
			  wr_done   		<= 0;
//			  data_cnt  		<= 0;
			  wrdat_sta 		<= WR_IDLE;
			  head_data         <= 0;
			  head_valid        <= 1;
			  cnt_delay			<= 32'h00000000;
			  done_cnt          <= 0;
		 end
		 else case(wrdat_sta)
			WR_IDLE:
				begin
					if(wr_fifo_halffull_2ff)
						wrdat_sta <= WR_START;
					else if((wr_packet == (wr_pack_num-1)) && (wr_fifo_count == wr_last_pack_num)&& (wr_last_pack_num != 0))
						wrdat_sta <= WR_START;
					else 
						wrdat_sta <= WR_IDLE;
				end
				
			WR_START:
				begin	
				   if(wr_packet == (wr_pack_num-1)&& wr_last_pack_num != 0)begin   // The Last Packet (wr_last_pack_num != 0 aviod zhengshubei)
						wr_dword_count <= wr_last_pack_num;
						wr_packet      <= wr_packet + 1;
						wrdat_sta      <= WR_WAIT;
					end
					else  begin
						wr_dword_count <= 512;
						wr_packet      <= wr_packet + 1;
						wrdat_sta      <= WR_WAIT;
					end
				end

			 WR_WAIT:begin
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
			WR_HEAD: begin
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
					if(!lan_rdy_n & (!wr_fifo_empty))begin
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
		    WR_DELAY:begin
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
			WR_END:begin              
                if(wr_packet == wr_pack_num)begin  // All Packet Finished, To End
                    wr_dword_count	<= 0;
                    wr_packet		<= 0;
                    wr_done			<= 1'b1;
                    wrdat_sta <= TX_DONE; 
                end
                else
                    begin
                     wr_dword_count	<= wr_dword_count;
                     wr_packet		<= wr_packet;
                     wr_done	    <= wr_done; 
                     wrdat_sta <= WR_IDLE;  
                    end
		    end
		    TX_DONE:begin
		      if(done_cnt < 4'd4)
		      begin
		         wr_done   <= 1'b1;
                 wrdat_sta <= TX_DONE; 
                 done_cnt <= done_cnt + 1'b1;
              end
              else
                begin
                   wr_done   <= 1'b0;
                   wrdat_sta <= WR_IDLE; 
                   done_cnt <= 0;
                end
		    end
			default:begin
				  wr_cnt       <= 0;
				  wr_packet    <= 0;
				  wr_done      <= 0;
				  wrdat_sta    <= WR_IDLE;
			 end
		 endcase
	end
	
	


//	ila lia_tx (
//		 .CONTROL(CONTROL0), // INOUT BUS [35:0]
//		 .CLK(clk), // IN
//		 .TRIG0(trig) // IN BUS [255:0]
//	);	
	
//assign trig[5:0] 	=	wrdat_sta;
//assign trig[6] 	 	=	lan_rdy_n;
//assign trig[7] 	 	=	lan_sof_n;
//assign trig[8] 	 	=	lan_vld_n;
//assign trig[9] 	 	=	lan_eof_n;
//assign trig[17:10] 	=	lan_data;

//assign trig[18] 	=	wr_fifo_empty;
//assign trig[19] 	=	wr_fifo_rden;
//assign trig[27:20] 	=	wr_data;

//assign trig[28] 	=	head_valid;
//assign trig[60:29]	=	wr_num;
//assign trig[71:61]	=	wr_cnt;
//assign trig[82:72]	=	wr_dword_count;

//assign trig[104:83]	 =	wr_pack_num;
//assign trig[115:105] =	wr_last_pack_num;
//assign trig[136:116] =	wr_packet;
//assign trig[152:137] =	IP_packet_length;
//assign trig[163:153] =	wr_fifo_count;
//assign trig[164]	 =	wr_fifo_halffull_2ff;
//assign trig[170:165] =	cnt_delay;
////assign trig[255:165] =  0;

generate    
    if(ILA_DEBUG) begin:ila_debug   
     LAN_TX_ILA inst_LAN_TX_ILA (
        .clk(clk), // input wire clk
        .probe0(wrdat_sta), // input wire [5:0]  probe0  
        .probe1(lan_rdy_n), // input wire [0:0]  probe1 
        .probe2(lan_sof_n), // input wire [0:0]  probe2 
        .probe3(lan_vld_n), // input wire [0:0]  probe3 
        .probe4(lan_eof_n), // input wire [0:0]  probe4 
        .probe5(lan_data), // input wire [7:0]  probe5 
        .probe6(wr_fifo_empty), // input wire [0:0]  probe6 
        .probe7(wr_fifo_rden), // input wire [0:0]  probe7 
        .probe8(wr_data), // input wire [7:0]  probe8 
        .probe9(head_valid), // input wire [0:0]  probe9 
        .probe10(wr_num), // input wire [31:0]  probe10 
        .probe11(wr_cnt), // input wire [10:0]  probe11 
        .probe12(wr_dword_count), // input wire [10:0]  probe12 
        .probe13(wr_pack_num), // input wire [21:0]  probe13 
        .probe14(wr_last_pack_num), // input wire [10:0]  probe14 
        .probe15(wr_packet), // input wire [21:0]  probe15 
        .probe16(IP_packet_length), // input wire [15:0]  probe16 
        .probe17(wr_fifo_count), // input wire [9:0]  probe17 
        .probe18(wr_fifo_halffull_2ff), // input wire [0:0]  probe18 
        .probe19(cnt_delay) // input wire [31:0]  probe19
    );
end
endgenerate 

endmodule

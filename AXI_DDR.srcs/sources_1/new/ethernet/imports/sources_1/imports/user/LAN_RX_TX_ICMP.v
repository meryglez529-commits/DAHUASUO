`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:27:36 10/27/2015 
// Design Name: 
// Module Name:    LAN_RX_ICMP 
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
module LAN_RX_TX_ICMP(
			input                   clk,
			input                   reset_n,
			input                   init_done,
            
			input                   lan_data_en,    //low is valid
			input          [7:0]    lan_data_in,
            
			input          [47:0]   SOR_MAC_i,      //for board
			input          [31:0]   SOR_IP_i,       //for board
			
			output   reg            ICMP_pc_req_o = 0,
			input                   ICMP_ACK_i,
			output   reg            tx_ICMP_busy = 0,
			
			input                   lan_rdy_n,
			output   reg   [7:0]    lan_data,
			output   reg            lan_vld_n,
			output   reg            lan_sof_n,
			output   reg            lan_eof_n
			);

//*********************************************************//
			  /***** register declaration *****/
//*********************************************************//			
	parameter      idle                     = 5'b00001;      //1
	parameter      start                    = 5'b00010;      //2
	parameter      frame_type_judge         = 5'b00011;      //3
	parameter      IP_header_resolution     = 5'b00100;      //4	
	parameter      ICMP_packet_resolution   = 5'b00101;      //5
	parameter      ICMP_packet_tx           = 5'b00111;      //7
	parameter      ICMP_wait_tx             = 5'b00110;      //6
    
//	parameter      PACKET_LENGTH_init       = 10'h04A;       //10'd74 (14 + 20 + 40)
	
	reg   [4:0]    state;
	
	reg            lan_data_en_r;
	reg   [7:0]    lan_data_in_r;
	reg   [7:0]    lan_data_in_2r;
	reg   [7:0]    lan_data_in_3r;
	reg   [7:0]    lan_data_in_4r;
	reg   [7:0]    lan_data_in_5r;
    
	wire  [7:0]    ICMP_packet_array [73:0];
    wire  [47:0]   judge_array;

	reg   [3:0]    start_wait_cnt;
	reg   [4:0]    IP_header_cnt;
	reg   [5:0]    ICMP_byte_cnt;
	reg   [6:0]    tx_cnt;

	reg   [47:0]   DES_MAC_RX;
	reg   [47:0]   SOR_MAC_RX;
	reg   [15:0]   FRAME_TYPE;
	reg   [15:0]   IP_VERSION;
	reg   [15:0]   IP_PACKET_LENGTH;
	reg   [15:0]   IP_ID;
	reg   [15:0]   FRAGMENT_OFFSET;
	reg   [15:0]   IP_TYPE;
	reg   [15:0]   IP_HEAD_CHECKSUM;
	reg   [31:0]   SOR_IP_RX;
	reg   [31:0]   DES_IP_RX;
    
	wire  [47:0]   DES_MAC;
	wire  [31:0]   DES_IP;
    
	reg   [15:0]   ICMP_TYPE;
	reg   [15:0]   ICMP_CHECKSUM;
	reg   [15:0]   ICMP_ID;
	reg   [15:0]   SEQUENCE_SUM;
	reg   [15:0]   data_dbyte_0;
	reg   [15:0]   data_dbyte_1;
	reg   [15:0]   data_dbyte_2;
	reg   [15:0]   data_dbyte_3;
	reg   [15:0]   data_dbyte_4;
	reg   [15:0]   data_dbyte_5;
	reg   [15:0]   data_dbyte_6;
	reg   [15:0]   data_dbyte_7;
	reg   [15:0]   data_dbyte_8;
	reg   [15:0]   data_dbyte_9;
	reg   [15:0]   data_dbyte_10;
	reg   [15:0]   data_dbyte_11;
	reg   [15:0]   data_dbyte_12;
	reg   [15:0]   data_dbyte_13;
	reg   [15:0]   data_dbyte_14;
	reg   [15:0]   data_dbyte_15;
    
//*********************************************************//
				  /***** chipscope ******/
//*********************************************************//
//	wire  [255:0] trig;		
	
//	ila u_chip_ila_rx ( 
//		.CLK    (clk ),     // IN
//		.TRIG0  (trig)      // IN BUS [255:0] 
//	);
//	assign trig[0]          = lan_data_en;
//	assign trig[8:1]        = lan_data_in; 
//	assign trig[13:9]       = state;
//	assign trig[61:14]      = judge_array;
//	assign trig[65:62]      = start_wait_cnt;
//	assign trig[70:66]      = IP_header_cnt;
//	assign trig[76:71]      = ICMP_byte_cnt;
//	assign trig[92:77]      = IP_VERSION;
//	assign trig[108:93]     = IP_PACKET_LENGTH;
//	assign trig[124:109]    = IP_ID;
//	assign trig[140:125]    = FRAGMENT_OFFSET;
//	assign trig[156:141]    = IP_TYPE;
//	assign trig[172:157]    = IP_HEAD_CHECKSUM;
//	assign trig[188:173]    = ICMP_TYPE;
//	assign trig[204:189]    = ICMP_CHECKSUM;
//	assign trig[220:205]    = ICMP_ID;
//	assign trig[236:221]    = SEQUENCE_SUM;
//	assign trig[237]        = lan_sof_n;
//	assign trig[238]        = lan_eof_n;
//	assign trig[239]        = lan_vld_n;
//	assign trig[247:240]    = lan_data;
//	assign trig[254:248]    = tx_cnt;

//ila_2 inst_ICMP (
//	.clk(clk), // input wire clk
//	.probe0(lan_data_en), // input wire [0:0]  probe0  
//	.probe1(lan_data_in), // input wire [7:0]  probe1 
//	.probe2(state), // input wire [4:0]  probe2 
//	.probe3(judge_array), // input wire [47:0]  probe3 
//	.probe4(start_wait_cnt), // input wire [3:0]  probe4 
//	.probe5(IP_header_cnt), // input wire [4:0]  probe5 
//	.probe6(ICMP_byte_cnt), // input wire [5:0]  probe6 
//	.probe7(IP_VERSION), // input wire [15:0]  probe7 
//	.probe8(IP_PACKET_LENGTH), // input wire [15:0]  probe8 
//	.probe9(IP_ID), // input wire [15:0]  probe9 
//	.probe10(FRAGMENT_OFFSET), // input wire [15:0]  probe10 
//	.probe11(IP_TYPE), // input wire [15:0]  probe11 
//	.probe12(IP_HEAD_CHECKSUM), // input wire [15:0]  probe12 
//	.probe13(ICMP_TYPE), // input wire [15:0]  probe13 
//	.probe14(ICMP_CHECKSUM), // input wire [15:0]  probe14 
//	.probe15(ICMP_ID), // input wire [15:0]  probe15 
//	.probe16(SEQUENCE_SUM), // input wire [15:0]  probe16 
//	.probe17(lan_sof_n), // input wire [0:0]  probe17 
//	.probe18(lan_eof_n), // input wire [0:0]  probe18 
//	.probe19(lan_vld_n), // input wire [0:0]  probe19 
//	.probe20(lan_data), // input wire [7:0]  probe20 
//	.probe21(tx_cnt), // input wire [6:0]  probe21
//	.probe22(ICMP_pc_req_o), // input wire [0:0]  probe21
//	.probe23(ICMP_ACK_i) // input wire [0:0]  probe21
//);
	
//*********************************************************//
             /*****  Begin Design Instance  *****/
//*********************************************************//
//------ ETH ------- 0CC47A1F3547 / ABCDEFABCDEF / 0800
	assign  ICMP_packet_array [0]	=	DES_MAC[47:40];
	assign  ICMP_packet_array [1]	=	DES_MAC[39:32];
	assign  ICMP_packet_array [2]	=	DES_MAC[31:24];
	assign  ICMP_packet_array [3]	=	DES_MAC[23:16];
	assign  ICMP_packet_array [4]	=	DES_MAC[15:8];
	assign  ICMP_packet_array [5]	=	DES_MAC[7:0];
	assign  ICMP_packet_array [6]	=	SOR_MAC_i[47:40];
	assign  ICMP_packet_array [7]	=	SOR_MAC_i[39:32];
	assign  ICMP_packet_array [8]	=	SOR_MAC_i[31:24];
	assign  ICMP_packet_array [9]	=	SOR_MAC_i[23:16];
	assign  ICMP_packet_array [10]	=	SOR_MAC_i[15:8];
	assign  ICMP_packet_array [11]	=	SOR_MAC_i[7:0];
	assign  ICMP_packet_array [12]	=	FRAME_TYPE[15:8];
	assign  ICMP_packet_array [13]	=	FRAME_TYPE[7:0];
//------ IP -------- 4500 / 003C / IP_ID / 0000 / 8001 / IP_HEAD_CHECKSUM
	assign  ICMP_packet_array [14]	=	IP_VERSION[15:8];
	assign  ICMP_packet_array [15]	=	IP_VERSION[7:0];
	assign  ICMP_packet_array [16]	=	IP_PACKET_LENGTH[15:8];
	assign  ICMP_packet_array [17]	=	IP_PACKET_LENGTH[7:0];
	assign  ICMP_packet_array [18]	=	IP_ID[15:8];
	assign  ICMP_packet_array [19]	=	IP_ID[7:0];
	assign  ICMP_packet_array [20]	=	FRAGMENT_OFFSET[15:8];
	assign  ICMP_packet_array [21]	=	FRAGMENT_OFFSET[7:0];   
	assign  ICMP_packet_array [22]	=	IP_TYPE[15:8];	//IP_TYPE[15:8]
	assign  ICMP_packet_array [23]	=	IP_TYPE[7:0];
	assign  ICMP_packet_array [24]	=	IP_HEAD_CHECKSUM[15:8];					//ip checksum
	assign  ICMP_packet_array [25]	=	IP_HEAD_CHECKSUM[7:0];					//ip checksum
	assign  ICMP_packet_array [26]	=	SOR_IP_i[31:24];
	assign  ICMP_packet_array [27]	=	SOR_IP_i[23:16];
	assign  ICMP_packet_array [28]	=	SOR_IP_i[15:8];
	assign  ICMP_packet_array [29]	=	SOR_IP_i[7:0];
	assign  ICMP_packet_array [30]	=	DES_IP[31:24];
	assign  ICMP_packet_array [31]	=	DES_IP[23:16];
	assign  ICMP_packet_array [32]	=	DES_IP[15:8];
	assign  ICMP_packet_array [33]	=	DES_IP[7:0];
//------ ICMP -------- 0000 / ICMP_CHECKSUM / 0400 / 0X00(X=1,2,3,4) / 32B data
	assign  ICMP_packet_array [34]	=	ICMP_TYPE[15:8] - 8'h08;
	assign  ICMP_packet_array [35]	=	ICMP_TYPE[7:0];
	
//	assign  ICMP_packet_array [36]	=   ICMP_CHECKSUM[15:8] + 8'h08;
//	assign  ICMP_packet_array [37]	=   ICMP_CHECKSUM[7:0];
//	assign  ICMP_packet_array [38]	=	ICMP_ID[15:8];
//	assign  ICMP_packet_array [39]	=	ICMP_ID[7:0];
//	assign  ICMP_packet_array [40]	=	SEQUENCE_SUM[15:8];
//	assign  ICMP_packet_array [41]	=	SEQUENCE_SUM[7:0];
    wire [15:0] ICMP_CHECKSUM_tx;  
    wire [15:0] ICMP_CHECKSUM_tx1;                                                 
    wire [31:0] ICMP_CHECKSUM1;                                            
                                                                               
    assign  ICMP_packet_array [36]        =   ICMP_CHECKSUM_tx[15:8];      
    assign  ICMP_packet_array [37]        =   ICMP_CHECKSUM_tx[7:0];       
    assign  ICMP_packet_array [38]        =        ICMP_ID[15:8];          
    assign  ICMP_packet_array [39]        =        ICMP_ID[7:0];           
    assign  ICMP_packet_array [40]        =        SEQUENCE_SUM[15:8];     
    assign  ICMP_packet_array [41]        =        SEQUENCE_SUM[7:0];      
                                                                           
    assign ICMP_CHECKSUM1 = SEQUENCE_SUM + ICMP_ID + 20'h6AA9D;            
    assign ICMP_CHECKSUM_tx1 = ICMP_CHECKSUM1[31:16] + ICMP_CHECKSUM1[15:0]; 
    assign ICMP_CHECKSUM_tx  = 16'hFFFF - ICMP_CHECKSUM_tx1;
    
	assign  ICMP_packet_array [42]	=	data_dbyte_0[15:8];
	assign  ICMP_packet_array [43]	=	data_dbyte_0[7:0];
	assign  ICMP_packet_array [44]	=	data_dbyte_1[15:8];
	assign  ICMP_packet_array [45]	=	data_dbyte_1[7:0];
	assign  ICMP_packet_array [46]	=	data_dbyte_2[15:8];
	assign  ICMP_packet_array [47]	=	data_dbyte_2[7:0];
	assign  ICMP_packet_array [48]	=	data_dbyte_3[15:8];
	assign  ICMP_packet_array [49]	=	data_dbyte_3[7:0];
	assign  ICMP_packet_array [50]	=	data_dbyte_4[15:8];
	assign  ICMP_packet_array [51]	=	data_dbyte_4[7:0];
	assign  ICMP_packet_array [52]	=	data_dbyte_5[15:8];
	assign  ICMP_packet_array [53]	=	data_dbyte_5[7:0];
	assign  ICMP_packet_array [54]	=	data_dbyte_6[15:8];
	assign  ICMP_packet_array [55]	=	data_dbyte_6[7:0];
	assign  ICMP_packet_array [56]	=	data_dbyte_7[15:8];
	assign  ICMP_packet_array [57]	=	data_dbyte_7[7:0];
	assign  ICMP_packet_array [58]	=	data_dbyte_8[15:8];
	assign  ICMP_packet_array [59]	=	data_dbyte_8[7:0];
	assign  ICMP_packet_array [60]	=	data_dbyte_9[15:8];
	assign  ICMP_packet_array [61]	=	data_dbyte_9[7:0];
	assign  ICMP_packet_array [62]	=	data_dbyte_10[15:8];
	assign  ICMP_packet_array [63]	=	data_dbyte_10[7:0];
	assign  ICMP_packet_array [64]	=	data_dbyte_11[15:8];
	assign  ICMP_packet_array [65]	=	data_dbyte_11[7:0];
	assign  ICMP_packet_array [66]	=	data_dbyte_12[15:8];
	assign  ICMP_packet_array [67]	=	data_dbyte_12[7:0];
	assign  ICMP_packet_array [68]	=	data_dbyte_13[15:8];
	assign  ICMP_packet_array [69]	=	data_dbyte_13[7:0];
	assign  ICMP_packet_array [70]	=	data_dbyte_14[15:8];
	assign  ICMP_packet_array [71]	=	data_dbyte_14[7:0];
	assign  ICMP_packet_array [72]	=	data_dbyte_15[15:8];
	assign  ICMP_packet_array [73]	=	data_dbyte_15[7:0];
    
	assign  DES_MAC =   SOR_MAC_RX;
	assign  DES_IP  =   SOR_IP_RX;
    
//*********************************************************//
             /*****  Begin Design Instance  *****/
//*********************************************************//
	always@(posedge clk)begin
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

    wire     lan_data_en_p;
    assign  lan_data_en_p   = !lan_data_en && lan_data_en_r;
    assign  judge_array     = {lan_data_in_5r,lan_data_in_4r,lan_data_in_3r,lan_data_in_2r,lan_data_in_r,lan_data_in};
    
    reg ICMP_ACK_r0 = 0;
    reg ICMP_ACK_r1 = 0;
    always@(posedge clk)
     begin
       ICMP_ACK_r0 <= ICMP_ACK_i;             
       ICMP_ACK_r1 <= ICMP_ACK_r0;             
     end
    
	always@(posedge clk)begin
		if(!reset_n)begin
		    tx_ICMP_busy      <= 0;
		    ICMP_pc_req_o       <= 0;
            start_wait_cnt    <= 4'd0;
			IP_header_cnt     <= 5'd0;
			ICMP_byte_cnt     <= 6'd0;
			tx_cnt            <= 7'd0;
			DES_MAC_RX        <= 48'd0;
			SOR_MAC_RX        <= 48'd0;
			FRAME_TYPE        <= 16'd0;
			IP_VERSION        <= 16'd0;
			IP_PACKET_LENGTH  <= 16'd0;
			IP_ID             <= 16'd0;
			FRAGMENT_OFFSET   <= 16'd0;
			IP_TYPE           <= 16'd0;
			IP_HEAD_CHECKSUM  <= 16'd0;
			ICMP_TYPE         <= 16'd0;
			ICMP_CHECKSUM     <= 16'd0;
			ICMP_ID           <= 16'd0;
			SEQUENCE_SUM      <= 16'd0;
			SOR_IP_RX         <= 32'd0;
			DES_IP_RX         <= 32'd0;
			data_dbyte_0      <= 16'd0;
			data_dbyte_1      <= 16'd0;
			data_dbyte_2      <= 16'd0;
			data_dbyte_3      <= 16'd0;
			data_dbyte_4      <= 16'd0;
			data_dbyte_5      <= 16'd0;
			data_dbyte_6      <= 16'd0;
			data_dbyte_7      <= 16'd0;
			data_dbyte_8      <= 16'd0;
			data_dbyte_9      <= 16'd0;
			data_dbyte_10     <= 16'd0;
			data_dbyte_11     <= 16'd0;
			data_dbyte_12     <= 16'd0;
			data_dbyte_13     <= 16'd0;
			data_dbyte_14     <= 16'd0;
			data_dbyte_15     <= 16'd0;
			lan_sof_n         <= 1'd1;
			lan_eof_n         <= 1'd1;
			lan_vld_n         <= 1'd1;
			lan_data          <= 8'd0;
			state             <= idle;
		end
		else begin
			case(state)
				idle:                                       //1
					begin
                        start_wait_cnt    <= 4'b0;
                        IP_header_cnt     <= 5'd0;
                        ICMP_byte_cnt     <= 6'd0;
                        tx_cnt            <= 7'd0;
                        lan_sof_n         <= 1'd1;
                        lan_eof_n         <= 1'd1;
                        lan_vld_n         <= 1'd1;
                        lan_data          <= 8'd0;                     
						if(init_done && lan_data_en_p)//20151222
							state    <= start;
						else 
							state    <= idle;
					end
					
				start:                                      //2
					begin
						if(lan_data_en == 0)begin
                            if(start_wait_cnt == 4'd11)begin
                                start_wait_cnt  <= 0;
                                state           <= frame_type_judge;
                            end
                            else begin
                                start_wait_cnt  <= start_wait_cnt + 1;
                                if(start_wait_cnt == 4'd10)
                                    SOR_MAC_RX      <= judge_array;
                                else
                                    SOR_MAC_RX      <= SOR_MAC_RX;
                            end
                        end
                        else
                            state    <= idle;
					end
					
				frame_type_judge:                           //3
					begin
                        if(judge_array[15:0] == 16'h0800)begin   //IPv4
                            FRAME_TYPE  <= judge_array[15:0];
                            state       <= IP_header_resolution;
                        end
                        else
                            state       <= idle;
                    end

                IP_header_resolution:                       //4
                    begin
                        if(IP_header_cnt == 5'd20)begin
                            IP_header_cnt <= 6'd0;
                            if(IP_TYPE[7:0] == 8'h01 &&IP_PACKET_LENGTH == 16'h003C && DES_IP_RX == SOR_IP_i) begin //IP_TYPE == 16'h4001 && 16'h8001
                                state    <= ICMP_packet_resolution;
//                                IP_HEAD_CHECKSUM <= IP_HEAD_CHECKSUM + IP_TYPE[15:8] - 8'hFF;
                            end
                            else
                                state    <= idle;
                        end
                        else begin
                            IP_header_cnt <= IP_header_cnt + 1;
                            case(IP_header_cnt)
                                6'd5:begin
                                    IP_VERSION          <= {judge_array[47:32]};    
                                    IP_PACKET_LENGTH    <= {judge_array[31:16]};    
                                    IP_ID               <= {judge_array[15:0]};     
                                end                                                 
                                6'd11:begin
                                    FRAGMENT_OFFSET     <= {judge_array[47:32]};   
                                    IP_TYPE             <= {judge_array[31:16]};   
                                    IP_HEAD_CHECKSUM    <= {judge_array[15:0]};    
                                end                                                
                                6'd15:begin
                                    SOR_IP_RX           <= {judge_array[31:0]};
                                end
                                6'd19:begin
                                    DES_IP_RX           <= {judge_array[31:0]};
                                end
                            endcase
                        end
                    end
											
                ICMP_packet_resolution:                     //5
                    begin
                        if(ICMP_byte_cnt == 6'd39)begin
                            ICMP_byte_cnt <= 6'd0;
                            if(ICMP_TYPE == 16'h0800)      //requet
                                begin
                                    ICMP_pc_req_o <= 1'b1;
                                    state       <= ICMP_wait_tx;
                                    tx_ICMP_busy      <= 1'b1;
                                end
                            else
                                state    <= idle;
                        end
                        else begin
                            ICMP_byte_cnt <= ICMP_byte_cnt + 1;
                            case(ICMP_byte_cnt)
                                6'd4:begin
                                    ICMP_TYPE       <= {judge_array[47:32]};    
                                    ICMP_CHECKSUM   <= {judge_array[31:16]};    
                                    ICMP_ID         <= {judge_array[15:0]};     
                                end                                             
                                6'd10:begin                                     
                                    SEQUENCE_SUM    <= {judge_array[47:32]};    
                                    data_dbyte_0    <= {judge_array[31:16]};     
                                    data_dbyte_1    <= {judge_array[15:0]};     
                                end                                                
                                6'd16:begin
                                    data_dbyte_2    <= {judge_array[47:32]};    
                                    data_dbyte_3    <= {judge_array[31:16]};     
                                    data_dbyte_4    <= {judge_array[15:0]};     
                                end
                                6'd22:begin
                                    data_dbyte_5    <= {judge_array[47:32]};    
                                    data_dbyte_6    <= {judge_array[31:16]};     
                                    data_dbyte_7    <= {judge_array[15:0]};     
                                end
                                6'd28:begin
                                    data_dbyte_8    <= {judge_array[47:32]};    
                                    data_dbyte_9    <= {judge_array[31:16]};     
                                    data_dbyte_10   <= {judge_array[15:0]};     
                                end
                                6'd34:begin
                                    data_dbyte_11   <= {judge_array[47:32]};    
                                    data_dbyte_12   <= {judge_array[31:16]};     
                                    data_dbyte_13   <= {judge_array[15:0]};     
                                end
                                6'd38:begin
                                    data_dbyte_14   <= {judge_array[31:16]};     
                                    data_dbyte_15   <= {judge_array[15:0]};     
                                end
                            endcase
                        end
                    end
				ICMP_wait_tx:begin
				    if(ICMP_ACK_r0 && !ICMP_ACK_r1)
				        state <= ICMP_packet_tx;
				    else
				        state <= ICMP_wait_tx;
				end							
                ICMP_packet_tx:                              //5
                    begin
                        if(tx_cnt == 7'd74)begin
                            tx_cnt      <= 7'd0;
                            lan_sof_n   <= 1'd1;
                            lan_eof_n   <= 1'd1;
                            lan_vld_n   <= 1'd1;
                            lan_data    <= 8'd0;
                            state       <= idle;
                            tx_ICMP_busy      <= 1'b0;
                            ICMP_pc_req_o     <= 1'b0;
                        end
                        else begin
                            tx_cnt      <= tx_cnt + 1;
                            lan_vld_n   <= 1'd0;
                            lan_data    <= ICMP_packet_array [tx_cnt];
                            if(tx_cnt == 7'd73)begin
                                lan_eof_n   <= 1'd0;
                            end
                            else if(tx_cnt == 7'd1)begin
                                lan_sof_n   <= 1'd1;
                            end
                            else if(tx_cnt == 7'd0)begin
                                lan_sof_n   <= 1'd0;
                            end
                            else begin
                                lan_sof_n   <= lan_sof_n;
                                lan_eof_n   <= lan_eof_n;
                            end
                        end
                    end

				default:
					begin
                        start_wait_cnt    <= 4'b0;
                        IP_header_cnt     <= 5'd0;
                        ICMP_byte_cnt     <= 6'd0;
                        tx_cnt            <= 7'd0;
                        DES_MAC_RX        <= 48'd0;
                        SOR_MAC_RX        <= 48'd0;
                        FRAME_TYPE        <= 16'd0;
                        IP_VERSION        <= 16'd0;
                        IP_PACKET_LENGTH  <= 16'd0;
                        IP_ID             <= 16'd0;
                        FRAGMENT_OFFSET   <= 16'd0;
                        IP_TYPE           <= 16'd0;
                        IP_HEAD_CHECKSUM  <= 16'd0;
                        ICMP_TYPE         <= 16'd0;
                        ICMP_CHECKSUM     <= 16'd0;
                        ICMP_ID           <= 16'd0;
                        SEQUENCE_SUM      <= 16'd0;
                        SOR_IP_RX         <= 32'd0;
                        DES_IP_RX         <= 32'd0;
                        data_dbyte_0      <= 16'd0;
                        data_dbyte_1      <= 16'd0;
                        data_dbyte_2      <= 16'd0;
                        data_dbyte_3      <= 16'd0;
                        data_dbyte_4      <= 16'd0;
                        data_dbyte_5      <= 16'd0;
                        data_dbyte_6      <= 16'd0;
                        data_dbyte_7      <= 16'd0;
                        data_dbyte_8      <= 16'd0;
                        data_dbyte_9      <= 16'd0;
                        data_dbyte_10     <= 16'd0;
                        data_dbyte_11     <= 16'd0;
                        data_dbyte_12     <= 16'd0;
                        data_dbyte_13     <= 16'd0;
                        data_dbyte_14     <= 16'd0;
                        data_dbyte_15     <= 16'd0;
                        lan_sof_n         <= 1'd1;
                        lan_eof_n         <= 1'd1;
                        lan_vld_n         <= 1'd1;
                        lan_data          <= 8'd0;
                        state             <= idle;
					end
			endcase
		end
	end
	
						
endmodule

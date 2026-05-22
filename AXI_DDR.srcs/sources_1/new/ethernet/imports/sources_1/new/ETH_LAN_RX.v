`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:39:59 06/16/2015 
// Design Name: 
// Module Name:    ETH_LAN_RX 
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
module ETH_LAN_RX#(
 parameter ILA_DEBUG = 1'b0
)(
			input                   clk,
			input                   reset_n,
			input                   init_done,
            
			input                   lan_data_en,
			input          [7:0]    lan_data_in,
			input                   rx_axis_fifo_tlast,
            
			input          [47:0]   SOR_MAC_i,      //for board
			input          [31:0]   SOR_IP_i,       //for board
			input          [15:0]   SOR_PORT_UDP_i,
//			input          [47:0]   DES_MAC_i,      //for board
//			input          [31:0]   DES_IP_i,       //for board
            input          [15:0]     DES_PORT_UDP_RX_i, //LAN_RX_TYPE= 1    rx_test port
            input          [15:0]     DES_PORT_UDP_RX0_i, //LAN_RX_TYPE= 2   write and read reg
            input          [15:0]     DES_PORT_UDP_RX1_i, //LAN_RX_TYPE= 3   load waveform data to DDR3
            input          [15:0]     DES_PORT_UDP_RX2_i, //LAN_RX_TYPE= 4   load waveform addr 
            input          [15:0]     DES_PORT_UDP_RX3_i, //LAN_RX_TYPE= 5   load SEQ waveform addr 
            input          [15:0]     DES_PORT_UDP_RX4_i, //LAN_RX_TYPE= 6   load marker data 
            input          [15:0]     DES_PORT_UDP_RX5_i, //LAN_RX_TYPE= 7   load marker addr 
            input          [15:0]     DES_PORT_UDP_RX6_i, //LAN_RX_TYPE= 8   load SEQ marker addr 
            input          [15:0]     DES_PORT_UDP_RX7_i, //LAN_RX_TYPE= 9   load en data
            input          [15:0]     DES_PORT_UDP_RX8_i, //LAN_RX_TYPE= 10   load SEQ addr
            input          [15:0]     DES_PORT_UDP_RX9_i, //LAN_RX_TYPE= 11  load config files
              
            output   reg   [15:0]   LAN_DATA_NUM = 0,
            output   reg   [3:0]    LAN_RX_TYPE  = 0,     //receive type sel
			output   reg            lan_data_valid = 0,   //byte data valid
			output   reg   [7:0]    lan_data_out   = 0    //byte data
            
			);

//reg       lan_data_en_y0 = 0;
//reg [7:0] lan_data_in_y0 = 8'd0;
//reg [1:0] y_fsm = 0;
//always@(posedge clk)
//    if(!reset_n)
//        begin
//        end
//    else case(y_fsm)
//        0:begin
//            if(lan_data_en)
                
//        end
//    endcase

//*********************************************************//
				  /***** register declaration ******/
//*********************************************************//			
	localparam      idle                  = 5'b00001;      //1
	localparam      start                 = 5'b00010;      //2
	localparam      frame_type_judge      = 5'b00011;      //3
	localparam      data_resolution       = 5'b00100;      //4	
	localparam      port_type_judge       = 5'b00101;      //5
	localparam      data_rx               = 5'b00110;      //6
    
//	parameter      PACKET_LENGTH_init    = 10'h05c;         //10'd92 (64 + 28)
	
	reg   [4:0]    state;
	
	reg            lan_data_en_r;
	reg   [7:0]    lan_data_in_r;
	reg   [7:0]    lan_data_in_2r;
	reg   [7:0]    lan_data_in_3r;
	reg   [7:0]    lan_data_in_4r;
	reg   [7:0]    lan_data_in_5r;

	reg   [3:0]     wait_cnt;
	reg   [4:0]     byte_cnt;
	reg   [15:0]    data_cnt;

	//ETH  14
    reg [47:0] DES_MAC_REC = 0;                                 
    reg [47:0] SOR_MAC_REC = 0;                                                                                                                                                                                                                                                                                                                                                       
    reg [15:0] FRAME_TYPE_REC = 0;                               
    //IP   20                                      
    reg [15:0] IP_VERSION_REC = 0;                                                              
    reg [15:0] IP_PACKET_LENGTH_REC = 0;                                             
    reg [15:0] IP_ID_REC = 0;                                                                       
    reg [15:0] FRAGMENT_OFFSET_REC = 0;                                                   
    reg [15:0] IP_TYPE_REC = 0;	                                                                 
    reg [15:0] IP_HEAD_CHECKSUM_REC = 0;//ip checksum    
    reg [31:0] SOR_IP_REC = 0;                                                                                                                             
    reg [31:0] DES_IP_REC = 0;                                                                 
    //UDP  8                                                                   
    reg [15:0] SOR_PORT_REC = 0;                                                         
    reg [15:0] DES_PORT_REC = 0;                                                          
    reg [15:0] UDP_PACKET_LENGTH_REC = 0;                                          
    reg [15:0] UDP_CHECKSUM_REC = 0; 
    
    wire  [47:0]   judge_array;
			
//*********************************************************//
				  /***** chipscope ******/
//*********************************************************//
generate    
    if(ILA_DEBUG) begin:ila_debug   
    lan_rx_ila inst_lan_rx_ila (
        .clk(clk), // input wire clk
        .probe0(lan_data_en), // input wire [0:0]  probe0  
        .probe1(lan_data_in), // input wire [7:0]  probe1 
        .probe2(lan_data_valid), // input wire [0:0]  probe2 
        .probe3(lan_data_out), // input wire [7:0]  probe3 
        .probe4(state), // input wire [4:0]  probe4 
        .probe5(wait_cnt), // input wire [3:0]  probe5 
        .probe6(byte_cnt), // input wire [4:0]  probe6 
        .probe7(data_cnt), // input wire [15:0]  probe7 
        .probe8(DES_MAC_REC), // input wire [47:0]  probe8 
        .probe9(SOR_MAC_REC), // input wire [47:0]  probe9 
        .probe10(FRAME_TYPE_REC), // input wire [15:0]  probe10 
        .probe11(IP_VERSION_REC), // input wire [15:0]  probe11 
        .probe12(IP_PACKET_LENGTH_REC), // input wire [15:0]  probe12 
        .probe13(IP_ID_REC), // input wire [15:0]  probe13 
        .probe14(FRAGMENT_OFFSET_REC), // input wire [15:0]  probe14 
        .probe15(IP_TYPE_REC), // input wire [15:0]  probe15 
        .probe16(IP_HEAD_CHECKSUM_REC), // input wire [15:0]  probe16 
        .probe17(SOR_IP_REC), // input wire [31:0]  probe17 
        .probe18(DES_IP_REC), // input wire [31:0]  probe18 
        .probe19(SOR_PORT_REC), // input wire [15:0]  probe19 
        .probe20(DES_PORT_REC), // input wire [15:0]  probe20 
        .probe21(UDP_PACKET_LENGTH_REC), // input wire [15:0]  probe21 
        .probe22(UDP_CHECKSUM_REC), // input wire [15:0]  probe22 
        .probe23(judge_array), // input wire [47:0]  probe23
        .probe24(LAN_DATA_NUM), // input wire [15:0]  probe24
        .probe25(LAN_RX_TYPE), // input wire [3:0]  probe25
        .probe26(rx_axis_fifo_tlast) // input wire [0:0]  probe26
    ); 
end
endgenerate 

	
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
    
    wire lan_data_en_p;
    assign  lan_data_en_p   = !lan_data_en && lan_data_en_r;  //falling edge
    assign  judge_array     = {lan_data_in_5r,lan_data_in_4r,lan_data_in_3r,lan_data_in_2r,lan_data_in_r,lan_data_in};
    
	always@(posedge clk)begin
		if(!reset_n)begin
            wait_cnt        <= 4'b0;
            byte_cnt        <= 5'd0;
            data_cnt        <= 16'd0;
			//ETH  14
            DES_MAC_REC <= 0;                                 
            SOR_MAC_REC <= 0;                                                                                                                                                                                                                                                                                                                                                       
            FRAME_TYPE_REC <= 0;                               
            //IP   20                                      
            IP_VERSION_REC <= 0;                                                              
            IP_PACKET_LENGTH_REC <= 0;                                             
            IP_ID_REC <= 0;                                                                       
            FRAGMENT_OFFSET_REC <= 0;                                                   
            IP_TYPE_REC <= 0;	                                                                 
            IP_HEAD_CHECKSUM_REC <= 0; //ip checksum    
            SOR_IP_REC <= 0;                                                                                                                             
            DES_IP_REC <= 0;                                                                 
            //UDP  8                                                                   
            SOR_PORT_REC <= 0;                                                         
            DES_PORT_REC <= 0;                                                          
            UDP_PACKET_LENGTH_REC <= 0;                                          
            UDP_CHECKSUM_REC <= 0;  
			state           <= idle;
		end
		else begin
			case(state)
				idle:                                       //1
					begin
                        wait_cnt     <= 4'b0;
                        byte_cnt     <= 5'd0;
                        data_cnt     <= 16'd0;
//						if(init_done && lan_rd_en)          //20150906 by gk 
						if(init_done && lan_data_en_p)//20151222
							state   <= start;
						else 
							state   <= idle;
					end					
				start:                                      //2
					begin
					    wait_cnt  <= wait_cnt + 1'b1;
						if(lan_data_en == 0)begin
                            if(wait_cnt == 4'd11)begin
                                wait_cnt  <= 0;
                                state     <= frame_type_judge;
                            end
                            else if(wait_cnt == 4'd4)
                                DES_MAC_REC <= judge_array;
                            else if(wait_cnt == 4'd10)
                                SOR_MAC_REC <= judge_array;
                            else begin
                                 state     <= start;
                            end
                        end
                        else
                            state    <= idle;
					end
					
				frame_type_judge:                           //3
					begin
                        if(judge_array[15:0] == 16'h0800)
                            state    <= data_resolution;
                        else
                            state    <= idle;
                    end
                    
                data_resolution:                            //4
                    begin
                        byte_cnt <= byte_cnt + 1'b1;
                        if(byte_cnt == 5'd27)begin
                            byte_cnt <= 6'd0;
                            state    <= port_type_judge;
                            DES_PORT_REC <= judge_array[47:32];
                            UDP_PACKET_LENGTH_REC <= judge_array[31:16];
                            UDP_CHECKSUM_REC <= judge_array[15:0]; 
                        end
                        else case(byte_cnt)
                            3:begin
                                FRAME_TYPE_REC <= judge_array[47:32];
                                IP_VERSION_REC <= judge_array[31:16];
                                IP_PACKET_LENGTH_REC <= judge_array[15:0];
                            end
                            9:begin
                                IP_ID_REC <= judge_array[47:32];
                                FRAGMENT_OFFSET_REC <= judge_array[31:16];
                                IP_TYPE_REC <= judge_array[15:0];
                            end
                            15:begin
                               IP_HEAD_CHECKSUM_REC <= judge_array[47:32];
                               SOR_IP_REC <= judge_array[31:0];
                            end
                            21:begin
                               DES_IP_REC  <= judge_array[47:16];
                               SOR_PORT_REC <= judge_array[15:0];
                            end     
                            default:begin
                                state    <= data_resolution;
                            end
                        endcase 
                    end							
				port_type_judge:                            //5
					begin
					    if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX_i) //test 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                LAN_RX_TYPE <= 4'd1;
                                state    <= data_rx;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX0_i) //receive0 DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                LAN_RX_TYPE <= 4'd2;
                                state    <= data_rx;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX1_i) //receive1 DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state    <= data_rx;
                                LAN_RX_TYPE <= 4'd3;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX2_i) //receive2 DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd4;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX3_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd5;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX4_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd6;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX5_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd7;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX6_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd8;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX7_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd9;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX8_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd10;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX9_i) //receive3  DES_MAC_REC == SOR_MAC_i && 
                            begin
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd11;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else begin
                            state    <= idle;
                            LAN_RX_TYPE <= 4'b0000;
                        end
                    end 
                data_rx:                                    //6
                    begin
						if(data_cnt == LAN_DATA_NUM)begin
							data_cnt       <= 16'd0;
							lan_data_valid <= 1'b0;
							LAN_RX_TYPE    <= 4'b0000;
							lan_data_out   <= 8'd0;
							if(!lan_data_en)
							   state <= start;  
							else
							   state <= idle;
                        end
                        else begin
                            data_cnt       <= data_cnt + 1'b1;
							lan_data_valid <= 1;
							lan_data_out   <= lan_data_in;
							state          <= data_rx;
                        end
                    end
				default:
					begin
                        wait_cnt     <= 4'b0;
                        byte_cnt     <= 5'd0;
                        data_cnt     <= 16'd0;
						state        <= idle;
					end
			endcase
		end
	end
	
						
endmodule

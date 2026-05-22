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
module LAN_RX_ARP#(
 parameter ILA_DEBUG = 1'b0
)(
			input                   clk,
			input                   reset_n,
			input                   init_done,
//			input                   lan_rd_en,
            
			input                   lan_data_en,
			input          [7:0]    lan_data_in,
			
			input         READ_DONE, 
            input  [47:0] FPGA_MAC,  
            input  [31:0] FPGA_IP,
            output  reg       ip_update = 1'b0,
            
			output         [47:0]   SOR_MAC_o,      //for board
			output         [31:0]   SOR_IP_o,       //for board
            
			output   reg   [47:0]   DES_MAC_o,      //for board
			output   reg   [31:0]   DES_IP_o,       //for board
            
			output   reg            ARP_req_en = 0,
			output   reg            ARP_resp_en = 0,
			output   reg [47:0]     arp_data0 = 0,
            output   reg [47:0]     arp_data1 = 0,
            output   reg [47:0]     arp_data2 = 0
			);

//*********************************************************//
			  /***** register declaration *****/
//*********************************************************//			
	localparam      idle                  = 5'b00001;      //1
	localparam      start                 = 5'b00010;      //2
	localparam      frame_type_judge      = 5'b00011;      //3
	localparam      ARP_resolution        = 5'b00100;      //4	
	localparam      ARP_req_success       = 5'b00101;      //5
    
//	parameter      PACKET_LENGTH_init    = 10'h05c;         //10'd92 (64 + 28)
	
	reg   [4:0]    state;
	
	reg            lan_data_en_r;
	reg   [7:0]    lan_data_in_r;
	reg   [7:0]    lan_data_in_2r;
	reg   [7:0]    lan_data_in_3r;
	reg   [7:0]    lan_data_in_4r;
	reg   [7:0]    lan_data_in_5r;

	reg            rx_success;
	reg   [5:0]    ARP_packet_time_cnt;
	reg   [3:0]    start_wait_cnt;
//	reg   [5:0]    wait_cnt;

	reg   [15:0]   ARP_TYPE;
	reg   [15:0]   FRAME_TYPE;
	reg   [15:0]   HW_TYPE;
	reg   [15:0]   PROTOCOL_TYPE;
	reg   [47:0]   SOR_MAC;
	reg   [47:0]   DES_MAC;
	reg   [31:0]   SOR_IP;
	reg   [31:0]   DES_IP;
	reg   [7:0]    MAC_LENGTH;
	reg   [7:0]    IP_LENGTH;
    
    wire  [47:0]   judge_array;
    
//    reg [47:0] arp_data0 = 0;
//    reg [47:0] arp_data1 = 0;
//    reg [47:0] arp_data2 = 0;
			
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
	
	
//*********************************************************//
             /*****  Begin Design Instance  *****/
//*********************************************************//
//	assign  ARP_req_en  = ((ARP_TYPE == 16'h0001) && (DES_IP == SOR_IP_i)) ? rx_success : 1'b0;
////	assign  ARP_req_en  = ((ARP_TYPE == 16'h0001) || (DES_IP == SOR_IP_i)) ? rx_success : 1'b0;
//	assign  ARP_resp_en = ((ARP_TYPE == 16'h0002) && (DES_IP == SOR_IP_i) && (DES_MAC == SOR_MAC_i)) ? rx_success : 1'b0;
	
//	always@(posedge clk)
//		if(!reset_n)begin
//			DES_MAC_o         <= 48'd0;
//			DES_IP_o          <= 32'd0;
//		end
//		else if(ARP_req_en || ARP_resp_en)begin
//			DES_MAC_o       <= SOR_MAC;
//			DES_IP_o        <= SOR_IP;
//		end
//		else
//		  begin
//		      DES_MAC_o <= DES_MAC_o;
//		      DES_IP_o  <= DES_IP_o;
//		  end
 wire  READ_DONE_w;
 reg READ_DONE_r0 = 1'b0;
 reg READ_DONE_r1 = 1'b0;
 reg READ_DONE_r2 = 1'b0;
 reg READ_DONE_r3 = 1'b0;
 always@(posedge clk)begin
    READ_DONE_r0 <= READ_DONE;
    READ_DONE_r1 <= READ_DONE_r0;
    READ_DONE_r2 <= READ_DONE_r1;
    READ_DONE_r3 <= READ_DONE_r2;
 end
 
 assign READ_DONE_w = READ_DONE_r2 &&  !READ_DONE_r3;
    
    reg [31:0] SOR_IP_r  = 32'hC0A80108;      //192.168.1.8 DEFAULT IP
    reg [47:0] SOR_MAC_r = 48'hDA0102030405;      //DA0102030405 DEFAULT MAC
    reg [1:0] ip_fsm = 0;
    
	always@(posedge clk)
		if(!reset_n)begin
		   SOR_IP_r <= 32'hC0A80108;
		   SOR_MAC_r <= 48'hDA0102030405;
		   ip_fsm   <= 0;
           ip_update <= 1'b0;
		end
        else case(ip_fsm)
            0:begin
                if(READ_DONE_w)begin
                    ip_update <= 1'b1;
                    ip_fsm <= 2;
                end
                else if(rx_success) 
                    ip_fsm <= 1;
                else
                    ip_fsm <= 0;
            end
            1:begin
                 ip_fsm <= 0;
                 if(arp_data0[47:32] == 16'h5A5A) begin
                     ip_update <= 1'b0;
                     SOR_IP_r <= arp_data0[31:0];
                 end
                 else
                    SOR_IP_r <= SOR_IP_r;
            end
            2:begin
                ip_fsm <= 0;
                SOR_IP_r  <= FPGA_IP;
                SOR_MAC_r <= FPGA_MAC;
            end
            default:begin
               SOR_IP_r <= 32'hC0A80108;
		       SOR_MAC_r <= 48'hDA0102030405;
		       ip_fsm   <= 0; 
            end
        endcase
               
    assign SOR_IP_o  = SOR_IP_r;
    assign SOR_MAC_o = SOR_MAC_r;
		
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
    
	always@(posedge clk)begin
		if(!reset_n)begin
		    DES_MAC_o         <= 48'd0;
			DES_IP_o          <= 32'd0;
			ARP_packet_time_cnt     <= 6'd0;
            start_wait_cnt          <= 4'b0;
			rx_success              <= 1'b0;
			FRAME_TYPE              <= 16'd0;
			PROTOCOL_TYPE           <= 16'd0;
			HW_TYPE                 <= 16'd0;
			DES_MAC                 <= 48'd0;
			SOR_MAC                 <= 48'd0;
			SOR_IP                  <= 32'd0;
			DES_IP                  <= 32'd0;
			ARP_TYPE                <= 16'd0;
			ARP_req_en              <= 1'b0;
			ARP_resp_en             <= 1'b0;
			arp_data0               <= 48'd0;
			arp_data1               <= 48'd0;
			arp_data2               <= 48'd0;
			state                   <= idle;
		end
		else begin
			case(state)
				idle:                                       //1
					begin
                        ARP_packet_time_cnt     <= 6'd0;
                        start_wait_cnt          <= 4'b0;
                        rx_success              <= 1'b0;
//                        FRAME_TYPE              <= 16'd0;
//                        PROTOCOL_TYPE           <= 16'd0;
//                        HW_TYPE                 <= 16'd0;
//                        DES_MAC                 <= 48'd0;
//                        SOR_MAC                 <= 48'd0;
//                        SOR_IP                  <= 32'd0;
//                        DES_IP                  <= 32'd0;
//                        ARP_TYPE                <= 16'd0;
                          ARP_req_en              <= 1'b0;
			              ARP_resp_en             <= 1'b0;

//						if(init_done && lan_rd_en)          //20150906 by gk 
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
                                state           <= start;
                            end
                        end
                        else
                            state    <= idle;
					end
					
				frame_type_judge:                           //3
					begin
                        if(judge_array[15:0] == 16'h0806)
                            state    <= ARP_resolution;
//                        else if(judge_array[15:0] == 16'h0800)
//                            state    <= DATA_RESOLUTION;
                        else
                            state    <= idle;
                    end
                    
                ARP_resolution:                             //4
                    begin
                        if(ARP_packet_time_cnt == 6'd45)begin
                            ARP_packet_time_cnt <= 6'd0;
                            arp_data2           <= judge_array;
                            state               <= ARP_req_success;
                        end
                        else begin
                            ARP_packet_time_cnt <= ARP_packet_time_cnt + 1'b1;
                            case(ARP_packet_time_cnt)
                                6'd3:begin
                                    if(judge_array == 48'h080600010800)begin
                                        FRAME_TYPE      <= {judge_array[47:32]};
                                        HW_TYPE         <= {judge_array[31:16]};
                                        PROTOCOL_TYPE   <= {judge_array[15:0]};
                                    end
                                    else
                                        state    <= idle;
                                end
                                6'd7:begin
                                    if(judge_array[15:0] == 16'h0001 || 16'h0002)begin
                                        MAC_LENGTH      <= {judge_array[31:24]};
                                        IP_LENGTH       <= {judge_array[23:16]};
                                        ARP_TYPE        <= {judge_array[15:0]};
                                    end
                                    else
                                        state    <= idle;
                                end
                                6'd13:
                                    SOR_MAC         <= judge_array;         //computer MAC
                                6'd17:
                                    SOR_IP          <= {judge_array[31:0]}; //computer IP
                                6'd23:
                                    DES_MAC         <= judge_array;         //board MAC
                                6'd27:
                                    DES_IP          <= {judge_array[31:0]}; //board IP
                                6'd33:
                                    arp_data0       <= judge_array;
                                6'd39:
                                    arp_data1       <= judge_array;
                             default:begin
                                state <= state;
                             end
                            endcase
                        end
                    end
											
                ARP_req_success:                            //5
                    begin
                        state       <= idle;
                        if(((ARP_TYPE == 16'h0001) && (DES_IP == SOR_IP_r))|| ((ARP_TYPE == 16'h0001) && (arp_data0 == 48'h55AA_55AA_55AA)))
                            begin
                                ARP_req_en <= 1'b1;
                                DES_MAC_o       <= SOR_MAC;
			                    DES_IP_o        <= SOR_IP;
			                    rx_success  <= 1'b1;
                            end
                        else if((ARP_TYPE == 16'h0002) && (DES_IP == SOR_IP_r) && (DES_MAC == SOR_MAC_o))
                            begin
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
//                        FRAME_TYPE              <= 16'd0;
//                        PROTOCOL_TYPE           <= 16'd0;
//                        HW_TYPE                 <= 16'd0;
//                        DES_MAC                 <= 48'd0;
//                        SOR_MAC                 <= 48'd0;
//                        SOR_IP                  <= 32'd0;
//                        DES_IP                  <= 32'd0;
//                        ARP_TYPE                <= 16'd0;
                        arp_data0               <= 48'd0;
			            arp_data1               <= 48'd0;
			            arp_data2               <= 48'd0;
						state                   <= idle;
					end
			endcase
		end
	end
	
						
endmodule

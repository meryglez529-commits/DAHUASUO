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


module LAN_RD_REG(
    input               tx_fifo_clock,
    input               reset_n,
    
    input               REG_VALID,
    input [15:0]        REG_ADDR, 
    input [31:0]        REG_DATA,
    
    output        reg      RD_REG_req_o = 0,
    input                  RD_ACK_i,
    output  reg   [15:0]   LAN_DATA_NUM_o = 0,
    output  reg            lan_data_valid_o = 0,
    output  reg   [7:0]    lan_data_o = 0
    );
    
    reg [15:0] REG_ADDR_r = 0;
    reg [31:0] REG_DATA_r = 0;
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
   
   reg RD_ACK_r0 = 0;
   reg RD_ACK_r1 = 0;
   always@(posedge tx_fifo_clock)
    begin
       RD_ACK_r0 <= RD_ACK_i; 
       RD_ACK_r1 <= RD_ACK_r0;
    end
    
    reg [2:0] fsm_r = 0;
    reg [4:0] byte_cnt = 0;
//    reg [15:0] REG_ADDR_r = 0;
//    reg [31:0] REG_DATA_r = 0;
    always@(posedge tx_fifo_clock)
        if(!reset_n)
            begin
               fsm_r    <= 0;
               byte_cnt <= 0;
               REG_ADDR_r <= 16'd0;
               REG_DATA_r <= 32'd0;
               LAN_DATA_NUM_o <= 0;
               RD_REG_req_o <= 0;
            end
        else case(fsm_r)
            0:begin
                if(REG_VALID)
                    begin
                       REG_ADDR_r <= REG_ADDR;
                       REG_DATA_r <= REG_DATA;
                       LAN_DATA_NUM_o <= 16'd14;
                       RD_REG_req_o <= 1'b1;   //request
                       fsm_r <= 1;
                    end
                else 
                    begin
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
               if(byte_cnt < 5'd14)
	           begin
	              lan_data_valid_o <= 1'b1;
	              lan_data_o      <= packet_array[byte_cnt];
	              byte_cnt <= byte_cnt +1'b1;
	              fsm_r <= 2;
	           end
	       else
	           begin
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
    
    
    
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/11 13:30:49
// Design Name: 
// Module Name: LAN_WR_REG  LAN_RD_REG
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


module LAN_WR_REG(
    input               tx_fifo_clock,
    input               reset_n,
    
    input      [15:0]   LAN_DATA_NUM_i,
    input      [3:0]    LAN_RX_TYPE_i,     //receive type sel
	input               lan_data_valid_i,   //byte data valid
	input      [7:0]    lan_data_i,    //byte data
     
    output  reg              WR_REG_VALID_o = 0,   // write byte data valid   
    output  reg    [15:0]    WR_REG_ADDR_o = 0,    //write addr
	output  reg    [31:0]    WR_REG_DATA_o = 0,    //byte data  
	
	output  reg              RD_REG_VALID_o = 0,  //read byte data valid
	output  reg    [15:0]    RD_REG_ADDR_o = 0   //read addr

    );
    
    
 reg        lan_data_valid_r = 0;  
 reg [7:0]  lan_data_r = 8'd0;
 always@(posedge tx_fifo_clock)
    if(LAN_RX_TYPE_i == 4'd2 && lan_data_valid_i)
        begin
            lan_data_valid_r <= lan_data_valid_i;
            lan_data_r       <= lan_data_i;
        end
    else
        begin
           lan_data_valid_r <= 0;
           lan_data_r       <= 8'd0; 
        end
    
    reg [7:0] lan_data_i_r0 = 0;
    reg [7:0] lan_data_i_r1 = 0;
    reg [7:0] lan_data_i_r2 = 0;
    reg [7:0] lan_data_i_r3 = 0;
    wire [31:0] data_type;
    always@(posedge tx_fifo_clock)
        if(lan_data_valid_r)
            begin
               lan_data_i_r0 <= lan_data_r; 
               lan_data_i_r1 <= lan_data_i_r0; 
               lan_data_i_r2 <= lan_data_i_r1; 
               lan_data_i_r3 <= lan_data_i_r2; 
            end
   assign data_type = {lan_data_i_r3,lan_data_i_r2,lan_data_i_r1,lan_data_i_r0};
    
    reg [3:0] fsm_r = 0;
    reg [15:0] byte_cnt = 0;
    reg [31:0] HEAD_TYPE = 0;
    reg [15:0] CMD_TYPE = 0;
    reg [15:0] LEN_TYPE = 0;
    always@(posedge tx_fifo_clock)
        if(!reset_n)
            begin
               fsm_r    <= 0;
               byte_cnt <= 0;
               WR_REG_VALID_o <= 1'b0;
               WR_REG_ADDR_o <= 16'd0;
               WR_REG_DATA_o <= 32'd0;
            end
        else
         case(fsm_r)
            0:begin
                WR_REG_VALID_o <= 1'b0;
                RD_REG_VALID_o <= 1'b0;
                if(lan_data_valid_r&&lan_data_r == 8'h55)
                    begin
                        fsm_r <= 1;
                        byte_cnt <= byte_cnt + 1'b1;
                    end
                else
                    begin
                        fsm_r <= 0;
                        byte_cnt <= 0;
                    end
            end
            1:begin
                byte_cnt <= byte_cnt + 1'b1;
                if(byte_cnt == 5'd4)
                    begin
                        fsm_r <= 2;
                        HEAD_TYPE <= data_type;
                    end
                else
                   fsm_r <= 1; 
            end
            2:begin
                byte_cnt <= byte_cnt + 1'b1;
                if(HEAD_TYPE == 32'h5555AAAA)
                     fsm_r <= 3; 
                else
                    fsm_r <= 0;
            end
            3:begin
                byte_cnt <= byte_cnt + 1'b1;
                if(byte_cnt == 5'd6)
                    begin
                        CMD_TYPE <= data_type[15:0];
                        fsm_r <= 4;
                    end
                 else
                    fsm_r <= 3;
            end
            4:begin
               byte_cnt <= byte_cnt + 1'b1;
                if(CMD_TYPE == 16'h0001)  //write reg
                     fsm_r <= 5; 
                else if(CMD_TYPE == 16'h0002) //read reg
                     fsm_r <= 9; 
                else
                     fsm_r <= 0; 
            end
            5:begin 
                if(byte_cnt == 5'd8)
                    begin
                        byte_cnt <= 0;
                        LEN_TYPE <= data_type[15:0];
                        fsm_r <= 6;
                    end
                 else begin
                    fsm_r <= 5;
                    byte_cnt <= byte_cnt + 1'b1;
                 end
            end
            6:begin
                byte_cnt <= byte_cnt + 1'b1;
                if(byte_cnt == 5'd1)
                    begin
                        WR_REG_ADDR_o <= data_type[15:0];
                        fsm_r <= 7;
                    end
                 else
                    fsm_r <= 6;
            end 
            7:begin
               byte_cnt <= byte_cnt + 1'b1;
                if(byte_cnt == 5'd5)
                    begin
                        WR_REG_DATA_o <= data_type;
                        fsm_r <= 8;
                    end
                 else
                    fsm_r <= 7; 
            end
            8:begin
                fsm_r <= 0;
                byte_cnt <= 0;
                if(byte_cnt == LEN_TYPE)   //error
                    begin
                       WR_REG_VALID_o <= 1'b1; 
                    end
                else
                    begin
                       WR_REG_VALID_o <= 1'b0;  
                    end
            end
            9:begin
               if(byte_cnt == 5'd8)
                    begin
                        byte_cnt <= 0;
                        LEN_TYPE <= data_type[15:0];
                        fsm_r <= 10;
                    end
                 else begin
                    fsm_r <= 9;
                    byte_cnt <= byte_cnt + 1'b1;
                 end 
            end
            10:begin
                byte_cnt <= byte_cnt + 1'b1;
                if(byte_cnt == 5'd1)
                    begin
                        RD_REG_ADDR_o <= data_type[15:0];
                        fsm_r <= 11;
                    end
                 else
                    fsm_r <= 10;
            end
            11:begin
                fsm_r <= 0;
                byte_cnt <= 0;
                if(byte_cnt == LEN_TYPE)   //error
                    begin
                       RD_REG_VALID_o <= 1'b1; 
                    end
                else
                    begin
                       RD_REG_VALID_o <= 1'b0;  
                    end
            end
            default:begin
               fsm_r    <= 0;
               byte_cnt <= 0;
            end
        endcase
    
endmodule

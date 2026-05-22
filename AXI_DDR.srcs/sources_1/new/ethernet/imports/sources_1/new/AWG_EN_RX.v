`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/16 09:20:46
// Design Name: 
// Module Name: AWG_EN_RX
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


module AWG_EN_RX #(
 parameter ILA_DEBUG = 1'b0
)
(
        input               tx_fifo_clock,
        input               reset_n,  
        
        input      [15:0]   CHN_CMD,             
        input      [2:0]    LAN_RX_TYPE_i,     //receive type sel  4
	    input               lan_data_valid_i,   //byte data valid
	    input      [7:0]    lan_data_i,    //byte data
	    
	    output                 AWGen_wr_clk,
	    output  reg            AWGen_data_valid = 0,
	    output  reg   [15:0]   AWGen_addr = 0,
	    output  reg   [79:0]   AWGen_data = 0,
	    output  reg            load_done = 0
	    
    );
  
// parameter  CHN_CMD = 16'h0001;
 
 reg        lan_data_valid_r = 0;  
 reg [7:0]  lan_data_r = 8'd0;
 always@(posedge tx_fifo_clock)
    if(LAN_RX_TYPE_i == 3'd4 && lan_data_valid_i)
        begin
            lan_data_valid_r <= lan_data_valid_i;
            lan_data_r       <= lan_data_i;
        end
    else
        begin
           lan_data_valid_r <= 0;
           lan_data_r       <= 8'd0; 
        end
        
 assign AWGen_wr_clk = tx_fifo_clock;
 
 reg [7:0] lan_data [8:0];
 
 reg [4:0]  fsm = 0;
 reg [31:0] AWGen_data_len = 0;
 reg [15:0] AWGen_start_addr = 0;
 reg [15:0] AWGen_end_addr = 0;
 reg [15:0] CNT_addr = 0;
 reg [31:0] byte_cnt = 0;
 always@(posedge tx_fifo_clock)
    if(!reset_n)
        begin
            fsm <= 0;
        end
    else
     case(fsm)
        0:begin
            byte_cnt <= 0;
            if(lan_data_valid_r&&lan_data_r == 8'h55) 
                begin
                    fsm <= 1;
//                    load_done <= 1'b0;
                end
            else
                begin
                    fsm <= 0;
                end
        end
        1:begin
            if(lan_data_valid_r&&lan_data_r == 8'hAA) 
                fsm <= 2;
            else
                fsm <= 0;
        end
        2:begin
            if(lan_data_valid_r&&lan_data_r == 8'h55) 
                fsm <= 3;
            else
                fsm <= 0;
        end
        3:begin
            if(lan_data_valid_r&&lan_data_r == 8'hAA)   //head:0x55AA55AA
                fsm <= 4;
            else
                fsm <= 0;
        end
        4:begin
            if(lan_data_valid_r&&lan_data_r == CHN_CMD[15:8]) 
                fsm <= 5;
            else
                fsm <= 0;
        end
        5:begin
            if(lan_data_valid_r&&lan_data_r == CHN_CMD[7:0])begin  //zhiling  0x0001/0x0002/0x0003/0x0004
                fsm <= 6;
                load_done <= 1'b0;
            end
            else
                fsm <= 0;
        end
        6:begin
            if(lan_data_valid_r) begin
                AWGen_data_len[31:24] <= lan_data_r;
                fsm <= 7;
            end
            else
                fsm <= 6;
        end
        7:begin
            if(lan_data_valid_r) begin
                AWGen_data_len[23:16] <= lan_data_r;
                fsm <= 8;
            end
            else
                fsm <= 7;
        end
        8:begin
            if(lan_data_valid_r) begin
                AWGen_data_len[15:8] <= lan_data_r;
                fsm <= 9;
            end
            else
                fsm <= 8;
        end
        9:begin
            if(lan_data_valid_r) begin
                AWGen_data_len[7:0] <= lan_data_r;    //length of data
                fsm <= 10;
            end
            else
                fsm <= 9;
        end
        10:begin
            if(lan_data_valid_r) begin
                AWGen_start_addr[15:8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 11;
            end
            else
                fsm <= 10;
        end
        11:begin
            if(lan_data_valid_r) begin
                AWGen_start_addr[7:0] <= lan_data_r; //AWGen_start_addr
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 12;
            end
            else
                fsm <= 11;
        end
        12:begin
            CNT_addr <= AWGen_start_addr;
            if(lan_data_valid_r) begin
                AWGen_end_addr[15:8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 13;
            end
            else
                fsm <= 12;
        end
        13:begin
            if(lan_data_valid_r) begin
                AWGen_end_addr[7:0] <= lan_data_r;   //AWGen_end_addr
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 14;
            end
            else
                fsm <= 13;
        end
        14:begin
            AWGen_data_valid <= 1'b0;
            AWGen_addr       <= 16'd0;
            AWGen_data       <= 80'd0;
            if(lan_data_valid_r) begin            //ddr3_data
                lan_data[8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 15;
            end
            else
                fsm <= 14;
        end
        15,16,17,18,19,20,21,22:begin
            if(lan_data_valid_r) begin            //ddr3_data
                lan_data[22-fsm] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= fsm + 1'b1;
            end
            else
                fsm <= fsm;
        end
        23:begin
            if(lan_data_valid_r) begin            //ddr3_data
                AWGen_data_valid <= 1'b1;
                AWGen_addr       <= CNT_addr;
                CNT_addr         <= CNT_addr + 1'b1;
                AWGen_data       <= {lan_data[8],lan_data[7],lan_data[6],lan_data[5],lan_data[4],lan_data[3],lan_data[2],lan_data[1],lan_data[0],lan_data_r};
                byte_cnt         <= byte_cnt + 1'b1;
                if(CNT_addr == AWGen_end_addr)
                        fsm <= 24;
                else
                        fsm <= 14;
            end
            else
                fsm <= fsm;
        end
        24:begin
            AWGen_data_valid <= 1'b0;
            AWGen_addr       <= 16'd0;
            AWGen_data       <= 80'd0;
            CNT_addr         <= 16'd0; 
            fsm              <= 0;
            if(byte_cnt == AWGen_data_len)
                 load_done <= 1'b1;
            else
                 load_done <= 1'b0;
        end
        default:begin
           fsm <= 0; 
        end
    endcase
generate    
    if(ILA_DEBUG) begin:ila_debug   
        ila_AWG_EN_RX ila_AWG_EN_RX_inst (
            .clk(tx_fifo_clock), // input wire clk
            .probe0(LAN_RX_TYPE_i), // input wire [2:0]  probe0  
            .probe1(lan_data_valid_r), // input wire [0:0]  probe1 
            .probe2(lan_data_r), // input wire [7:0]  probe2 
            .probe3(AWGen_data_valid), // input wire [0:0]  probe3 
            .probe4(AWGen_addr), // input wire [15:0]  probe4 
            .probe5(AWGen_data), // input wire [79:0]  probe5 
            .probe6(load_done), // input wire [0:0]  probe6 
            .probe7(fsm), // input wire [4:0]  probe7 
            .probe8(AWGen_data_len), // input wire [31:0]  probe8 
            .probe9(AWGen_start_addr), // input wire [15:0]  probe9 
            .probe10(AWGen_end_addr), // input wire [15:0]  probe10 
            .probe11(CNT_addr), // input wire [15:0]  probe11 
            .probe12(byte_cnt) // input wire [31:0]  probe12
        );  
end
endgenerate  

 
endmodule

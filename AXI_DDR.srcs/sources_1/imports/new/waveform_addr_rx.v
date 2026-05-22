`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/16 14:22:56
// Design Name: 
// Module Name: waveform_addr_rx
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


module waveform_addr_rx#(
 parameter ILA_DEBUG = 1'b0
)(
        input               tx_fifo_clock,
        input               reset_n,  
         
        input      [15:0]   CHN_CMD,            
        input      [2:0]    LAN_RX_TYPE_i,     //receive type sel  3
	    input               lan_data_valid_i,   //byte data valid
	    input      [7:0]    lan_data_i,    //byte data
	    
	    output                 AWGaddr_wr_clk,
	    output  reg   [15:0]   AWG_seq           = 0,  //N no more than 1024
	    output  reg            AWG_en_addr_valid = 0,
	    output  reg   [9:0]    AWG_en_addr       = 0,
	    output  reg   [47:0]   AWG_en_data = 0,  //repeat times(2 Byte) + start addr(2 Byte) + end addr(2 Byte)
	    
	    output  reg   [15:0]   AWG_subseq           = 0,  //M no more than 1024
	    output  reg            AWG_wf_addr_valid = 0,
	    output  reg   [9:0]    AWG_wf_addr       = 0,
	    output  reg   [79:0]   AWG_wf_data = 0,  //repeat times(2 Byte) + start addr(4 Byte) + end addr(4 Byte)
	    output  reg            load_done = 0
	    
    );
    
// parameter  CHN_CMD = 16'h0001;
  
 reg        lan_data_valid_r = 0;  
 reg [7:0]  lan_data_r = 8'd0;
 always@(posedge tx_fifo_clock)
    if(LAN_RX_TYPE_i == 3'd5 && lan_data_valid_i)
        begin
            lan_data_valid_r <= lan_data_valid_i;
            lan_data_r       <= lan_data_i;
        end
    else
        begin
           lan_data_valid_r <= 0;
           lan_data_r       <= 8'd0; 
        end
        
 assign AWGaddr_wr_clk = tx_fifo_clock;
 
 reg [7:0] lan_data [4:0]; //11 byte
 reg [7:0] lan_data1 [8:0]; //11 byte
 
 reg [5:0]  fsm = 0;
 reg [31:0] AWGaddr_data_len = 0;
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
            if(lan_data_valid_r&&lan_data_r == 8'hAA)   //zhen tou
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
            if(lan_data_valid_r&&lan_data_r == CHN_CMD[7:0])begin  //zhiling 0x0001/0x0002/0x0003/0x0004
                fsm <= 6;
                load_done <= 1'b0;
            end
            else
                fsm <= 0;
        end
        6:begin
            if(lan_data_valid_r) begin
                AWGaddr_data_len[31:24] <= lan_data_r;
                fsm <= 7;
            end
            else
                fsm <= 6;
        end
        7:begin
            if(lan_data_valid_r) begin
                AWGaddr_data_len[23:16] <= lan_data_r;
                fsm <= 8;
            end
            else
                fsm <= 7;
        end
        8:begin
            if(lan_data_valid_r) begin
                AWGaddr_data_len[15:8] <= lan_data_r;
                fsm <= 9;
            end
            else
                fsm <= 8;
        end
        9:begin
            if(lan_data_valid_r) begin
                AWGaddr_data_len[7:0] <= lan_data_r;    //length of data
                fsm <= 10;
            end
            else
                fsm <= 9;
        end
        10:begin
            if(lan_data_valid_r) begin         
                AWG_seq[15:8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 11;
            end
            else
                fsm <= 10;
        end
        11:begin
            if(lan_data_valid_r) begin                //num of seq
                AWG_seq[7:0] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 12;
            end
            else
                fsm <= 11;
        end
        12:begin
            AWG_en_addr_valid <= 1'b0;
            AWG_en_addr       <= 10'd0;
            AWG_en_data       <= 48'd0;
            if(lan_data_valid_r) begin            //en_data
                lan_data[4] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 13;
            end
            else
                fsm <= 12;
        end
        13,14,15,16:begin
            if(lan_data_valid_r) begin            //en_data
                lan_data[16-fsm] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= fsm + 1'b1;
            end
            else
                fsm <= fsm;
        end
        17:begin
            if(lan_data_valid_r) begin            //en_data
                AWG_en_addr_valid <= 1'b1;
                AWG_en_addr       <= CNT_addr;
                AWG_en_data       <= {lan_data[4],lan_data[3],lan_data[2],lan_data[1],lan_data[0],lan_data_r};
                byte_cnt <= byte_cnt + 1'b1;
                if(CNT_addr == (AWG_seq -1'b1))begin
                        fsm <= 18;
                        CNT_addr <= 0;
                end
                else begin
                       fsm <= 12;
                       CNT_addr <= CNT_addr + 1'b1; 
                end
            end
            else
                fsm <= fsm;
        end
        18:begin
            AWG_en_addr_valid <= 1'b0;
            AWG_en_addr       <= 10'd0;
            AWG_en_data       <= 48'd0;
            if(lan_data_valid_r) begin         
                AWG_subseq[15:8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 19;
            end
            else
                fsm <= 18;
        end
        19:begin
            if(lan_data_valid_r) begin                //num of subseq
                AWG_subseq[7:0] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 20;
            end
            else
                fsm <= 19;
        end
        20:begin
            AWG_wf_addr_valid <= 1'b0;
            AWG_wf_addr       <= 10'd0;
            AWG_wf_data       <= 80'd0;
            if(lan_data_valid_r) begin            //ddr3_data
                lan_data1[8] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= 21;
            end
            else
                fsm <= 20;
        end
        21,22,23,24,25,26,27,28:begin
            if(lan_data_valid_r) begin            //ddr3_data
                lan_data1[28-fsm] <= lan_data_r;
                byte_cnt <= byte_cnt + 1'b1;
                fsm <= fsm + 1'b1;
            end
            else
                fsm <= fsm;
        end
        29:begin
            if(lan_data_valid_r) begin            //ddr3_data
                AWG_wf_addr_valid <= 1'b1;
                AWG_wf_addr       <= CNT_addr;
                AWG_wf_data       <= {lan_data1[8],lan_data1[7],lan_data1[6],lan_data1[5],lan_data1[4],lan_data1[3],lan_data1[2],lan_data1[1],lan_data1[0],lan_data_r};
                byte_cnt <= byte_cnt + 1'b1;
                if(CNT_addr == (AWG_seq -1'b1))begin
                        fsm <= 30;
                        CNT_addr <= 0;
                end
                else begin
                       fsm <= 20;
                       CNT_addr <= CNT_addr + 1'b1; 
                end
            end
            else
                fsm <= fsm;
        end
        30:begin
            AWG_wf_addr_valid <= 1'b0;
            AWG_wf_addr       <= 10'd0;
            AWG_wf_data       <= 80'd0;
            fsm             <= 0;
            if(byte_cnt == AWGaddr_data_len)
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
        ila_waveform_addr_rx ila_waveform_addr_rx_inst (
        .clk(tx_fifo_clock), // input wire clk
        .probe0(LAN_RX_TYPE_i), // input wire [2:0]  probe0  
        .probe1(lan_data_valid_r), // input wire [0:0]  probe1 
        .probe2(lan_data_r), // input wire [7:0]  probe2 
        .probe3(AWG_seq), // input wire [15:0]  probe3 
        .probe4(AWG_en_addr_valid), // input wire [0:0]  probe4 
        .probe5(AWG_en_addr), // input wire [9:0]  probe5 
        .probe6(AWG_en_data), // input wire [47:0]  probe6 
        .probe7(AWG_subseq), // input wire [15:0]  probe7 
        .probe8(AWG_wf_addr_valid), // input wire [0:0]  probe8 
        .probe9(AWG_wf_addr), // input wire [9:0]  probe9 
        .probe10(AWG_wf_data), // input wire [79:0]  probe10 
        .probe11(load_done), // input wire [0:0]  probe11 
        .probe12(fsm), // input wire [5:0]  probe12 
        .probe13(AWGaddr_data_len), // input wire [31:0]  probe13 
        .probe14(CNT_addr), // input wire [15:0]  probe14 
        .probe15(byte_cnt) // input wire [31:0]  probe15
       );
end
endgenerate    
    

 
endmodule

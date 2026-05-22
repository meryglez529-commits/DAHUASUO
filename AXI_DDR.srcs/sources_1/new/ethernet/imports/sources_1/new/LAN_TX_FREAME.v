`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/12 10:34:32
// Design Name: 
// Module Name: LAN_TX_FREAME
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


module LAN_TX_FREAME(
    input                   tx_clk,
    input                   resetn,  
    
    input      [9:0]           wr_data_count,
    input                      tx_data_done,
    input                      data_en,  
    output      reg            data_req_o = 0,
    input                      data_ACK_i,
    output         [15:0]      data_wr_num_o,         //data port input
    output  reg    [7:0]       data_tx_data_o,
    output  reg                data_tx_valid_o
    );
    
    parameter NUM = 16'd20000;
    assign data_wr_num_o = NUM;
    
    reg data_ACK_r0 = 0;
    reg data_ACK_r1 = 0;
    reg data_en_r0 = 0;
    reg data_en_r1 = 0;
    always@(posedge tx_clk)
        begin
           data_ACK_r0 <= data_ACK_i;
           data_ACK_r1 <= data_ACK_r0;
           
           data_en_r0 <= data_en;
           data_en_r1 <= data_en_r0;
        end
      
    
    reg [3:0] fsm_r = 0;
    reg [15:0] byte_cnt = 0;
    reg [31:0] delay_cnt = 0;
    always@(posedge tx_clk)
        if(!resetn)
            begin
               data_req_o <= 0;
               data_tx_data_o <= 0;
               data_tx_valid_o <= 0;
               byte_cnt <= 0;
               delay_cnt <= 0;
            end
        else case(fsm_r)
            0:begin
               if(data_en_r1) //data_en_r0 && !data_en_r1
               begin
                   data_req_o <= 1'b1;
                   fsm_r <= 1; 
               end
               else
                  fsm_r <= 0;  
            end
            1:begin
                if(data_ACK_r0 && !data_ACK_r1)
                    fsm_r <= 2;
                else
                    fsm_r <= 1;
            end
            2:begin
                if(byte_cnt < NUM)
                    begin
                        if(wr_data_count < 10'd1000) begin
                            data_tx_valid_o <= 1'b1;
                            data_tx_data_o  <= data_tx_data_o + 1'b1;
                            byte_cnt <= byte_cnt + 1'b1;
                            fsm_r <= 2;
                        end
                        else
                            begin
                              data_tx_valid_o <= 1'b0;
                              data_tx_data_o  <= data_tx_data_o;
                              byte_cnt <= byte_cnt;
                              fsm_r <= 2; 
                            end
                    end
                else
                    begin
                        data_req_o <= 1'b0;
                        data_tx_valid_o <= 1'b0;
                        data_tx_data_o  <= 0;
                        byte_cnt <= 0;
                        fsm_r <= 3; 
                    end
            end
            3:begin
                if(tx_data_done)
                    begin
                        fsm_r <= 0;
//                        delay_cnt <= delay_cnt + 1'b1;
                    end
                else begin
                    fsm_r <= 3;
//                    delay_cnt <= 0;
                end
            end
            default:begin
               data_req_o <= 0;
               data_tx_data_o <= 0;
               data_tx_valid_o <= 0;
               byte_cnt <= 0;
            end
        endcase
    
endmodule

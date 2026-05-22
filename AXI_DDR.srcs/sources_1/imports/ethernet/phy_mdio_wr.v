`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/12/23 09:27:24
// Design Name: 
// Module Name: phy_mdio_wr
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


module phy_mdio_wr(
    input             clk_i,        // 10~100M
    input             rst_i,       //reset high
    input [1:0]       en_sig_i,      //01:write 10:read
    input [4:0]       addr,    //{Addr} control word
    input [15:0]      w_data_i,    //write data
    output reg [15:0] r_data_o = 0,  //read data
    output            reg done_sig_o = 0,    //write or read done
    //phy interface
    output reg sclk_o = 0,       
    output reg sdo_o = 0,              //connect to device's sdi_i
    input      sdi_i,                 //connect to device's sdo_o
    output reg tri_dir = 0,
    output reg busy = 0,
    
    output [4:0] dg_fsm_o //debug port
    );
   
   localparam phy_addr = 5'b00111;
   localparam NUM = 5'd19;      //sclk_o = clk_i/(NUM + 1)  sclk_o < 8.3MHz   
   localparam NUM_H = 5'd9;
   localparam NUM_R = 5'd7;
    
   wire [31:0] wr_cmd_word;
   assign      wr_cmd_word = {4'b0101,phy_addr,addr,2'b10,w_data_i};
   wire [13:0] rd_cmd_word;
   assign      rd_cmd_word = {4'b0110,phy_addr,addr};
   //sclk_o gen    
   reg [4:0] cnt = 5'd0;
   always@(posedge clk_i)
    if(rst_i)
        begin
            sclk_o <= 0;
            busy   <= 0;
            cnt <= 5'd0;
        end
    else if(en_sig_i == 2'b01 || en_sig_i == 2'b10)  //read and write enable sclk_o low power
        begin
            busy <= 1'b1;
            cnt <= cnt + 1'b1;
            if(cnt == NUM_H)   //rising edge
                sclk_o <= 1'b1;                                        
            else if(cnt == NUM) //falling edge
                begin cnt <= 0;sclk_o <= 1'b0;end
        end
    else 
        begin
            sclk_o <= 0;
            busy   <= 0;
            cnt <= 5'd0;
        end
         
  //w/r state
   reg [4:0]  fsm = 5'd0;
   reg [7:0]  cnt_dly = 0;//done delay wait for dec to finish
   reg [17:0] r_data_ram = 0;
   reg [4:0]  ii = 0;
    always@(posedge clk_i)
    if(rst_i)
        begin
            fsm <= 5'd0;
            sdo_o <= 1'b1;
            r_data_ram <= 0;
            r_data_o <= 0;
            done_sig_o <= 1'b0;
            cnt_dly <= 0;
            tri_dir <= 0;
            ii <= 0;
        end
    else if(en_sig_i == 2'b01)  //write
        case(fsm)
        0:begin   
            tri_dir <= 1'b1;                    
            if(cnt == NUM)
                begin fsm <= 1;sdo_o <= wr_cmd_word[31-ii];end
            else
                fsm <= 0;               
        end
        1:begin
            if(ii < 5'd31)begin
                ii <= ii + 1'b1;
                fsm <= 0;
            end
            else begin
                ii <= 0;
                fsm <= 2;
            end
        end
        2:begin
           if(cnt==NUM) 
              begin fsm <= 3;sdo_o <= 1'b1;tri_dir <= 1'b0;end
           else 
              fsm <= 2; 
        end
        3:begin
            if(cnt_dly < 8'd200)  //necessary for device to deal
                begin
                    fsm <= 3;
                    cnt_dly <= cnt_dly + 1'b1;
                    end
                else
                begin
                    fsm <= 4;
                    cnt_dly <= 0;
                end
        end    
        4:begin
            done_sig_o <= 1'b1;fsm <= 5;
        end   
        5:begin
            done_sig_o <= 1'b0;fsm <= 0;
        end 
        default:begin
            fsm <= 0;
        end                                              
        endcase
    else if(en_sig_i == 2'b10) //read
        case(fsm)           
        0:begin                       
            tri_dir <= 1'b1;                    
            if(cnt == NUM)
                begin fsm <= 1;sdo_o <= rd_cmd_word[13-ii];end
            else
                fsm <= 0;                 
        end
        1:begin
             if(ii < 5'd13)begin
                ii <= ii + 1'b1;
                fsm <= 0;
            end
            else begin
                ii <= 0;
                fsm <= 2;
            end
        end
        2:begin
           if(cnt==NUM) 
              begin fsm <= 3;sdo_o <= 1'b1;tri_dir <= 1'b0;end
           else 
              fsm <= 2; 
        end                    
        3:begin
            if(cnt==NUM_R) 
            begin fsm <= 4;r_data_ram[17-ii] <= sdi_i;end
            else 
            fsm <= 3;
        end  
        4:begin
            if(ii < 5'd17)begin
                ii <= ii + 1'b1;
                fsm <= 3;
            end
            else begin
                ii <= 0;
                fsm <= 5;
            end
        end
        5:begin
            if(cnt_dly < 8'd200)
                begin
                    fsm <= 5;
                    cnt_dly <= cnt_dly + 1'b1;
                    end
                else
                begin
                    fsm <= 6;
                    cnt_dly <= 0;
                end
        end    
        6:begin
            done_sig_o <= 1'b1;r_data_o <= r_data_ram[15:0];fsm <= 7;
        end   
        7:begin
            done_sig_o <= 1'b0;fsm <= 0;
        end     
        default:begin
            fsm <= 0;
        end                                               
        endcase                
    else
        begin
            fsm <= 5'd0;
            sdo_o <=1'b1;
            r_data_ram <= 0;
            r_data_o <= r_data_o;
            done_sig_o <= 1'b0;
            cnt_dly <= 0;
            tri_dir <= 1'b0;
        end                
                                                                                                  
 assign dg_fsm_o = fsm;                  
endmodule

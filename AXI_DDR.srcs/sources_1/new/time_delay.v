`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/20 10:01:09
// Design Name: 
// Module Name: time_delay
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
  module time_delay(
    input clk10m,
    input rstn,
    output reg rstn_fram,                       //delay 104ms
    output reg rstn_offdac,                     //delay 104ms
    output reg rstn_pll,                        //delay 104ms
    output reg rstn_adc_dac                    //delay 420ms
    );
    
  wire rstn_buf;    
  sync_module sync_module_inst0 (.data_in(rstn), .clk_in(clk10m), .data_out(rstn_buf));
  
  reg [23:0] delay1_cnt;
  always@(posedge clk10m or negedge rstn_buf) 
  begin
    if((!rstn_buf)) begin
        delay1_cnt <= 24'd0;
        rstn_fram <= 1'b0;
        rstn_offdac <= 1'b0;
        rstn_pll <= 1'b0;
    end
    else
        if (delay1_cnt[20]==0) begin
            delay1_cnt <= delay1_cnt + 1'b1;
            rstn_fram <= 1'b0;
            rstn_offdac <= 1'b0;
            rstn_pll <= 1'b0;
        end
        else begin                                      
            delay1_cnt <= delay1_cnt;
            rstn_fram <= 1'b1;
            rstn_offdac <= 1'b1;
            rstn_pll <= 1'b1;
        end
  end  
     
  reg [23:0] delay2_cnt;
  always@(posedge clk10m or negedge rstn_buf) 
  begin
    if((!rstn_buf)) begin
        delay2_cnt <= 24'd0;
        rstn_adc_dac <= 1'b0;
    end
    else
        if (delay2_cnt[22]==0) begin
            delay2_cnt <= delay2_cnt + 1'b1;
            rstn_adc_dac <= 1'b0;
        end
        else begin                                      
            delay2_cnt <= delay2_cnt;
            rstn_adc_dac <= 1'b1;
        end
  end  
    
endmodule
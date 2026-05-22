`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/12 14:04:56
// Design Name: 
// Module Name: adc_acq_sim
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
module adc_acq_sim;
reg             ui_clk;     
reg             rstn;
reg             adc_dco;
reg             rstnr;
reg             adc_tri;
reg [15:0]      row_repeat;
reg [23:0]      adc_interval;
reg [15:0]      adc_sample;
reg [15:0]      image_column;
reg [15:0]      adc_data;
reg             div_adc_rd_en;
wire [9:0]      div_adc_rd_data_count;
wire[15:0]      div_adc_out;

adcdata_acq adcdata1_acq(
    .ui_clk                 (ui_clk), 
    .rstn                   (rstn),
    .adc_tri                (adc_tri),
    .row_repeat             (row_repeat),
    .adc_interval           (adc_interval),
    .adc_sample             (adc_sample),
    .image_column           (image_column),
    .adc_dco                (adc_dco),
    .adc_data               (adc_data),
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_rd_data_count  (div_adc_rd_data_count),
    .div_adc_out            (div_adc_out)
    );
    
initial begin
ui_clk  = 0;
rstn    = 0;
adc_dco = 0;
rstnr   = 0;
#1000
rstn    = 1;
#200
rstnr   = 1;
end

always #2.5 ui_clk  = ~ui_clk;  
always #10  adc_dco = ~adc_dco; 

reg     [31:0]  cnt;
always@(posedge adc_dco or negedge rstnr)
begin
    if(!rstnr) begin
        cnt             <= 0;
        adc_tri         <= 0;
        row_repeat      <= 4;
        adc_interval    <= 20;
        adc_sample      <= 1;
        image_column    <= 100;
        adc_data        <= 0;
        div_adc_rd_en   <= 0;
    end
    else begin
        adc_data        <= cnt[15:0];
        cnt             <= cnt + 1'b1;
        if(cnt[7:0]==0)
            adc_tri     <= 1;
        else
            adc_tri     <= 0; 
    end   
end

always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn)
        div_adc_rd_en   <= 0;
    else if(div_adc_rd_data_count > 0 && div_adc_rd_en == 0)
        div_adc_rd_en   <= 1;
    else
        div_adc_rd_en   <= 0;
end  

endmodule
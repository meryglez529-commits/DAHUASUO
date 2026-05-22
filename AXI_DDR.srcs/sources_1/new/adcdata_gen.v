`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/18 09:40:08
// Design Name: 
// Module Name: adcdata_gen
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


module adcdata_gen(
    input clk,
    input rdclk,
    input rstn,
    input [7:0] fre_div_cnt,   //adc_sample
    input [7:0] scan_state,
    
    output ADC1_DCOA,
    output ADC1_DCOB,
    output ADC2_DCOA,
    output ADC2_DCOB,
    output reg adc1_data_en,    
    output reg adc2_data_en,
    output reg adc3_data_en,
    output reg adc4_data_en,
    output reg [15:0] adc1_data,
    output reg [15:0] adc2_data,
    output reg [15:0] adc3_data,
    output reg [15:0] adc4_data
    );


reg [7:0] fre_div_cnt_reg;
reg [7:0] fre_div_cnt_reg1;
reg [7:0] scan_state_reg;
reg [7:0] scan_state_reg1;
reg [7:0] js;
reg DCO_REG;

wire [8:0] adc1_rd_data_count;
wire [8:0] adc1_wr_data_count;
wire [8:0] adc2_rd_data_count;
wire [8:0] adc2_wr_data_count;
wire [8:0] adc3_rd_data_count;
wire [8:0] adc3_wr_data_count;
wire [8:0] adc4_rd_data_count;
wire [8:0] adc4_wr_data_count;

wire [15:0] adc1_dout;
wire [15:0] adc2_dout;
assign ADC1_DCOA=(fre_div_cnt_reg1==1)? clk:DCO_REG;
assign ADC1_DCOB=(fre_div_cnt_reg1==1)? clk:DCO_REG;
assign ADC2_DCOA=(fre_div_cnt_reg1==1)? clk:DCO_REG;
assign ADC2_DCOB=(fre_div_cnt_reg1==1)? clk:DCO_REG;

fifo_generator_0 adc1_fifo(
    .wr_rst(!rstn),
    .rd_rst(!rstn),
    .wr_clk(ADC1_DCOA),
    .rd_clk(rdclk),
    .din(adc1_data),
    .wr_en(adc1_data_en),
    .rd_en(1'b0),
    .dout(adc1_dout),
    .full(),
    .empty(),
    .rd_data_count(adc1_rd_data_count),
    .wr_data_count(adc1_wr_data_count)
    );

fifo_generator_0 adc2_fifo(
    .wr_rst(!rstn),
    .rd_rst(!rstn),
    .wr_clk(ADC1_DCOB),
    .rd_clk(rdclk),
    .din(adc2_data),
    .wr_en(adc2_data_en),
    .rd_en(1'b0),
    .dout(adc2_dout),
    .full(),
    .empty(),
    .rd_data_count(adc2_rd_data_count),
    .wr_data_count(adc2_wr_data_count)
    );

fifo_generator_0 adc3_fifo(
    .wr_rst(!rstn),
    .rd_rst(!rstn),
    .wr_clk(ADC2_DCOA),
    .rd_clk(rdclk),
    .din(adc3_data),
    .wr_en(adc3_data_en),
    .rd_en(),
    .dout(),
    .full(),
    .empty(),
    .rd_data_count(adc3_rd_data_count),
    .wr_data_count(adc3_wr_data_count)
    );

fifo_generator_0 adc4_fifo(
    .wr_rst(!rstn),
    .rd_rst(!rstn),
    .wr_clk(ADC2_DCOB),
    .rd_clk(rdclk),
    .din(adc4_data),
    .wr_en(adc4_data_en),
    .rd_en(),
    .dout(),
    .full(),
    .empty(),
    .rd_data_count(adc4_rd_data_count),
    .wr_data_count(adc4_wr_data_count)
    );

always@(posedge clk or posedge rstn)
    begin
        if(!rstn) 
            begin  
                scan_state_reg<=8'd0;  
                scan_state_reg1<=8'd0; 
                fre_div_cnt_reg<=8'd0;
                fre_div_cnt_reg1<=8'd0; 
            end
        else
            begin 
                scan_state_reg<=scan_state;
                scan_state_reg1<=scan_state_reg;    
                fre_div_cnt_reg<=fre_div_cnt;
                fre_div_cnt_reg1<=fre_div_cnt_reg;            
            end  
    end          
  
always@(posedge clk or posedge rstn)
    begin
        if(!rstn)
            begin
                adc1_data_en<=1'b0; 
                adc2_data_en<=1'b0; 
                adc3_data_en<=1'b0; 
                adc4_data_en<=1'b0; 
                adc1_data<=16'd0; 
                adc2_data<=16'd1; 
                adc3_data<=16'd2; 
                adc4_data<=16'd3;
                js<=8'd0;
                DCO_REG<=1'b0;
            end
        else 
            if (scan_state_reg1==1)
                if (fre_div_cnt_reg==fre_div_cnt_reg1) 
                    begin
                        adc1_data_en<=1'b1; 
                        adc2_data_en<=1'b1; 
                        adc3_data_en<=1'b1; 
                        adc4_data_en<=1'b1;
                        if (js<fre_div_cnt_reg1-1)  js<=js+1'b1; else js<=8'd0;  
                        if (js==0) 
                            begin 
                                DCO_REG<=~DCO_REG;
                                adc1_data<=adc1_data+1;
                                adc2_data<=adc2_data+1;
                                adc3_data<=adc3_data+1;
                                adc4_data<=adc4_data+1;
                            end    
                        else if (js==fre_div_cnt_reg1>>1) 
                                begin
                                    DCO_REG<=~DCO_REG;
                                    adc1_data<=adc1_data;
                                    adc2_data<=adc2_data;
                                    adc3_data<=adc3_data;
                                    adc4_data<=adc4_data;
                                end 
                             else  
                                begin 
                                    DCO_REG<=DCO_REG;
                                    adc1_data<=adc1_data;
                                    adc2_data<=adc2_data;
                                    adc3_data<=adc3_data;
                                    adc4_data<=adc4_data;
                                end                  
                    end
                else
                    begin
                        adc1_data_en<=1'b0; 
                        adc2_data_en<=1'b0; 
                        adc3_data_en<=1'b0; 
                        adc4_data_en<=1'b0; 
                        adc1_data<=16'd0; 
                        adc2_data<=16'd1; 
                        adc3_data<=16'd2; 
                        adc4_data<=16'd3;
                        js<=8'd0;
                        DCO_REG<=1'b0;
                    end
            else
               begin
                   adc1_data_en<=1'b0; 
                   adc2_data_en<=1'b0; 
                   adc3_data_en<=1'b0; 
                   adc4_data_en<=1'b0; 
                   adc1_data<=16'd0; 
                   adc2_data<=16'd1; 
                   adc3_data<=16'd2; 
                   adc4_data<=16'd3;
                   js<=8'd0;
                   DCO_REG<=1'b0;
                end                      
    end  
endmodule
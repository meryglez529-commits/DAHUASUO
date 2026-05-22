`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/29 13:53:05
// Design Name: 
// Module Name: AD9747_cfg
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

//////////////////////////////////////////////////////////////////////////////////
  module ad9747_cfg(
    input clk10m,
    input rstn,
    input dacx_gain,
    input dacy_gain,
    input  dac_sdo,
    output dac_sclk,
    output dac_sdio,
    output dac_csb,
    output dac_reset
    );
  assign dac_reset=1'b0;
/////////////////////////////////////////////////////////////////////////////////
  localparam wrrom1   = {2'hf,1'b0,2'd0,5'h00,8'h20,2'hf};//soft reset	
  localparam wrrom2   = {2'hf,1'b0,2'd0,5'h00,8'h00,2'hf};//spi 4 wire mode(default)
  localparam wrrom3   = {2'hf,1'b0,2'd0,5'h02,8'h80,2'hf};//80unsigned binary format, 00twos complement binary format                  normal dual port
  localparam wrrom4A  = {2'hf,1'b0,2'd0,5'h0B,8'hAC,2'hf};//DAC1=12.5mA(172)
  localparam wrrom5A  = {2'hf,1'b0,2'd0,5'h0C,8'h00,2'hf};//
  localparam wrrom6A  = {2'hf,1'b0,2'd0,5'h0F,8'hAC,2'hf};//DAC2=12.5mA(172)
  localparam wrrom7A  = {2'hf,1'b0,2'd0,5'h10,8'h00,2'hf};//
  localparam wrrom4B  = {2'hf,1'b0,2'd0,5'h0B,8'hD7,2'hf};//DAC1=25mA(727)
  localparam wrrom5B  = {2'hf,1'b0,2'd0,5'h0C,8'h02,2'hf};//
  localparam wrrom6B  = {2'hf,1'b0,2'd0,5'h0F,8'hD7,2'hf};//DAC2=25mA(727)
  localparam wrrom7B  = {2'hf,1'b0,2'd0,5'h10,8'h02,2'hf};//
  wire  [19:0] wrrom4;
  wire  [19:0] wrrom5;
  wire  [19:0] wrrom6;
  wire  [19:0] wrrom7;
  reg   [2:0] dacx_gain_reg;
  reg   [2:0] dacy_gain_reg;
  assign wrrom4=(dacx_gain_reg[2])? wrrom4B : wrrom4A;
  assign wrrom5=(dacx_gain_reg[2])? wrrom5B : wrrom5A;
  assign wrrom6=(dacy_gain_reg[2])? wrrom6B : wrrom6A;
  assign wrrom7=(dacy_gain_reg[2])? wrrom7B : wrrom7A;
//////////////////////////////////////////////////////////////////////////////////////
  always@(posedge clk10m or negedge rstn) 
  begin
	if(!rstn) begin
		dacx_gain_reg <= 3'b111;
		dacy_gain_reg <= 3'b111;
    end
	else begin
        dacx_gain_reg <= {dacx_gain_reg[1:0],dacx_gain};
        dacy_gain_reg <= {dacy_gain_reg[1:0],dacy_gain};
    end
  end
  
  reg [8:0] cntr;
  reg [19:0] data_reg;
  reg [19:0] csn_reg;
  always@(posedge clk10m or negedge rstn) 
  begin
	if(!rstn) 
		cntr <= 9'h0;
	else
        if(cntr<9'h12A)
            if(cntr[4:0] < 20) 
                begin cntr[8:5] <= cntr[8:5]; cntr[4:0] <= cntr[4:0] + 1'b1;end
            else 
                begin cntr[8:5] <= cntr[8:5]+1'b1; cntr[4:0] <= 5'd0; end
        else
            if ((dacx_gain_reg[1] != dacx_gain_reg[2]) || (dacy_gain_reg[1] != dacy_gain_reg[2]))
                cntr <= 9'h0A0;    
            else
                cntr <= 9'h12A; 
  end

  always@(posedge clk10m or negedge rstn) 
  begin
	if(!rstn) 
		begin data_reg <= -1; csn_reg  <= -1; end 
	else if(cntr[4:0] == 5'd10)
		begin 
			case(cntr[8:5])
				4'd1:       begin data_reg <= wrrom1; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd2,4'd3:  begin data_reg <= wrrom2; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd4:       begin data_reg <= wrrom3; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd5:       begin data_reg <= wrrom4; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd6:       begin data_reg <= wrrom5; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd7:       begin data_reg <= wrrom6; csn_reg  <= {2'hf,16'd0,2'hf}; end
				4'd8:       begin data_reg <= wrrom7; csn_reg  <= {2'hf,16'd0,2'hf}; end																																															
				default:    begin data_reg <= -1; csn_reg <= -1; end
			endcase
		end
    else
		begin data_reg <= {data_reg[18:0],1'b1}; csn_reg <= {csn_reg[18:0],1'b1}; end
  end

  assign dac_sclk  = (cntr < 9'h12A) ?  ( ~clk10m) : (1'b1);
  assign dac_sdio  =  data_reg[19];
  assign dac_csb =  csn_reg[19];
endmodule
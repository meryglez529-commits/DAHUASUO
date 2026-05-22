`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/28 10:31:24
// Design Name: 
// Module Name: ad9517_cfg
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
  module ad9517_cfg(
    input  clk10m,
    input  rstn,
    input  clk_sel,
    input  pll_ld,
    input  pll_sdo,
    output pll_csn,
    output pll_sclk,
    output pll_sdio,
    output pll_ref_sel,
    output pll_resetn
    );  
assign pll_resetn=1'b1;
assign pll_ref_sel=1'b0;
/////////////////////////////////////////////////////////////////////////////////
localparam wrrom1  = {4'hf,1'b0,2'd0,13'h0000,8'h3c,4'hf};//soft reset	
localparam wrrom2  = {4'hf,1'b0,2'd0,13'h0000,8'h99,4'hf};//sdo active
localparam wrrom3  = {4'hf,1'b0,2'd0,13'h0004,8'h01,4'hf};//read active registers
localparam wrrom4  = {4'hf,1'b0,2'd0,13'h0010,8'h7E,4'hf};//PLL normal operation
localparam wrrom5  = {4'hf,1'b0,2'd0,13'h0011,8'h10,4'hf};//R=16
localparam wrrom6  = {4'hf,1'b0,2'd0,13'h0014,8'h0F,4'hf};//B=15
localparam wrrom7  = {4'hf,1'b0,2'd0,13'h0013,8'h00,4'hf};//A=0
localparam wrrom8  = {4'hf,1'b0,2'd0,13'h0016,8'h06,4'hf};//P=32
localparam wrrom9A  = {4'hf,1'b0,2'd0,13'h001C,8'h02,4'hf};//02-single ref1 on
localparam wrrom9B  = {4'hf,1'b0,2'd0,13'h001C,8'h44,4'hf};//02-single ref2 on

localparam wrrom10 = {4'hf,1'b0,2'd0,13'h00F0,8'h08,4'hf};//OUT0 total power on-------
localparam wrrom11 = {4'hf,1'b0,2'd0,13'h00F1,8'h0B,4'hf};//OUT1 total power down
localparam wrrom12 = {4'hf,1'b0,2'd0,13'h00F4,8'h08,4'hf};//OUT2 total power on-----
localparam wrrom13 = {4'hf,1'b0,2'd0,13'h00F5,8'h0B,4'hf};//OUT3 total power down
localparam wrrom14 = {4'hf,1'b0,2'd0,13'h0140,8'h42,4'hf};//OUT4 LVDS output
localparam wrrom15 = {4'hf,1'b0,2'd0,13'h0141,8'h42,4'hf};//OUT5 LVDS output
localparam wrrom16 = {4'hf,1'b0,2'd0,13'h0142,8'h42,4'hf};//OUT6 LVDS output
localparam wrrom17 = {4'hf,1'b0,2'd0,13'h0143,8'h4A,4'hf};//OUT7A CMOS output,OUTB shut down

localparam wrrom18 = {4'hf,1'b0,2'd0,13'h001D,8'h00,4'hf};//
localparam wrrom19 = {4'hf,1'b0,2'd0,13'h0018,8'h06,4'hf};//VCO calibration   //PFD frequencies < 25 MHz
localparam wrrom20 = {4'hf,1'b0,2'd0,13'h0232,8'h01,4'hf};//update registers 
localparam wrrom21 = {4'hf,1'b0,2'd0,13'h0018,8'h07,4'hf};//VCO calibration	
localparam wrrom22 = {4'hf,1'b0,2'd0,13'h01e0,8'h01,4'hf};//VCO = 1500,VCO divider =3	  
localparam wrrom23 = {4'hf,1'b0,2'd0,13'h01e1,8'h02,4'hf};//select VCO as input

localparam wrrom24 = {4'hf,1'b0,2'd0,13'h0190,8'h11,4'hf};//divide0  500/4=125M  
localparam wrrom25 = {4'hf,1'b0,2'd0,13'h0191,8'h00,4'hf};//divide0 enable
localparam wrrom26 = {4'hf,1'b0,2'd0,13'h0196,8'h11,4'hf};//divide1  500/4=125M
localparam wrrom27 = {4'hf,1'b0,2'd0,13'h0197,8'h00,4'hf};//divide1 enable

localparam wrrom28 = {4'hf,1'b0,2'd0,13'h0199,8'h44,4'hf};//divide2.1  500/10=50
localparam wrrom29 = {4'hf,1'b0,2'd0,13'h019C,8'h20,4'hf};//divide2.2  bypass
localparam wrrom30 = {4'hf,1'b0,2'd0,13'h019E,8'h44,4'hf};//divide3.1  800/16=50
localparam wrrom31 = {4'hf,1'b0,2'd0,13'h01A1,8'h20,4'hf};//divide3.2  bypass
localparam wrrom32 = {4'hf,1'b0,2'd0,13'h0232,8'h01,4'hf};//update registers
 
//////////////////////////////////////////////////////////////////////////////////////
reg [15:0] cntr;
reg [31:0] data_reg;
reg [31:0] csn_reg;
reg [2:0]  clk_sel_reg;
wire [31:0] wrrom9;
assign wrrom9 = (clk_sel_reg[2])? wrrom9B:wrrom9A;

always@(posedge clk10m or negedge rstn) 
begin
	if((!rstn)) 
		clk_sel_reg <= 3'b0;     //0ref1£ºFPGA_50M//1ref2:50Hz
	else
		clk_sel_reg <= {clk_sel_reg[1:0],clk_sel};
end

always@(posedge clk10m or negedge rstn) 
begin
	if((!rstn)) 
		cntr <= 16'h0;
	else 
        if(cntr < 16'h0470) 
            cntr <= cntr + 16'd1;
        else
            if (clk_sel_reg[2] != clk_sel_reg[1])
                cntr <= 16'h0;
            else
                cntr <= 16'h0470;  
end

always@(posedge clk10m or negedge rstn) 
begin
	if(!rstn) 
		begin 
			data_reg <= -1;
			csn_reg  <= -1;
		end 
	else if(cntr[4:0] == 5'd16)
		begin 
			case(cntr[10:5])
				6'd1:
				begin
					data_reg <= wrrom1;
					csn_reg  <= {4'hf,24'd0,4'hf};
				end
				6'd2, 6'd3, 6'd4:
				begin
					data_reg <= wrrom2;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd5:
				begin
					data_reg <= wrrom3;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd6:
				begin
					data_reg <= wrrom4;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd7:
				begin
					data_reg <= wrrom5;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd8:
				begin
					data_reg <= wrrom6;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd9:
				begin
					data_reg <= wrrom7;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd10:
				begin
					data_reg <= wrrom8;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd11:
				begin
					data_reg <= wrrom9;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd12:
				begin
					data_reg <= wrrom10;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd13:
				begin
					data_reg <= wrrom11;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd14:
				begin
					data_reg <= wrrom12;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				5'd15:
				begin
					data_reg <= wrrom13;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd16:
				begin
					data_reg <= wrrom14;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd17:
				begin
					data_reg <= wrrom15;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd18:
				begin
					data_reg <= wrrom16;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd19:
				begin
					data_reg <= wrrom17;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd20:
				begin
					data_reg <= wrrom18;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd21:
				begin
					data_reg <= wrrom19;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd22:
				begin
					data_reg <= wrrom20;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd23:
				begin
					data_reg <= wrrom21;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd24:
				begin
					data_reg <= wrrom22;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd25:
				begin
					data_reg <= wrrom23;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd26:
				begin
					data_reg <= wrrom24;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd27:
				begin
					data_reg <= wrrom25;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd28:
				begin
					data_reg <= wrrom26;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end
				6'd29:
				begin
					data_reg <= wrrom27;
					csn_reg  <= {4'hf,24'd0,4'hf};				
				end	
				6'd30:
                begin
                    data_reg <= wrrom28;
                    csn_reg  <= {4'hf,24'd0,4'hf};                
                end    				
				6'd31:
                begin
                    data_reg <= wrrom29;
                    csn_reg  <= {4'hf,24'd0,4'hf};                
                end    				
				6'd32:
                begin
                    data_reg <= wrrom30;
                    csn_reg  <= {4'hf,24'd0,4'hf};                
                end    				
				6'd33:
                begin
                    data_reg <= wrrom31;
                    csn_reg  <= {4'hf,24'd0,4'hf};                
                end    				
				6'd34:
                begin
                    data_reg <= wrrom32;
                    csn_reg  <= {4'hf,24'd0,4'hf};                
                end  																																															
				default:
				begin
					data_reg <= -1;//{data_reg[30:0],1'b1};
					csn_reg <= -1;//{csn_reg[30:0],1'b1};
				end
			endcase
		end
		else
		begin
			data_reg <= {data_reg[30:0],1'b1};
			csn_reg <= {csn_reg[30:0],1'b1};
		end
end

assign pll_sclk  = (cntr < 16'h0470) ?  ( ~clk10m) : (1'b1);
assign pll_sdio  =  data_reg[31];
assign pll_csn =  csn_reg[31];

endmodule
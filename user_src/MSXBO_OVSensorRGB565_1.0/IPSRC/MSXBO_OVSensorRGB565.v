
`timescale 1ns / 1ps
// Company: cz123 milinker
// Engineer: tjy
// bbs:http://www.osrc.cn
// taobao:http://osrc.taobao.com
// Create Date: 2019/02/27 22:09:55
// Design Name: MSXBO_OVSensorRGB565
// Module Name: MSXBO_OVSensorRGB565
// Project Name: MSXBO_OVSensorRGB565
// Copyright: msxbo Copyright (c) 2019
// Revision 0.01 - File Created
// Additional Comments: decode ov sensor RGB565 to rgb 888
// 


module MSXBO_OVSensorRGB565(
	input cmos_clk_i,//cmos senseor clock.
	input rst_n_i,//system reset.active low.
	input cmos_pclk_i,//input pixel clock.
	input cmos_href_i,//input pixel hs signal.
	input cmos_vsync_i,//input pixel vs signal.
	input [7:0]cmos_data_i,//data.
	output cmos_xclk_o,//output clock to cmos sensor.
    output [31:0] rgb_o,
    output de_o,
    output vs_o,
    output hs_o
    );
    
assign cmos_xclk_o = cmos_clk_i;    
parameter[3:0]CMOS_FRAME_WAITCNT = 4'd15;    
reg[4:0] rst_n_reg = 5'd0;    
reg cmos_href_r;
reg cmos_vsync_r;
reg [7:0]cmos_data_r;
    
always@(posedge cmos_pclk_i)
begin
       cmos_data_r <= cmos_data_i;
       cmos_href_r <= cmos_href_i;
       cmos_vsync_r<= ~cmos_vsync_i;
end    
    
//reset signal deal with.
always@(posedge cmos_clk_i)
begin
	rst_n_reg <= {rst_n_reg[3:0],rst_n_i};
end

reg[1:0]vsync_d;
reg[1:0]href_d;
wire vsync_start;
wire vsync_end;
//vs signal deal with.
always@(posedge cmos_pclk_i)
begin
	vsync_d <= {vsync_d[0],cmos_vsync_r};
	href_d  <= {href_d[0],cmos_href_r};
end

assign vsync_end  =  vsync_d[1]&(!vsync_d[0]);
assign vsync_start  = (!vsync_d[1])&vsync_d[0];

reg[6:0]cmos_fps;
//frame count.
always@(posedge cmos_pclk_i)
begin
	if(!rst_n_reg[4])
		begin
		cmos_fps <= 7'd0;
		end
	else if(vsync_start)
		begin
		cmos_fps <= cmos_fps + 7'd1;
		end
	else if(cmos_fps >= CMOS_FRAME_WAITCNT)
		begin
		cmos_fps <= CMOS_FRAME_WAITCNT;
		end
end
//wait frames and output enable.
reg out_en;
always@(posedge cmos_pclk_i)
begin
	if(!rst_n_reg[4])
		begin
		out_en <= 1'b0;
		end
	else if(cmos_fps >= CMOS_FRAME_WAITCNT)
		begin
		out_en <= 1'b1;
		end
	else
		begin
		out_en <= out_en;
		end
end

//output data 8bit changed into 16bit in rgb565.
reg href_cnt   = 1'b0;
reg data_en  = 1'b0;
reg [15:0]rgb2 = 32'd0;
reg de_r       = 1'b0;
always@(posedge cmos_pclk_i)
begin
	if(!rst_n_reg[4])begin
	   href_cnt  <= 1'd0;
	   data_en <= 1'b0;
	   rgb2      <= 16'd0;
	   de_r      <= 1'b0;
	end	
	else begin
	   href_cnt  <= cmos_href_r ?  href_cnt + 1'b1 : 1'b0 ;
       data_en   <= (href_cnt==1'd1);
       //de_r <= data64_en;
       if(cmos_href_r) begin
            rgb2 <= {rgb2[7:0],cmos_data_r};
       end    
	end	
end

/*
reg [7:0]cnt_test;
reg [8:0]cnt_temp;

reg [11:0]vcounter;
reg [15:0]vcnt=10'd0;
always@(posedge cmos_pclk_i) begin
if(!rst_n_reg[4]) begin
    vcnt<=16'd0;
end else begin
    if(vsync_start) 
            vcounter <=12'd0;
            if(!vcnt[15])vcnt <= vcnt+1'b1;
     else if({href_d[0],cmos_href_r}==2'b01)
             vcounter <= vcounter + 12'd1;
 end
end

reg [11:0]hcounter;
always@(posedge cmos_pclk_i) begin
  if(!cmos_href_r) 
    hcounter <=12'd0;
  else 
    hcounter <= hcounter + 12'd1;
end

reg[7:0]	grid_data_1;
reg[7:0]	grid_data_2;
always @(posedge cmos_pclk_i)//¸ñ×ÓÍ¼Ïñ
begin
	if((hcounter[2]==1'b1)^(vcounter[4]==1'b1))
	grid_data_1	<=	8'h00;
	else
	grid_data_1	<=	8'hff;
	
	if((hcounter[6]==1'b1)^(vcounter[6]==1'b1))
	grid_data_2	<=	8'h00;
	else
	grid_data_2	<=	8'hff;
end
assign  rgb_o  = {8'd0,grid_data_2 ,grid_data_2 ,grid_data_2};
//assign  rgb_o  = {8'd0,8'd0,8'd0,hcounter[7:0]};
*/


assign  rgb_o  = {8'd0,{rgb2[15:11],3'd0 ,rgb2[10:5] ,2'd0,rgb2[4:0],3'd0}};

assign	de_o   = out_en ? data_en      : 1'b0;
assign	vs_o   = out_en ? cmos_vsync_r : 1'b0;
assign	hs_o   = out_en ? cmos_href_r  : 1'b0;

endmodule

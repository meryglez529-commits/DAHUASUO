`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/01 11:15:07
// Design Name: 
// Module Name: step_module
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
module step_module(
    input                   clk,
    input                   rst,
    input                   cal_en,
    input       [15:0]      point,
    input       [15:0]      strat_level,
    input       [15:0]      end_level,
    output  reg [63:0]      step_o
    );

wire [15:0] pp_level;
assign       pp_level = end_level - strat_level; 
reg         cal_en_r;
always@(posedge clk or posedge rst)
begin
    if(rst)
        cal_en_r <= 1'b0;
    else
        cal_en_r <= cal_en;    
end
 
wire        step_en;
wire [79:0] step_o_r;  
always@(posedge clk or posedge rst)
begin
    if(rst)
        step_o <= 0;
    else if(step_en==1)
        step_o <= step_o_r[79:16];
    else
        step_o <= step_o;
end

div_gen_1 dax_step_div ( 
    .aclk                   (   clk        ),
    .aresetn                (   ~rst       ),
    .s_axis_divisor_tvalid  (   cal_en_r   ),                       //³ýÊý16bit
    .s_axis_divisor_tdata   (   point-1'b1 ),
    .s_axis_dividend_tvalid (   cal_en_r   ),
    .s_axis_dividend_tdata  (   {pp_level,48'd0}  ),               //±»³ýÊý16bit
    .m_axis_dout_tvalid     (   step_en    ),
    .m_axis_dout_tdata      (   step_o_r   )
    ); 
endmodule

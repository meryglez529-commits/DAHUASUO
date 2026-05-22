`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/04/26 09:52:50
// Design Name: 
// Module Name: sync_module
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
module sync_module(
	input data_in,
	input clk_in,
	
	output data_out
	);
	
	// wire and register declaraion
	reg [2:0] data_in_r;
	
//----------------------------main programme begin here-------------------------------------//


always @(posedge clk_in)
begin
	data_in_r	<= {data_in_r[1:0],data_in};
end

assign data_out = data_in_r[2];


endmodule

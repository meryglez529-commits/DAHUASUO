`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/12 08:51:14
// Design Name: 
// Module Name: async_reg
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


module async_reg(
            input [31:0]  datain,
            
            input         clk,
            input         clk_en,
            output [31:0] dataout
    );
    
 FDPE #(
      .INIT(32'h0000_0000) // Initial value of register (1'b0 or 1'b1)
   ) FDPE_inst[31:0] (
      .Q(dataout),      // 1-bit Data output
      .C(clk),      // 1-bit Clock input
      .CE(clk_en),    // 1-bit Clock enable input
      .PRE(datain),  // 1-bit Asynchronous preset input
      .D(32'h0000_0000)       // 1-bit Data input
   );    
    
    
    
    
    
endmodule

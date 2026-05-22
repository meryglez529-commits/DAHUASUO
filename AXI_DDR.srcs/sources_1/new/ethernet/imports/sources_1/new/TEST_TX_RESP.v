`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/11 13:19:21
// Design Name: 
// Module Name: TEST_TX_RESP
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


module TEST_TX_RESP(
    input               tx_fifo_clock,
    input               reset_n,
    
    input      [15:0]   LAN_DATA_NUM_i,
    input      [3:0]    LAN_RX_TYPE_i,     //receive type sel
	input               lan_data_valid_i,   //byte data valid
	input      [7:0]    lan_data_i,    //byte data
        
    output  reg    [15:0]   LAN_DATA_NUM_o = 0,
	output  reg             lan_data_valid_o = 0,   //byte data valid
	output  reg    [7:0]    lan_data_out_o = 0    //byte data   
    );
    
    always@(posedge tx_fifo_clock)
        if(!reset_n)
            begin
               LAN_DATA_NUM_o   <= 0; 
               lan_data_valid_o <= 0; 
               lan_data_out_o   <= 0; 
            end
        else if(LAN_RX_TYPE_i == 4'd1 && lan_data_valid_i)
            begin
               LAN_DATA_NUM_o   <= LAN_DATA_NUM_i; 
               lan_data_valid_o <= lan_data_valid_i; 
               lan_data_out_o   <= lan_data_i; 
            end
        else begin
               LAN_DATA_NUM_o   <= LAN_DATA_NUM_o; 
               lan_data_valid_o <= 0; 
               lan_data_out_o   <= 0;
        end
    
endmodule

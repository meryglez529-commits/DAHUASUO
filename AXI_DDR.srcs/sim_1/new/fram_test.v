`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/13 11:11:54
// Design Name: 
// Module Name: fram_test
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
module fram_test;
    reg           eth_clk;
    reg           eth_rstn;
    reg           dac_dco;
    reg [15:0]    row_repeat;
    reg [15:0]    dac_sample;
    reg [15:0]    image_row;
    reg [15:0]    dacx_strat_level;
    reg [15:0]    dacx_step;
    reg [15:0]    dacx_tk_point;
    reg [15:0]    dacx_recovery_time;
    reg [15:0]    dacy_strat_level;
    reg [15:0]    dacy_step;
    reg [31:0]    frame_waiting_time;
    reg [31:0]    dax_fall_time;
    reg [3:0]     scan_mode;
    reg           scan_state;
    reg [15:0]    row_m;
    reg [15:0]    row_n;

    wire          adc_tri;
    wire [15:0]   DAX_DATA;
    wire [15:0]   DAY_DATA;
    
dacdata_config dacdata_config_inst(
    .eth_clk                 (eth_clk),
    .eth_rstn                (eth_rstn), 
    .dac_dco                 (dac_dco),
    .row_repeat              (row_repeat),
    .dac_sample              (dac_sample),
    .image_row               (image_row),
    .dacx_strat_level        (dacx_strat_level),
    .dacx_step               (dacx_step),
    .dacx_tk_point           (dacx_tk_point),
    .dacx_recovery_time      (dacx_recovery_time),
    .dacy_strat_level        (dacy_strat_level),
    .dacy_step               (dacy_step),
    .frame_waiting_time      (frame_waiting_time),
    .dax_fall_time           (dax_fall_time),
    .scan_mode               (scan_mode),
    .scan_state              (scan_state),
    .row_m                   (row_m),
    .row_n                   (row_n), 
    
    .adc_tri                 (adc_tri),
    .DAX_DATA                (DAX_DATA),
    .DAY_DATA                (DAY_DATA)
    );

initial begin
eth_clk = 0;
eth_rstn = 0;
dac_dco = 0;

# 1000
eth_rstn = 1;
end

always #4 eth_clk  = ~eth_clk;  
always #10 dac_dco = ~dac_dco;  

reg [31:0] state;
always@(posedge eth_clk or negedge eth_rstn)
begin
    if(!eth_rstn) begin 
        state               <= 0;
        row_repeat          <= 2;
        dac_sample          <= 1;
        image_row           <= 30;
        dacx_strat_level    <= 1000;
        dacx_step           <= 100;
        dacx_tk_point       <= 9;
        dacx_recovery_time  <= 1;
        dacy_strat_level    <= 1;
        dacy_step           <= 1;
        frame_waiting_time  <= 200;
        dax_fall_time       <= 1;
        scan_mode           <= 1;
        scan_state          <= 0;
        row_m               <= 1;
        row_n               <= 1;
    end
    else begin
        state   <= state + 1'b1;
        if(state ==100) 
            scan_state <= 1'b1;
        else
            scan_state <= scan_state;   
    end
end  
    
endmodule
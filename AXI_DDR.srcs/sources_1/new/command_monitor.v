`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 15:21:19
// Design Name: 
// Module Name: command_monitor
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


module command_monitor(
    input [0:0] clk,
    input [0:0] bram_rst,
    input [0:0] bram_en,
    input [3:0] bram_we,
    input [11:0] bram_addr,
    input [31:0] bram_wrdata,
    output reg [31:0] bram_rddata,
    output wire [1:0] clk_sel,
    output wire [7:0] dac_clk,
    output wire [7:0] adc_clk,
    output wire [7:0] dac_sample,
    output wire [7:0] adc_sample,
    output wire [7:0] dac_synclk,
    output wire [7:0] adc1_gain,
    output wire [7:0] adc2_gain,
    output wire [7:0] adc3_gain,
    output wire [7:0] adc4_gain,
    output wire [7:0] dacx_gain,
    output wire [7:0] dacy_gain,
    output wire [15:0] dacx_strat_level,
    output wire [15:0] dacx_end_level,
    output wire [15:0] dacx_tk_point,
    output wire [15:0] dacx_recovery_time,
    output wire [15:0] dacy_strat_level,
    output wire [15:0] dacy_end_level,
    output wire [15:0] dacy_step,
    output wire [7:0]  scan_state
    );
   
    reg bram_en_reg;   
    reg [1:0] clk_sel_reg;
    reg [7:0] dac_clk_reg;
    reg [7:0] adc_clk_reg;
    reg [7:0] dac_sample_reg;
    reg [7:0] adc_sample_reg;
    reg [7:0] dac_synclk_reg;
    reg [7:0] adc1_gain_reg;
    reg [7:0] adc2_gain_reg;
    reg [7:0] adc3_gain_reg;
    reg [7:0] adc4_gain_reg;
    reg [7:0] dacx_gain_reg;
    reg [7:0] dacy_gain_reg;
    reg [15:0] dacx_strat_level_reg;
    reg [15:0] dacx_end_level_reg;
    reg [15:0] dacx_tk_point_reg;
    reg [15:0] dacx_recovery_time_reg;
    reg [15:0] dacy_strat_level_reg;
    reg [15:0] dacy_end_level_reg;
    reg [15:0] dacy_step_reg;
    reg [7:0]  scan_state_reg;   
    reg [15:0] version_number=0; 
    assign clk_sel = clk_sel_reg;
    assign dac_clk = dac_clk_reg;
    assign adc_clk = adc_clk_reg;
    assign dac_sample = dac_sample_reg;
    assign adc_sample = adc_sample_reg;
    assign dac_synclk = dac_synclk_reg;
    assign adc1_gain = adc1_gain_reg;
    assign adc2_gain = adc2_gain_reg;
    assign adc3_gain = adc3_gain_reg;
    assign adc4_gain = adc4_gain_reg;
    assign dacx_gain = dacx_gain_reg;
    assign dacy_gain = dacy_gain_reg;
    assign dacx_strat_level = dacx_strat_level_reg;
    assign dacx_end_level = dacx_end_level_reg;
    assign dacx_tk_point = dacx_tk_point_reg;
    assign dacx_recovery_time = dacx_recovery_time_reg;
    assign dacy_strat_level = dacy_strat_level_reg;
    assign dacy_end_level = dacy_end_level_reg;
    assign dacy_step = dacy_step_reg;
    assign scan_state = scan_state_reg;     
  
  
  
   
always@(posedge clk or posedge bram_rst)
    begin
        if(bram_rst)
            bram_en_reg<=1'b0; 
        else 
            bram_en_reg <= bram_en;   
    end
    
always@(posedge clk or posedge bram_rst)
    begin
        if(bram_rst)
            begin
                clk_sel_reg<=2'b0;
                dac_clk_reg<=8'b0;
                adc_clk_reg<=8'b0;
                dac_sample_reg<=8'b0;
                adc_sample_reg<=8'b0;
                dac_synclk_reg<=8'b0;
                adc1_gain_reg<=8'b0;
                adc2_gain_reg<=8'b0;
                adc3_gain_reg<=8'b0;
                adc4_gain_reg<=8'b0;
                dacx_gain_reg<=8'b0;
                dacy_gain_reg<=8'b0;
                dacx_strat_level_reg<=16'b0;
                dacx_end_level_reg<=16'b0;
                dacx_tk_point_reg<=16'b0;
                dacx_recovery_time_reg<=16'b0;
                dacy_strat_level_reg<=16'b0;
                dacy_end_level_reg<=16'b0;
                dacy_step_reg<=16'b0;
                scan_state_reg<=8'b0;
            end
        else if (bram_en_reg==0 && bram_en==1)
                if (bram_we[0]==1)      //write
                    case (bram_addr[5:0])                               
                        6'h00: begin clk_sel_reg <= bram_wrdata[1:0]; end
                        6'h04: begin dac_clk_reg <= bram_wrdata[31:24];
                                     dac_sample_reg <= bram_wrdata[23:16];
                                     adc_clk_reg <= bram_wrdata[15:8];
                                     adc_sample_reg <= bram_wrdata[7:0]; end
                        6'h08: begin dac_synclk_reg <= bram_wrdata[7:0]; end
                        6'h0C: begin adc1_gain_reg <= bram_wrdata[7:0];
                                     adc2_gain_reg <= bram_wrdata[15:8];
                                     adc3_gain_reg <= bram_wrdata[23:16];
                                     adc4_gain_reg <= bram_wrdata[31:24]; end
                        6'h14: begin dacx_strat_level_reg <= bram_wrdata[31:16];
                                     dacx_end_level_reg <= bram_wrdata[15:0]; end
                        6'h18: begin dacx_tk_point_reg <= bram_wrdata[31:16];
                                     dacx_recovery_time_reg <= bram_wrdata[15:0]; end
                        6'h1C: begin dacy_strat_level_reg <= bram_wrdata[31:16];
                                     dacy_end_level_reg <= bram_wrdata[15:0]; end
                        6'h20: begin dacy_step_reg <= bram_wrdata[15:0]; end
                        6'h24: begin scan_state_reg <= bram_wrdata[7:0]; end
                        default;
                    endcase    
                else  //read
                    case (bram_addr[5:0])                               
                        6'h00: begin bram_rddata <= {30'b0, clk_sel_reg}; end
                        6'h04: begin bram_rddata <= {dac_clk_reg, dac_sample_reg, adc_clk_reg, adc_sample_reg}; end
                        6'h08: begin bram_rddata <= {24'b0, dac_synclk_reg}; end
                        6'h0C: begin bram_rddata <= {adc4_gain_reg, adc3_gain_reg, adc2_gain_reg, adc1_gain_reg}; end
                        6'h14: begin bram_rddata <= {dacx_strat_level_reg, dacx_end_level_reg}; end
                        6'h18: begin bram_rddata <= {dacx_tk_point_reg, dacx_recovery_time_reg}; end
                        6'h1C: begin bram_rddata <= {dacy_strat_level_reg, dacy_end_level_reg}; end
                        6'h20: begin bram_rddata <= {16'b0,dacy_step_reg}; end
                        6'h24: begin bram_rddata <= {24'b0,scan_state_reg}; end
                        6'h28: begin bram_rddata <= {16'b0,version_number}; end
                        default;
                    endcase 
    end    
   
endmodule

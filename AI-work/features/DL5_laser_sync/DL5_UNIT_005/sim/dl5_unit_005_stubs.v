`timescale 1ns / 1ps

module sync_module(
    input  data_in,
    input  clk_in,
    output reg data_out
);
initial data_out = 1'b0;
always @(posedge clk_in) begin
    data_out <= data_in;
end
endmodule

module div_gen_0(
    input         aclk,
    input         aresetn,
    input         s_axis_divisor_tvalid,
    input  [31:0] s_axis_divisor_tdata,
    input         s_axis_dividend_tvalid,
    input  [39:0] s_axis_dividend_tdata,
    output reg    m_axis_dout_tvalid,
    output reg [63:0] m_axis_dout_tdata
);
always @(posedge aclk) begin
    if (!aresetn) begin
        m_axis_dout_tvalid <= 1'b0;
        m_axis_dout_tdata  <= 64'd0;
    end else begin
        m_axis_dout_tvalid <= s_axis_dividend_tvalid;
        if (s_axis_dividend_tvalid && s_axis_divisor_tvalid && s_axis_divisor_tdata != 0)
            m_axis_dout_tdata <= s_axis_dividend_tdata / s_axis_divisor_tdata;
        else
            m_axis_dout_tdata <= 64'd0;
    end
end
endmodule

module fifo_generator_1(
    input         rst,
    input         rd_clk,
    input         wr_clk,
    input  [15:0] din,
    input         wr_en,
    input         rd_en,
    output [15:0] dout,
    output        empty
);
assign dout  = 16'd0;
assign empty = 1'b1;
endmodule

module row_repeat_module(
    input         ui_clk,
    input         rstn,
    input  [15:0] row_repeat,
    input  [15:0] image_column,
    output        fifo1_rd_en,
    input  [15:0] fifo1_dout,
    input         fifo1_empty,
    input         div_adc_rd_en,
    output [15:0] div_adc_out,
    output [9:0]  div_adc_rd_data_count
);
assign fifo1_rd_en          = 1'b0;
assign div_adc_out          = 16'd0;
assign div_adc_rd_data_count = 10'd0;
endmodule

module ila_12(
    input         clk,
    input         probe0,
    input  [15:0] probe1,
    input         probe2,
    input         probe3,
    input         probe4,
    input  [15:0] probe5,
    input  [3:0]  probe6,
    input  [15:0] probe7,
    input  [23:0] probe8,
    input  [23:0] probe9,
    input  [15:0] probe10,
    input  [31:0] probe11,
    input  [15:0] probe12,
    input         probe13,
    input  [31:0] probe14,
    input  [31:0] probe15
);
endmodule

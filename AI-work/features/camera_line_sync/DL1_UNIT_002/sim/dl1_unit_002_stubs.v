`timescale 1ns / 1ps

// Simulation-only replacements for IP used by the focused camera-sync test.
module BUFG(input I, output O);
assign O = I;
endmodule

module sync_module(input data_in, input clk_in, output reg data_out);
always @(posedge clk_in) data_out <= data_in;
endmodule

// The test never fills this FIFO.  dout updates on the read clock; this matches
// the registered FIFO-output latency expected by dac_output's rd_en/rd_en_r
// pipeline.
module fifo_generator_4(
    input wr_clk,
    input rst,
    input rd_clk,
    input [34:0] din,
    input wr_en,
    input rd_en,
    output reg [34:0] dout,
    output prog_full,
    output prog_empty,
    output wr_rst_busy,
    output rd_rst_busy
);
reg [34:0] mem [0:1023];
integer wr_ptr;
integer rd_ptr;
assign prog_full   = 1'b0;
assign prog_empty  = (wr_ptr == rd_ptr);
assign wr_rst_busy = 1'b0;
assign rd_rst_busy = 1'b0;
always @(posedge wr_clk or posedge rst) begin
    if (rst)
        wr_ptr <= 0;
    else if (wr_en) begin
        mem[wr_ptr] <= din;
        wr_ptr <= wr_ptr + 1;
    end
end
always @(posedge rd_clk or posedge rst) begin
    if (rst) begin
        rd_ptr <= 0;
        dout <= 35'd0;
    end
    else if (rd_en && !prog_empty) begin
        dout <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1;
    end
end
endmodule

// Divider outputs are sufficient for the parameters used by this focused test.
module div_gen_2(
    input aclk,
    input s_axis_divisor_tvalid,
    input [15:0] s_axis_divisor_tdata,
    input s_axis_dividend_tvalid,
    input [15:0] s_axis_dividend_tdata,
    output reg m_axis_dout_tvalid,
    output reg [31:0] m_axis_dout_tdata
);
always @(posedge aclk) begin
    m_axis_dout_tvalid <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
    if (s_axis_divisor_tdata == 0)
        m_axis_dout_tdata <= 32'd0;
    else
        m_axis_dout_tdata <= {(s_axis_dividend_tdata / s_axis_divisor_tdata),
                               (s_axis_dividend_tdata % s_axis_divisor_tdata)};
end
endmodule

module div_gen_3(
    input aclk,
    input s_axis_divisor_tvalid,
    input [31:0] s_axis_divisor_tdata,
    input s_axis_dividend_tvalid,
    input [63:0] s_axis_dividend_tdata,
    output reg m_axis_dout_tvalid,
    output reg [95:0] m_axis_dout_tdata
);
always @(posedge aclk) begin
    m_axis_dout_tvalid <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
    if (s_axis_divisor_tdata == 0)
        m_axis_dout_tdata <= 96'd0;
    else
        m_axis_dout_tdata <= {(s_axis_dividend_tdata / s_axis_divisor_tdata), 32'd0};
end
endmodule

module ila_1(
    input clk,
    input probe0,
    input [31:0] probe1,
    input [3:0] probe2,
    input probe3,
    input [31:0] probe4,
    input [15:0] probe5,
    input probe6
);
endmodule

module ila_2(
    input clk,
    input probe0,
    input [15:0] probe1,
    input [15:0] probe2,
    input probe3,
    input probe4,
    input probe5,
    input probe6
);
endmodule

module ila_3(
    input clk,
    input [3:0] probe0,
    input probe1,
    input [31:0] probe2,
    input [15:0] probe3,
    input probe4,
    input probe5
);
endmodule

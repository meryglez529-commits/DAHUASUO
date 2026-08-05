`timescale 1ns / 1ps

module sync_module(input data_in, input clk_in, output reg data_out);
    reg stage0;
    initial begin stage0 = 1'b0; data_out = 1'b0; end
    always @(posedge clk_in) begin stage0 <= data_in; data_out <= stage0; end
endmodule

module BUFG(input I, output O);
    assign O = I;
endmodule

module div_gen_2(
    input aclk,
    input s_axis_divisor_tvalid,
    input [31:0] s_axis_divisor_tdata,
    input s_axis_dividend_tvalid,
    input [31:0] s_axis_dividend_tdata,
    output reg m_axis_dout_tvalid,
    output reg [31:0] m_axis_dout_tdata
);
    reg [15:0] q;
    reg [15:0] r;
    always @(posedge aclk) begin
        m_axis_dout_tvalid <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
        if (s_axis_divisor_tdata != 0) begin
            q = s_axis_dividend_tdata / s_axis_divisor_tdata;
            r = s_axis_dividend_tdata % s_axis_divisor_tdata;
            m_axis_dout_tdata <= {q, r};
        end else begin
            m_axis_dout_tdata <= 32'd0;
        end
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
    reg [63:0] q;
    always @(posedge aclk) begin
        m_axis_dout_tvalid <= s_axis_divisor_tvalid && s_axis_dividend_tvalid;
        if (s_axis_divisor_tdata != 0) begin
            q = s_axis_dividend_tdata / s_axis_divisor_tdata;
            m_axis_dout_tdata <= {q, 32'd0};
        end else begin
            m_axis_dout_tdata <= 96'd0;
        end
    end
endmodule

module fifo_generator_4(
    input rst, input wr_clk, input rd_clk, input [34:0] din,
    input wr_en, input rd_en, output reg [34:0] dout,
    output full, output empty, output prog_full, output prog_empty,
    output reg wr_rst_busy, output reg rd_rst_busy
);
    reg [34:0] mem [0:1023];
    integer wr_ptr;
    integer rd_ptr;
    integer count;
    initial begin
        wr_ptr = 0; rd_ptr = 0; count = 0; dout = 35'd0;
        wr_rst_busy = 1'b0; rd_rst_busy = 1'b0;
    end
    assign full = 1'b0;
    assign empty = (count == 0);
    assign prog_full = 1'b0;
    assign prog_empty = (count == 0);
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            wr_ptr = 0;
            count = 0;
            wr_rst_busy <= 1'b0;
        end else if (wr_en) begin
            mem[wr_ptr] = din;
            wr_ptr = (wr_ptr + 1) % 1024;
            count = count + 1;
        end
    end
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            rd_ptr = 0;
            dout <= 35'd0;
            rd_rst_busy <= 1'b0;
        end else if (rd_en && count > 0) begin
            dout <= mem[rd_ptr];
            rd_ptr = (rd_ptr + 1) % 1024;
            count = count - 1;
        end
    end
endmodule

module ila_1(input clk, input probe0, input [31:0] probe1, input [3:0] probe2,
             input probe3, input [31:0] probe4, input [15:0] probe5, input probe6);
endmodule

module ila_2(input clk, input probe0, input [15:0] probe1, input [15:0] probe2,
             input probe3, input probe4, input probe5, input probe6);
endmodule

module ila_3(input clk, input [3:0] probe0, input probe1, input [31:0] probe2,
             input [15:0] probe3, input probe4, input probe5);
endmodule

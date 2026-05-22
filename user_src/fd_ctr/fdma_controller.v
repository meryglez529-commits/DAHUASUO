`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: cz123 milinker
// Engineer: tjy
// bbs:http://www.osrc.cn
// taobao:http://osrc.taobao.com
// Create Date: 2019/02/27 22:09:55
// Design Name: fdma_controller
// Module Name: fdma_controller
// Project Name: 
// Copyright: msxbo Copyright (c) 2019
// Revision 0.01 - File Created
// Additional Comments:
// this codes is used for images frams control
//////////////////////////////////////////////////////////////////////////////////

module fdma_controller#
(
parameter  integer  ADDR_OFFSET = 0,
parameter  integer  BUF_SIZE = 3,
parameter  integer  H_CNT = 640, 
parameter  integer  V_CNT = 480			
)
(
    input           ui_clk,
    input           ui_rstn,
//sensor input -W0_FIFO--------------
    input           W0_FS_i,
    input           W0_wclk_i,
    input           W0_wren_i,
    input  [31:0]   W0_data_i, 
//----------fdma signals write-------       
    output  reg    pkg_wr_areq,       
    input           pkg_wr_en,
    input           pkg_wr_last,
    output  [31:0]  pkg_wr_addr,
    output  [127:0] pkg_wr_data,
    output  [31:0]  pkg_wr_size,
    output reg [6:0] W0_Fbuf   
    );
    
parameter FBUF_SIZE = BUF_SIZE -1'b1;
parameter BURST_SIZE  = 1024*4;
parameter BURST_TIMES = H_CNT*V_CNT/1024;
parameter PKG_SIZE    = 256;
assign pkg_wr_size = PKG_SIZE;
//------------vs ¬À≤®---------------
reg  W0_FIFO_Rst; 
wire W0_FS;
reg W0_s_rdy;
fs_cap fs_cap_W0(
  .clk_i(ui_clk),
  .rstn_i(ui_rstn),
  .vs_i(W0_FS_i),
  .s_rdy_i(W0_s_rdy),
  .fs_cap_o(W0_FS)
);
parameter S_IDLE  =  2'd0;  
parameter S_RST   =  2'd1;  
parameter S_DATA1 =  2'd2;   
parameter S_DATA2 =  2'd3; 

reg [1 :0]  W_MS;
reg [22:0]  W0_addr;
reg [31 :0] W0_fcnt;
reg [10 :0] W0_bcnt;
wire[9 :0]  W0_rcnt;
reg W0_REQ;

assign pkg_wr_addr = {W0_Fbuf,W0_addr}+ ADDR_OFFSET;
//assign pkg_wr_data = {32'hffff0000,32'hffff1111,32'haaaa0000,W0_fcnt};
//--------“ª∏±ÕºœÒ–¥»ÎDDR------------
 always @(posedge ui_clk) begin
    if(!ui_rstn)begin
        W_MS <= S_IDLE;
        W0_addr <= 23'd0;
        pkg_wr_areq <= 1'd0;
        W0_FIFO_Rst <= 1'b1;
        W0_fcnt <= 0;
        W0_bcnt <= 0;
        W0_s_rdy <= 1'b0;
        W0_Fbuf <= 7'd0;
    end
    else begin
      case(W_MS)
       S_IDLE:begin
          W0_addr <= 23'd0;
          W0_fcnt <= 0;
          W0_bcnt <= 11'd0;
          W0_s_rdy <= 1'b1;
          if(W0_FS) W_MS <= S_RST;
       end
       S_RST:begin
           W0_s_rdy <= 1'b0;  
          if(W0_fcnt > 8'd30 ) W_MS <= S_DATA1;
          W0_FIFO_Rst <= (W0_fcnt < 8'd20); 
          W0_fcnt <= W0_fcnt +1'd1;
        end          
        S_DATA1:begin 
            if(W0_bcnt == BURST_TIMES) begin
                if(W0_Fbuf == FBUF_SIZE) 
                    W0_Fbuf <= 7'd0;
                 else 
                    W0_Fbuf <= W0_Fbuf + 1'b1; 
                 W_MS <= S_IDLE;
            end
            else if(W0_REQ) begin
                W0_fcnt <=0;
                pkg_wr_areq <= 1'b1;
                W_MS <= S_DATA2;  
            end           
         end
         S_DATA2:begin
            pkg_wr_areq <= 1'b0;
            if(pkg_wr_last)begin
                W_MS <= S_DATA1; 
                W0_bcnt <= W0_bcnt + 1'd1; 
                W0_addr <= W0_addr + BURST_SIZE;
            end
         end
       endcase
    end
 end 


 always@(posedge ui_clk)
 begin     
     W0_REQ    <= (W0_rcnt    >= PKG_SIZE); 
 end
 
 wire [127:0]fifo_data;
 assign pkg_wr_data={
                     fifo_data[7  :  0],fifo_data[15 : 8 ],fifo_data[23 : 16],fifo_data[31 : 24],
                     fifo_data[39 : 32],fifo_data[47 : 40],fifo_data[55 : 48],fifo_data[63 : 56],
                     fifo_data[71 : 64],fifo_data[79 : 72],fifo_data[87 : 80],fifo_data[95 : 88],
                     fifo_data[103: 96],fifo_data[111:104],fifo_data[119:112],fifo_data[127:120]
                    };
W0_FIFO W0_FIFO_0 (
  .rst(W0_FIFO_Rst),  // input wire rst
  .wr_clk(W0_wclk_i),  // input wire wr_clk
  .din(W0_data_i),        // input wire [31 : 0] din
  .wr_en(W0_wren_i),    // input wire wr_en
  .rd_clk(ui_clk),  // input wire rd_clk 
  .rd_en(pkg_wr_en),    // input wire rd_en
  .dout(fifo_data),      // output wire [63 : 0] dout
  .rd_data_count(W0_rcnt)  // output wire [10 : 0] wr_data_count
);

endmodule

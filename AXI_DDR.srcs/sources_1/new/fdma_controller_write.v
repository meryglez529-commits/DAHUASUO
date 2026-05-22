`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/17 10:44:40
// Design Name: 
// Module Name: fdma_controller_write
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
module fdma_controller_write(
    input   wire            ui_clk,
    input   wire            fdma_rstn,
    input   wire            remote_rstn,
    input   wire            eth_clk,
    input   wire            eth_rstn,
    input   wire            remote_wr_en,
    input   wire [15:0]     remote_wr_data,

    output  reg             pkg_wr_areq,       
    input   wire            pkg_wr_en,
    input   wire            pkg_wr_last,
    output  reg  [31:0]     pkg_wr_addr,
    output  wire [63:0]     pkg_wr_data,
    output  wire [31:0]     pkg_wr_size
    );
//////////////////////////////////////////////////////////////
wire remote_rstn_r;
sync_signal sync_signal_inst(
    .data_a     (remote_rstn),
    .clka       (eth_clk),
    .rstn_a     (eth_rstn),
    .clkb       (ui_clk),
    .rstn_b     (fdma_rstn),
    .data_b     (remote_rstn_r)
    );   

    wire    [7:0]   PKG_SIZE;
    wire    [11:0]  BURST_SIZE;
    assign           PKG_SIZE     = 8'd128;
    assign           BURST_SIZE   = {1'b0,PKG_SIZE,3'd0};   //burst_size按字节计算
    assign           pkg_wr_size  = {24'd0,PKG_SIZE};  //pkg_wr_size按pkg_wr_data的位宽计算
    
    reg             W0_REQ;
    wire    [7:0]   rd_data_count;
    reg     [1:0]   current_state;
    reg     [1:0]   next_state;
    parameter IDLE  = 2'b00;
    parameter S0    = 2'b01;
    parameter S1    = 2'b10;
    parameter S2    = 2'b11;
  always@(posedge ui_clk or negedge fdma_rstn)
  begin  
    if(!fdma_rstn)  
        W0_REQ <= 1'b0;  
    else 
        W0_REQ <= (rd_data_count >= PKG_SIZE-2);   
  end

  always@(posedge ui_clk or negedge fdma_rstn)
  begin
    if(!fdma_rstn)  
        current_state <= IDLE;
    else
        current_state <= next_state;
  end

  always@(current_state or W0_REQ or pkg_wr_last)  
  begin
    case(current_state)
    IDLE: next_state = (W0_REQ == 1)? S0:IDLE;
    S0: next_state = S1;     
    S1: next_state = (pkg_wr_last==1)?S2:S1;
    S2: next_state = IDLE;      
    default: next_state = IDLE;
    endcase 
  end  
   
  always@(posedge ui_clk or negedge fdma_rstn)  
  begin
    if(!fdma_rstn) begin  
        pkg_wr_areq <= 1'b0; 
        pkg_wr_addr <= 32'd0;
    end
    else 
        case(next_state)
        IDLE:   begin   pkg_wr_areq <= 1'b0;  
                        if(remote_rstn_r)
                            pkg_wr_addr <= pkg_wr_addr; 
                        else
                            pkg_wr_addr <= 32'd0;    
                end
        S0:     begin   pkg_wr_areq <= 1'b1;  pkg_wr_addr <= pkg_wr_addr; end
        S1:     begin   pkg_wr_areq <= 1'b0;  pkg_wr_addr <= pkg_wr_addr; end
        S2:     begin   pkg_wr_areq <= 1'b0;  pkg_wr_addr <= pkg_wr_addr + BURST_SIZE; end  
        default:begin   pkg_wr_areq <= 1'b0;  pkg_wr_addr <= 32'd0; end 
        endcase  
  end

  fifo_generator_10 W0_fifo_generator_10 (
    .rst           (!(fdma_rstn & eth_rstn & remote_rstn)),  
    .wr_clk         (eth_clk),  
    .din            (remote_wr_data),       
    .wr_en          (remote_wr_en),  
    .rd_clk         (ui_clk),  
    .rd_en          (pkg_wr_en),   
    .dout           (pkg_wr_data),     
    .rd_data_count  (rd_data_count)  
    );

//ila_1 pkg_wr_ila(
//    .clk        (ui_clk),
//    .probe0     (pkg_wr_areq),
//    .probe1     (pkg_wr_en),
//    .probe2     (pkg_wr_last),
//    .probe3     (pkg_wr_addr),
//    .probe4     (pkg_wr_data),
//    .probe5     (pkg_wr_size),
//    .probe6     (W0_REQ),
//    .probe7     (rd_data_count)
//    );  
endmodule
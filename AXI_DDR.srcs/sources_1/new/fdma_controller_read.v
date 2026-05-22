`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/17 18:31:58
// Design Name: 
// Module Name: fdma_controller_read
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
module fdma_controller_read(
    input               ui_clk,
    input               fdma_rstn,
    input               eth_clk,
    input               eth_rstn,
    input               clk_50m,
    input               remote_en,
    
    input       [63:0] pkg_rd_data,
    input               pkg_rd_en,
    input               pkg_rd_last,
    output reg  [31:0]  pkg_rd_addr,
    output reg          pkg_rd_areq,
    output      [31:0]   pkg_rd_size,
    
    input               data_in_flag,
    output       [3:0]  data_in
    );
    
    assign pkg_rd_size = 32'd128;
    parameter BURST_SIZE  = 1024;
//--------------------sync-------------------------------------
wire remote_en_r;
sync_signal sync_signal_inst(
    .data_a     (remote_en),
    .clka       (eth_clk),
    .rstn_a     (eth_rstn),
    .clkb       (ui_clk),
    .rstn_b     (fdma_rstn),
    .data_b     (remote_en_r)
    ); 

reg [31:0] remote_en_reg;
always@(posedge ui_clk or negedge fdma_rstn)
begin
    if(!fdma_rstn)  
        remote_en_reg <= 64'd0;
    else
        remote_en_reg <= {remote_en_reg[30:0],remote_en_r};    
end


/////////////////////////////////////////////////////////
  wire          pre_prog_full;
  wire          pre_prog_empty;
  reg           pre_rd_en; 
  wire          sec_prog_full;
  reg           sec_wr_en;
  wire [31:0]   sec_data;
   
  reg [1:0] current_state;
  reg [1:0] next_state;
  parameter IDLE = 2'b00;
  parameter S0 = 2'b01;
  parameter S1 = 2'b10;
  parameter S2 = 2'b11; 
  

  always@(posedge ui_clk or negedge fdma_rstn)
  begin
    if(!fdma_rstn)  
        current_state <= IDLE;
    else
        current_state <= next_state;
  end
  
  wire  rd_req;            
  assign rd_req = remote_en_reg[31] & (!pre_prog_full);      
  always@(current_state or rd_req or pkg_rd_last)  
  begin
    case(current_state)
        IDLE: next_state = (rd_req)? S0:IDLE;
        S0: next_state =  S1;     
        S1: next_state = (pkg_rd_last==1)?S2:S1;
        S2: next_state = IDLE;      
        default: next_state = IDLE;
    endcase 
  end  
          
  always@(posedge ui_clk or negedge fdma_rstn)  
  begin
    if(!fdma_rstn) begin  
        pkg_rd_areq <= 1'b0; 
        pkg_rd_addr <=32'h00000000;
    end
    else
        case(current_state)
        IDLE:   begin 
                    pkg_rd_areq <= 1'b0; 
                    if(remote_en_r)
                        pkg_rd_addr <= pkg_rd_addr; 
                    else
                        pkg_rd_addr <= 32'h00000000;   
                end
        S0:     begin 
                    pkg_rd_areq <= 1'b1; 
                    pkg_rd_addr <= pkg_rd_addr; 
                end  
        S1:     begin 
                    pkg_rd_areq <= 1'b0; 
                    pkg_rd_addr <= pkg_rd_addr; 
                end
        S2:     begin 
                    pkg_rd_areq <= 1'b0;
                    pkg_rd_addr <= pkg_rd_addr+BURST_SIZE; 
                end
        default:begin  
                    pkg_rd_areq <= 1'b0; 
                    pkg_rd_addr <= 31'b0; 
                end 
        endcase    
  end

  fifo_generator_5 first_fifo_inst( 
    .clk        (ui_clk),  
    .srst       (!remote_en_r),
//    .din({pkg_rd_data[7:0],pkg_rd_data[15:8],pkg_rd_data[23:16],pkg_rd_data[31:24],pkg_rd_data[39:32],pkg_rd_data[47:40],pkg_rd_data[55:48],pkg_rd_data[63:56],
//         pkg_rd_data[71:64],pkg_rd_data[79:72],pkg_rd_data[87:80],pkg_rd_data[95:88],pkg_rd_data[103:96],pkg_rd_data[111:104],pkg_rd_data[119:112],pkg_rd_data[127:120]}),
    .din        (pkg_rd_data),
    .wr_en      (pkg_rd_en),
    .rd_en      (pre_rd_en),
    .dout       (sec_data),
    .prog_full  (pre_prog_full),
    .prog_empty (pre_prog_empty)
    );

  always@(posedge ui_clk or negedge fdma_rstn)  
  begin
    if(!fdma_rstn) 
        pre_rd_en<=1'b0;           
    else 
        if(sec_prog_full==0 && pre_prog_empty==0)     //需要往里面写数 
            pre_rd_en<=1'b1;
        else
            pre_rd_en<=1'b0;  
  end    
   
  always@(posedge ui_clk or negedge fdma_rstn)  
  begin
    if(!fdma_rstn)
        sec_wr_en<=1'b0;
    else   
        sec_wr_en <= pre_rd_en;
    end   
      
  fifo_generator_8 second_fifo_inst(
    .wr_clk         (ui_clk),
    .rd_clk         (clk_50m),
    .rst            (~remote_en_r),
    .din            (sec_data),
    .wr_en          (sec_wr_en),
    .rd_en          (data_in_flag),
    .dout           (data_in),
    .prog_full      (sec_prog_full)
    );       
endmodule
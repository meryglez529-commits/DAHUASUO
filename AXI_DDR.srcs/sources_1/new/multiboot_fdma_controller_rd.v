`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
  module multiboot_fdma_controller_rd(
    input ui_clk,
    input clk_50m,
    input rstn,

    input [127:0] pkg_rd_data,
    input pkg_rd_en,
    input pkg_rd_last,
    output reg [31:0] pkg_rd_addr,
    output reg pkg_rd_areq,
    output wire [31:0] pkg_rd_size,
    
    input data_in_flag,
    output [3:0] data_in
    );
  wire clk50m_rstn;
  sync_module sync1(.data_in(rstn),.clk_in(clk_50m),.data_out(clk50m_rstn));     
  wire pre_prog_full;
  wire pre_prog_empty;
  reg pre_rd_en; 
  wire free1_config_prog_full;
  reg free1_config_wr_en;
  wire [31:0] free1_config_data;
   
  parameter BURST_SIZE  = 1024;
  parameter PKG_SIZE    = 64;
  assign pkg_rd_size = PKG_SIZE;  
  reg [1:0] current_state;
  reg [1:0] next_state;
  parameter IDLE = 2'b00;
  parameter S0 = 2'b01;
  parameter S1 = 2'b10;
  parameter S2 = 2'b11; 
  always@(posedge ui_clk or negedge rstn)
  begin
    if(!rstn)  
        current_state <= IDLE;
    else
        current_state <= next_state;
  end
          
  always@(current_state or pre_prog_full or pkg_rd_last)  
  begin
    case(current_state)
        IDLE: next_state = (!pre_prog_full)? S0:IDLE;
        S0: next_state =  S1;     
        S1: next_state = (pkg_rd_last==1)?S2:S1;
        S2: next_state = IDLE;      
        default: next_state = IDLE;
    endcase 
  end  
          
  always@(posedge ui_clk or negedge rstn)  
  begin
    if(!rstn) begin  
        pkg_rd_areq <= 1'b0; 
        pkg_rd_addr[31:0]<=31'h1800000;
    end
    else
        case(next_state)
        IDLE:   begin 
                    pkg_rd_areq <= 1'b0; 
                    pkg_rd_addr<=pkg_rd_addr; 
                end
        S0:     begin 
                    pkg_rd_areq <= 1'b1; 
                    pkg_rd_addr<=pkg_rd_addr; 
                end  
        S1:     begin 
                    pkg_rd_areq <= 1'b0; 
                    pkg_rd_addr<=pkg_rd_addr; 
                end
        S2:     begin 
                    pkg_rd_areq <= 1'b0;
                    pkg_rd_addr<= pkg_rd_addr+BURST_SIZE; 
                end
        default:begin  
                    pkg_rd_areq <= 1'b0; 
                    pkg_rd_addr<=31'b0; 
                end 
        endcase    
  end

  fifo_generator_5 first_fifo_inst( 
    .clk(ui_clk),  
    .srst(!rstn),
    .din({pkg_rd_data[7:0],pkg_rd_data[15:8],pkg_rd_data[23:16],pkg_rd_data[31:24],pkg_rd_data[39:32],pkg_rd_data[47:40],pkg_rd_data[55:48],pkg_rd_data[63:56],
         pkg_rd_data[71:64],pkg_rd_data[79:72],pkg_rd_data[87:80],pkg_rd_data[95:88],pkg_rd_data[103:96],pkg_rd_data[111:104],pkg_rd_data[119:112],pkg_rd_data[127:120]}),
    .wr_en(pkg_rd_en),
    .rd_en(pre_rd_en),
    .dout(free1_config_data),
    .prog_full(pre_prog_full),
    .prog_empty(pre_prog_empty)
    );

  always@(posedge ui_clk or negedge rstn)  
  begin
    if(!rstn) 
        pre_rd_en<=1'b0;           
    else 
        if(free1_config_prog_full==0 && pre_prog_empty==0)     //需要往里面写数 
            pre_rd_en<=1'b1;
        else
            pre_rd_en<=1'b0;  
  end    
   
  always@(posedge ui_clk or negedge rstn)  
  begin
    if(!rstn)
        free1_config_wr_en<=1'b0;
    else   
        free1_config_wr_en <= pre_rd_en;
    end   
      
  fifo_generator_7 second_fifo_inst(
    .wr_clk(ui_clk),
    .wr_rst(!rstn),
    .rd_clk(clk_50m),
    .rd_rst(!clk50m_rstn),
    .din(free1_config_data),
    .wr_en(free1_config_wr_en),
    .rd_en(data_in_flag),
    .dout(data_in),
    .prog_full(free1_config_prog_full)
    );  
       
endmodule
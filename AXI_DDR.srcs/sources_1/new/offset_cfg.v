`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/13 17:54:57
// Design Name: 
// Module Name: offset_cfg
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
  module offset_cfg(
    input clk10m,
    input rstn,
    output reg ADC_SCL,
    inout ADC_SDA,
    input read_flag,
    input [15:0] channel1,
    input [15:0] channel2,
    input [15:0] channel3,
    input [15:0] channel4
    );
    
  reg bir;        //H:output;   L:input 
  reg ADC_SDO;    
  wire ADC_SDI;                         
  assign ADC_SDA = (bir)? ADC_SDO : 1'bz;
  assign ADC_SDI = ADC_SDA; 
      
  reg read_flag_reg;
  always@(posedge clk10m or negedge rstn) 
  begin
  if(!rstn) 
    read_flag_reg <= 1'b0;
  else
    read_flag_reg <= read_flag;
  end
   
  localparam wr_slave_address = 8'h18;  
  localparam rd_slave_address = 8'h19;    
  localparam wr_command = 4'h3;  //写入并更新DAC通道n     
  reg [1:0] current_state;
  parameter IDLE = 2'd0;
  parameter wr_state_pre = 2'd1;
  parameter wr_state = 2'd2;      
  reg [2:0] fre_cnt; 
  reg [7:0] wr_data;
  reg [23:0] offset_data;
  reg [3:0] command_cnt;
  reg [2:0] bit_cnt;
  reg [1:0] byte_cnt;
  reg [7:0] state;
  always@(posedge clk10m or negedge rstn) 
  begin
    if(!rstn) begin
        fre_cnt <= 3'd0;
        current_state<=IDLE; 
        wr_data <= 8'd0;
        offset_data <= 24'd0;
        command_cnt <= 4'd0;
        bit_cnt <= 3'd0;
        byte_cnt <= 2'd0;
        state <= 8'd0;
        bir <= 1'b1;
        ADC_SCL <= 1'b0;
        ADC_SDO <= 1'b1;
    end
  else
    case(current_state) 
    IDLE:
    begin
        if(read_flag_reg==0 && read_flag==1)
            current_state<=wr_state_pre;
        else
            current_state<=IDLE;        
    end
    wr_state_pre:
    begin
       wr_data<=wr_slave_address;
       if(command_cnt<4) begin
           command_cnt<=command_cnt+1'b1;  
           current_state<=wr_state;
       end
       else begin
           command_cnt<=4'd0;  
           current_state<=IDLE; 
       end
       case(command_cnt)
       4'd0:   begin offset_data <= {wr_command,4'h1,channel1[11:0],4'd0};end
       4'd1:   begin offset_data <= {wr_command,4'h2,channel2[11:0],4'd0};end
       4'd2:   begin offset_data <= {wr_command,4'h4,channel3[11:0],4'd0};end
       4'd3:   begin offset_data <= {wr_command,4'h8,channel4[11:0],4'd0};end
       default:begin offset_data <= 24'd0; end
       endcase
    end
    wr_state:
    begin  
       if(fre_cnt==7) begin
           fre_cnt <= 3'd0;     
           case(state)
           8'd0: begin state<=state+1'b1; ADC_SCL <= 1'b0; ADC_SDO<=ADC_SDO; bir<=1'b1; end 
           8'd1: begin state<=state+1'b1; ADC_SCL <= 1'b0; ADC_SDO<=1'b1; end 
           8'd2: begin state<=state+1'b1; ADC_SCL <= 1'b1; ADC_SDO<=1'b1; end 
           8'd3: begin state<=state+1'b1; ADC_SCL <= 1'b1; ADC_SDO<=1'b0; end    //start
           8'd4: begin state<=state+1'b1; ADC_SCL <= 1'b0; bir <= 1'b1; end
           8'd5: begin state<=state+1'b1; ADC_SCL <= 1'b0; ADC_SDO<=wr_data[7];wr_data<={wr_data[6:0],wr_data[7]}; end
           8'd6: begin state<=state+1'b1; ADC_SCL <= 1'b1; end
           8'd7: begin bit_cnt<=bit_cnt+1'b1; ADC_SCL <= 1'b1; 
                       if(bit_cnt<7)  
                           state <= 8'd4;  
                       else 
                           state <= 8'd8;  
                 end 
           8'd8: begin state<=state+1'b1; ADC_SCL <= 1'b0; end          
           8'd9: begin state<=state+1'b1; ADC_SCL <= 1'b0; bir <= 1'b0; end
           8'd10:begin state<=state+1'b1; ADC_SCL <= 1'b1; end
           8'd11:begin if(ADC_SDI==0) begin                             //acknowledge success
                           byte_cnt <= byte_cnt + 1'b1;
                           wr_data <= offset_data[23:16];
                           offset_data <= {offset_data[15:0],8'd0};
                           if(byte_cnt<3)
                                state<=8'd4; 
                           else
                                state<=8'd12;
                       end
                       else                                         //acknowledge failed
                           state <= 8'd0;    
                 end
           8'd12:begin state<=state+1'b1; ADC_SCL <= 1'b0; bir<=1'b1; end
           8'd13:begin state<=state+1'b1; ADC_SCL <= 1'b0; ADC_SDO<=1'b0; end
           8'd14:begin state<=state+1'b1; ADC_SCL <= 1'b1; ADC_SDO<=1'b0; end 
           8'd15:begin state<=8'd0; ADC_SCL <= 1'b1; ADC_SDO<=1'b1; current_state <= wr_state_pre; end   //end
           default: begin state<=8'd0; ADC_SCL <= 1'b1; ADC_SDO<=1'b1; current_state <= wr_state_pre; end
           endcase  
       end
       else
           fre_cnt <= fre_cnt + 1'b1;      
    end     
    default:begin current_state <= IDLE; end  
    endcase
end   

endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/11 17:35:23
// Design Name: 
// Module Name: fram_cfg
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
  module fram_cfg(    
    input               ui_clk,
    input               rstn,
    input               clk10m,
    input               rstn_buf,
    output reg          FRAM_SCL,
    inout               FRAM_SDA,
    input               wr_offset_flag,
    input       [31:0] offset_adc1_adc2,
    input       [31:0] offset_adc3_adc4,
    input       [31:0] offset_dacx_dacy,
    output reg         read_flag,  
    output      [15:0] offset_adc1,
    output      [15:0] offset_adc2,
    output      [15:0] offset_adc3,
    output      [15:0] offset_adc4,
    output      [15:0] offset_dacx,
    output      [15:0] offset_dacy,
    input              write_rom_flag,
    input       [7:0]  flash_type_in,
    output      [7:0]  flash_type_out
    );
//------sync---------------------------------------------------------------------------  
  reg [23:0] wr_offset_flag_reg;
  wire wr_offset;
  assign wr_offset = (wr_offset_flag_reg[23:3]==0)? 1'b0 : 1'b1;
  always@(posedge ui_clk or negedge rstn) 
  begin
    if(!rstn) 
        wr_offset_flag_reg <= 24'd0; 
    else
        wr_offset_flag_reg <= {wr_offset_flag_reg[22:0],wr_offset_flag};
  end 
  
  reg [1:0] wr_offset_reg;
  always@(posedge clk10m or negedge rstn_buf) 
  begin
    if(!rstn_buf)
        wr_offset_reg <= 2'b00;
    else
        wr_offset_reg <= {wr_offset_reg[0],wr_offset};
  end
  
  reg [31:0] offset_adc1_adc2_reg[0:2];
  reg [31:0] offset_adc3_adc4_reg[0:2];
  reg [31:0] offset_dacx_dacy_reg[0:2];
  reg [7:0]  flash_type_reg[0:2];
  always@(posedge clk10m or negedge rstn_buf) 
  begin
    if(!rstn_buf) begin
        {offset_adc1_adc2_reg[2],offset_adc1_adc2_reg[1],offset_adc1_adc2_reg[0]} <= 96'd0;
        {offset_adc3_adc4_reg[2],offset_adc3_adc4_reg[1],offset_adc3_adc4_reg[0]} <= 96'd0;
        {offset_dacx_dacy_reg[2],offset_dacx_dacy_reg[1],offset_dacx_dacy_reg[0]} <= 96'd0;
        {flash_type_reg[2],flash_type_reg[1],flash_type_reg[0]} <= 24'd0; 
    end
    else begin
        {offset_adc1_adc2_reg[2],offset_adc1_adc2_reg[1],offset_adc1_adc2_reg[0]} <= {offset_adc1_adc2_reg[1],offset_adc1_adc2_reg[0],offset_adc1_adc2};
        {offset_adc3_adc4_reg[2],offset_adc3_adc4_reg[1],offset_adc3_adc4_reg[0]} <= {offset_adc3_adc4_reg[1],offset_adc3_adc4_reg[0],offset_adc3_adc4};
        {offset_dacx_dacy_reg[2],offset_dacx_dacy_reg[1],offset_dacx_dacy_reg[0]} <= {offset_dacx_dacy_reg[1],offset_dacx_dacy_reg[0],offset_dacx_dacy};
        {flash_type_reg[2],flash_type_reg[1],flash_type_reg[0]} <= {flash_type_reg[1],flash_type_reg[0],flash_type_in};
    end
  end 
  
  localparam offset_adc1H_address = 16'd0;
  localparam offset_adc1L_address = 16'd1;  
  localparam offset_adc2H_address = 16'd2; 
  localparam offset_adc2L_address = 16'd3;  
  localparam offset_adc3H_address = 16'd4;
  localparam offset_adc3L_address = 16'd5;
  localparam offset_adc4H_address = 16'd6;
  localparam offset_adc4L_address = 16'd7; 
  localparam offset_dacxH_address = 16'd8;
  localparam offset_dacxL_address = 16'd9;
  localparam offset_dacyH_address = 16'd10;  
  localparam offset_dacyL_address = 16'd11;  
  localparam flash_type_address =   16'd12;  
  localparam rd_slave_address = 8'hA1;
  localparam wr_slave_address = 8'hA0;
   
  reg [2:0] current_state;
  parameter IDLE = 3'd0;
  parameter wr_state_pre = 3'd1;
  parameter wr_state = 3'd2;
  parameter rd_state_pre = 3'd3;
  parameter rd_state = 3'd4;
  reg [7:0] state; 
  reg bir;        //H:output;   L:input 
  reg FRAM_SDO;    
  wire FRAM_SDI;                         
  assign FRAM_SDA = (bir)? FRAM_SDO : 1'bz;
  assign FRAM_SDI = FRAM_SDA; 
  
  reg [2:0] fre_cnt; 
  reg [2:0] bit_cnt;
  reg [1:0] byte_cnt;
  reg [3:0] command_cnt;
  reg [7:0] wr_data;
  reg [103:0] rd_data;
  reg [15:0] offset_address;
  reg [7:0] offset_data;
  
  assign offset_adc1 = rd_data[103:88];
  assign offset_adc2 = rd_data[87:72];
  assign offset_adc3 = rd_data[71:56];
  assign offset_adc4 = rd_data[55:40];
  assign offset_dacx = rd_data[39:24];
  assign offset_dacy = rd_data[23:8];
  assign flash_type_out = rd_data[7:0];
  
 reg[2:0] write_rom_flag_reg;
 always@(posedge clk10m or negedge rstn_buf) 
  begin
    if(!rstn_buf)
        write_rom_flag_reg <= 3'b000;
    else begin
        write_rom_flag_reg[2] <= write_rom_flag_reg[1];
        write_rom_flag_reg[1] <= write_rom_flag_reg[0];
        write_rom_flag_reg[0] <= write_rom_flag;
    end
  end 
/////////////////////////  
  always@(posedge clk10m or negedge rstn_buf) 
  begin
    if(!rstn_buf) begin
        current_state <= IDLE;
        state <= 8'd0;
        read_flag <= 1'b0;
        bir <= 1'b1;
        FRAM_SDO <= 1'b1;
        FRAM_SCL <= 1'b0;
        fre_cnt <= 3'd0; 
        bit_cnt <= 3'd0;
        byte_cnt <= 2'd0;
        command_cnt <= 3'd0;
        wr_data <= 7'hff;
        rd_data <= 104'd0;
        offset_address <= 16'd0;
        offset_data <= 8'd0;
    end
    else 
    case(current_state)     
    IDLE:
    begin
    	  if(write_rom_flag_reg[2] > 0) begin
        	 current_state <= wr_state_pre; 
        	 command_cnt<=4'd12 ;
        end 
        else if(wr_offset_reg[1]==0)begin
            if(read_flag==0)                     //不要求写数据之前只读一次，每次写完数据再读一次
                current_state <= rd_state_pre;
            else
                current_state <= IDLE;  
        end 
        else
           current_state <= wr_state_pre; 
    end
    wr_state_pre:
    begin
        wr_data<=wr_slave_address;
        if(command_cnt<13) begin
            command_cnt<=command_cnt+1'b1;  
            current_state<=wr_state;
        end
        else begin
            command_cnt<=4'd0;  
            current_state<=IDLE;    //  写完以后立刻读出来
            read_flag <= 1'b0;
        end
        case(command_cnt)
        4'd0:   begin offset_address <= offset_adc1H_address; offset_data <= offset_adc1_adc2_reg[2][31:24];end
        4'd1:   begin offset_address <= offset_adc1L_address; offset_data <= offset_adc1_adc2_reg[2][23:16];end
        4'd2:   begin offset_address <= offset_adc2H_address; offset_data <= offset_adc1_adc2_reg[2][15:8]; end
        4'd3:   begin offset_address <= offset_adc2L_address; offset_data <= offset_adc1_adc2_reg[2][7:0];  end
        4'd4:   begin offset_address <= offset_adc3H_address; offset_data <= offset_adc3_adc4_reg[2][31:24];end
        4'd5:   begin offset_address <= offset_adc3L_address; offset_data <= offset_adc3_adc4_reg[2][23:16];end
        4'd6:   begin offset_address <= offset_adc4H_address; offset_data <= offset_adc3_adc4_reg[2][15:8]; end
        4'd7:   begin offset_address <= offset_adc4L_address; offset_data <= offset_adc3_adc4_reg[2][7:0];  end
        4'd8:   begin offset_address <= offset_dacxH_address; offset_data <= offset_dacx_dacy_reg[2][31:24];end
        4'd9:   begin offset_address <= offset_dacxL_address; offset_data <= offset_dacx_dacy_reg[2][23:16];end
        4'd10:  begin offset_address <= offset_dacyH_address; offset_data <= offset_dacx_dacy_reg[2][15:8]; end
        4'd11:  begin offset_address <= offset_dacyL_address; offset_data <= offset_dacx_dacy_reg[2][7:0];  end
        4'd12:  begin offset_address <= flash_type_address;   offset_data <= flash_type_reg[2];  end
        default:begin offset_address <= 16'hffff; offset_data <= 8'hff; end
        endcase
    end
    wr_state:
    begin  
        if(fre_cnt==7) begin
            fre_cnt <= 3'd0;     
            case(state)
            8'd0: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=FRAM_SDO; bir<=1'b1; end 
            8'd1: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=1'b1; end 
            8'd2: begin state<=state+1'b1; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; end 
            8'd3: begin state<=state+1'b1; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b0; end    //start
            8'd4: begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir <= 1'b1; end
            8'd5: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=wr_data[7];wr_data<={wr_data[6:0],wr_data[7]}; end
            8'd6: begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd7: begin bit_cnt<=bit_cnt+1'b1; FRAM_SCL <= 1'b1; 
                        if(bit_cnt<7)  
                            state <= 8'd4;  
                        else 
                            state <= 8'd8;  
                  end 
            8'd8: begin state<=state+1'b1; FRAM_SCL <= 1'b0; end          
            8'd9: begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir <= 1'b0; end
            8'd10:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd11:begin if(FRAM_SDI==0)    //acknowledge success
                            case(byte_cnt)
                            2'd0:   begin state<=8'd4; byte_cnt<=byte_cnt+1'b1; wr_data <= offset_address[15:8]; end
                            2'd1:   begin state<=8'd4; byte_cnt<=byte_cnt+1'b1; wr_data <= offset_address[7:0]; end
                            2'd2:   begin state<=8'd4; byte_cnt<=byte_cnt+1'b1; wr_data <= offset_data; end
                            2'd3:   begin state<=8'd12; byte_cnt<=2'd0; end 
                            default:begin state<=8'd12; byte_cnt<=2'd0; end 
                            endcase               
                        else            //acknowledge failed
                            state <= 8'd0;    
                  end
            8'd12:begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir<=1'b1; end
            8'd13:begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=1'b0; end
            8'd14:begin state<=state+1'b1; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b0; end 
            8'd15:begin state<=8'd0; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; current_state <= wr_state_pre; end   //end
            default: begin state<=8'd0; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; current_state <= wr_state_pre; end
            endcase  
        end
        else
            fre_cnt <= fre_cnt + 1'b1;      
    end
    rd_state_pre:
    begin
        wr_data<=wr_slave_address;
        if(command_cnt<13) begin
            command_cnt<=command_cnt+1'b1;  
            current_state<=rd_state;
        end
        else begin
            command_cnt<=4'd0;  
            current_state<=IDLE;
            read_flag <= 1'b1; 
        end
        case(command_cnt)
        4'd0:   begin offset_address <= offset_adc1H_address; end
        4'd1:   begin offset_address <= offset_adc1L_address; end
        4'd2:   begin offset_address <= offset_adc2H_address; end
        4'd3:   begin offset_address <= offset_adc2L_address; end
        4'd4:   begin offset_address <= offset_adc3H_address; end
        4'd5:   begin offset_address <= offset_adc3L_address; end
        4'd6:   begin offset_address <= offset_adc4H_address; end
        4'd7:   begin offset_address <= offset_adc4L_address; end
        4'd8:   begin offset_address <= offset_dacxH_address; end
        4'd9:   begin offset_address <= offset_dacxL_address; end
        4'd10:  begin offset_address <= offset_dacyH_address; end
        4'd11:  begin offset_address <= offset_dacyL_address; end
        4'd12:  begin offset_address <= flash_type_address; end
        default:begin offset_address <= 16'hffff; end
        endcase
    end
    rd_state:
    begin  
        if(fre_cnt==7) begin
            fre_cnt <= 3'd0;     
            case(state)
            8'd0: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=FRAM_SDO; bir<=1'b1; end 
            8'd1: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=1'b1; end 
            8'd2: begin state<=state+1'b1; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; end 
            8'd3: begin state<=state+1'b1; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b0; end    //start
            8'd4: begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir <= 1'b1; end
            8'd5: begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=wr_data[7];wr_data<={wr_data[6:0],wr_data[7]}; end
            8'd6: begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd7: begin bit_cnt<=bit_cnt+1'b1; FRAM_SCL <= 1'b1; 
                        if(bit_cnt<7)  
                            state <= 8'd4;  
                        else 
                            state <= 8'd8;  
                  end 
            8'd8: begin state<=state+1'b1; FRAM_SCL <= 1'b0; end          
            8'd9: begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir <= 1'b0; end
            8'd10:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd11:begin if(FRAM_SDI==0)    //acknowledge success
                            case(byte_cnt)
                            2'd0:   begin state<=8'd4; byte_cnt<=byte_cnt+1'b1; wr_data <= offset_address[15:8]; end
                            2'd1:   begin state<=8'd4; byte_cnt<=byte_cnt+1'b1; wr_data <= offset_address[7:0]; end
                            2'd2:   begin state<=8'd0; byte_cnt<=byte_cnt+1'b1; wr_data <= rd_slave_address; end
                            2'd3:   begin state<=8'd12; byte_cnt<=2'd0; end 
                            default:begin state<=8'd12; byte_cnt<=2'd0; end 
                            endcase               
                        else            //acknowledge failed
                            state <= 8'd0;    
                  end
            8'd12:begin state<=state+1'b1; FRAM_SCL <= 1'b0; end
            8'd13:begin state<=state+1'b1; FRAM_SCL <= 1'b0; end      
            8'd14:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd15:begin bit_cnt<=bit_cnt+1'b1; FRAM_SCL <= 1'b1; rd_data <= {rd_data[102:0],FRAM_SDI};
                        if(bit_cnt<7)  
                            state <= 8'd12;  
                        else 
                            state <= 8'd16;  
                  end      
            8'd16:begin state<=state+1'b1; FRAM_SCL <= 1'b0; bir<=1'b1; end
            8'd17:begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=1'b1; end
            8'd18:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd19:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd20:begin state<=state+1'b1; FRAM_SCL <= 1'b0; end
            8'd21:begin state<=state+1'b1; FRAM_SCL <= 1'b0; FRAM_SDO<=1'b0;end
            8'd22:begin state<=state+1'b1; FRAM_SCL <= 1'b1; end
            8'd23:begin state<=8'd0; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; current_state <= rd_state_pre; end 
            default: begin state<=8'd0; FRAM_SCL <= 1'b1; FRAM_SDO<=1'b1; current_state <= rd_state_pre; end
            endcase  
        end
        else
            fre_cnt <= fre_cnt + 1'b1;      
    end
    default:begin current_state <= IDLE; end  
    endcase
  end
  
//  ila_6 fram_sim(
//    .clk(clk10m),
//    .probe0(wr_offset_reg),
//    .probe1(bir),
//    .probe2(FRAM_SDO),
//    .probe3(FRAM_SCL),
//    .probe4(read_flag),
//    .probe5(rd_data),
//    .probe6(current_state)
//    );    
endmodule
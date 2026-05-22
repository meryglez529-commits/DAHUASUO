`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/16 16:07:42
// Design Name: 
// Module Name: qspi_cfg
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
  module qspi_cfg(
    input inclk,
    input inReset_EnableB,
    input qspi_cfg_en,
//-------------ex -------------------
    input [31:0] program_byte_count,
    output reg data_in_flag,
    input [3:0] data_in,
    output reg program_done,
//-------------QSPI_CFG_PIN-------------------------------
    inout qspi_d0,
    inout qspi_d1,  
    inout qspi_d2, 
    inout qspi_d3,
    output reg qspi_csb,
    output qspi_clk,
    input program_en,
    input read_en
    );
//inout pin ctrl...bir=1,out,///bir=0,input
  reg  [3:0] bir;
  wire [3:0] qspi_din;
  reg  [3:0] qspi_dout;
  assign qspi_d3 = (bir[3])? qspi_dout[3]:1'bz;
  assign qspi_d2 = (bir[2])? qspi_dout[2]:1'bz;
  assign qspi_d1 = (bir[1])? qspi_dout[1]:1'bz;
  assign qspi_d0 = (bir[0])? qspi_dout[0]:1'bz; 
  assign qspi_din = {qspi_d3,qspi_d2,qspi_d1,qspi_d0};
  assign qspi_clk = (~inclk)& (~qspi_csb);
//state machine
  reg [4:0] current_state;
  reg [4:0] next_state;
  parameter IDLE                        = 5'd1;
  parameter reset_state                 = 5'd2;
  parameter rdid_state                  = 5'd3; 
  parameter checkid_state               = 5'd4;
  parameter wr_reg_cfg_state            = 5'd5;
  parameter erase_state                 = 5'd6;
  parameter rd_reg_flag_cfg_state1      = 5'd7;
  parameter judge_erase_state           = 5'd8;
  parameter program_state               = 5'd9;
  parameter rd_reg_flag_cfg_state2      = 5'd10;
  parameter judge_program_state         = 5'd11;
  parameter read_state                  = 5'd12;
  parameter spi1_sendcommand            = 5'd13;
  parameter spi1_sendword               = 5'd14;
  parameter spi1_4_sendword             = 5'd15;
  parameter end_state                   = 5'd16;

  localparam wr_enable              =8'h06;
  localparam reset_enable           =8'h66;
  localparam reset_memory           =8'h99;
  localparam read_id                =8'h9F;
  localparam MT25QL256_ID           =24'h20BA19;
  localparam wr_reg_cfg             =8'h81;             //write volatile configuration register
  localparam sector_erase           =8'hDC;
  localparam rd_reg_flag            =8'h70;
  localparam clear_reg_flag         =8'h50;
  localparam fast_program           =8'h34;
  localparam fast_read              =8'h6C;
  localparam start_address          =32'h01000000;
  reg [15:0] send_cnt;
  reg [15:0] rec_cnt;
  reg [15:0] cnt; 
  reg [7:0]  reg8;
  reg [39:0] reg40;
  reg [31:0] ctrl_address;
  reg program_flag;
  reg qspi_cfg_en_reg;
  always@(posedge inclk or negedge inReset_EnableB)
  begin
    if(!inReset_EnableB) begin 
        current_state <= IDLE;
        next_state <= IDLE; 
        send_cnt <= 16'd0;
        rec_cnt <= 16'd0;
        cnt<=16'd0;        
        reg8 <= 8'd0;
        reg40 <= 40'd0;
        ctrl_address <= start_address;
        program_flag <= 1'b0;
        qspi_csb <= 1'b1;
        bir <= 4'b1101;
        qspi_dout <= 4'b1111;
        data_in_flag <= 1'b0;
        program_done <= 1'b0;
        qspi_cfg_en_reg <= 1'b0;
    end 
    else begin
        qspi_cfg_en_reg <= qspi_cfg_en; 
        case(current_state)
        IDLE:
            begin
                if(qspi_cfg_en==1 && qspi_cfg_en_reg==0)
                    current_state <= reset_state;
                else begin
                    current_state <= IDLE;   
                    next_state <= IDLE; 
                    send_cnt <= 16'd0;
                    rec_cnt <= 16'd0;
                    cnt<=16'd0;        
                    reg8 <= 8'd0;
                    reg40 <= 40'd0;
                    ctrl_address <= start_address;
                    program_flag <= 1'b0;
                    qspi_csb <= 1'b1;
                    bir <= 4'b1101;
                    qspi_dout <= 4'b1111;
                    data_in_flag <= 1'b0;
                    program_done <= 1'b0;
                end
            end
        reset_state:     
            begin
               current_state <= spi1_sendcommand;
               next_state <= rdid_state;
               reg8 <= reset_enable;
               reg40 <= {reset_memory,32'd0};
               send_cnt <= 16'd1;
               rec_cnt <= 16'd0;
            end       
        rdid_state:
            begin
                current_state <= spi1_sendword;
                next_state <= checkid_state;          
                reg40 <= {read_id,32'd0};
                send_cnt <= 16'd1;
                rec_cnt <= 16'd3;
            end   
        checkid_state:
            begin 
                if(reg40[23:0]==MT25QL256_ID) 
                    current_state <= wr_reg_cfg_state; 
                else
                    current_state <= end_state;
            end
        wr_reg_cfg_state:                                       //4 dummy cycle
            begin
                current_state <= spi1_sendcommand;
                next_state <= erase_state;
                reg8 <= wr_enable;
                reg40 <= {wr_reg_cfg,8'h4B,24'd0};
                send_cnt <= 16'd2;
                rec_cnt <= 16'd0;
            end              
        erase_state:
            begin
                current_state <= spi1_sendcommand;     
                next_state <= rd_reg_flag_cfg_state1;
                reg8 <= wr_enable;
                reg40 <= {sector_erase,ctrl_address};
                send_cnt <= 16'd5;
                rec_cnt <= 16'd0;
            end
        rd_reg_flag_cfg_state1:
            begin
                current_state <= spi1_sendword;    
                next_state <= judge_erase_state;
                reg40 <= {rd_reg_flag,32'd0};
                send_cnt <= 16'd1;
                rec_cnt <= 16'd1;
            end   
        judge_erase_state:
            begin
                if(reg40[7]==1)
                    if(reg40[5]==0)
                        if (ctrl_address>=32'h01FF0000) begin
                            ctrl_address <= start_address;
                            current_state <= program_state;  
                        end
                        else begin
                            ctrl_address <= ctrl_address + 20'd65536;    //sector erase,one sector = 64KB = 65536bytes
                            current_state <= erase_state;
                        end
                    else begin
                        current_state <= spi1_sendword;     //clear flag status register
                        next_state <= erase_state;
                        reg40 <= {clear_reg_flag,32'd0};
                        send_cnt <= 16'd1;
                        rec_cnt <= 16'd0;
                    end
                else
                    current_state <= rd_reg_flag_cfg_state1;                
            end
        program_state:                                  //quad input fast program  32
            begin
                current_state <= spi1_sendcommand;
                next_state <= rd_reg_flag_cfg_state2;
                reg8 <= wr_enable;
                reg40 <= {fast_program,ctrl_address};
                send_cnt <= 16'd5;
                program_flag <= 1'b1;
                if((program_byte_count+start_address-ctrl_address)<256)
                    rec_cnt <= (program_byte_count+start_address-ctrl_address);
                else
                    rec_cnt <= 256;
            end  
        rd_reg_flag_cfg_state2: 
            begin
                current_state <= spi1_sendword;     
                next_state <= judge_program_state;
                reg40 <= {rd_reg_flag,32'd0};
                send_cnt <= 16'd1;
                rec_cnt <= 16'd1;
            end          
        judge_program_state:
            begin
                if(reg40[7]==1)
                    if ( (ctrl_address+256)<(program_byte_count + start_address) ) begin   //page program,one page=256bytes  
                        ctrl_address <= ctrl_address + 10'd256;
                        current_state <= program_state;
                    end
                    else begin
                        ctrl_address <= start_address;
                        current_state <= end_state;
                        program_done <= 1'b1;
                    end
                else
                    current_state <= rd_reg_flag_cfg_state2;                
            end 
//        read_state:
//            begin
//            if (read_en==1) begin
//                current_state <= spi1_4_sendword;     
//                next_state <= end_state;
//                reg40 <= {fast_read,32'h01000000};
//                send_cnt <= 16'd5;
//                rec_cnt <= 16'd1000;
//            end
//            else
//                current_state <= read_state;
//            end    
        end_state:
            begin            
                current_state <= IDLE;
            end
////////////////////////   
        spi1_sendcommand:
            begin
                bir <= 4'b1101;
                if(cnt<8) begin 
                    cnt<=cnt+1'b1; 
                    qspi_csb<=1'b0; 
                    qspi_dout[3:2] <= 2'b11;
                    qspi_dout[0] <= reg8[7];
                    reg8 <= {reg8[6:0],1'd0};
                    current_state <= spi1_sendcommand;
                end       
                else begin
                    qspi_csb<=1'b1;
                    cnt<=16'd0;
                    if(program_flag==1)
                        current_state <= spi1_4_sendword;
                    else
                        current_state <= spi1_sendword;
                end
            end
        spi1_sendword:
            begin
                if(cnt<(send_cnt<<3)) begin  //send
                    cnt<=cnt+1'b1; 
                    qspi_csb<=1'b0; 
                    bir <= 4'b1101;
                    qspi_dout[3:2] <= 2'b11;
                    qspi_dout[0] <= reg40[39];
                    reg40 <= {reg40[38:0],1'd0};
                    current_state<=spi1_sendword;
                end
                else begin
                    bir <= 4'b1101;
                    qspi_dout[3:2] <= 2'b11;
                    reg40 <= {reg40[38:0],qspi_din[1]};
                    if(cnt<((send_cnt+rec_cnt)<<3)) begin          //spix4
                        qspi_csb<=1'b0;
                        cnt<=cnt+1'b1;
                        current_state<=spi1_sendword;
                    end
                    else begin
                        qspi_csb<=1'b1;
                        cnt<=16'd0; 
                        current_state<=next_state;
                    end 
                end
            end
        spi1_4_sendword:
            begin
                if(cnt<(send_cnt<<3)) begin  //send
                    cnt<=cnt+1'b1; 
                    qspi_csb<=1'b0;         
                    qspi_dout[0] <= reg40[39];
                    reg40 <= {reg40[38:0],1'd0};
                    current_state <= spi1_4_sendword;
                    if(program_flag==1) begin
                        bir <= 4'b0001; 
                        if(cnt==((send_cnt<<3)-1))
                            data_in_flag <= 1'b1;
                        else
                            data_in_flag <= 1'b0;    
                    end 
                    else
                        begin bir <= 4'b1001; qspi_dout[3] <= 1'b1; end   
                end
                else begin
                    if(program_flag==1) begin 
                        bir<=4'b1111; 
                        qspi_dout <= data_in; 
                        if(cnt==((send_cnt<<3)+(rec_cnt<<1)-1))
                            data_in_flag <= 1'b0;
                        else
                            data_in_flag <= data_in_flag; 
                    end
                    else begin 
                        bir<=4'b0000; 
                        reg40 <= {reg40[35:0],qspi_din}; 
                    end  
                    
                    if(cnt<((send_cnt<<3)+(rec_cnt<<1))) begin          //spix4
                        cnt<=cnt+1'b1;
                        current_state<=spi1_4_sendword;
                        qspi_csb<=1'b0;
                    end
                    else begin
                        cnt<=16'd0; 
                        current_state<=next_state;
                        qspi_csb<=1'b1;
                        program_flag <= 1'b0;
                    end 
                 end
            end
 ////////
        default:
            begin
                current_state <= IDLE; 
            end
        endcase  
    end 
  end 
  
  ila_6 ila_inst (
    .clk(inclk),    
    .probe0(program_done),
    .probe1(current_state)
    );
 
endmodule
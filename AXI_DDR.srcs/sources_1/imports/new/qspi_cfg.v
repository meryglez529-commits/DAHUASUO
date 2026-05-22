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
    input               inclk,
    input               inReset_EnableB,
    input               qspi_cfg_en,
//-------------ex -------------------
    input       [31:0]  program_byte_count,
    output reg          data_in_flag,
    input       [3:0]   data_in,
    output reg  [31:0]  remote_result,
    output reg          remote_complete,
    input               read_flash_flag,
    input[7:0]          flash_type_in,
    output      reg     write_rom_flag,
    output reg[7:0]     write_rom_data,
//-------------QSPI_CFG_PIN-------------------------------
    inout               qspi_d0,
    inout               qspi_d1,  
    inout               qspi_d2, 
    inout               qspi_d3,
    output reg          qspi_csb,
    output              qspi_clk
    );
 //   
 reg[2:0]  read_flash_flag_reg;
 always@(posedge inclk or negedge inReset_EnableB)
  begin
    if(!inReset_EnableB) begin
    	 read_flash_flag_reg <= 3'b0;
     end
     else begin
     	 read_flash_flag_reg[2] <= read_flash_flag_reg[1];
     	 read_flash_flag_reg[1] <= read_flash_flag_reg[0];
     	 read_flash_flag_reg[0] <= read_flash_flag;
     	end  	
  end 
    
 reg[7:0]  flash_type_in_reg[0:2];
 always@(posedge inclk or negedge inReset_EnableB)
  begin
    if(!inReset_EnableB) begin
    	 {flash_type_in_reg[2],flash_type_in_reg[1],flash_type_in_reg[0]} <= 24'b0;
     end
     else begin
     	 {flash_type_in_reg[2],flash_type_in_reg[1],flash_type_in_reg[0]} <= {flash_type_in_reg[1],flash_type_in_reg[0],flash_type_in};  	
  	 end
  end  

reg[7:0] get_flash_type;
always@(posedge inclk or negedge inReset_EnableB)
  begin
    if(!inReset_EnableB) begin
    	 get_flash_type <= 8'b0;
     end
     else if(read_flash_flag_reg[2] == 1'b1 && flash_type_in_reg[2] < 8'd2)begin
     	  get_flash_type <= flash_type_in_reg[2];
     end
     else 
 				get_flash_type <= get_flash_type;
  end 
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
//--------------------------------------------------------------------
  localparam wr_enable              =8'h06;
//  localparam reset_enable           =8'h66;
//  localparam reset_memory           =8'h99;
//  localparam read_id                =8'h9F;
  localparam MT25QL256_ID           =24'h20BA19;
  localparam S25FL256_ID            =16'h0118;//24'h20BA19--
  localparam IS25LP256D_ID          =16'h6019;//24'h20BA19--
//  localparam clear_reg_flag         =8'h50;
//  localparam wr_reg_cfg             =8'h81;             //write volatile configuration register
//  localparam sector_erase           =8'hDC;
//  localparam rd_reg_flag            =8'h70;
//  localparam fast_program           =8'h34;
  localparam fast_read              =8'h6C;
  localparam start_address          =32'h01000000; 
  reg [4:0] current_state;
  reg [4:0] next_state;
  parameter IDLE                        = 5'd1;
  parameter reset_state                 = 5'd2;
  parameter rdid_state                  = 5'd3; 
  parameter checkid_state               = 5'd4;
  parameter clear_reg_flag_state        = 5'd5;
  parameter wr_reg_cfg_state            = 5'd6;
  parameter erase_state                 = 5'd7;
  parameter rd_reg_flag_cfg_state1      = 5'd8;
  parameter judge_erase_state           = 5'd9;
  parameter program_state               = 5'd10;
  parameter rd_reg_flag_cfg_state2      = 5'd11;
  parameter judge_program_state         = 5'd12;
  parameter end_state                   = 5'd13;
  parameter spi1_sendcommand            = 5'd14;
  parameter spi1_sendword               = 5'd15;
  parameter spi1_4_sendword             = 5'd16;
  
  reg [15:0]    send_cnt;
  reg [15:0]    rec_cnt;
  reg [15:0]    cnt; 
  reg [7:0]     reg8;
  reg [39:0]    reg40;
  reg [31:0]    ctrl_address;
  reg           program_flag;
  reg [2:0]     qspi_cfg_en_reg;
  /*********************************/
  reg[7:0]  reset_enable  ;
  reg[7:0]  read_id       ;
  reg[7:0]  clear_reg_flag;
  reg[7:0]  wr_reg_cfg    ;
  reg[7:0]  sector_erase  ;
  reg[7:0]  rd_reg_flag   ;
  reg[7:0]  fast_program  ;
  reg[7:0]  config_reg    ;
  reg[7:0]  reset_memory  ;
  reg[1:0]  flash_type     ;//1-MT25QL256,0-S25FL256,2-IS25LP256D;
  reg wr_ready  ;
  reg[2:0] judge_ready_bit;
  reg[2:0] judge_erase_bit;
  reg[2:0] judge_program_bit;
  /********* 
  assign reset_memory           = ( flash_type ==2'd1 )?  8'h99 : 8'h00 ;
  assign reset_enable           = ( flash_type ==2'd1 )?  8'h66 : 8'hF0 ;  
  assign read_id                = ( flash_type ==2'd1 )?  8'h9F : 8'h90 ;
  assign clear_reg_flag         = ( flash_type ==2'd1 )?  8'h50 : 8'h30 ;
  assign wr_reg_cfg             = ( flash_type ==2'd1 )?  8'h81 : 8'h17 ;             //write volatile configuration register
  assign sector_erase           = ( flash_type ==2'd1 )?  8'hDC : 8'hD8 ;
  assign rd_reg_flag            = ( flash_type ==2'd1 )?  8'h70 : 8'h05 ;
  assign fast_program           = ( flash_type ==2'd1 )?  8'h34 : 8'h32 ;
  assign config_reg             = ( flash_type ==2'd1 )?  8'h4B : 8'h80 ;
  //ÅÐ¶Ï±êÖ¾
  assign  wr_ready = ( flash_type ==2'd1 )?  1 : 0 ;
  assign  judge_ready_bit = ( flash_type ==2'd1 )?  3'd7 : 3'd0 ;
  assign  judge_erase_bit = 3'd5  ;
  assign  judge_program_bit = ( flash_type ==2'd1 )?  3'd4 : 3'd6 ;
  **************************/
  always@ (*)
  begin
  	case(flash_type)
  	2'b00:begin
  	      		reset_memory       =    8'h00 ;
  	      		reset_enable       =    8'hF0 ;
  	      		read_id            =    8'h90 ;
  	      		clear_reg_flag     =    8'h30 ;
  	      		wr_reg_cfg         =    8'h17 ;
  	      		sector_erase       =    8'hD8 ;
  	      		rd_reg_flag        =    8'h05 ;
  	      		fast_program       =    8'h32 ;
  	      		config_reg         =    8'h80 ;
  	      		wr_ready           =    1'b0  ;
  	      		judge_ready_bit    =    3'd0  ;
  	      		judge_erase_bit    =    3'd5  ;
  	      		judge_program_bit  =    3'd6  ;
  	      end
	  	2'b01:begin
		      		reset_memory       =    8'h99 ;
		      		reset_enable       =    8'h66 ;
		      		read_id            =    8'h9F ;
		      		clear_reg_flag     =    8'h50 ;
		      		wr_reg_cfg         =    8'h81 ;
		      		sector_erase       =    8'hDC ;
		      		rd_reg_flag        =    8'h70 ;
		      		fast_program       =    8'h34 ;
		      		config_reg         =    8'h4B ;
		      		wr_ready           =    1'b1  ;
		      		judge_ready_bit    =    3'd7  ;
		      		judge_erase_bit    =    3'd5  ;
		      		judge_program_bit  =    3'd4  ;
	      end
  	  2'b10:begin
		      		reset_memory       =    8'h99 ;
		      		reset_enable       =    8'h66 ;
		      		read_id            =    8'h9F ;
		      		clear_reg_flag     =    8'h82 ;
		      		wr_reg_cfg         =    8'h17 ;
		      		sector_erase       =    8'hDC ;
		      		rd_reg_flag        =    8'h81 ;
		      		fast_program       =    8'h34 ;
		      		config_reg         =    8'h80 ;
		      		wr_ready           =    1'b0  ;
		      		judge_ready_bit    =    3'd0  ;
		      		judge_erase_bit    =    3'd3  ;
		      		judge_program_bit  =    3'd2  ;
    end
  	default:begin
  	      		reset_memory       =    8'h00 ;
  	      		reset_enable       =    8'hF0 ;
  	      		read_id            =    8'h90 ;
  	      		clear_reg_flag     =    8'h30 ;
  	      		wr_reg_cfg         =    8'h17 ;
  	      		sector_erase       =    8'hD8 ;
  	      		rd_reg_flag        =    8'h05 ;
  	      		fast_program       =    8'h32 ;
  	      		config_reg         =    8'h80 ;
  	      		wr_ready           =    1'b0  ;
  	      		judge_ready_bit    =    3'd0  ;
  	      		judge_erase_bit    =    3'd5  ;
  	      		judge_program_bit  =    3'd6  ;
  	      end
  	endcase
  end
  /*********************************/
  reg[4:0]  write_rom_cnt; 
  always@(posedge inclk or negedge inReset_EnableB)
  begin
    if(!inReset_EnableB) begin 
        current_state   <= IDLE;
        next_state      <= IDLE; 
        send_cnt        <= 16'd0;
        rec_cnt         <= 16'd0;
        cnt             <= 16'd0;        
        reg8            <= 8'd0;
        reg40           <= 40'd0;
        ctrl_address    <= start_address;
        program_flag    <= 1'b0;
        qspi_csb        <= 1'b1;
        bir             <= 4'b1101;
        qspi_dout       <= 4'b1111;
        data_in_flag    <= 1'b0;
        remote_result   <= 32'd0;
        qspi_cfg_en_reg <= 3'd0;
        remote_complete <= 1'b0;
        flash_type      <= 2'b0;
        write_rom_cnt   <= 5'd0;
        write_rom_flag  <= 1'b0; 
    end 
    else begin
        qspi_cfg_en_reg <= {qspi_cfg_en_reg[1:0],qspi_cfg_en}; 
        case(current_state)
        IDLE:   begin
            if(qspi_cfg_en_reg[1]==1 && qspi_cfg_en_reg[2]==0)begin
                current_state   <= reset_state;
                flash_type      <=get_flash_type[1:0];
            end
            else begin
                current_state   <= IDLE;   
                next_state      <= IDLE; 
                send_cnt        <= 16'd0;
                rec_cnt         <= 16'd0;
                cnt             <= 16'd0;        
                reg8            <= 8'd0;
                reg40           <= 40'd0;
                ctrl_address    <= start_address;
                program_flag    <= 1'b0;
                qspi_csb        <= 1'b1;
                bir             <= 4'b1101;
                qspi_dout       <= 4'b1111;
                data_in_flag    <= 1'b0;
            end
        end
        reset_state:    begin
            current_state    <= spi1_sendcommand;
            next_state       <= rdid_state;
            reg8             <= reset_enable;
            reg40            <= {reset_memory,32'd0};
      //      send_cnt         <= 16'd1;
            rec_cnt          <= 16'd0;
            if(flash_type >= 2'd1)  // 
            		send_cnt         <= 16'd1;
            else
                send_cnt         <= 16'd0;
        end       
        rdid_state: begin
            current_state   <= spi1_sendword;
            next_state      <= checkid_state;          
            reg40           <= {read_id,32'd0};
//            send_cnt        <= 16'd1;
            if(flash_type >= 2'd1)begin
            		rec_cnt         <= 16'd3;
            		send_cnt        <= 16'd1;
            end
            else  begin
                rec_cnt         <= 16'd2;
                send_cnt        <= 16'd4;
            end
        end   
        checkid_state:  begin 
            if(flash_type == 2'd2)begin
		            if(reg40[15:0] == IS25LP256D_ID) 
		                current_state <= clear_reg_flag_state; 
		            else begin
		                current_state <= reset_state;
		                // remote_result <= 32'h01010101;
		                flash_type      <= 0 ;
		                next_state      <= IDLE; 
			              send_cnt        <= 16'd0;
			              rec_cnt         <= 16'd0;
			              cnt             <= 16'd0;        
			              reg8            <= 8'd0;
			              reg40           <= 40'd0;
			              ctrl_address    <= start_address;
			              program_flag    <= 1'b0;
			              qspi_csb        <= 1'b1;
			              bir             <= 4'b1101;
			              qspi_dout       <= 4'b1111;
			              data_in_flag    <= 1'b0;
		            end
		         end
        		else if(flash_type == 2'd1)begin
		            if(reg40[23:0] == MT25QL256_ID) 
		                current_state <= clear_reg_flag_state; 
		            else begin
		                current_state <= reset_state;
		                // remote_result <= 32'h01010101;
		                flash_type      <= 2 ;
		                next_state      <= IDLE; 
			              send_cnt        <= 16'd0;
			              rec_cnt         <= 16'd0;
			              cnt             <= 16'd0;        
			              reg8            <= 8'd0;
			              reg40           <= 40'd0;
			              ctrl_address    <= start_address;
			              program_flag    <= 1'b0;
			              qspi_csb        <= 1'b1;
			              bir             <= 4'b1101;
			              qspi_dout       <= 4'b1111;
			              data_in_flag    <= 1'b0;
		            end
		         end
		         else if(flash_type == 2'd0)begin
		            if(reg40[15:0] == S25FL256_ID) 
		                current_state <= clear_reg_flag_state; 
		            else begin
		                current_state <= reset_state;
		               // remote_result <= 32'h01010101;
		                flash_type      <= 1 ;
		                next_state      <= IDLE; 
			              send_cnt        <= 16'd0;
			              rec_cnt         <= 16'd0;
			              cnt             <= 16'd0;        
			              reg8            <= 8'd0;
			              reg40           <= 40'd0;
			              ctrl_address    <= start_address;
			              program_flag    <= 1'b0;
			              qspi_csb        <= 1'b1;
			              bir             <= 4'b1101;
			              qspi_dout       <= 4'b1111;
			              data_in_flag    <= 1'b0;
		            end		         	
		         end
		         else begin
	         		    current_state <= end_state;
	                remote_result <= 32'h01010101;
		         end     
        end
        clear_reg_flag_state:   begin                                       //4 dummy cycle 
            current_state   <= spi1_sendword;
            next_state      <= wr_reg_cfg_state;
            reg40           <= {clear_reg_flag,32'd0};
            send_cnt        <= 16'd1;
            rec_cnt         <= 16'd0;
        end      
        wr_reg_cfg_state:  begin                                      //4 dummy cycle
//            current_state   <= spi1_sendcommand;
            next_state      <= erase_state;
//            reg8            <= wr_enable;
            reg40           <= {wr_reg_cfg,config_reg,24'd0};
            send_cnt        <= 16'd2;
            rec_cnt         <= 16'd0;
            if(flash_type == 2'd1)begin
            		reg8            <= wr_enable;
            		current_state   <= spi1_sendcommand;
            end
            else begin
            		current_state   <= spi1_sendword;
            end
        end              
        erase_state:    begin
            current_state   <= spi1_sendcommand;     
            next_state      <= rd_reg_flag_cfg_state1;
            reg8            <= wr_enable;
            reg40           <= {sector_erase,ctrl_address};
            send_cnt        <= 16'd5;
            rec_cnt         <= 16'd0;
        end
        rd_reg_flag_cfg_state1: begin
            current_state   <= spi1_sendword;    
            next_state      <= judge_erase_state;
            reg40           <= {rd_reg_flag,32'd0};
            send_cnt        <= 16'd1;
            rec_cnt         <= 16'd1;
        end   
        judge_erase_state: begin
            if(reg40[judge_ready_bit]==wr_ready)
                if(reg40[judge_erase_bit]==0)
                    if (ctrl_address>=32'h01FF0000) begin
                        ctrl_address    <= start_address;
                        current_state   <= program_state;  
                    end
                    else begin
                        ctrl_address    <= ctrl_address + 20'd65536;    //sector erase,one sector = 64KB = 65536bytes
                        current_state   <= erase_state;
                    end
                else begin
                    current_state <= spi1_sendword;     //clear flag status register
                    next_state  <= erase_state;
                    reg40       <= {clear_reg_flag,32'd0};
                    send_cnt    <= 16'd1;
                    rec_cnt     <= 16'd0;
                end
            else
                current_state   <= rd_reg_flag_cfg_state1;                
        end
        program_state:  begin                                  //quad input fast program  32
            current_state   <= spi1_sendcommand;
            next_state      <= rd_reg_flag_cfg_state2;
            reg8            <= wr_enable;
            reg40           <= {fast_program,ctrl_address};
            send_cnt        <= 16'd5;
            program_flag    <= 1'b1;
            if((program_byte_count+start_address-ctrl_address)<256)
                rec_cnt <= (program_byte_count+start_address-ctrl_address);
            else
                rec_cnt <= 256;
        end  
        rd_reg_flag_cfg_state2: begin 
            current_state   <= spi1_sendword;     
            next_state      <= judge_program_state;
            reg40           <= {rd_reg_flag,32'd0};
            send_cnt        <= 16'd1;
            rec_cnt         <= 16'd1;
        end          
        judge_program_state:    begin
            if(reg40[judge_ready_bit]==wr_ready )
                if(reg40[judge_program_bit]==0)
                    if ( (ctrl_address+256)<(program_byte_count + start_address) ) begin   //page program,one page=256bytes  
                        ctrl_address    <= ctrl_address + 10'd256;
                        current_state   <= program_state;
                    end
                    else begin
                        ctrl_address    <= start_address;
                        current_state   <= end_state;
                        remote_result   <= 32'h02020202;
                        remote_complete <= 1'b1;
                    end
                else begin
                    ctrl_address        <= start_address;
                    current_state       <= end_state;
                    remote_result       <= 32'h03030303;
                end       
            else
                current_state           <= rd_reg_flag_cfg_state2;                
        end   
        end_state:  begin 
        	 remote_complete <= 1'b0;
        	 write_rom_data  <= {6'd0,flash_type};
        	 if(write_rom_cnt > 5'd15 )begin
        	 	   write_rom_cnt   <= 5'd0;
        	 	   current_state <= IDLE;
        	 	   write_rom_flag  <= 1'b0; 
        	 end
        	 else begin
        	 	   write_rom_cnt   <= write_rom_cnt + 1'b1;
        	 	   write_rom_flag  <= 1'b1;
           end
        end
////////////////////////   
        spi1_sendcommand:   begin
            bir <= 4'b1101;
            if(cnt<8) begin 
                cnt             <=cnt+1'b1; 
                qspi_csb        <=1'b0; 
                qspi_dout[3:2]  <= 2'b11;
                qspi_dout[0]    <= reg8[7];
                reg8            <= {reg8[6:0],1'd0};
                current_state   <= spi1_sendcommand;
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
        spi1_sendword:  begin
            if(cnt<(send_cnt<<3)) begin  //send
                cnt             <= cnt+1'b1; 
                qspi_csb        <= 1'b0; 
                bir             <= 4'b1101;
                qspi_dout[3:2]  <= 2'b11;
                qspi_dout[0]    <= reg40[39];
                reg40           <= {reg40[38:0],1'd0};
                current_state   <= spi1_sendword;
            end
            else begin
                bir             <= 4'b1101;
                qspi_dout[3:2]  <= 2'b11;
                reg40           <= {reg40[38:0],qspi_din[1]};
                if(cnt<((send_cnt+rec_cnt)<<3)) begin          //spix4
                    qspi_csb        <= 1'b0;
                    cnt             <= cnt+1'b1;
                    current_state   <= spi1_sendword;
                end
                else begin
                    qspi_csb        <= 1'b1;
                    cnt             <= 16'd0; 
                    current_state   <= next_state;
                end 
            end
        end
        spi1_4_sendword:    begin
            if(cnt<(send_cnt<<3)) begin  //send
                cnt                 <= cnt+1'b1; 
                qspi_csb            <= 1'b0;         
                qspi_dout[0]        <= reg40[39];
                reg40               <= {reg40[38:0],1'd0};
                current_state       <= spi1_4_sendword;
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
        default:    begin current_state <= IDLE; end
        endcase  
    end 
  end 
 
ila_4 remote_inst(
    .clk(inclk),
    .probe0(qspi_cfg_en),//1
    .probe1(reg40),//40
    .probe2(flash_type),//2
    .probe3(current_state),//5
    .probe4(reg8 ),//8 
    .probe5(flash_type_in ),//8 
    .probe6(read_flash_flag )//
    ); 
 
endmodule
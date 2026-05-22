`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/09 13:38:47
// Design Name: 
// Module Name: WR_RD_REG_TOP
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


module WR_RD_REG_TOP#(
 parameter ILA_DEBUG = 1'b0
)(
        input     tx_fifo_clock,
        input     reset_n,

        input           chn0_rep_done,
        input           chn1_rep_done,
        input           chn2_rep_done,
        input           chn3_rep_done,
        
        output              reg_clk,
        output              reg_valid,
        output  reg [31:0]  reg0x0010_o = 0,       // W/R
        output      [31:0]  reg0x0011_o,  
        output  reg [31:0]  reg0x0012_o = 0,  
        output  reg [31:0]  reg0x0013_o = 0,  
        output  reg [31:0]  reg0x0014_o = 32'h0000_0000,  
        output  reg [31:0]  reg0x0015_o = 32'h0000_0000,  
        output      [31:0]  reg0x0016_o,     //
        output  reg [31:0]  reg0x0017_o = 0,  
        output  reg [31:0]  reg0x0018_o = 0,  
        output  reg [31:0]  reg0x0019_o = 0,  
        output  reg [31:0]  reg0x0020_o = 0,  
        output  reg [31:0]  reg0x0021_o = 0,  
        output  reg [31:0]  reg0x0022_o = 0,  
        output  reg [31:0]  reg0x0023_o = 0,  
        output  reg [31:0]  reg0x0024_o = 0,  
        output  reg [31:0]  reg0x0025_o = 0,  
        output  reg [31:0]  reg0x0026_o = 0,  
        output  reg [31:0]  reg0x0040_o = 0,  
        output  reg [31:0]  reg0x0041_o = 0,  
        output  reg [31:0]  reg0x0042_o = 0,  
        output  reg [31:0]  reg0x0043_o = 0,  
        output  reg [31:0]  reg0x0044_o = 0,  
        output  reg [31:0]  reg0x0049_o = 0,  
        output  reg [31:0]  reg0x004A_o = 0,  
        output  reg [31:0]  reg0x004B_o = 0,  
        output  reg [31:0]  reg0x004C_o = 0,  
        output  reg [31:0]  reg0x0051_o = 32'h0000_0000,  
        output  reg [31:0]  reg0x0052_o = 32'h0000_0000,  
        output  reg [31:0]  reg0x0055_o = 0,  
        output  reg [31:0]  reg0x0056_o = 0,  
        
        input       [31:0]  reg0x0000_i,         //R
        input       [31:0]  reg0x0001_i,
        input       [31:0]  reg0x0002_i,
        input       [31:0]  reg0x0003_i,
        input       [31:0]  reg0x0004_i,
        input       [31:0]  reg0x0005_i,
        input       [31:0]  reg0x0006_i,
        input       [31:0]  reg0x0007_i,
        input       [31:0]  reg0x0008_i,
        input       [31:0]  reg0x0009_i,
        input       [31:0]  reg0x000A_i,
        input       [31:0]  reg0x000B_i,
        
        
        input      [15:0]   LAN_DATA_NUM_i,
        input      [3:0]    LAN_RX_TYPE_i,     //receive type sel
	     input               lan_data_valid_i,   //byte data valid
	     input      [7:0]    lan_data_i,    //byte data
	    
	     output              RD_REG_req_o,
        input               RD_ACK_i,
        output     [15:0]   LAN_DATA_NUM_o,
        output              lan_data_valid_o,
        output     [7:0]    lan_data_o
    );

wire [31:0] reg0x0000_i_s;    
wire [31:0] reg0x0001_i_s;    
wire [31:0] reg0x0002_i_s;    
wire [31:0] reg0x0003_i_s;    
wire [31:0] reg0x0004_i_s;    
wire [31:0] reg0x0005_i_s;    
wire [31:0] reg0x0006_i_s;    
wire [31:0] reg0x0007_i_s;    
wire [31:0] reg0x0008_i_s;    
wire [31:0] reg0x0009_i_s;    
wire [31:0] reg0x000A_i_s;    
wire [31:0] reg0x000B_i_s;    

assign reg0x0001_i_s = reg0x0001_i;
assign reg0x0004_i_s = reg0x0004_i;   //加载成功标记，不需要同步
assign reg0x0009_i_s = reg0x0009_i;
assign reg0x000A_i_s = reg0x000A_i;
assign reg0x000B_i_s = reg0x000B_i;
assign reg0x0008_i_s = reg0x0008_i;

async_reg async_reg_inst0 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0000_i),
   .dataout (reg0x0000_i_s)
); 

// async_reg async_reg_inst1 (
//    // Input Ports - Single Bit
//    .clk           (tx_fifo_clock),        
//    .clk_en        (reset_n),     
//    .datain  (reg0x0001_i),
//    .dataout (reg0x0001_i_s)
// );

async_reg async_reg_inst2 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0002_i),
   .dataout (reg0x0002_i_s)
);

async_reg async_reg_inst3 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0003_i),
   .dataout (reg0x0003_i_s)
);

// async_reg async_reg_inst4 (
//    // Input Ports - Single Bit
//    .clk           (tx_fifo_clock),        
//    .clk_en        (reset_n),     
//    .datain  (reg0x0008_i),
//    .dataout (reg0x0008_i_s)
// );

async_reg async_reg_inst5 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0005_i),
   .dataout (reg0x0005_i_s)
);

async_reg async_reg_inst6 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0006_i),
   .dataout (reg0x0006_i_s)
);

async_reg async_reg_inst7 (
   // Input Ports - Single Bit
   .clk           (tx_fifo_clock),        
   .clk_en        (reset_n),     
   .datain  (reg0x0007_i),
   .dataout (reg0x0007_i_s)
);

// rep_done_sync Outputs
wire  chn0_rep_done_s;
wire  chn1_rep_done_s;
wire  chn2_rep_done_s;
wire  chn3_rep_done_s;
wire  chn_rep_done_s;
wire [4:0] chn_rep;
assign chn_rep = {chn_rep_done_s,chn3_rep_done_s,chn2_rep_done_s,chn1_rep_done_s,chn0_rep_done_s};


reg        comb_indep_w  = 1'b0;
reg [3:0]  comb_indep_sw = 4'h0;
always@(posedge tx_fifo_clock)begin
     comb_indep_w  <= reg0x0020_o[0];  //mode switch
     comb_indep_sw <= reg0x0021_o[3:0];//mode select
end
rep_done_sync  u_rep_done_sync (
    .clk                     ( tx_fifo_clock     ),
    .comb_indep_w            ( comb_indep_w      ),
    .comb_indep_sw           ( comb_indep_sw     ),
    .chn0_rep_done           ( chn0_rep_done     ),
    .chn1_rep_done           ( chn1_rep_done     ),
    .chn2_rep_done           ( chn2_rep_done     ),
    .chn3_rep_done           ( chn3_rep_done     ),

    .chn0_rep_done_s         ( chn0_rep_done_s   ),
    .chn1_rep_done_s         ( chn1_rep_done_s   ),
    .chn2_rep_done_s         ( chn2_rep_done_s   ),
    .chn3_rep_done_s         ( chn3_rep_done_s   ),
    .chn_rep_done_s          ( chn_rep_done_s    )
);
    
wire        WR_REG_VALID_w;
wire [15:0] WR_REG_ADDR_w;
wire [31:0] WR_REG_DATA_w;
reg         WR_REG_VALID = 1'b0;
reg [15:0]  WR_REG_ADDR = 16'd0;
reg [31:0]  WR_REG_DATA = 32'd0;

reg sys_rst = 1'b0;
always@(posedge tx_fifo_clock)  //write 
   if(WR_REG_VALID_w && WR_REG_ADDR_w == 16'h0016 && WR_REG_DATA_w == 32'h0000_0001)
      sys_rst <= 1'b1;
   else if(WR_REG_VALID_w && WR_REG_ADDR_w == 16'h0016 && WR_REG_DATA_w == 32'h0000_0000)
      sys_rst <= 1'b0;
   else
   begin
      WR_REG_VALID <= WR_REG_VALID_w;
      WR_REG_ADDR  <= WR_REG_ADDR_w;
      WR_REG_DATA  <= WR_REG_DATA_w;
   end
assign reg0x0016_o = {31'd0,sys_rst};


reg       chn_valid = 1'b0;
reg [4:0] chn_start = 1'b0;
always@(posedge tx_fifo_clock)
if(!reset_n)begin
   chn_start <= 5'b00000;
   chn_valid <= 1'b0;
end
else if(WR_REG_VALID && WR_REG_ADDR == 16'h0011)begin
   chn_start <= WR_REG_DATA[4:0];
   chn_valid <= 1'b1;
end
else case(chn_rep)
   5'b00001:begin
      if(!comb_indep_w)begin
         chn_start <= {chn_start[4:1],1'b0};
         chn_valid <= 1'b1;
      end
      else begin
         chn_start <= chn_start;
         chn_valid <= chn_valid;
      end
   end
   5'b00010:begin
      if(!comb_indep_w)begin
         chn_start <= {chn_start[4:2],1'b0,chn_start[0]};
         chn_valid <= 1'b1;
      end
      else begin
         chn_start <= chn_start;
         chn_valid <= chn_valid;
      end
   end
   5'b00100:begin
      if(!comb_indep_w)begin
         chn_start <= {chn_start[4:3],1'b0,chn_start[1:0]};
         chn_valid <= 1'b1;
      end
      else begin
         chn_start <= chn_start;
         chn_valid <= chn_valid;
      end
   end
   5'b01000:begin
      if(!comb_indep_w)begin
         chn_start <= {chn_start[4],1'b0,chn_start[2:0]};
         chn_valid <= 1'b1;
      end
      else begin
         chn_start <= chn_start;
         chn_valid <= chn_valid;
      end
   end
   5'b10000:begin                  //combine mode
      if(comb_indep_w)begin
         chn_start <= {1'b0,chn_start[3:0]};
         chn_valid <= 1'b1;
      end
      else begin
         chn_start <= chn_start;
         chn_valid <= chn_valid;
      end
   end
   default:begin
      chn_start <= chn_start;
      chn_valid <= 1'b0;
   end
endcase


assign reg0x0011_o = {27'd0,chn_start};

wire        RD_REG_VALID;
wire [15:0] RD_REG_ADDR;

reg        TX_REG_VALID = 0;
reg [15:0] TX_REG_ADDR = 0;
reg [31:0] TX_REG_DATA = 0;
reg         reg_data_valid = 1'b0;
reg         reg_data_valid_r0 = 1'b0;
reg         reg_data_valid_r1 = 1'b0;
always@(posedge tx_fifo_clock)
    begin
       reg_data_valid_r0 <= reg_data_valid || chn_valid; 
       reg_data_valid_r1 <= reg_data_valid_r0; 
    end
assign reg_valid = reg_data_valid_r1 | reg_data_valid_r0;
assign reg_clk = tx_fifo_clock;

// reg [31:0] reg0x0004_o = 32'h00000000;
// reg [31:0] reg0x0009_o = 32'h00000000;
// reg [31:0] reg0x000A_o = 32'h00000000;
// reg [31:0] reg0x000B_o = 32'h00000000;
// (* dont_touch="true" *)reg        clear_r = 1'b0;
always@(posedge tx_fifo_clock)  //write 
    if(!reset_n || sys_rst)
        begin
          reg_data_valid <= 1'b0;
         //  reg0x0004_o <= 32'h00000000;
         //  reg0x0009_o <= 32'h00000000;
         //  reg0x000A_o <= 32'h00000000;
         //  reg0x000B_o <= 32'h00000000;
         //  clear_r <= 1'b0;
          reg0x0010_o <= 0;  //wr
         //  reg0x0011_o <= 0;  
          reg0x0012_o <= 0;  
          reg0x0013_o <= 0;  
          reg0x0014_o <= 32'h0000_0000;  
          reg0x0015_o <= 32'h0000_0000;  
         //  reg0x0016_o <= 0;  
          reg0x0017_o <= 0;  
          reg0x0018_o <= 0;  
          reg0x0019_o <= 0;  
          reg0x0020_o <= 0;  
          reg0x0021_o <= 0;  
          reg0x0022_o <= 0;  
          reg0x0023_o <= 0;  
          reg0x0024_o <= 0; 
          reg0x0025_o <= 0; 
          reg0x0026_o <= 0; 
          reg0x0040_o <= 0;  
          reg0x0041_o <= 0;  
          reg0x0042_o <= 0;  
          reg0x0043_o <= 0;  
          reg0x0044_o <= 0;  
          reg0x0049_o <= 0;  
          reg0x004A_o <= 0;  
          reg0x004B_o <= 0;  
          reg0x004C_o <= 0;
          reg0x0051_o <= 32'h0000_0000;
          reg0x0052_o <= 32'h0000_0000;
          reg0x0055_o <= 0;
          reg0x0056_o <= 0;
        end
    else if(WR_REG_VALID) 
    case(WR_REG_ADDR)
      //   16'h0004:begin reg0x0004_o <= WR_REG_DATA; clear_r <= 1'b1; end
      //   16'h0009:begin reg0x0009_o <= WR_REG_DATA; clear_r <= 1'b1; end
      //   16'h000A:begin reg0x000A_o <= WR_REG_DATA; clear_r <= 1'b1; end
      //   16'h000B:begin reg0x000B_o <= WR_REG_DATA; clear_r <= 1'b1; end

        16'h0010:begin reg0x0010_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
      //   16'h0011:begin reg0x0011_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0012:begin reg0x0012_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0013:begin reg0x0013_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0014:begin reg0x0014_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0015:begin reg0x0015_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
      //   16'h0016:begin reg0x0016_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0017:begin reg0x0017_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0018:begin reg0x0018_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0019:begin reg0x0019_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0020:begin reg0x0020_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0021:begin reg0x0021_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0022:begin reg0x0022_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0023:begin reg0x0023_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0024:begin reg0x0024_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0025:begin reg0x0025_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0026:begin reg0x0026_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0040:begin reg0x0040_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0041:begin reg0x0041_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0042:begin reg0x0042_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0043:begin reg0x0043_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0044:begin reg0x0044_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0049:begin reg0x0049_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h004A:begin reg0x004A_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h004B:begin reg0x004B_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h004C:begin reg0x004C_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0051:begin reg0x0051_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0052:begin reg0x0052_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0055:begin reg0x0055_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        16'h0056:begin reg0x0056_o <= WR_REG_DATA; reg_data_valid <= 1'b1; end
        default:begin
         //  clear_r     <= 1'b0;
         //  reg0x0004_o <= reg0x0004_o;  //wr
         //  reg0x0009_o <= reg0x0009_o;  //wr
         //  reg0x000A_o <= reg0x000A_o;  //wr
         //  reg0x000B_o <= reg0x000B_o;  //wr

          reg0x0010_o <= reg0x0010_o;  
         //  reg0x0011_o <= reg0x0011_o;  
          reg0x0012_o <= reg0x0012_o;  
          reg0x0013_o <= reg0x0013_o;  
          reg0x0014_o <= reg0x0014_o;  
          reg0x0015_o <= reg0x0015_o;  
         //  reg0x0016_o <= reg0x0016_o;  
          reg0x0017_o <= reg0x0017_o;  
          reg0x0018_o <= reg0x0018_o;  
          reg0x0019_o <= reg0x0019_o;  
          reg0x0020_o <= reg0x0020_o;  
          reg0x0021_o <= reg0x0021_o;  
          reg0x0022_o <= reg0x0022_o;  
          reg0x0023_o <= reg0x0023_o;  
          reg0x0024_o <= reg0x0024_o;  
          reg0x0025_o <= reg0x0025_o;  
          reg0x0026_o <= reg0x0026_o;  
          reg0x0040_o <= reg0x0040_o;  
          reg0x0041_o <= reg0x0041_o;  
          reg0x0042_o <= reg0x0042_o;  
          reg0x0043_o <= reg0x0043_o;  
          reg0x0044_o <= reg0x0044_o;  
          reg0x0049_o <= reg0x0049_o;  
          reg0x004A_o <= reg0x004A_o;  
          reg0x004B_o <= reg0x004B_o;  
          reg0x004C_o <= reg0x004C_o; 
          reg0x0051_o <= reg0x0051_o; 
          reg0x0052_o <= reg0x0052_o; 
          reg0x0055_o <= reg0x0055_o; 
          reg0x0056_o <= reg0x0056_o; 
          reg_data_valid <= 1'b0;
        end
    endcase
    else begin
          reg_data_valid <= 1'b0;
         //  clear_r        <= 1'b0;
         //  reg0x0004_o <= reg0x0004_o;  //wr
         //  reg0x0009_o <= reg0x0009_o;  //wr
         //  reg0x000A_o <= reg0x000A_o;  //wr
         //  reg0x000B_o <= reg0x000B_o;  //wr

          reg0x0010_o <= reg0x0010_o;  //wr
         //  reg0x0011_o <= reg0x0011_o;  
          reg0x0012_o <= reg0x0012_o;  
          reg0x0013_o <= reg0x0013_o;  
          reg0x0014_o <= reg0x0014_o;  
          reg0x0015_o <= reg0x0015_o;  
         //  reg0x0016_o <= reg0x0016_o;  
          reg0x0017_o <= reg0x0017_o;  
          reg0x0018_o <= reg0x0018_o;  
          reg0x0019_o <= reg0x0019_o;  
          reg0x0020_o <= reg0x0020_o;  
          reg0x0021_o <= reg0x0021_o;  
          reg0x0022_o <= reg0x0022_o;  
          reg0x0023_o <= reg0x0023_o;  
          reg0x0024_o <= reg0x0024_o;  
          reg0x0025_o <= reg0x0025_o;  
          reg0x0026_o <= reg0x0026_o;  
          reg0x0040_o <= reg0x0040_o;  
          reg0x0041_o <= reg0x0041_o;  
          reg0x0042_o <= reg0x0042_o;  
          reg0x0043_o <= reg0x0043_o;  
          reg0x0044_o <= reg0x0044_o;  
          reg0x0049_o <= reg0x0049_o;  
          reg0x004A_o <= reg0x004A_o;  
          reg0x004B_o <= reg0x004B_o;  
          reg0x004C_o <= reg0x004C_o; 
          reg0x0051_o <= reg0x0051_o; 
          reg0x0052_o <= reg0x0052_o; 
          reg0x0055_o <= reg0x0055_o; 
          reg0x0056_o <= reg0x0056_o;
      end

// wire [31:0] reg0x0004;
// wire [31:0] reg0x0009;
// wire [31:0] reg0x000A;
// wire [31:0] reg0x000B;
// load_flag  u_load_flag0 (
//     .tx_fifo_clock           ( tx_fifo_clock   ),
//     .reset_n                 ( reset_n         ),
//     .clear_r                 ( clear_r         ),
//     .start                   ( reg0x0004_o[8]  ),
//     .reg_in                  ( reg0x0004_i_s   ),
//     .reg_out                 ( reg0x0004        )
// );

// load_flag  u_load_flag1 (
//     .tx_fifo_clock           ( tx_fifo_clock   ),
//     .reset_n                 ( reset_n         ),
//     .clear_r                 ( clear_r         ),
//     .start                   ( reg0x0009_o[8]  ),
//     .reg_in                  ( reg0x0009_i_s   ),
//     .reg_out                 ( reg0x0009        )
// );

// load_flag  u_load_flag2 (
//     .tx_fifo_clock           ( tx_fifo_clock   ),
//     .reset_n                 ( reset_n         ),
//     .clear_r                 ( clear_r         ),
//     .start                   ( reg0x000A_o[8]  ),
//     .reg_in                  ( reg0x000A_i_s   ),
//     .reg_out                 ( reg0x000A        )
// );

// load_flag  u_load_flag3 (
//     .tx_fifo_clock           ( tx_fifo_clock   ),
//     .reset_n                 ( reset_n         ),
//     .clear_r                 ( clear_r         ),
//     .start                   ( reg0x000B_o[8]  ),
//     .reg_in                  ( reg0x000B_i_s   ),
//     .reg_out                 ( reg0x000B        )
// );



always@(posedge tx_fifo_clock)
    if(!reset_n)
        begin
            TX_REG_VALID <= 0;
            TX_REG_ADDR  <= 0;
            TX_REG_DATA  <= 0;
        end
    else if(RD_REG_VALID)
        case(RD_REG_ADDR)
            16'h0000:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0000;TX_REG_DATA <= reg0x0000_i_s;end
            16'h0001:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0001;TX_REG_DATA <= reg0x0001_i_s;end
            16'h0002:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0002;TX_REG_DATA <= reg0x0002_i_s;end
            16'h0003:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0003;TX_REG_DATA <= reg0x0003_i_s;end
            16'h0004:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0004;TX_REG_DATA <= reg0x0004_i_s;end
            16'h0005:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0005;TX_REG_DATA <= reg0x0005_i_s;end
            16'h0006:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0006;TX_REG_DATA <= reg0x0006_i_s;end
            16'h0007:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0007;TX_REG_DATA <= reg0x0007_i_s;end
            16'h0008:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0008;TX_REG_DATA <= reg0x0008_i_s;end
            16'h0009:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0009;TX_REG_DATA <= reg0x0009_i_s;end
            16'h000A:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h000A;TX_REG_DATA <= reg0x000A_i_s;end
            16'h000B:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h000B;TX_REG_DATA <= reg0x000B_i_s;end
            16'h0010:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0010;TX_REG_DATA <= reg0x0010_o;end
            16'h0011:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0011;TX_REG_DATA <= reg0x0011_o;end
            16'h0012:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0012;TX_REG_DATA <= reg0x0012_o;end
            16'h0013:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0013;TX_REG_DATA <= reg0x0013_o;end
            16'h0014:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0014;TX_REG_DATA <= reg0x0014_o;end
            16'h0015:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0015;TX_REG_DATA <= reg0x0015_o;end
            16'h0016:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0016;TX_REG_DATA <= reg0x0016_o;end
            16'h0017:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0017;TX_REG_DATA <= reg0x0017_o;end
            16'h0018:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0018;TX_REG_DATA <= reg0x0018_o;end
            16'h0019:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0019;TX_REG_DATA <= reg0x0019_o;end
            16'h0020:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0020;TX_REG_DATA <= reg0x0020_o;end
            16'h0021:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0021;TX_REG_DATA <= reg0x0021_o;end
            16'h0022:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0022;TX_REG_DATA <= reg0x0022_o;end
            16'h0023:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0023;TX_REG_DATA <= reg0x0023_o;end
            16'h0024:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0024;TX_REG_DATA <= reg0x0024_o;end
            16'h0025:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0025;TX_REG_DATA <= reg0x0025_o;end
            16'h0026:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0026;TX_REG_DATA <= reg0x0026_o;end
            16'h0040:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0040;TX_REG_DATA <= reg0x0040_o;end
            16'h0041:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0041;TX_REG_DATA <= reg0x0041_o;end
            16'h0042:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0042;TX_REG_DATA <= reg0x0042_o;end
            16'h0043:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0043;TX_REG_DATA <= reg0x0043_o;end
            16'h0044:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0044;TX_REG_DATA <= reg0x0044_o;end
            16'h0049:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0049;TX_REG_DATA <= reg0x0049_o;end
            16'h004A:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h004A;TX_REG_DATA <= reg0x004A_o;end
            16'h004B:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h004B;TX_REG_DATA <= reg0x004B_o;end
            16'h004C:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h004C;TX_REG_DATA <= reg0x004C_o;end
            16'h0051:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0051;TX_REG_DATA <= reg0x0051_o;end
            16'h0052:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0052;TX_REG_DATA <= reg0x0052_o;end
            16'h0055:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0055;TX_REG_DATA <= reg0x0055_o;end
            16'h0056:begin TX_REG_VALID <= 1'b1;TX_REG_ADDR <= 16'h0056;TX_REG_DATA <= reg0x0056_o;end
            default:begin
                TX_REG_VALID <= 0;
                TX_REG_ADDR  <= 0;
                TX_REG_DATA  <= 0;
            end
        endcase
    else begin
        TX_REG_VALID <= 0;
        TX_REG_ADDR  <= 0;
        TX_REG_DATA  <= 0;
    end       

LAN_WR_REG LAN_WR_REG_inst (
   // Input Ports - Single Bit
   .tx_fifo_clock        (tx_fifo_clock),
   .reset_n              (reset_n),           
        
   .lan_data_valid_i     (lan_data_valid_i), 
   .lan_data_i           (lan_data_i[7:0]),   
   .LAN_DATA_NUM_i       (LAN_DATA_NUM_i[15:0]),
   .LAN_RX_TYPE_i        (LAN_RX_TYPE_i[3:0]),
   // Output Ports - Single Bit
   .WR_REG_VALID_o          (WR_REG_VALID_w),       
   .WR_REG_ADDR_o           (WR_REG_ADDR_w[15:0]),  
   .WR_REG_DATA_o           (WR_REG_DATA_w[31:0]),
   
   .RD_REG_ADDR_o           (RD_REG_ADDR),
   .RD_REG_VALID_o          (RD_REG_VALID)  
);  
    
 LAN_RD_REG INST_LAN_RD_REG(   //return the data of addr
       .tx_fifo_clock(tx_fifo_clock),
       .reset_n(reset_n),
       
       .REG_VALID(TX_REG_VALID),
       .REG_ADDR(TX_REG_ADDR), 
       .REG_DATA(TX_REG_DATA),
       
       .RD_REG_req_o(RD_REG_req_o),
       .RD_ACK_i(RD_ACK_i),
       .LAN_DATA_NUM_o(LAN_DATA_NUM_o),
       .lan_data_valid_o (lan_data_valid_o),
       .lan_data_o(lan_data_o)
 );   

generate    
    if(ILA_DEBUG) begin:ila_debug   
     ila_reg_wr_rd inst_ila_reg_wr_rd (
      .clk(tx_fifo_clock), // input wire clk
      .probe0 (LAN_DATA_NUM_i[15:0]), // input wire [15:0] probe0  
      .probe1 (LAN_RX_TYPE_i[2:0]  ), // input wire [2:0]  probe1 
      .probe2 (lan_data_valid_i    ), // input wire [0:0]  probe2 
      .probe3 (lan_data_i[7:0]     ), // input wire [7:0]  probe3 
      .probe4 (RD_ACK_i            ), // input wire [0:0]  probe4 
      .probe5 (LAN_DATA_NUM_o[15:0]), // input wire [15:0] probe5 
      .probe6 (lan_data_valid_o    ), // input wire [0:0]  probe6 
      .probe7 (lan_data_o[7:0]     ), // input wire [7:0]  probe7 
      .probe8 (WR_REG_VALID_w      ), // input wire [0:0]  probe8 
      .probe9 (WR_REG_ADDR_w[15:0] ), // input wire [15:0] probe9 
      .probe10(WR_REG_DATA_w[31:0] ), // input wire [31:0] probe10 
      .probe11(RD_REG_VALID        ), // input wire [0:0]  probe11 
      .probe12(RD_REG_ADDR[15:0]   ), // input wire [15:0] probe12 
      .probe13(TX_REG_VALID        ), // input wire [0:0]  probe13 
      .probe14(TX_REG_ADDR[15:0]   ), // input wire [15:0] probe14 
      .probe15(TX_REG_DATA[31:0]   ), // input wire [31:0] probe15 
      .probe16(chn_start[4:0]      ), // input wire [4:0]  probe16 
      .probe17(chn0_rep_done_s     ), // input wire [0:0]  probe17 
      .probe18(chn1_rep_done_s     ), // input wire [0:0]  probe18 
      .probe19(chn2_rep_done_s     ), // input wire [0:0]  probe19 
      .probe20(chn3_rep_done_s     ), // input wire [0:0]  probe20 
      .probe21(chn_rep_done_s      ) // input wire [0:0]   probe21
  );
end
endgenerate  
 
    
endmodule

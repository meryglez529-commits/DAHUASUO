`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/03/07 17:19:23
// Design Name: 
// Module Name: I2C_ADV7611_Config
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


`timescale 1ns/1ns
module	I2C_ADV7611_Config
(
    input       		clk,
	input       		rst_n,
	input       		I2C_config_done, //�?次IIC配置完成标志
	output reg  		I2C_EN,	   		//启动IIC配置 配置配置数量为LUT_size
	output reg  		I2C_RW_flag,		//读写标志 0 �? 1 �?
	input [7:0] 		I2C_rdata, 			//读取到的IIC数据
	input [9 :0]		LUT_INDEX,  		//查找表索�?
	output reg [23:0]	LUT_DATA,			//查找数据
	output reg [9 :0]	LUT_SIZE 			//次数
);

parameter  DEV_CHECK_SIZE=10'd1;//启动阶段�?查ID
parameter  S1_SIZE =10'd47;	//第一阶段配置寄存器数�?
parameter  S2_SIZE =10'd131;//第二阶段配置寄存器数�?
parameter  S3_SIZE =10'd3;	//第三阶段配置寄存器数�?
reg [23:0] S1_DATA=24'h0;	//IIC配置阶段数据
reg [23:0] S2_DATA=24'h0;
reg [23:0] S3_DATA=24'h0;
reg [23:0] DEV_CHECK_DATA=24'd0;

parameter IDLE           =4'd0;
parameter DEV_CHECK_START=4'd7;
parameter DEV_CHECK      =4'd8;
parameter S1             =4'd1;
parameter WAIT1          =4'd2;
parameter S2             =4'd3;
parameter WAIT2          =4'd4;
parameter S3             =4'd5;
parameter WAIT3          =4'd6;
parameter INIT_END       =4'd9;
//时钟分频
reg[19:0] clk_div_cnt;
reg       clk_div_en;
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n)begin
    clk_div_cnt <= 0;
	clk_div_en  <= 0;
  end
  else begin
    clk_div_cnt <= clk_div_cnt + 1;
	 if(clk_div_cnt==5000 )
	   clk_div_en <= 1;
	  else clk_div_en <= 0;
  end  
end
reg [3:0] state;
reg[29:0]wait_cnt;//等待计数
reg wait_en=0;
always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)begin wait_cnt <= 0;  end
  else if(wait_en) begin
    if(wait_cnt <=10_000000)
      wait_cnt <= wait_cnt + 1'b1;
	 else wait_cnt <= 0;
  end
  else wait_cnt <= 0;
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)begin
    state    	 <= IDLE;
    I2C_EN   	 <= 0;//使能
    wait_en  	 <= 0;//延时使能
	 LUT_SIZE 	 <= 0;
	 I2C_RW_flag <= 0;//读写标志
  end
  else begin
    if(clk_div_en)begin
    case(state)
	 IDLE:begin//模块复位后，即启动配�?
	   state   <= WAIT1;//DEV_CHECK_START;
		I2C_EN  <= 0;
		wait_en <= 1;
		LUT_SIZE <= 0;
	 end
	 WAIT1:begin
	   if(wait_cnt >= 1_000000)begin
		  wait_en  <= 0;
		  state    <= S1;
		  I2C_EN   <= 1;
		  I2C_RW_flag <= 0;
		  LUT_SIZE <= S1_SIZE;
		end
		else state <= state ;
	 end
	 S1:begin
	   if(I2C_config_done)begin//当前阶段配置完成，跳到下�?阶段
		  state <= WAIT3;
		  wait_en <= 1;		  
		  I2C_EN <= 0;
		end
		else state <= state ;
	 end	 
	 WAIT2:begin
	   if(wait_cnt>=5_000000)begin
		  wait_en <= 0;
		  state <= S2;
		  I2C_RW_flag <= 0;
		  I2C_EN <= 1;
		  LUT_SIZE <= S2_SIZE;
		end
		else state <= state ;
	 end
	 S2:begin
	   if(I2C_config_done)begin
		  state   <= DEV_CHECK_START;//整体配置完成，结�?
		  wait_en <= 0;
		  I2C_EN  <= 0;
		end
		else state <= state ;
	 end	 
	 WAIT3:begin
	   if(wait_cnt >= 1_000000)begin
		  wait_en <= 0;
		  state   <= S3;
		  I2C_RW_flag <= 0;
		  I2C_EN  <= 1;
		  LUT_SIZE <= S3_SIZE;
		end
		else state <= state ;
	 end
	 S3:begin
	   if(I2C_config_done)begin
		  state <= WAIT2;
		  wait_en <= 1;
		  I2C_EN <= 0;
		end
		else state <= state ;
	 end
	 //�?测芯片版本号
	 DEV_CHECK_START:begin		
		if(wait_cnt>=10000)begin
	      state   <= DEV_CHECK;
		   I2C_EN  <= 1;
		   wait_en<=0;
		   I2C_RW_flag <= 1;
		   LUT_SIZE <= 1;
		end		
	 end
	 DEV_CHECK:begin
	   if(I2C_config_done)begin
	     if(I2C_rdata==8'h80)begin
	       state   <= INIT_END;
			 I2C_EN  <= 0;
		    wait_en <= 1;
			 LUT_SIZE <= 0;		  
		  end
		  else begin
	       state   <= IDLE;
		   I2C_EN  <= 0;wait_en<=0;
		  end
		end
		else state <= state ;
	 end
	 INIT_END:begin
	   I2C_EN  <= 0;
	 end
	 default: state <= INIT_END;
	 endcase
	 end
	 else begin
	   state <= state;
		I2C_EN  <=I2C_EN;
	 end
  end
end
always @(posedge clk)
begin
  if(I2C_EN)
  begin
    case(state)
	  DEV_CHECK:begin LUT_DATA <= {8'h98,8'hf4,8'h00}; end
      S1:begin LUT_DATA <= S1_DATA;end
      S2:begin LUT_DATA <= S2_DATA;end
      S3:begin LUT_DATA <= S3_DATA;end
      default:begin LUT_DATA <= 0;end
    endcase
  end
  else begin
    LUT_DATA <= 0;
  end
end
//-----------------------------------------------------------------
/////////////////////	Config Data LUT	  //////////////////////////	
//寄存器初始化部分
always@(*)
begin
	case(LUT_INDEX)
	//write Data Index
	0  : S1_DATA	=	{8'h98,8'hF4, 8'h80};	//Manufacturer ID Byte - High (Read only)
	1  : S1_DATA	=	{8'h98,8'hF5, 8'h7c};	//Manufacturer ID Byte - Low (Read only)
	2  : S1_DATA	= 	{8'h98,8'hF8, 8'h4c};	// BIT[7]-Reset all the Reg 
	3  : S1_DATA	= 	{8'h98,8'hF9, 8'h64};	//DC offset for analog process
	4  : S1_DATA	= 	{8'h98,8'hFA, 8'h6c};	//COM10 : href/vsync/pclk/data reverse(Vsync H valid)
	5  : S1_DATA	= 	{8'h98,8'hFB, 8'h68};	//VGA :	8'h22;	QVGA :	8'h3f;
	6  : S1_DATA	= 	{8'h98,8'hFD, 8'h44};	//VGA :	8'ha4;	QVGA :	8'h50;
	7  : S1_DATA	=	{8'h98,8'h01, 8'h05};	//VGA :	8'h07;	QVGA :	8'h03;
	8  : S1_DATA	= 	{8'h98,8'h00, 8'h13};	//VGA :	8'hf0;	QVGA :	8'h78;
	9  : S1_DATA	= 	{8'h98,8'h02, 8'hF7};	//HREF	/ 8'h80
	10 : S1_DATA  = 	{8'h98,8'h03, 8'h40};	//VGA :	8'hA0;	QVGA :	8'hF0
	11 : S1_DATA  = 	{8'h98,8'h04, 8'h42};	//VGA :	8'hF0;	QVGA :	8'h78
	12 : S1_DATA	=	{8'h98,8'h05, 8'h28};	//
	13 : S1_DATA	= 	{8'h98,8'h06, 8'ha7};	//
	14 : S1_DATA	= 	{8'h98,8'h0b, 8'h44};	//BIT[6] :	0 :VGA; 1;QVGA
	15 : S1_DATA	= 	{8'h98,8'h0C, 8'h42};	//
	16 : S1_DATA	= 	{8'h98,8'h15, 8'h80};	//
	17 : S1_DATA	= 	{8'h98,8'h19, 8'h8a};	//
	18 : S1_DATA	= 	{8'h98,8'h33, 8'h40};	//
	19 : S1_DATA	= 	{8'h98,8'h14, 8'h4c};	//
	//
	20	 : S1_DATA	= 	{8'h44,8'hba, 8'h01};	//
	21	 : S1_DATA	= 	{8'h44,8'h7c, 8'h01};	//
	
	22  : S1_DATA	= 	{8'h64,8'h40, 8'h81};	//DSP_Ctrl4 :00/01 : YUV or RGB; 10 : RAW8; 11 : RAW10	
	
   23 :	S1_DATA	=	{8'h68,8'h9b, 8'h03};			//ADI recommanded setting
   24 :	S1_DATA	=	{8'h68,8'hc1, 8'h01};			//ADI recommanded setting
   25 :	S1_DATA	=	{8'h68,8'hc2, 8'h01};			//ADI recommanded setting
   26 :	S1_DATA	=	{8'h68,8'hc3, 8'h01};			//ADI recommanded setting
   27 :	S1_DATA	=	{8'h68,8'hc4, 8'h01};			//ADI recommanded setting
   28 :	S1_DATA	=	{8'h68,8'hc5, 8'h01};			//ADI recommanded setting
   29 :	S1_DATA	=	{8'h68,8'hc6, 8'h01};			//ADI recommanded setting
   30 :	S1_DATA	=	{8'h68,8'hc7, 8'h01};			//ADI recommanded setting
   31 :	S1_DATA	=	{8'h68,8'hc8, 8'h01};			//ADI recommanded setting
   32 :	S1_DATA	=	{8'h68,8'hc9, 8'h01};			//ADI recommanded settin g
   33 :	S1_DATA	=	{8'h68,8'hca, 8'h01};			//ADI recommanded setting
   34 :	S1_DATA	=	{8'h68,8'hcb, 8'h01};			//ADI recommanded setting
   35 :	S1_DATA	=	{8'h68,8'hcc, 8'h01};			//ADI recommanded setting
   36 :	S1_DATA	=	{8'h68,8'h00, 8'h00}; 		//Set HDMI input Port A
   37 :	S1_DATA	=	{8'h68,8'h83, 8'hfe};			//terminator for Port A
   38 :	S1_DATA	=	{8'h68,8'h6f, 8'h08};			//ADI recommended setting
   39 :	S1_DATA	=	{8'h68,8'h85, 8'h1f};			//ADI recommended setting
   40 :	S1_DATA	=	{8'h68,8'h87, 8'h70};			//ADI recommended setting
   41 :	S1_DATA	=	{8'h68,8'h8d, 8'h04};			//LFG
   42 :	S1_DATA	=	{8'h68,8'h8e, 8'h1e};			//HFG
   43 :	S1_DATA	=	{8'h68,8'h1a, 8'h8a};			//unmute audio
   44 :	S1_DATA	=	{8'h68,8'h57, 8'hda};			// ADI recommended setting
   45 :	S1_DATA	=	{8'h68,8'h58, 8'h01};
   46 :	S1_DATA	=	{8'h68,8'h75, 8'h10};

	default:S1_DATA	=	0;
	endcase
end
//edid参数写入部分
always@(*)
begin
  case(LUT_INDEX)
//  	//edid 
 	//0: S2_DATA	= 	{8'h68,8'h6c ,8'ha3};//// enable manual HPA
 	//1: S2_DATA	= 	{8'h98,8'h20 ,8'h70};//HPD low
 	//2: S2_DATA	= 	{8'h64,8'h74 ,8'h00};//disable internal EDID  
	//edid par
    0   : S2_DATA	= 	{8'h6c,8'd0  , 8'h00};
	1   : S2_DATA	= 	{8'h6c,8'd1  , 8'hFF};
	2   : S2_DATA	= 	{8'h6c,8'd2  , 8'hFF};
	3   : S2_DATA	= 	{8'h6c,8'd3  , 8'hFF};
	4   : S2_DATA	= 	{8'h6c,8'd4  , 8'hFF};
	5   : S2_DATA	= 	{8'h6c,8'd5  , 8'hFF};
	6   : S2_DATA	= 	{8'h6c,8'd6  , 8'hFF};
	7   : S2_DATA	= 	{8'h6c,8'd7  , 8'h00};
	8   : S2_DATA	= 	{8'h6c,8'd8  , 8'h20};
	9   : S2_DATA	= 	{8'h6c,8'd9  , 8'hA3};
	10  : S2_DATA	= 	{8'h6c,8'd10 , 8'h29};
	11  : S2_DATA	= 	{8'h6c,8'd11 , 8'h00};
	12  : S2_DATA	= 	{8'h6c,8'd12 , 8'h01};
	13  : S2_DATA	= 	{8'h6c,8'd13 , 8'h00};
	14  : S2_DATA	= 	{8'h6c,8'd14 , 8'h00};
	15  : S2_DATA	= 	{8'h6c,8'd15 , 8'h00};
	16  : S2_DATA	= 	{8'h6c,8'd16 , 8'h23};
	17  : S2_DATA	= 	{8'h6c,8'd17 , 8'h12};
	18  : S2_DATA	= 	{8'h6c,8'd18 , 8'h01};
	19  : S2_DATA	= 	{8'h6c,8'd19 , 8'h03};
	20  : S2_DATA	= 	{8'h6c,8'd20 , 8'h80};
	21  : S2_DATA	= 	{8'h6c,8'd21 , 8'h73};
	22  : S2_DATA	= 	{8'h6c,8'd22 , 8'h41};
	23  : S2_DATA	= 	{8'h6c,8'd23 , 8'h78};
	24  : S2_DATA	= 	{8'h6c,8'd24 , 8'h0A};
	25  : S2_DATA	= 	{8'h6c,8'd25 , 8'hF3};
	26  : S2_DATA	= 	{8'h6c,8'd26 , 8'h30};
	27  : S2_DATA	= 	{8'h6c,8'd27 , 8'hA7};
	28  : S2_DATA	= 	{8'h6c,8'd28 , 8'h54};
	29  : S2_DATA	= 	{8'h6c,8'd29 , 8'h42};
	30  : S2_DATA	= 	{8'h6c,8'd30 , 8'hAA};
	31  : S2_DATA	= 	{8'h6c,8'd31 , 8'h26};
	32  : S2_DATA	= 	{8'h6c,8'd32 , 8'h0F};
	33  : S2_DATA	= 	{8'h6c,8'd33 , 8'h50};
	34  : S2_DATA	= 	{8'h6c,8'd34 , 8'h54};
	35  : S2_DATA	= 	{8'h6c,8'd35 , 8'h25};
	36  : S2_DATA	= 	{8'h6c,8'd36 , 8'hC8};
	37  : S2_DATA	= 	{8'h6c,8'd37 , 8'h00};
	38  : S2_DATA	= 	{8'h6c,8'd38 , 8'h61};
	39  : S2_DATA	= 	{8'h6c,8'd39 , 8'h4F};
	40  : S2_DATA	= 	{8'h6c,8'd40 , 8'h01};
	41  : S2_DATA	= 	{8'h6c,8'd41 , 8'h01};
	42  : S2_DATA	= 	{8'h6c,8'd42 , 8'h01};
	43  : S2_DATA	= 	{8'h6c,8'd43 , 8'h01};
	44  : S2_DATA	= 	{8'h6c,8'd44 , 8'h01};
	45  : S2_DATA	= 	{8'h6c,8'd45 , 8'h01};
	46  : S2_DATA	= 	{8'h6c,8'd46 , 8'h01};
	47  : S2_DATA	= 	{8'h6c,8'd47 , 8'h01};
	48  : S2_DATA	= 	{8'h6c,8'd48 , 8'h01};
	49  : S2_DATA	= 	{8'h6c,8'd49 , 8'h01};
	50  : S2_DATA	= 	{8'h6c,8'd50 , 8'h01};
	51  : S2_DATA	= 	{8'h6c,8'd51 , 8'h01};
	52  : S2_DATA	= 	{8'h6c,8'd52 , 8'h01};
	53  : S2_DATA	= 	{8'h6c,8'd53 , 8'h01};
	54  : S2_DATA	= 	{8'h6c,8'd54 , 8'h02};
	55  : S2_DATA	= 	{8'h6c,8'd55 , 8'h3A};
	56  : S2_DATA	= 	{8'h6c,8'd56 , 8'h80};
	57  : S2_DATA	= 	{8'h6c,8'd57 , 8'h18};
	58  : S2_DATA	= 	{8'h6c,8'd58 , 8'h71};
	59  : S2_DATA	= 	{8'h6c,8'd59 , 8'h38};
	60  : S2_DATA	= 	{8'h6c,8'd60 , 8'h2D};
	61  : S2_DATA	= 	{8'h6c,8'd61 , 8'h40};
	62  : S2_DATA	= 	{8'h6c,8'd62 , 8'h58};
	63  : S2_DATA	= 	{8'h6c,8'd63 , 8'h2C};
	64  : S2_DATA	= 	{8'h6c,8'd64 , 8'h45};
	65  : S2_DATA	= 	{8'h6c,8'd65 , 8'h00};
	66  : S2_DATA	= 	{8'h6c,8'd66 , 8'h80};
	67  : S2_DATA	= 	{8'h6c,8'd67 , 8'h88};
	68  : S2_DATA	= 	{8'h6c,8'd68 , 8'h42};
	69  : S2_DATA	= 	{8'h6c,8'd69 , 8'h00};
	70  : S2_DATA	= 	{8'h6c,8'd70 , 8'h00};
	71  : S2_DATA	= 	{8'h6c,8'd71 , 8'h1E};
	72  : S2_DATA	= 	{8'h6c,8'd72 , 8'h8C};
	73  : S2_DATA	= 	{8'h6c,8'd73 , 8'h0A};
	74  : S2_DATA	= 	{8'h6c,8'd74 , 8'hD0};
	75  : S2_DATA	= 	{8'h6c,8'd75 , 8'h8A};
	76  : S2_DATA	= 	{8'h6c,8'd76 , 8'h20};
	77  : S2_DATA	= 	{8'h6c,8'd77 , 8'hE0};
	78  : S2_DATA	= 	{8'h6c,8'd78 , 8'h2D};
	79  : S2_DATA	= 	{8'h6c,8'd79 , 8'h10};
	80  : S2_DATA	= 	{8'h6c,8'd80 , 8'h10};
	81  : S2_DATA	= 	{8'h6c,8'd81 , 8'h3E};
	82  : S2_DATA	= 	{8'h6c,8'd82 , 8'h96};
	83  : S2_DATA	= 	{8'h6c,8'd83 , 8'h00};
	84  : S2_DATA	= 	{8'h6c,8'd84 , 8'h80};
	85  : S2_DATA	= 	{8'h6c,8'd85 , 8'h88};
	86  : S2_DATA	= 	{8'h6c,8'd86 , 8'h42};
	87  : S2_DATA	= 	{8'h6c,8'd87 , 8'h00};
	88  : S2_DATA	= 	{8'h6c,8'd88 , 8'h00};
	89  : S2_DATA	= 	{8'h6c,8'd89 , 8'h18};
	90  : S2_DATA	= 	{8'h6c,8'd90 , 8'h00};
	91  : S2_DATA	= 	{8'h6c,8'd91 , 8'h00};
	92  : S2_DATA	= 	{8'h6c,8'd92 , 8'h00};
	93  : S2_DATA	= 	{8'h6c,8'd93 , 8'hFC};
	94  : S2_DATA	= 	{8'h6c,8'd94 , 8'h00};
	95  : S2_DATA	= 	{8'h6c,8'd95 , 8'h48};
	96  : S2_DATA	= 	{8'h6c,8'd96 , 8'h44};
	97  :  S2_DATA	= 	{8'h6c,8'd97 , 8'h4D};
	98  :  S2_DATA	= 	{8'h6c,8'd98 , 8'h49};
	99  :  S2_DATA	= 	{8'h6c,8'd99 , 8'h20};
	100 :  S2_DATA	= 	{8'h6c,8'd100 , 8'h20};
	101 :  S2_DATA	= 	{8'h6c,8'd101 , 8'h20};
	102 :  S2_DATA	= 	{8'h6c,8'd102 , 8'h20};
	103 :  S2_DATA	= 	{8'h6c,8'd103 , 8'h0A};
	104 :  S2_DATA	= 	{8'h6c,8'd104 , 8'h20};
	105 :  S2_DATA	= 	{8'h6c,8'd105 , 8'h20};
	106 :  S2_DATA	= 	{8'h6c,8'd106 , 8'h20};
	107 :  S2_DATA	= 	{8'h6c,8'd107 , 8'h20};
	108 :  S2_DATA	= 	{8'h6c,8'd108 , 8'h00};
	109 :  S2_DATA	= 	{8'h6c,8'd109 , 8'h00};
	110 :  S2_DATA	= 	{8'h6c,8'd110 , 8'h00};
	111 :  S2_DATA	= 	{8'h6c,8'd111 , 8'hFD};
	112 :  S2_DATA	= 	{8'h6c,8'd112 , 8'h00};
	113 :  S2_DATA	= 	{8'h6c,8'd113 , 8'h32};
	114 :  S2_DATA	= 	{8'h6c,8'd114 , 8'h55};
	115 :  S2_DATA	= 	{8'h6c,8'd115 , 8'h1F};
	116 :  S2_DATA	= 	{8'h6c,8'd116 , 8'h45};
	117 :  S2_DATA	= 	{8'h6c,8'd117 , 8'h0F};
	118 :  S2_DATA	= 	{8'h6c,8'd118 , 8'h00};
	119 :  S2_DATA	= 	{8'h6c,8'd119 , 8'h0A};
	120 :  S2_DATA	= 	{8'h6c,8'd120 , 8'h20};
	121 :  S2_DATA	= 	{8'h6c,8'd121 , 8'h20};
	122 :  S2_DATA	= 	{8'h6c,8'd122 , 8'h20};
	123 :  S2_DATA	= 	{8'h6c,8'd123 , 8'h20};
	124 :  S2_DATA	= 	{8'h6c,8'd124 , 8'h20};
	125 :  S2_DATA	= 	{8'h6c,8'd125 , 8'h20};
	126 :  S2_DATA	= 	{8'h6c,8'd126 , 8'h01};
	127 :  S2_DATA	= 	{8'h6c,8'd127 , 8'h24};
	
	
	128: S2_DATA	= 	{8'h64,8'h74 ,8'h01};// enable internal EDID
	129: S2_DATA	= 	{8'h98,8'h20 ,8'hf0}; // HPD high
	130: S2_DATA	= 	{8'h68,8'h6c ,8'ha2}; // disable manual HPA	
	
	default:S2_DATA=0;
  endcase
end
always @(*)
begin
  case(LUT_INDEX)    
	0: S3_DATA	= 	{8'h68,8'h6c ,8'ha3};//// enable manual HPA
	1: S3_DATA	= 	{8'h98,8'h20 ,8'h70};//HPD low
	2: S3_DATA	= 	{8'h64,8'h74 ,8'h00};//disable internal EDID 
	default:S3_DATA=0;
	endcase
end

endmodule

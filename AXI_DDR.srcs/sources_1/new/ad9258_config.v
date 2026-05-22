`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : ad9258_config
// Create Date : 2020/06/07
//
//------------------------------------------------------------------------------
// 0. 一句话搞清楚：这个文件是干嘛的
//
//   本模块负责给 *单片* AD9258 ADC 芯片做"上电 + SPI 寄存器初始化"。
//   它不搬运 ADC 采样数据，只在系统刚上电那段时间动一次 SPI，把芯片
//   配成"我们要的工作模式"，然后就闲下来不再动。
//
//   上层用法：ad9258_cfg.v 例化了 *两份* 这个模块，分别接到板上两片
//   AD9258（共 4 个模拟通道）。它们用各自独立的 SPI 总线并行配置。
//
//   再往上层 ETH_TOP.v 把 4 路偏置 offset_adc1~4 喂进来，
//   配置完成后真正的高速采样数据通过另一条并行总线（adc*_dco* + adc*_d*）
//   进入 FPGA，与本模块再无关系。
//
//------------------------------------------------------------------------------
// 1. 一次完整的上电流程被切成三段时序
//
//   段1  上电硬件解使能（delay_cnt 段，0 ~ 3.2 ms）
//        - t = 0.1 us : 拉低 adc_pwdn  (取消硬件 power-down)
//        - t = 2  ms  : 拉低 adc_oeb   (使能 ADC 数据并行输出)
//        - t = 3  ms  : 拉高 adc_dea / adc_deb (使能 A/B 两通道输出)
//        - t = 3.2 ms : delay_cnt[15] = 1，进入 SPI 配置阶段
//
//   段2  SPI 寄存器配置（cntr 段，约 1.6 ms）
//        - 一帧 SPI = 32 个 clk10m 周期 -> cntr[4:0] 是帧内位计数
//        - cntr[14:5] 是"第几条命令"的编号
//        - 实际只在编号 1 和 500~512 这 14 个编号上发命令，其余空过
//
//   段3  发完之后所有 SPI 信号回到 idle 状态，本模块永不再动
//
//------------------------------------------------------------------------------
// 2. 32-bit SPI 帧格式（AD9258 SPI 协议）
//
//   每写一个寄存器都按这 32 位排好后整体串出去：
//
//      bit[31:28] = 4'hF       4 位空闲（拉高，相当于 idle 前导）
//      bit[27]    = 1'b0       R/W = 0 表示"写"
//      bit[26:25] = 2'b00      传输字节数 = 1
//      bit[24:12] = 13 位地址  AD9258 寄存器地址
//      bit[11:4]  = 8 位数据   要写入的值
//      bit[3:0]   = 4'hF       4 位空闲尾（拉高）
//
//   命令链总共 14 条，其中第 1 条是软复位，500~512 是真正业务配置
//   （详见下面的 wrrom1~wrrom14 注释和 case 表）。
//
//------------------------------------------------------------------------------
// 3. 输出引脚里哪些"动"，哪些"几乎不动"
//
//   动得快（每个 clk10m 沿都可能翻转）：
//     adc_sclk : SPI 时钟，配置期间 = ~clk10m，配置完成后恒高
//     adc_sdio : SPI 数据，写阶段为输出，串出 data_reg[31]
//     adc_csb  : SPI 片选，低电平有效，data_reg/csn_reg 一同移位
//
//   慢变信号（整个上电期间只切一次）：
//     adc_pwdn : 上电先高（关电），1 us 后拉低（开电）
//     adc_oeb  : 数据输出使能，2 ms 后拉低
//     adc_dea  : A 通道数字输出使能，3 ms 后拉高
//     adc_deb  : B 通道数字输出使能，3 ms 后拉高
//
//////////////////////////////////////////////////////////////////////////////////
  module ad9258_config(
    input clk10m,             // 10 MHz 配置时钟，整个模块只用这一个时钟
    input rstn,               // 低有效复位（来自 sysclk PLL locked）
    output adc_dea,           // ADC A 通道输出使能（高有效，3 ms 后拉高）
    output adc_deb,           // ADC B 通道输出使能（高有效，3 ms 后拉高）
    output adc_oeb,           // ADC OEB：数据并口输出使能（低有效，2 ms 后拉低）
    output adc_pwdn,          // ADC 硬件下电（高有效，1 us 后拉低进入工作态）
    output adc_csb,           // SPI 片选 CSB（低有效）
    inout  adc_sdio,          // SPI 双向数据；本工程固定为输出方向
    output adc_sclk,          // SPI 时钟，配置期间 = ~clk10m
    input [7:0] offset_adcA,  // A 通道偏置补偿值（写入 AD9258 寄存器 0x0010）
    input [7:0] offset_adcB   // B 通道偏置补偿值（写入 AD9258 寄存器 0x0010）
    );

  //----------------------------------------------------------------------------
  // [A] 14 条 SPI 配置命令 ROM
  //
  // 每条都是 32 位，格式见文件头第 2 节。地址 = bit[24:12]，数据 = bit[11:4]。
  // wrrom10 / wrrom13 是 wire，因为它们的 data 段来自外部输入 offset_adcA/B；
  // 其它都是上电时刻就固定的常量，所以用 localparam。
  //----------------------------------------------------------------------------
  // 寄存器 0x0000 = 0x3C : SPI 端口配置 + 软复位（bit5=1）
  localparam wrrom1 = {4'hf,1'b0,2'd0,13'h0000,8'h3C,4'hf};//soft reset
  // 寄存器 0x0000 = 0x18 : 清软复位，保持 MSB first，SDO 激活
  localparam wrrom2 = {4'hf,1'b0,2'd0,13'h0000,8'h18,4'hf};//MSB first
  // 寄存器 0x0005 = 0x03 : Channel Index = 同时选 A(bit0) 和 B(bit1)，
  // 这样接下来对"全局生效"类寄存器（0x0008/0x000B/0x0014）的写入会同时落到两个通道
  localparam wrrom3 = {4'hf,1'b0,2'd0,13'h0005,8'h03,4'hf};//en ADC channel 0 and 1
  // 寄存器 0x0008 = 0x80 : Power Mode，外部 PWDN 引脚控制 + 内部正常工作
  localparam wrrom4 = {4'hf,1'b0,2'd0,13'h0008,8'h80,4'hf};//external pwdn,internal normal operation
  // 寄存器 0x000B = 0x00 : Clock 设置，DCO 正常输出（不反相、不关闭）
  localparam wrrom5 = {4'hf,1'b0,2'd0,13'h000B,8'h00,4'hf};//DCO旁路
  // 寄存器 0x0014 = 0x80 : Output Mode，Offset Binary 输出格式
  // 注释里 "20220902 将 0x00 改为 0x80 为兼容 AD9251" 是历史改动记录
  localparam wrrom6 = {4'hf,1'b0,2'd0,13'h0014,8'h80,4'hf};//20220902将8'h00改为8'h80，为兼容AD9251
  // 寄存器 0x0018 : VREF 选择（已被旁路，实际未使用，见下面 case 10'd505）
  localparam wrrom7 = {4'hf,1'b0,2'd0,13'h0018,8'hC0,4'hf};
  // 寄存器 0x00FF = 0x01 : Transfer，提交前面对"内部影子寄存器"的全部写入
  localparam wrrom8 = {4'hf,1'b0,2'd0,13'h00FF,8'h01,4'hf};
  // 寄存器 0x0005 = 0x01 : Channel Index 切换为"只选 A 通道"
  // 后续写 0x0010 偏置时只影响 A
  localparam wrrom9  = {4'hf,1'b0,2'd0,13'h0005,8'h01,4'hf};//en ADC channel A
  wire [31:0] wrrom10;
  // 寄存器 0x0010 = offset_adcA : 给 A 通道写硬件级 DC offset
  assign wrrom10 = {4'hf,1'b0,2'd0,13'h0010,offset_adcA,4'hf};//偏置
  localparam wrrom11 = {4'hf,1'b0,2'd0,13'h00FF,8'h01,4'hf};
  // 寄存器 0x0005 = 0x02 : Channel Index 切换为"只选 B 通道"
  localparam wrrom12 = {4'hf,1'b0,2'd0,13'h0005,8'h02,4'hf};//en ADC channel B
  wire [31:0] wrrom13;
  // 寄存器 0x0010 = offset_adcB : 给 B 通道写硬件级 DC offset
  assign wrrom13 = {4'hf,1'b0,2'd0,13'h0010,offset_adcB,4'hf};//偏置
  localparam wrrom14 = {4'hf,1'b0,2'd0,13'h00FF,8'h01,4'hf};

  //----------------------------------------------------------------------------
  // [B] 上电延时计数器 delay_cnt
  //
  // 一直 +1，加到 16'h8000（即 bit[15]=1）后冻结。
  // 在 10 MHz 时钟下 0x8000 ≈ 32768 / 10 MHz ≈ 3.27 ms。
  // 之后 delay_cnt[15] 保持为 1，作为"上电延时已完成"的标志，
  // 后续 cntr 段就根据这一位决定是否开始计数。
  //----------------------------------------------------------------------------
  reg [15:0] delay_cnt;
  always@(posedge clk10m or negedge rstn)
  begin
    if(!rstn)
        delay_cnt <= 16'h0000;
    else
        if(delay_cnt[15]==0)
            delay_cnt <= delay_cnt + 1'b1;
        else
            delay_cnt <= delay_cnt;
  end

  //----------------------------------------------------------------------------
  // [C] 慢变控制脚的上电时序
  //
  // 复位时（rstn=0）：芯片处于"硬件下电 + 输出禁用"状态。
  // delay_cnt 达到各个里程碑时一步步把芯片唤醒：
  //
  //     delay_cnt =     1   (0.1 us) : adc_pwdn = 0   解除硬件下电
  //     delay_cnt = 20000   (2  ms)  : adc_oeb  = 0   使能数据并口输出
  //     delay_cnt = 30000   (3  ms)  : dea/deb  = 11  使能 A/B 两通道
  //
  // 之后这几个信号保持不变，直到下次复位。
  //----------------------------------------------------------------------------
  reg adc_dea_reg;
  reg adc_deb_reg ;
  reg adc_pwdn_reg ;
  reg adc_oeb_reg ;
  assign adc_pwdn = adc_pwdn_reg;
  assign adc_oeb  = adc_oeb_reg;
  assign adc_dea  = adc_dea_reg;
  assign adc_deb  = adc_deb_reg;
  always@(posedge clk10m or negedge rstn)
  begin
    if(!rstn) begin
        adc_pwdn_reg <= 1'b1;
        adc_oeb_reg <= 1'b1;
        {adc_dea_reg,adc_deb_reg} <= 2'b00;
    end
    else
        if(delay_cnt==1)
            adc_pwdn_reg <= 1'b0;
        else if(delay_cnt==20000)    //2ms
            adc_oeb_reg <= 1'b0;
        else if (delay_cnt==30000)   //3ms
            {adc_dea_reg,adc_deb_reg} <= 2'b11;
        else begin
            adc_pwdn_reg <= adc_pwdn_reg;
            adc_oeb_reg <= adc_oeb_reg;
            {adc_dea_reg,adc_deb_reg} <= {adc_dea_reg,adc_deb_reg};
        end
  end

  //----------------------------------------------------------------------------
  // [D] SPI 命令计数器 cntr
  //
  // 等 delay_cnt[15]=1（即 3.2 ms 上电延时结束）以后才开始计数。
  // cntr 是 16 位，其中：
  //     cntr[4:0]   = 帧内位计数 (0~31)，控制 32 位 SPI 帧每一位
  //     cntr[14:5]  = 命令编号，case 表里只对 1 和 500~512 真正发命令
  //
  // 上限 16'h4030 = 16432 ≈ 1.64 ms（在 10 MHz 下），到了就冻结。
  // 命令编号 512 对应 cntr ≈ 16'h4010，所以最后一条命令发完之后
  // 大约还会再走 0x20 = 32 个周期把这一帧串完，然后 cntr 停在 0x4030 不动。
  //
  // 如果 delay_cnt[15]==0（说明芯片又被拉到复位前的延时阶段），
  // cntr 会被强制清零，等下一次延时结束再重新走一遍配置。
  //----------------------------------------------------------------------------
  reg [15:0] cntr;
  always@(posedge clk10m or negedge rstn)
  begin
	if(!rstn)
		cntr <= 16'h0000;
	else
        if(delay_cnt[15]==1)
            if(cntr < 16'h4030)
                cntr <= cntr + 1'b1;
            else
                cntr <= 16'h4030;
        else
            cntr <= 16'h0000;
  end

  //----------------------------------------------------------------------------
  // [E] SPI 三态总线方向
  //
  // adc_sdio 是双向引脚（inout）。AD9258 支持读寄存器，但本工程只写不读，
  // 所以 control 直接固定为 1，方向永远是 FPGA -> 芯片：
  //
  //     control = 1 : adc_sdio = adc_sdo （驱动）
  //     control = 0 : adc_sdio = 'bz     （让芯片驱动，本工程用不到）
  //
  // 上面被注释掉的那行原本是想在 SPI 帧的第 5~12 位让出总线以读取，但已弃用。
  //----------------------------------------------------------------------------
  wire control;
  //assign control = (cntr[4:0]>4 && cntr[4:0]<13 ) ?  (1'b0) : (1'b1);
  assign control = 1'b1;
  wire adc_sdi;
  wire adc_sdo;
  assign adc_sdio = (control)?adc_sdo:1'bz;
  assign adc_sdi = adc_sdio;

  //----------------------------------------------------------------------------
  // [F] SPI 数据 / 片选 移位寄存器（核心）
  //
  // 设计思路是"用一个 32 位移位寄存器，每个时钟把 MSB 输出出去"，
  //
  //     adc_sdo = data_reg[31];   // 数据位
  //     adc_csb = csn_reg[31];    // 片选位（位级跟随，方便把 4'hF 当前/后导）
  //
  // 工作方式按 cntr[4:0] 分两种行为：
  //
  //   (1) cntr[4:0] == 16 (帧的中央位)：
  //       根据 cntr[14:5] 当前命令编号，把对应 wrrom# 整字搬进 data_reg，
  //       同时把 csn_reg 装成 {4'hF, 24'h0, 4'hF}，
  //       即：前 4 位（idle，CSB=1） + 中间 24 位（CSB=0，真正发命令） + 后 4 位（idle，CSB=1）。
  //       注意 csn_reg 的位排布是为了让 CSB 与数据的有效区间对齐，
  //       因为 data_reg 的高 4 位和低 4 位也都是 4'hF 空闲填充。
  //
  //   (2) 其它周期：左移 1 位，最低位补 1（idle 高电平）。
  //       这样每个时钟 data_reg[31] 都会变成下一个要发的位，
  //       一帧 32 位连续 32 个 clk10m 沿串出去，正好和 adc_sclk 同步。
  //
  // 命令编号映射：
  //     1   : 软复位 wrrom1
  //     500~512 : 14 条业务配置（见 wrrom2~wrrom14）
  //     其它 : data_reg = -1 / csn_reg = -1，等价 CSB 一直高，sdio 一直高 -> 总线 idle
  //
  // 之所以隔得这么远（1 和 500），是为了在软复位后留出 ~1.6 ms 让芯片内部稳下来再继续配置。
  //----------------------------------------------------------------------------
  reg [31:0] data_reg;
  reg [31:0] csn_reg;
  always@(posedge clk10m  or negedge rstn)
  begin
	if(!rstn) begin
        data_reg <= -1;
        csn_reg  <= -1;
    end
	else
	   if(cntr[4:0] == 5'd16) begin
			case(cntr[14:5])
            10'd1:                  // 软复位
            begin
                data_reg <= wrrom1;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd500:                // 清软复位 + MSB first
            begin
                data_reg <= wrrom2;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd501:                // 同时选 A+B（全局参数下一步生效）
            begin
                data_reg <= wrrom3;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd502:                // Power Mode：外部 PWDN 控制
            begin
                data_reg <= wrrom4;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd503:                // DCO 正常输出
            begin
                data_reg <= wrrom5;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd504:                // Output Mode = Offset Binary
            begin
                data_reg <= wrrom6;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd505:                // 原本是 VREF（wrrom7），20220902 改为重复写 wrrom6 以兼容 AD9251
            begin
                data_reg <= wrrom6; //wrrom7; 20220902修改此处为了兼容AD9251
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd506:                // Transfer，提交前面 A+B 共同配置
            begin
                data_reg <= wrrom8;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd507:                // Channel Index = 只 A
            begin
                data_reg <= wrrom9;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd508:                // A 通道偏置 offset_adcA
            begin
                data_reg <= wrrom10;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd509:                // Transfer，提交 A 偏置
            begin
                data_reg <= wrrom11;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd510:                // Channel Index = 只 B
            begin
                data_reg <= wrrom12;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd511:                // B 通道偏置 offset_adcB
            begin
                data_reg <= wrrom13;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            10'd512:                // Transfer，提交 B 偏置（整个配置流程到此结束）
            begin
                data_reg <= wrrom14;
                csn_reg  <= {4'hf,24'd0,4'hf};
            end
            default:                // 不在命令编号上：保持 idle（全 1），CSB 始终高
            begin
                data_reg <= -1;
                csn_reg <= -1;
            end
        endcase
		end
		else begin
		    // 帧内其余 31 个周期：移位串出
			data_reg <= {data_reg[30:0],1'b1};
			csn_reg <= {csn_reg[30:0],1'b1};
		end
  end

  //----------------------------------------------------------------------------
  // [G] 三个 SPI 输出
  //
  // adc_sclk : 只在配置期间（cntr<0x4030）输出 ~clk10m，相当于 10 MHz SPI 时钟；
  //            配置完成后恒为 1，让芯片完全空闲。
  // adc_sdo  : 移位寄存器 MSB，串出当前帧的 32 位数据。
  // adc_csb  : 同步串出，4 位前导高 + 24 位低（真正写入区间）+ 4 位后导高。
  //----------------------------------------------------------------------------
  assign adc_sclk  = (cntr < 16'h4030) ?  ( ~clk10m) : (1'b1);
  assign adc_sdo  =  data_reg[31];
  assign adc_csb =  csn_reg[31];

endmodule


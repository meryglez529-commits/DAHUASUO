`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/04 18:51:57
// Design Name: 
// Module Name: adcdata_config
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
//------------------------------------------------------------------------------
// 0. 读这个模块，先记住一句话
//
// adcdata_config 做的事只有一件：
//   把 4 路 AD9258 采样数据整理成 64bit 数据流，写入 DDR，再从 DDR 读出并交给
//   以太网发送模块。
//
// 这个文件是 DL2 的装配层，不是单路采样算法文件。真正的数据处理分在下面几级：
//   - adcdata_acq      ：每一路 ADC 在自己的 DCO 域触发、采样、平均，并跨到 ui_clk。
//   - adcdata_get      ：在 ui_clk 域按 adc_channel 把 1/2/4 路 16bit 点打成 64bit。
//   - fdma_controller1_*：在 ui_clk 域把 64bit 流写 DDR、再读 DDR。
//   - LAN_TX_FREAME    ：把 DDR 读出的 64bit 数据变成 eth_clk 域的 8bit UDP payload。
//
// 先把单位记牢：
//   1 个 ADC 输入样本 = 顶层传来的 14bit，这里补 2 个高位 0 变成 16bit。
//   1 个 div_adc*_out = 单通道采样/平均/行重复后的 16bit 点。
//   1 个 adc_data_mix = adcdata_get 输出的 64bit 包，是写 DDR 的基本数据单位。
//   1 个 pkg_wr/pkg_rd beat = 64bit，后级 FDMA 通常按 128 beat 一包访问 DDR。
//------------------------------------------------------------------------------
module adcdata_config(
    
    // eth_clk 域负责 UDP 发送握手；ui_clk 域负责 DDR/FDMA 和通道聚合。
    input           eth_clk,
    input           eth_rstn,  
    input           ui_clk,
    input           fdma_rstn,
    // 4 路 ADC DCO 和 4 路 14bit 采样数据。进入 adcdata_acq 前会补成 16bit。
    input           adc1_dcoa,
    input           adc1_dcob,
    input           adc2_dcoa,
    input           adc2_dcob,
    input [13:0]    adc1_da,
    input [13:0]    adc1_db,
    input [13:0]    adc2_da,
    input [13:0]    adc2_db, 
    input [15:0]    row_repeat,   
    input           adc_tri,
    input [31:0]    image_point,
    input [20:0]    adc_len_single,     
    input [3:0]     adc_channel,
    input [31:0]    adc_sample,
    input [15:0]    image_column,
    input [23:0]    adc_interval,
    input [31:0]    adc_acq_delay,
    input           ultrafast_mode,
    input [31:0]    acq_dead_time,
    input           scan_state,
    input [31:0]    pc_ack,

    input           tx_data_done,
    input           data_en,              // 当前文件内未使用，保留为接口兼容/历史信号。
    input           prog_full,
    output          data_req,
    input           data_ACK,
    output [21:0]   data_wr_pack_num,
    output [15:0]   data_wr_last_pack_num,        //data port input
    output [7:0]    data_tx_data,
    output          data_tx_valid,
    output [3:0]    LED,
     
    // 本模块边界上的 pkg_* 是 ADC 数据专用 FDMA 接口；顶层会把它接到 pkg1_*。
    output              pkg_wr_areq,       
    input               pkg_wr_en,
    input               pkg_wr_last,
    output  [31:0]      pkg_wr_addr,
    output  [63:0]      pkg_wr_data,
    output  [31:0]      pkg_wr_size,
    input   [63:0]      pkg_rd_data,
    input               pkg_rd_en,
    input               pkg_rd_last,
    output  [31:0]      pkg_rd_addr,
    output              pkg_rd_areq,
    output  [31:0]      pkg_rd_size  
    );

//------------------------------------------------------------------------------
// 1. scan_state 到本链路复位/启动的同步
//
// fdma_rstn 是 DDR/FDMA 侧复位；scan_state 是上位机启动采集的控制位。
// 这里在 ui_clk 域打两拍，生成 rstnr1，作为 DL2 内部采样、打包和 DDR 控制的使能复位。
// 换句话说：scan_state 没拉起时，ADC 链路虽然有外部 DCO，但数据处理链保持在复位态。
//------------------------------------------------------------------------------
reg rstnr0;
reg rstnr1;
always@(posedge ui_clk or negedge fdma_rstn) 
begin
    if(~fdma_rstn) begin
        rstnr0 <= 1'b0;
        rstnr1 <= 1'b0;
    end
    else begin
        rstnr0 <= scan_state;
        rstnr1 <= rstnr0;
    end
end        

wire          adc1_dcoa_bufg;
wire          adc1_dcob_bufg;
wire          adc2_dcoa_bufg;
wire          adc2_dcob_bufg;
wire          div_adc_rd_en;
wire  [9:0]  div_adc1_rd_data_count;
wire  [15:0] div_adc1_out;
wire  [9:0]  div_adc2_rd_data_count;
wire  [15:0] div_adc2_out;
wire  [9:0]  div_adc3_rd_data_count;
wire  [15:0] div_adc3_out;
wire  [9:0]  div_adc4_rd_data_count;
wire  [15:0] div_adc4_out;
wire          adc_data_mix_wr_en;
wire  [63:0] adc_data_mix_wr_fifo;

wire [15:0]  line_count;
wire         line_count_en;
//------------------------------------------------------------------------------
// 2. ADC DCO 进入全局时钟网络
//
// 四路 AD9258 数据各自跟随一个 DCO：
//   adc1_da -> adc1_dcoa_bufg
//   adc1_db -> adc1_dcob_bufg
//   adc2_da -> adc2_dcoa_bufg
//   adc2_db -> adc2_dcob_bufg
//
// adcdata_acq 在对应 DCO 域完成触发窗口和平均，所以这里先把外部 DCO 过 BUFG。
//------------------------------------------------------------------------------
BUFG bufg_dcoa1(.O(adc1_dcoa_bufg),.I(adc1_dcoa)); 
BUFG bufg_dcoa2(.O(adc1_dcob_bufg),.I(adc1_dcob)); 
BUFG bufg_dcob1(.O(adc2_dcoa_bufg),.I(adc2_dcoa)); 
BUFG bufg_dcob2(.O(adc2_dcob_bufg),.I(adc2_dcob)); 
// LED[3:0] 只是用 DCO 计数器做活动指示：能闪说明对应 ADC DCO 在跑，不代表数据格式正确。
reg [25:0] cnt1;
reg [25:0] cnt2;
reg [25:0] cnt3;
reg [25:0] cnt4;
assign LED[0]=cnt1[25];
assign LED[1]=cnt2[25];
assign LED[2]=cnt3[25];
assign LED[3]=cnt4[25];
always@(posedge adc1_dcoa_bufg) 
begin
    cnt1<=cnt1+1'b1;
end
always@(posedge adc1_dcob_bufg) 
begin
    cnt2<=cnt2+1'b1;
end
always@(posedge adc2_dcoa_bufg) 
begin
    cnt3<=cnt3+1'b1;
end
always@(posedge adc2_dcob_bufg) 
begin
    cnt4<=cnt4+1'b1;
end 

//------------------------------------------------------------------------------
// 3. 四路单通道采集
//
// 每个 adcdata_acq 处理一路 ADC：
//   输入：一个 adc_dco 域的 16bit 样本、adc_tri 触发和采样参数。
//   输出：ui_clk 域可读的 16bit div_adc*_out，以及 FIFO 中可读点数。
//
// 注意这里的 {2'b0, adc*_d*}：
//   ETH_TOP 只把 AD9258 的 [15:2] 传进来，所以本模块端口是 14bit。
//   补 2 个 0 以后再按 16bit 无符号数参与平均和后续打包。
//
// line_count/line_count_en 只从第一路 adcdata1_acq 引出，供超快模式发包时回传行号。
//------------------------------------------------------------------------------
  adcdata_acq adcdata1_acq(
    .ui_clk                 (ui_clk), 
    .rstn                   (rstnr1),
    .adc_tri                (adc_tri),
    .row_repeat             (row_repeat),
    .adc_interval           (adc_interval),
    .ultrafast_mode         (ultrafast_mode),
    .acq_dead_time          (acq_dead_time),
    .adc_acq_delay          (adc_acq_delay),
    .adc_sample             (adc_sample),
    .image_column           (image_column),
    .adc_dco                (adc1_dcoa_bufg),
    .adc_data               ({2'b0,adc1_da}),
    .line_count             (line_count),
    .line_count_en          (line_count_en),   
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_rd_data_count  (div_adc1_rd_data_count),
    .div_adc_out            (div_adc1_out)
    );  
  adcdata_acq adcdata2_acq(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .adc_tri                (adc_tri),
    .row_repeat             (row_repeat),
    .adc_interval           (adc_interval),
    .ultrafast_mode         (ultrafast_mode),
    .acq_dead_time          (acq_dead_time),
    .adc_acq_delay          (adc_acq_delay),
    .adc_sample             (adc_sample),
    .image_column           (image_column),
    .adc_dco                (adc1_dcob_bufg),
    .adc_data               ({2'b0,adc1_db}),
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_rd_data_count  (div_adc2_rd_data_count),
    .div_adc_out            (div_adc2_out)
    );    
  adcdata_acq adcdata3_acq(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .row_repeat             (row_repeat),
    .adc_tri                (adc_tri),
    .adc_interval           (adc_interval),
    .ultrafast_mode         (ultrafast_mode),
    .acq_dead_time          (acq_dead_time),
    .adc_acq_delay          (adc_acq_delay),
    .adc_sample             (adc_sample),
    .image_column           (image_column),
    .adc_dco                (adc2_dcoa_bufg),
    .adc_data               ({2'b0,adc2_da}),
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_rd_data_count  (div_adc3_rd_data_count),
    .div_adc_out            (div_adc3_out)
    );    
   adcdata_acq adcdata4_acq(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .row_repeat             (row_repeat),
    .adc_tri                (adc_tri),
    .adc_interval           (adc_interval),
    .ultrafast_mode         (ultrafast_mode),
    .acq_dead_time          (acq_dead_time),
    .adc_acq_delay          (adc_acq_delay),
    .adc_sample             (adc_sample),
    .image_column           (image_column),
    .adc_dco                (adc2_dcob_bufg),
    .adc_data               ({2'b0,adc2_db}),
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_rd_data_count  (div_adc4_rd_data_count),
    .div_adc_out            (div_adc4_out)
    );
//------------------------------------------------------------------------------
// 4. 四通道聚合成 64bit 主合同
//
// adcdata_get 是 DL2 的汇流点。它根据 adc_channel 决定一个 64bit 包里放什么：
//   单通道：4 个连续 16bit 点凑成 1 个 64bit。
//   双通道：2 个位置 * 2 个通道凑成 1 个 64bit。
//   三/四通道：按 4 个 16bit 槽位直接组成 1 个 64bit。
//
// 后级 DDR 不关心选了几个通道，它只看统一合同：
//   adc_data_mix_wr_en == 1 时，adc_data_mix_wr_fifo[63:0] 有效。
//------------------------------------------------------------------------------
  adcdata_get adcdata_get_inst(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .adc_channel            (adc_channel),    
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc1_out           (div_adc1_out),    
    .div_adc2_out           (div_adc2_out),
    .div_adc3_out           (div_adc3_out),
    .div_adc4_out           (div_adc4_out),
    .div_adc1_rd_data_count (div_adc1_rd_data_count),
    .div_adc2_rd_data_count (div_adc2_rd_data_count),
    .div_adc3_rd_data_count (div_adc3_rd_data_count),
    .div_adc4_rd_data_count (div_adc4_rd_data_count),
    .adc_data_mix_wr_en     (adc_data_mix_wr_en),
    .adc_data_mix           (adc_data_mix_wr_fifo)
    );    

wire    [63:0]      cache_wr_size;    
//------------------------------------------------------------------------------
// 5. DDR 写侧：64bit 流 -> pkg_wr_* 用户接口
//
// fdma_controller1_write 内部有一个 ui_clk 同步 FIFO。adcdata_get 写入 64bit 包；
// 当 FIFO 中数据够一包时，它通过 pkg_wr_areq/pkg_wr_addr/pkg_wr_size 请求 FDMA 写 DDR。
//
// cache_wr_size 记录已经写入 DDR 的字节数，后面的读控制器用它判断 DDR 中有多少可读数据。
//------------------------------------------------------------------------------
fdma_controller1_write ddr3_wr(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .adc_data_mix_wr_en     (adc_data_mix_wr_en),
    .adc_data_mix_wr_fifo   (adc_data_mix_wr_fifo),
    .pkg_wr_areq            (pkg_wr_areq),       
    .pkg_wr_en              (pkg_wr_en),  
    .pkg_wr_last            (pkg_wr_last),  
    .pkg_wr_addr            (pkg_wr_addr),  
    .pkg_wr_data            (pkg_wr_data),  
    .pkg_wr_size            (pkg_wr_size),
    .cache_wr_size          (cache_wr_size)
    );   
wire            fdma_rd_req;
//------------------------------------------------------------------------------
// 6. DDR 读侧：以太网侧需要数据时，从 DDR 拉回 64bit beat
//
// fdma_rd_req 来自 LAN_TX_FREAME，意思是“发送侧 FIFO 快不够了，请继续从 DDR 补数据”。
// fdma_controller1_read 会结合 cache_wr_size 判断 DDR 里是否有足够未读数据，
// 然后通过 pkg_rd_areq/pkg_rd_addr/pkg_rd_size 发起 FDMA 读。
//------------------------------------------------------------------------------
fdma_controller1_read ddr3_rd(
    .ui_clk                 (ui_clk),
    .rstn                   (rstnr1),
    .cache_wr_size          (cache_wr_size),
    .read_req               (fdma_rd_req),
    
    .pkg_rd_data            (pkg_rd_data),
    .pkg_rd_en              (pkg_rd_en),
    .pkg_rd_last            (pkg_rd_last),
    .pkg_rd_addr            (pkg_rd_addr),
    .pkg_rd_areq            (pkg_rd_areq),
    .pkg_rd_size            (pkg_rd_size)
    ); 

//------------------------------------------------------------------------------
// 7. DDR 到以太网发送桥
//
// LAN_TX_FREAME 的输入名仍叫 adc_data_mix_*，但这里实际接的是 DDR 读口：
//   adc_data_mix_wr_en   <- pkg_rd_en
//   adc_data_mix_wr_fifo <- pkg_rd_data
//
// 它把 ui_clk 域 64bit DDR 读数据写入异步/宽度转换 FIFO，再在 eth_clk 域按字节输出
// data_tx_data/data_tx_valid，同时用 data_req/data_ACK/tx_data_done 和 ETHERNET_TOP 仲裁发送。
//------------------------------------------------------------------------------
LAN_TX_FREAME LAN_TX_FREAME_inst(
    .fdma_rd_req            (fdma_rd_req),
    .pc_ack                 (pc_ack),
    .eth_clk                (eth_clk),
    .adc_dco                (adc1_dcoa_bufg),
    .eth_rstn               (eth_rstn), 
    .ui_clk                 (ui_clk),
    .rstn                   (fdma_rstn),
    .image_point            (image_point),
    .adc_len_single         (adc_len_single),  
    .adc_channel            (adc_channel),
    .scan_state             (scan_state),
    .adc_data_mix_wr_en     (pkg_rd_en),
    .adc_data_mix_wr_fifo   (pkg_rd_data),
    .ultrafast_mode         (ultrafast_mode),
    .line_count             (line_count),
    .line_count_en          (line_count_en),

    .tx_data_done           (tx_data_done),
    .prog_full              (prog_full),
    .data_req_o             (data_req),
    .data_ACK_i             (data_ACK),
    .data_wr_pack_num       (data_wr_pack_num),
    .data_wr_last_pack_num  (data_wr_last_pack_num),        //data port input [15:0]
    .data_tx_data_o         (data_tx_data),                 //[7:0]
    .data_tx_valid_o        (data_tx_valid)
    );

//------------------------------------------------------------------------------
// 8. ILA 观察点
//
// 这两个 ILA 只观察 ADC 专用的 pkg1_* 通道在本模块内映射后的 pkg_* 端口。
// 调 DL2 时优先看：
//   写侧：pkg_wr_areq/pkg_wr_en/pkg_wr_last/pkg_wr_addr/pkg_wr_data。
//   读侧：pkg_rd_areq/pkg_rd_en/pkg_rd_last/pkg_rd_addr/pkg_rd_data。
//------------------------------------------------------------------------------
ila_0 pkg_rd_ila(
    .clk        (ui_clk),
    .probe0     (pkg_rd_areq),
    .probe1     (pkg_rd_en),
    .probe2     (pkg_rd_last),
    .probe3     (pkg_rd_addr),
    .probe4     (pkg_rd_data),
    .probe5     (pkg_rd_size)
    );  
ila_0 pkg_wr_ila(
    .clk        (ui_clk),
    .probe0     (pkg_wr_areq),
    .probe1     (pkg_wr_en),
    .probe2     (pkg_wr_last),
    .probe3     (pkg_wr_addr),
    .probe4     (pkg_wr_data),
    .probe5     (pkg_wr_size)
    );    
endmodule

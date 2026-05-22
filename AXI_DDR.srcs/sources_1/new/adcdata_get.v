`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/18 09:40:08
// Design Name: 
// Module Name: adcdata_gen
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
// 读这个模块先记住一句话：
//   adcdata_get 在 ui_clk 域把最多 4 路 ADC 的 16bit 列数据，按 adc_channel 选择关系
//   打包成统一的 64bit 数据包，交给 fdma_controller1_write 写入 DDR。
//
// 上游数据来源：
//   div_adc*_out 来自各路 row_repeat_module，已经是“采样平均 + 行重复平均”后的 16bit 点。
//   div_adc*_rd_data_count 表示对应输出 FIFO 里当前有多少个 16bit 点可读。
//
// 输出合同：
//   adc_data_mix_wr_en == 1 时，adc_data_mix[63:0] 是一个有效 64bit beat。
//   后级 DDR 写侧不再关心当前选了几个 ADC 通道，只看这个统一的 64bit 流。
//
// 打包规则：
//   单通道：4 个连续位置的 16bit 点 -> 1 个 64bit beat。
//   双通道：2 个连续位置 * 2 个通道 -> 1 个 64bit beat。
//   三/四通道：按 4 个 16bit 槽位直接输出 -> 1 个 64bit beat。
//   注意三通道也走四槽位格式，未启用的槽位由接收端按 adc_channel 解释。
  module adcdata_get(
    input               ui_clk,                 // 本模块唯一工作时钟，和 row_repeat_module 输出 FIFO/DDR 写侧同域
    input               rstn,
    input       [3:0]   adc_channel,            // bit0~bit3 分别表示 ADC1~ADC4 是否参与当前数据包
    output reg          div_adc_rd_en,          // 四路 row_repeat_module 输出 FIFO 的公共读使能
    input       [9:0]   div_adc1_rd_data_count, // ADC1 输出 FIFO 中可读的 16bit 点数
    input       [15:0]  div_adc1_out,
    input       [9:0]   div_adc2_rd_data_count,
    input       [15:0]  div_adc2_out,
    input       [9:0]   div_adc3_rd_data_count,
    input       [15:0]  div_adc3_out,
    input       [9:0]   div_adc4_rd_data_count,
    input       [15:0]  div_adc4_out,
    output reg          adc_data_mix_wr_en,     // 写 DDR 前级 FIFO 的 valid
    output reg  [63:0]  adc_data_mix            // 统一的 64bit ADC 数据包
    );

reg [3:0]      adc_channel_r0 =0; 
reg [3:0]      adc_channel_r1 =0; 
reg [3:0]      adc_channel_r2 =0;  
// adc_channel 来自配置寄存器，这里在 ui_clk 域打三拍后再参与读 FIFO 和打包判断。
// 采集运行中最好不要动态切换通道选择，否则 64bit 包边界可能混入两种格式。
always @(posedge ui_clk)
begin
    adc_channel_r0 <= adc_channel;
    adc_channel_r1 <= adc_channel_r0;
    adc_channel_r2 <= adc_channel_r1;
end 
//////////////////////judge ADC channel///////////////////////////////////////////////////////////
reg             div_rd_data_valid;
// 公共读使能产生逻辑：
//   对每一个被 adc_channel 选中的通道，要求它的输出 FIFO 至少有 6 个点；
//   未选中的通道不参与水位判断。
//
// 为什么阈值不是 1：
//   div_adc_rd_en 是公共读使能，后面单/双通道打包会连续读多拍；
//   留 6 个点可以覆盖 FIFO 读延迟和打包过程中连续消耗，降低读空风险。
// div_rd_data_valid 是 div_adc_rd_en 的后一拍，用来对齐 FIFO 读出的 div_adc*_out。
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        div_adc_rd_en       <= 1'b0;
        div_rd_data_valid   <= 1'b0; 
    end
    else begin
        div_rd_data_valid   <= div_adc_rd_en;
        if((div_adc1_rd_data_count>=6||adc_channel_r2[0]==0) && (div_adc2_rd_data_count>=6||adc_channel_r2[1]==0) && (div_adc3_rd_data_count>=6 ||adc_channel_r2[2]==0) && (div_adc4_rd_data_count>=6 || adc_channel_r2[3]==0))
            div_adc_rd_en   <= 1'b1;        
        else
            div_adc_rd_en   <= 1'b0;
    end   
end    
/////////////////////////
wire [15:0]     div_adc1_out_r;
wire [15:0]     div_adc2_out_r;
wire [15:0]     div_adc3_out_r;
wire [15:0]     div_adc4_out_r;
// 每路 16bit 数据做字节交换。上游输出是 [15:8][7:0]，这里变成 [7:0][15:8]，
// 使写入 DDR/后续 UDP 发送时符合上位机期望的字节序。
assign div_adc1_out_r = {div_adc1_out[7:0],div_adc1_out[15:8]};
assign div_adc2_out_r = {div_adc2_out[7:0],div_adc2_out[15:8]};
assign div_adc3_out_r = {div_adc3_out[7:0],div_adc3_out[15:8]};
assign div_adc4_out_r = {div_adc4_out[7:0],div_adc4_out[15:8]};

reg [1:0]       adc_data_mix_cnt;    
// 64bit 打包状态：
//   adc_data_mix_cnt 不是列号，而是“当前 64bit 包已经攒了几拍输入”。
//   单通道每拍只有 1 个 16bit 点，要攒 4 拍；
//   双通道每拍有 2 个 16bit 点，要攒 2 拍；
//   三/四通道每拍直接形成 4 个 16bit 槽位，所以每拍都 valid。
//
// 非阻塞赋值下，wr_en 根据 adc_data_mix_cnt 的旧值判断：
//   单通道 cnt==3 时，本拍追加第 4 个 16bit 点，同时拉高 wr_en；
//   双通道 cnt==1 或 3 时，本拍追加第二组 32bit，同时拉高 wr_en。
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        adc_data_mix_cnt    <= 2'd0;
        adc_data_mix_wr_en  <= 1'b0;
        adc_data_mix        <= 64'd0;
    end
    else if(div_rd_data_valid==1) begin
        adc_data_mix_cnt    <= adc_data_mix_cnt + 1'b1;
        case (adc_channel_r2[3:0])
        // 只选 ADC1：连续 4 个 ADC1 点拼成 64bit，时间顺序从高位逐步移到低位。
        4'b0001: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==3)? 1'b1 : 1'b0;
                    adc_data_mix        <= {adc_data_mix[47:0], div_adc1_out_r};                              
                 end  
        // 只选 ADC2/3/4 时规则相同：单通道 4 点拼 1 包。
        4'b0010: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==3)? 1'b1 : 1'b0;
                    adc_data_mix        <= {adc_data_mix[47:0], div_adc2_out_r};  
                 end 
        4'b0100: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==3)? 1'b1 : 1'b0; 
                    adc_data_mix        <= {adc_data_mix[47:0], div_adc3_out_r};  
                 end 
        4'b1000: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==3)? 1'b1 : 1'b0; 
                    adc_data_mix        <= {adc_data_mix[47:0], div_adc4_out_r};
                 end                                         
        // 双通道：一拍读出两个通道同一位置的点，两个位置凑成 64bit。
        // 例如 ADC1+ADC2：{上一个位置的 ch1/ch2, 当前位置的 ch1/ch2}。
        4'b0011: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0;
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc1_out_r, div_adc2_out_r}; 
                 end  
        4'b0101: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0; 
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc1_out_r, div_adc3_out_r};  
                 end 
        4'b1001: begin 
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0; 
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc1_out_r, div_adc4_out_r};  
                 end
        4'b0110: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0;
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc2_out_r, div_adc3_out_r};    
                 end
        4'b1010: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0; 
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc2_out_r, div_adc4_out_r};
                 end
        4'b1100: begin  
                    adc_data_mix_wr_en  <= (adc_data_mix_cnt==1 || adc_data_mix_cnt==3)? 1'b1 : 1'b0;
                    adc_data_mix        <= {adc_data_mix[31:0], div_adc3_out_r, div_adc4_out_r};  
                 end               
        // 三/四通道统一按四槽位输出。代码总是放 ADC1~ADC4 四个槽位，
        // 接收端需要结合 adc_channel 判断哪些槽位是真正启用的通道。
        4'b1111,4'b1110,4'b1101,4'b1011,
        4'b0111:begin  
                    adc_data_mix_wr_en  <= 1'b1;
                    adc_data_mix        <= {div_adc1_out_r, div_adc2_out_r, div_adc3_out_r, div_adc4_out_r};  
                end   
        default:begin  
                    adc_data_mix_wr_en  <= 1'b0;  
                    adc_data_mix        <= adc_data_mix;                     
                end
        endcase
    end 
    else begin 
        adc_data_mix_wr_en  <= 1'b0;
        adc_data_mix        <= adc_data_mix;
    end      
end  
   
// ILA 用来观察公共读使能、一路 16bit 输入、64bit 包 valid 和包内容。
ila_5 test1(
    .clk                    (ui_clk),
    .probe0                 (div_adc_rd_en),                //1
    .probe1                 (div_adc1_out_r),               //16
    .probe2                 (adc_data_mix_wr_en),           //1
    .probe3                 (adc_data_mix)                  //64
    );   
endmodule

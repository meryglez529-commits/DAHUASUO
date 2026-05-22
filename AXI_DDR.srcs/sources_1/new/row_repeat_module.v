`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/12 10:19:04
// Design Name: 
// Module Name: row_repeat_module
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
//////////////////////////////////////////////////////////////////////////////////
// 读这个模块先记住一句话：
//   row_repeat_module 在 ui_clk 域把“同一列的多次重复采样”累加起来，最后除以 row_repeat，
//   输出每一列的重复平均值。
//
// 它位于 adcdata_acq 的异步 FIFO 后面：
//   fifo1_dout 是单路 ADC 已经完成采样平均后的 16bit 列数据；
//   image_column 表示一行有多少列；
//   row_repeat 表示同一行/同一列要重复测几次再平均。
//
// 举例：
//   image_column=4, row_repeat=3 时，输入顺序应理解为
//     第1遍: col0 col1 col2 col3  -> 写入 RAM，暂不输出
//     第2遍: col0 col1 col2 col3  -> 与 RAM 中同列累加，暂不输出
//     第3遍: col0 col1 col2 col3  -> 与 RAM 中同列累加后除以 3，输出 4 个平均列点
//
// 注意：
//   这个模块只处理“行重复平均”，不改变通道数，也不打包成 64bit；
//   后级 adcdata_get 会再按通道把多个 16bit 点组成 64bit 数据流。
//   row_repeat 必须配置为 >= 1，否则除法器分母和状态判断都会异常。
module row_repeat_module(
    input           ui_clk,                 // 本模块唯一工作时钟；输入 FIFO 已经从 ADC DCO 域跨到 ui_clk 域
    input           rstn,
    input   [15:0]  row_repeat,             // 同一列要累加平均的重复次数，配置值应 >= 1
    input   [15:0]  image_column,           // 一行的列数，也是 RAM 按列寻址的循环长度
    output  reg     fifo1_rd_en,            // 读 adcdata_acq 内部异步 FIFO 的读使能
    input   [15:0]  fifo1_dout,             // 当前列的 16bit ADC 平均值
    input           fifo1_empty,            // 上游 FIFO 空标志；不空时本模块才取下一个列点
    
    input           div_adc_rd_en,          // 后级 adcdata_get 读取输出 FIFO 的读使能
    output  [15:0]  div_adc_out,            // 行重复平均后的 16bit 列数据
    output  [9:0]   div_adc_rd_data_count   // 输出 FIFO 当前可读数据量
    );
    
//---------------------SYNC-------------------------------
reg [15:0]  row_repeat_r0   = 1;
reg [15:0]  row_repeat_r1   = 1;
reg [15:0]  row_repeat_r2   = 1;
reg [15:0]  image_column_r0 = 1024;
reg [15:0]  image_column_r1 = 1024;
reg [15:0]  image_column_r2 = 1024;
// row_repeat/image_column 来自配置寄存器，这里在 ui_clk 域打三拍后使用。
// 它不是握手式参数更新，因此采集运行时最好保持配置稳定。
always @(posedge ui_clk)
begin
    row_repeat_r0   <= row_repeat;
    row_repeat_r1   <= row_repeat_r0;
    row_repeat_r2   <= row_repeat_r1;
    image_column_r0 <= image_column;
    image_column_r1 <= image_column_r0;
    image_column_r2 <= image_column_r1;
end
//------------------------------------------------------------------------------
// RAM 的角色：按列暂存“前几遍重复采样的累加和”。
//
// 地址 ram_addr = column_cnt，即第几列；
// 数据 ram_din/ram_dout 是 32bit 累加和，足够容纳多个 16bit ADC 点的相加结果。
// 第一遍重复采样只写当前列值；中间遍读出旧和再加当前值写回；最后一遍只送去除法器。
//------------------------------------------------------------------------------
reg             ram_ena;
reg             ram_wea;
reg     [15:0]  ram_addr;
reg     [31:0]  ram_din;
wire    [31:0]  ram_dout;
blk_mem_gen_0 blk_mem_gen_0(
    .clka                   (ui_clk),
    .ena                    (ram_ena),
    .wea                    (ram_wea),
    .addra                  (ram_addr),
    .dina                   (ram_din),
    .douta                  (ram_dout)
    );
    
reg             div_en;
reg     [31:0]  div_data;
reg             div_en_reg;
reg     [31:0]  div_data_reg;
reg     [2:0]   state1;
reg     [15:0]  row_repeat_cnt;
reg     [15:0]  column_cnt;
//------------------------------------------------------------------------------
// 主状态机：每次从上游 FIFO 取一个“列点”，并根据它属于第几遍 row_repeat 决定动作。
//
// column_cnt：
//   当前列号，范围 0 .. image_column-1。
// row_repeat_cnt：
//   当前是第几遍重复测量。0 表示第一遍；row_repeat-1 表示最后一遍。
//
// 状态含义：
//   0：等待上游 FIFO 非空，同时发起 RAM 读和 FIFO 读；
//   6：多等一拍，让 BRAM 的 ram_dout 和 FIFO 数据稳定；
//   1：根据 row_repeat_cnt 分流；
//   2：row_repeat==1，直接把当前列值送除法器，相当于除以 1；
//   3：第一遍，当前列值写入 RAM，暂不输出；
//   4：中间遍，RAM 旧累加和 + 当前列值，再写回 RAM；
//   5：最后一遍，RAM 旧累加和 + 当前列值送除法器，输出重复平均值。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        column_cnt      <= 0;
        div_en          <= 1'b0;
        div_data        <= 0;
        div_en_reg      <= 1'b0;
        div_data_reg    <= 0;
        ram_ena         <= 1'b0;
        ram_wea         <= 1'b0;
        ram_addr        <= 0;
        ram_din         <= 0;
        fifo1_rd_en     <= 1'b0;
        state1          <= 0;
        row_repeat_cnt  <= 0;
    end
    else begin
        div_en_reg                  <= div_en;
        div_data_reg                <= div_data;
        case(state1)
        0:  begin
                div_en              <= 1'b0;
                div_data            <= 0;
                if(fifo1_empty==0) begin             // 同一拍发起 RAM 读和上游 FIFO 读
                    ram_ena         <= 1'b1;
                    ram_wea         <= 1'b0;
                    ram_addr        <= column_cnt;
                    fifo1_rd_en     <= 1'b1;
                    state1          <= 6;
                end
                else begin
                    ram_ena         <= 1'b0;
                    ram_wea         <= 1'b0;
                    fifo1_rd_en     <= 1'b0;
                    state1          <= 0;        
                end    
            end
        6:  begin
                // BRAM 读数据有延迟，这里延长一拍，保证后面使用 ram_dout 时对应当前 column_cnt。
                ram_ena             <= 1'b1;//20230227延长一拍
                ram_wea             <= 1'b0;
                fifo1_rd_en         <= 1'b0;
                state1              <= 1;
            end
        1:  begin
                if(row_repeat_r2==1)
                    state1          <= 2;    
                else
                    if(row_repeat_cnt==0)                           // 第一遍：RAM 还没有有效历史和
                        state1      <= 3;   
                    else if(row_repeat_cnt < row_repeat_r2 - 1)     // 中间遍：需要读旧和并写回新和
                        state1      <= 4; 
                    else
                        state1      <= 5;                           // 最后一遍：读旧和，加当前值后输出平均结果
            end
        2:  begin
                // 不做行重复时，当前列值直接送去除法器；分母是 row_repeat=1，输出等于输入。
                state1              <= 0;
                div_en              <= 1'b1;
                div_data            <= fifo1_dout;
                if(column_cnt < image_column_r2 - 1)
                    column_cnt      <= column_cnt + 1'b1;
                else 
                    column_cnt      <= 0;         
            end
        3:  begin
                // 第一遍重复采样：把每一列的值作为初始累加和写入 RAM。
                // 一整行写完后 row_repeat_cnt 加 1，准备处理下一遍同一行。
                state1              <= 0;
                ram_ena             <= 1'b1;
                ram_wea             <= 1'b1;
                ram_addr            <= column_cnt;
                ram_din             <= fifo1_dout;
                if(column_cnt < image_column_r2 - 1)
                    column_cnt      <= column_cnt + 1'b1;
                else begin
                    column_cnt      <= 0;
                    row_repeat_cnt  <= row_repeat_cnt + 1;
                end
            end     
        4:  begin
                // 中间遍重复采样：同列相加后写回 RAM，但还不输出。
                // 这样 RAM 中始终保存“到目前为止该列的累加和”。
                state1              <= 0;
                ram_ena             <= 1'b1;
                ram_wea             <= 1'b1;
                ram_addr            <= column_cnt;
                ram_din             <= ram_dout + fifo1_dout;
                if(column_cnt < image_column_r2 - 1)
                    column_cnt      <= column_cnt + 1'b1;
                else begin
                    column_cnt      <= 0;
                    row_repeat_cnt  <= row_repeat_cnt + 1;
                end
            end
        5:  begin
                // 最后一遍重复采样：得到完整累加和，送给除法器除以 row_repeat。
                // 这里不再写回 RAM，因为这一组行重复已经结束。
                state1              <= 0;
                div_en              <= 1'b1;
                div_data            <= ram_dout + fifo1_dout;
                if(column_cnt < image_column_r2 - 1)
                    column_cnt      <= column_cnt + 1'b1;
                else begin
                    column_cnt      <= 0;
                    row_repeat_cnt  <= 0;
                end       
            end
        default: 
            begin
                column_cnt      <= 0;
                div_en          <= 1'b0;
                div_data        <= 0;
                div_en_reg      <= 1'b0;
                div_data_reg    <= 0;
                ram_ena         <= 1'b0;
                ram_wea         <= 1'b0;
                ram_addr        <= 0;
                ram_din         <= 0;
                fifo1_rd_en     <= 1'b0;
                state1          <= 0;
                row_repeat_cnt  <= 0;
            end
        endcase
    end
end
  ///////////////////////// row repeat average divider //////////////////////////////
wire            adc_data_en;
wire [47:0]     adc_data_o;
// div_gen_4 把 32bit 累加和除以 row_repeat，得到重复平均后的列值。
// div_en 先打一拍成 div_en_reg，是为了让 div_data_reg 与 valid 对齐。
div_gen_4 dividend32_divisor16(
    .aclk                   (ui_clk),
    .aresetn                (rstn),
    .s_axis_divisor_tvalid  (1'b1),                      // 分母 row_repeat 常备有效
    .s_axis_divisor_tdata   (row_repeat_r2),
    .s_axis_dividend_tvalid (div_en_reg),
    .s_axis_dividend_tdata  (div_data_reg),              // 被除数是同一列的重复采样累加和
    .m_axis_dout_tvalid     (adc_data_en),
    .m_axis_dout_tdata      (adc_data_o) 
    );    

// 输出 FIFO 缓冲已经完成 row_repeat 平均的 16bit 列数据。
// 后级 adcdata_get 用 div_adc_rd_en 统一读取四路 ADC 的 div_adc_out。
// 当前代码没有接 FIFO full/prog_full 反压，系统层面需要保证 adcdata_get 读取足够及时。
fifo_generator_0  adc_fifo2(
    .srst                   (~rstn),
    .clk                    (ui_clk),
    .din                    (adc_data_o[31:16]),
    .wr_en                  (adc_data_en),
    .rd_en                  (div_adc_rd_en),
    .dout                   (div_adc_out),
    .data_count             (div_adc_rd_data_count) 
    );   
endmodule

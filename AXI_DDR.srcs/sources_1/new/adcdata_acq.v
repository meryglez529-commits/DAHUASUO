`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/18 08:46:38
// Design Name: 
// Module Name: adcdata_acq
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
// 读这个模块时，可以把它看成“单路 ADC 采样整理器”：
// 1) 在 adc_dco 时钟域等待 adc_tri 触发，并按配置延时后打开采集窗口；
// 2) 每 adc_sample_reg 个原始 adc_data 累加一次，再通过 div_gen_0 求平均；
// 3) 平均后的 16bit 数据经异步 FIFO 转到 ui_clk 域，再交给 row_repeat_module 做行重复和后级读出。
// 注意：adc_sample/image_column/adc_interval 等配置量是直接打三拍进入 adc_dco 域的，
//      上层最好在采集空闲期更新这些多 bit 参数，避免跨时钟域时采到中间值。
module adcdata_acq(
    // ui_clk 域接口：后级从这里读取已经平均、行重复处理后的 ADC 数据。
    input               ui_clk,
    input               rstn,
    input [15:0]        row_repeat,
    // 采集配置和触发输入：这些信号会在下面同步到 adc_dco 域后使用。
    input               adc_tri,
    input       [31:0]  adc_sample,
    input       [15:0]  image_column,
    input       [23:0]  adc_interval,   // 普通模式下触发后到开始采集之间的等待计数
    input               ultrafast_mode,
    input       [31:0]  acq_dead_time,
    input       [31:0]  adc_acq_delay,// 超快模式下触发后的采集延时
    // DL5 激光模式参数
    input               laser_mode_en,  // 1=激光模式，0=普通模式
    input       [31:0]  acq_time,       // 激光模式 ADC 采集点数
    // ADC 真实数据输入：采集、累加、除法启动都工作在 adc_dco 域。
    input               adc_dco,
    input       [15:0]  adc_data,
    // row_repeat_module 输出侧接口，由 adcdata_get 在 ui_clk 域读取。
    input               div_adc_rd_en,
    output  reg [15:0]  line_count,
    output  reg         line_count_en,
    output      [9:0]   div_adc_rd_data_count,
    output      [15:0]  div_adc_out
    );
 wire rstnr;
 // 将系统复位同步到 adc_dco 域，避免采集状态机在 DCO 域异步释放复位。
 sync_module sync_module_inst0 (.data_in(rstn), .clk_in(adc_dco), .data_out(rstnr));
//-------------------sync----------------------------------------------------------------------------
reg         adc_tri_r0      = 0;
reg         adc_tri_r1      = 0;
reg         adc_tri_r2      = 0;
reg [23:0]  adc_interval_r0 = 19; 
reg [23:0]  adc_interval_r1 = 19; 
reg [23:0]  adc_interval_r2 = 19; 
reg [31:0]  adc_sample_r0   = 50;
reg [31:0]  adc_sample_r1   = 50;
reg [31:0]  adc_sample_r2   = 50;
reg [15:0]  image_column_r0 = 1024;
reg [15:0]  image_column_r1 = 1024;
reg [15:0]  image_column_r2 = 1024;
reg         ultrafast_mode_r0= 0;
reg         ultrafast_mode_r1= 0;
reg         ultrafast_mode_r2= 0;
reg [23:0]  adc_acq_delay_r0 = 0;
reg [23:0]  adc_acq_delay_r1 = 0;
reg [23:0]  adc_acq_delay_r2 = 0;
reg [31:0]  acq_dead_time_r0 = 0;
reg [31:0]  acq_dead_time_r1 = 0;
reg [31:0]  acq_dead_time_r2 = 0;
reg         laser_mode_en_r0 = 0;
reg         laser_mode_en_r1 = 0;
reg         laser_mode_en_r2 = 0;
reg [31:0]  acq_time_r0      = 50;
reg [31:0]  acq_time_r1      = 50;
reg [31:0]  acq_time_r2      = 50;

// adc_tri 和各类配置参数统一进入 adc_dco 域后再使用。
// 这里对多 bit 配置只做寄存器打拍，不是握手式 CDC；因此这些参数应在采集未运行时保持稳定。
always @(posedge adc_dco)
begin
    adc_tri_r0      <= adc_tri;
    adc_tri_r1      <= adc_tri_r0;
    adc_tri_r2      <= adc_tri_r1;
    adc_interval_r0 <= adc_interval;
    adc_interval_r1 <= adc_interval_r0;
    adc_interval_r2 <= adc_interval_r1;
    adc_sample_r0   <= adc_sample;
    adc_sample_r1   <= adc_sample_r0;
    adc_sample_r2   <= adc_sample_r1;
    image_column_r0 <= image_column;
    image_column_r1 <= image_column_r0;
    image_column_r2 <= image_column_r1;
    ultrafast_mode_r0 <= ultrafast_mode;
    ultrafast_mode_r1 <= ultrafast_mode_r0;
    ultrafast_mode_r2 <= ultrafast_mode_r1;
    adc_acq_delay_r0 <= adc_acq_delay;
    adc_acq_delay_r1 <= adc_acq_delay_r0;
    adc_acq_delay_r2 <= adc_acq_delay_r1;   
    acq_dead_time_r0 <= acq_dead_time;
    acq_dead_time_r1 <= acq_dead_time_r0;
    acq_dead_time_r2 <= acq_dead_time_r1;
    laser_mode_en_r0 <= laser_mode_en;
    laser_mode_en_r1 <= laser_mode_en_r0;
    laser_mode_en_r2 <= laser_mode_en_r1;
    acq_time_r0      <= acq_time;
    acq_time_r1      <= acq_time_r0;
    acq_time_r2      <= acq_time_r1;
end

wire[39:0]  adc_valid_point;
// 本次采集窗口内允许产生的原始采样点数：
// 激光模式 = acq_time，单像素多窗口采集；
// 超快模式 = adc_sample - adc_acq_delay - acq_dead_time - 2，对触发周期中的延时和死区做扣除；
// 普通模式 = image_column * adc_sample，覆盖一整行。
assign adc_valid_point = laser_mode_en_r2   ? acq_time_r2
                       : ultrafast_mode_r2  ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                       : image_column_r2 * adc_sample_r2;
/* always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_valid_point <= 40'd51200;
    else if(ultrafast_mode_r2)
        adc_valid_point <= adc_sample_r2 - adc_acq_delay_r2 - 24'd2;
    else
        adc_valid_point <= image_column_r2 * adc_sample_r2; */

reg [31:0]adc_interval_reg;
// state 1 使用的等待计数。激光模式立即采集（0），超快模式用 adc_acq_delay，普通模式用 adc_interval。
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(laser_mode_en_r2)
        adc_interval_reg <= 32'd0;
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;
    else
        adc_interval_reg <= adc_interval_r2;

reg [3:0]       state;
reg [23:0]      adc_interval_cnt;
// 40bit 计数用于覆盖 image_column * adc_sample 的整行采样范围。
reg [39:0]      adc_valid_point_cnt;                    // 40bit 是为了覆盖 image_column * adc_sample 的整行计数范围
reg             acq_en;
reg [15:0]      image_column_cnt;
reg [31:0]      adc_dead_time_cnt;
// 采集状态机全部运行在 adc_dco 域：
// state 0：等待 adc_tri 上升沿；
// state 1：等待触发后的延时/间隔；
// state 2：打开 acq_en，统计有效采样点；
// state 3：超快模式下等待列间 dead time。
always@(posedge adc_dco or negedge rstnr)
begin
    if(!rstnr) begin
        state                   <= 0;
        adc_interval_cnt        <= 24'd0;
        adc_valid_point_cnt     <= 40'd0;
        acq_en                  <= 1'b0;
        image_column_cnt        <= 16'd0;
        line_count              <= 16'd0;
        line_count_en           <= 16'd0;
        adc_dead_time_cnt       <= 32'd0;
    end
    else
        case(state)
        4'd0:   begin
                        line_count_en       <= 1'b0;
                    // adc_tri 打拍后用 r2/r1 检测上升沿，触发一次采集流程。
                    if(adc_tri_r2==0 && adc_tri_r1==1)
                        state               <= 4'd1;    
                    else
                        state               <= 4'd0;        
                end
        4'd1:   begin                  
                    // 延时计满后进入采集窗口，同时 image_column_cnt 记录当前正在处理的列/窗口序号。
                    if(adc_interval_cnt < adc_interval_reg) begin
                        adc_interval_cnt    <= adc_interval_cnt + 1'b1; 
                        state               <= 4'd1;
                    end
                    else begin
                        adc_interval_cnt    <= 24'd0;
                        image_column_cnt <= image_column_cnt + 1'b1;
                        state               <= 4'd2;
                    end   
                end
        4'd2:   begin
                    if(adc_valid_point == 0) begin                                // adc_valid_point 配成 0 时表示连续采集
                        acq_en              <= 1'b1;
                        state               <= 4'd2;  
                    end
                    else if(adc_valid_point_cnt < adc_valid_point) begin
                        adc_valid_point_cnt <= adc_valid_point_cnt + 1'b1;
                        acq_en              <= 1'b1;
                        state               <= 4'd2;
                    end
                    else if(ultrafast_mode_r2 == 1)begin
                        // 超快模式下，一个窗口结束后可能继续下一列；整行结束时更新 line_count。
                        adc_valid_point_cnt <= 0;
                        acq_en              <= 1'b0;
                        if(acq_dead_time_r2 == 32'd0)
                            if(image_column_cnt == image_column_r2) begin
                                state               <= 4'd0;
                                image_column_cnt    <= 16'd0;
                                line_count          <= line_count + 1'b1;
                                line_count_en       <= 1'b1;
                                end
                            else
                                state               <= 4'd1;
                        else
                                state               <= 4'd3;
                    end
                    else if(laser_mode_en_r2 == 1)begin
                        // 激光模式：单像素多窗口，跳过 dead time，窗口采满后根据 image_column 判断是否继续。
                        adc_valid_point_cnt <= 0;
                        acq_en              <= 1'b0;
                        if(image_column_cnt == image_column_r2) begin
                            state               <= 4'd0;
                            image_column_cnt    <= 16'd0;
                            line_count          <= line_count + 1'b1;
                            line_count_en       <= 1'b1;
                        end
                        else
                            state               <= 4'd1;
                    end
                    else begin
                        // 普通模式一次触发只采一整行，窗口结束后回到等待触发。
                        adc_valid_point_cnt <= 0;
                        acq_en              <= 1'b0;
                        state               <= 4'd0;
                    end  
                end
        4'd3:   begin
                    // dead time 只在超快模式使用，用来隔开相邻列/窗口。
                    if(adc_dead_time_cnt == acq_dead_time_r2 - 1)begin
                        adc_dead_time_cnt <= 32'd0;
                        if(image_column_cnt == image_column_r2) begin 
                            state               <= 4'd0;
                            image_column_cnt    <= 16'd0;
                            line_count          <= line_count + 1'b1;
                            line_count_en       <= 1'b1;
                            end
                        else
                            state               <= 4'd1;
                    end
                    else begin
                        adc_dead_time_cnt <= adc_dead_time_cnt + 1'b1;
                        state             <= 4'd3;
                    end
        end

        default:begin
                    state                   <= 0;
                    adc_interval_cnt        <= 24'd0;
                    adc_valid_point_cnt     <= 0;
                    adc_dead_time_cnt       <= 0;
                    acq_en                  <= 1'b0;
                    line_count              <= 16'd0;
                    line_count_en           <= 16'd0;
                end
        endcase
end         
///////////////////////// average accumulator //////////////////////////////
reg  [23:0]     adc_sum_cnt;
reg  [39:0]     adc_sum_data_r;
reg  [39:0]     adc_sum_data;
reg             adc_divide_en;
wire [31:0]     adc_sample_reg;
// 每个平均点的分母。激光模式用 acq_time；超快模式扣掉延时和死区；普通模式直接用 adc_sample。
// 若超快模式参数设置不合理导致这里为 0 或下溢，后级除法器输入也会异常，配置侧需要保证合法。
assign adc_sample_reg = laser_mode_en_r2  ? acq_time_r2
                      : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 -  24'd2)
                      : adc_sample_r2;
// N 点累加平均的前级累加器：acq_en 有效时累计 adc_sample_reg 个 adc_data，
// 累满后把总和送给除法 IP，并用 adc_divide_en 拉高一个周期作为 dividend 的 valid。
always@(posedge adc_dco or negedge rstnr)
begin
    if(!rstnr) begin
        adc_sum_cnt         <= 24'd0;
        adc_sum_data_r      <= 40'd0;
        adc_sum_data        <= 40'd0;
        adc_divide_en       <= 1'b0;   
    end
    else if (acq_en)
        if(adc_sum_cnt < adc_sample_reg - 1) begin
            adc_sum_cnt         <= adc_sum_cnt +1'b1;
            adc_sum_data_r      <= adc_sum_data_r + adc_data;
            adc_divide_en       <= 1'b0;
        end
        else begin
            adc_sum_cnt         <= 24'd0;
            adc_sum_data_r      <= 40'd0;
            adc_sum_data        <= adc_sum_data_r + adc_data;  
            adc_divide_en       <= 1'b1;
        end  
    else
        adc_divide_en       <= 1'b0;    
end     
///////////////////////// average divider //////////////////////////////
wire            adc_average_data_en;
wire [63:0]     adc_average_data;
// div_gen_0：把 40bit 累加和除以 adc_sample_reg，输出平均值。
// 当前代码取 adc_average_data[39:24] 作为 16bit 结果，具体位宽/小数格式取决于该除法 IP 的配置。
div_gen_0 dividend40_divisor24 (
    .aclk                   (adc_dco),
    .aresetn                (rstn),
    .s_axis_divisor_tvalid  (1'b1),                      // 分母常备有效，真正启动由 dividend 的 adc_divide_en 决定
    .s_axis_divisor_tdata   (adc_sample_reg),
    .s_axis_dividend_tvalid (adc_divide_en),
    .s_axis_dividend_tdata  (adc_sum_data),             // 被除数为本窗口内的 ADC 累加和
    .m_axis_dout_tvalid     (adc_average_data_en),
    .m_axis_dout_tdata      (adc_average_data) 
    );     
/////////sec_fifo//////////////////////////////////////
wire            fifo1_rd_en;
wire    [15:0]  fifo1_dout;
wire            fifo1_empty;
// 异步 FIFO：写端是 adc_dco 域的平均结果，读端是 ui_clk 域。
// 这里没有接 full/prog_full 反压，系统层面需要保证后级读取速度和 FIFO 深度足够。
fifo_generator_1  adc_fifo1(
    .rst                    (~(rstn & rstnr)),
    .rd_clk                 (ui_clk),
    .wr_clk                 (adc_dco),
    .din                    (adc_average_data[39:24]),
    .wr_en                  (adc_average_data_en),
    .rd_en                  (fifo1_rd_en),
    .dout                   (fifo1_dout),
    .empty                  (fifo1_empty) 
    ); 

// row_repeat_module 在 ui_clk 域消费平均后的单行数据，根据 row_repeat 做行重复，
// 最终通过 div_adc_out/div_adc_rd_data_count 供 adcdata_get 汇聚四路 ADC 数据。
row_repeat_module row_repeat_module_inst(
    .ui_clk                 (ui_clk),
    .rstn                   (rstn),
    .row_repeat             (row_repeat),
    .image_column           (image_column),
    .fifo1_rd_en            (fifo1_rd_en),
    .fifo1_dout             (fifo1_dout),
    .fifo1_empty            (fifo1_empty),
    
    .div_adc_rd_en          (div_adc_rd_en),
    .div_adc_out            (div_adc_out),
    .div_adc_rd_data_count  (div_adc_rd_data_count)
);   

// ILA 调试点覆盖触发、采集使能、除法输出、状态机、有效点计数和行计数，
// 适合在线确认触发到平均数据输出之间的时序关系。
ila_12 test(
    .clk                    (adc_dco),
    .probe0                 (adc_tri_r1),               //1
    .probe1                 (adc_data),                 //16
    .probe2                 (acq_en),                   //1
    .probe3                 (adc_divide_en),            //1
    .probe4                 (adc_average_data_en),      //1
    .probe5                 (adc_average_data[39:24]),   //16
	.probe6                 (state), // input wire [3:0]  probe6 
	.probe7                 (adc_valid_point[15:0]), // input wire [15:0]  probe7 
	.probe8                 (adc_sample_r2[23:0]), // input wire [23:0]  probe8 
	.probe9                 (adc_acq_delay_r2), // input wire [31:0]  probe9 
	.probe10                (adc_valid_point_cnt[15:0]), // input wire [15:0]  probe10
    .probe11                (adc_sample_reg),
	.probe12                (line_count), // input wire [15:0]  probe10
    .probe13                (line_count_en),
	.probe14                (acq_dead_time_r2), // input wire [15:0]  probe10
    .probe15                (adc_dead_time_cnt)
);
 

endmodule

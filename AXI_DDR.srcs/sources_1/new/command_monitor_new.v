`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2021/03/10 08:55:05
// Design Name:
// Module Name: command_monitor_new
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
// command_monitor_new 做的事只有一件：
//   把上位机通过 UDP 写进来的 16-bit 地址 + 32-bit 数据，保存成 eth_clk 域的控制寄存器影子表。
//
// 为什么需要它：
//   LAN_WR_REG 只负责把网络 payload 拆成 WR_REG/RD_REG 命令，不知道地址含义。
//   DL1/DL2/DL3 业务模块需要的是长期保持的参数，例如图像行列数、ADC 采样长度、
//   DAC 起止电平、扫描启停、remote 复位和 offset 配置。
//   本模块就是两者之间的“协议翻译表”。
//
// 先把单位分清：
//   wr_reg_addr / rd_reg_addr = 16-bit 控制地址。
//   wr_reg_data / rd_reg_data = 32-bit 寄存器数据。
//   image_row / image_column = 一帧里的空间位置维度，image_point = row * column。
//   dacx/dacy_*_level = 16-bit DAC 码值；dacx_step/dacy_step 是由 step_module 派生出的 64-bit 步进量。
//
// 在 DL4 链路中的位置：
//   WR_RD_REG_TOP -> command_monitor_new -> adcdata_config / dacdata_config / ddr3_ctrl / offset 配置模块
//------------------------------------------------------------------------------
module command_monitor_new(
    input       [0:0]   eth_clk,
    input       [0:0]   eth_rst,
    input       [0:0]   wr_reg_valid,
    input       [15:0]  wr_reg_addr,
    input       [31:0]  wr_reg_data,
    input       [0:0]   rd_reg_valid,
    input       [15:0]  rd_reg_addr,
    output  reg [31:0]  rd_reg_data,

    input        [31:0] remote_result,
    output  reg         clk_sel,
    output  reg [20:0]  adc_len_single,
    output  reg [3:0]   adc_channel,
    output  reg [31:0]  adc_sample,
    output  reg [31:0]  dac_sample,
    output  reg [1:0]   adc1_gain,
    output  reg [1:0]   adc2_gain,
    output  reg [1:0]   adc3_gain,
    output  reg [1:0]   adc4_gain,
    output  reg [1:0]   dacx_gain,
    output  reg [1:0]   dacy_gain,
    output  reg [15:0]  image_row,
    output  reg [15:0]  image_column,

    output  reg [15:0]  dacx_strat_level,
    output  reg [15:0]  dacx_end_level,
    output      [63:0]  dacx_step,
    output  reg [15:0]  dacx_tk_point,
    output  reg [15:0]  dacx_recovery_time,
    output  reg [15:0]  dacy_strat_level,
    output  reg [15:0]  dacy_end_level,
    output      [63:0]  dacy_step,
    output  reg [31:0]  frame_waiting_time,
    output  reg [31:0]  dax_fall_time,
    output  reg [23:0]  adc_interval,
    output  reg [3:0]   scan_mode,
    output  reg [3:0]   scan_state,
    output  reg         remote_rstn,
    output  reg         wr_offset_flag,
    output  reg [31:0]  offset_adc1_adc2,
    output  reg [31:0]  offset_adc3_adc4,
    output  reg [31:0]  offset_dacx_dacy,
    output  reg [31:0]  image_point,

    output reg  [15:0]    row_repeat,
    output reg  [15:0]    row_m,
    output reg  [15:0]    row_n,
    output reg  [15:0]    sync1_pixel_tri_wigth,
    output reg  [15:0]    sync2_pixel_tri_wigth,
    output reg  [31:0]    adc_acq_delay,
    output reg  [31:0]    ultrafast_line_rec,
    output reg            ultrafast_mode,
    output reg  [15:0]    sync_sig_delay1,
    output reg  [15:0]    sync_sig_delay2,
    output reg  [31:0]    acq_dead_time,

    // DL5 激光同步模式新增寄存器（地址 0x0205~0x020A）
    output reg            laser_mode_en,
    output reg  [15:0]    scan_delay_time,
    output reg  [15:0]    blanker_delay_time,
    output reg  [15:0]    blanker_time,
    output reg  [15:0]    acq_data_delay_time,
    output reg  [15:0]    acq_time,

    output  reg [31:0]  pc_ack_r
    );
//------------------------------------------------------------------------------
// 1. 异步状态同步：把 remote_result 打 3 拍后再给 PC 读回
//
// remote_result 来自 remote/DDR/QSPI 相关链路。这里不解释它的每一位，
// 只把它在 eth_clk 域寄存 3 拍，读地址 0x000B 时返回 remote_result_reg[2]。
// 这样 PC 看到的是较稳定的状态快照，而不是直接读外部输入。
//------------------------------------------------------------------------------
reg [31:0] version_number={16'd3,16'd172};
reg [31:0] remote_result_reg[0:2];
always@(posedge eth_clk or posedge eth_rst)
begin
if(eth_rst)
    {remote_result_reg[2],remote_result_reg[1],remote_result_reg[0]} <= {32'd0,32'd0,32'd0};
else
    {remote_result_reg[2],remote_result_reg[1],remote_result_reg[0]} <= {remote_result_reg[1],remote_result_reg[0],remote_result};
end

reg         dacx_step_flag;
reg         dacy_step_flag;
reg [31:0]  heart_beat;
reg         heart_beat_flag;
reg         heart_rst;
reg         pc_ack_flag;
reg [31:0]  pc_ack;

//------------------------------------------------------------------------------
// 2. 写寄存器表：一拍 WR_REG 命令变成长期保持的控制参数
//
// wr_reg_valid 是 LAN_WR_REG 解析完一个写 payload 后给出的一拍脉冲。
// 本 always 块在这一拍用 wr_reg_addr 选择写哪个“影子寄存器”。
// 写入后，输出寄存器会一直保持，直到下一次写、eth_rst 或 heart_rst 清回默认值。
//
// 这些输出不是业务数据流本身，而是控制 DL1/DL2/DL3 的参数：
//   DL1 DAC 扫描：dac_sample、image_row、dacx/dacy 电平、scan_mode、sync 延迟等。
//   DL2 ADC 采集：adc_len_single、adc_channel、adc_sample、adc_interval、ultrafast 参数等。
//   DL3/支撑链路：remote_rstn、offset_*、wr_offset_flag、pc_ack 等。
//
// 注意几个非直觉点：
//   0x0002 同时写 dac_sample 和 adc_sample，说明 DAC 停留/ADC 平均使用同一个上位机参数。
//   0x0004 写 row/column 时同步计算 image_point，并触发 dacy_step_flag 重新计算 Y 步进。
//   wr_offset_flag、dacx_step_flag、dacy_step_flag、heart_beat_flag、pc_ack_flag 都是一拍触发信号，
//   不写对应地址时会在下面的 else/default 分支里清 0。
//------------------------------------------------------------------------------
always@(posedge eth_clk or posedge eth_rst)
begin
    if(eth_rst) begin
        clk_sel             <= 1'b0;
        adc_len_single      <= 21'd1;
        adc_channel         <= 4'd15;
        adc_sample          <= 32'd50;
        dac_sample          <= 32'd50;
        adc1_gain           <= 2'd2;
        adc2_gain           <= 2'd2;
        adc3_gain           <= 2'd2;
        adc4_gain           <= 2'd2;
        dacx_gain           <= 2'd3;
        dacy_gain           <= 2'd3;
        image_row           <= 16'd1024;
        image_column        <= 16'd1024;
        image_point         <= 32'd1048576;
        dacx_strat_level    <= 16'h8000;
        dacx_end_level      <= 16'h8000;
        dacx_tk_point       <= 16'd128;
        dacx_recovery_time  <= 16'd1;
        dacy_strat_level    <= 16'h8000;
        dacy_end_level      <= 16'h8000;
        frame_waiting_time  <= 32'd0;
        dax_fall_time       <= 32'd20;
        adc_interval        <= 24'd19; //380ns
        scan_mode           <= 4'd1;
        scan_state          <= 4'd0;
        remote_rstn         <= 1'b0;
        heart_beat          <= 32'h00000000;
        offset_adc1_adc2    <= 32'd0;
        offset_adc3_adc4    <= 32'd0;
        offset_dacx_dacy    <= 32'd0;
        row_repeat          <= 1;
        row_m               <= 0;
        row_n               <= 1;
        sync1_pixel_tri_wigth <= 16'd1;
        sync2_pixel_tri_wigth <= 16'd1;
        adc_acq_delay       <= 32'd0;
        ultrafast_line_rec  <= 32'd1;
        ultrafast_mode      <= 1'b0;
        sync_sig_delay1    <= 16'd0;
        sync_sig_delay2    <= 16'd0;
        acq_dead_time      <= 32'd0;
        // DL5 激光同步模式寄存器初始化
        laser_mode_en           <= 1'b0;
        scan_delay_time         <= 16'd0;
        blanker_delay_time      <= 16'd0;
        blanker_time            <= 16'd0;
        acq_data_delay_time     <= 16'd0;
        acq_time                <= 16'd0;
        // 以下 flag 都是”一拍事件”，复位时清 0，避免消费者误认为还有新命令。
        wr_offset_flag      <= 1'b0;
        dacx_step_flag      <= 1'b0;
        dacy_step_flag      <= 1'b0;
        heart_beat_flag     <= 1'b0;
        pc_ack_flag         <= 1'b0;
        pc_ack              <= 32'haa5555aa;
    end
    else if(heart_rst)begin
        clk_sel             <= 1'b0;
        adc_len_single      <= 21'd1;
        adc_channel         <= 4'd15;
        adc_sample          <= 32'd50;
        dac_sample          <= 32'd50;
        adc1_gain           <= 2'd2;
        adc2_gain           <= 2'd2;
        adc3_gain           <= 2'd2;
        adc4_gain           <= 2'd2;
        dacx_gain           <= 2'd3;
        dacy_gain           <= 2'd3;
        image_row           <= 16'd1024;
        image_column        <= 16'd1024;
        image_point         <= 32'd1048576;
        dacx_strat_level    <= 16'h8000;
        dacx_end_level      <= 16'h8000;
        dacx_tk_point       <= 16'd128;
        dacx_recovery_time  <= 16'd1;
        dacy_strat_level    <= 16'h8000;
        dacy_end_level      <= 16'h8000;
        frame_waiting_time  <= 32'd0;
        dax_fall_time       <= 32'd20;
        adc_interval        <= 24'd19; //380ns
        scan_mode           <= 4'd1;
        scan_state          <= 4'd0;
        offset_adc1_adc2    <= 32'd0;
        offset_adc3_adc4    <= 32'd0;
        offset_dacx_dacy    <= 32'd0;
        // heart_rst 走的是一次软清默认值路径，但仍允许同拍重新接收 0x000D 心跳写入。
        wr_offset_flag      <= 1'b0;
        dacx_step_flag      <= 1'b0;
        dacy_step_flag      <= 1'b0;
        pc_ack_flag         <= 1'b0;
        pc_ack              <= 32'h00000000;
        if(wr_reg_valid==1 && wr_reg_addr==16'h000D)
            begin heart_beat <= wr_reg_data[31:0];  heart_beat_flag <= 1'b1; end
        else
            heart_beat_flag <= 1'b0;
    end
    else
        if(wr_reg_valid)
            case (wr_reg_addr)
            // 0x0000: 时钟/触发选择。它只保存选择位，具体怎么使用在 dacdata_config 等消费者里。
            16'h0000: begin clk_sel         <= wr_reg_data[0];  end
            // 0x0001: ADC 上传/采样配置。
            // [24:4] 是 21-bit 长度字段，[3:0] 是通道选择字段。
            16'h0001: begin
                            adc_len_single  <= wr_reg_data[24:4];
                            adc_channel     <= wr_reg_data[3:0];
                      end
            // 0x0002: DAC 与 ADC 共用 sample 参数。
            // 读回时只返回 adc_sample，但写入时 dac_sample/adc_sample 同步更新。
            16'h0002: begin
                            dac_sample      <= wr_reg_data[31:0];
                            adc_sample      <= wr_reg_data[31:0];
                      end
            // 0x0003: 六个 2-bit gain 字段打包在低 12 bit。
            16'h0003: begin
                            adc1_gain       <= wr_reg_data[1:0];
                            adc2_gain       <= wr_reg_data[3:2];
                            adc3_gain       <= wr_reg_data[5:4];
                            adc4_gain       <= wr_reg_data[7:6];
                            dacx_gain       <= wr_reg_data[9:8];
                            dacy_gain       <= wr_reg_data[11:10];
                      end
            // 0x0004: 图像尺寸。
            // row/column 是空间维度，image_point 是一帧总位置数；通道数不改变 image_point。
            // 写 row/column 后触发 Y 方向步进重算，因为 dacy_step 以 image_row 为 point。
            16'h0004: begin
                            image_row       <= wr_reg_data[31:16];
                            image_column    <= wr_reg_data[15:0];
                            dacy_step_flag  <= 1'b1;
                            image_point     <= wr_reg_data[31:16] * wr_reg_data[15:0];
                      end
            // 0x0005/0x0006 控制 X 方向扫描。
            // 0x0006 改变点数/恢复时间后触发 dacx_step 重新计算。
            16'h0005: begin
                            dacx_strat_level    <= wr_reg_data[31:16];
                            dacx_end_level      <= wr_reg_data[15:0];
                      end
            16'h0006: begin
                            dacx_tk_point       <= wr_reg_data[31:16];
                            dacx_recovery_time  <= wr_reg_data[15:0];
                            dacx_step_flag      <= 1'b1;
                      end
            // 0x0007 控制 Y 方向扫描，写入后触发 dacy_step 重新计算。
            16'h0007: begin
                            dacy_strat_level    <= wr_reg_data[31:16];
                            dacy_end_level      <= wr_reg_data[15:0];
                            dacy_step_flag      <= 1'b1;
                      end
            16'h0008: begin frame_waiting_time  <= wr_reg_data[31:0]; end
            16'h000F: begin dax_fall_time       <= wr_reg_data[31:0]; end
            // 0x0009: 扫描时序与启停。
            // [31:8] 是 ADC 间隔，[7:4] 是扫描模式，[3:0] 是扫描状态。
            16'h0009: begin
                            adc_interval        <= wr_reg_data[31:8];
                            scan_mode           <= wr_reg_data[7:4];
                            scan_state          <= wr_reg_data[3:0];
                      end
            16'h000C: begin remote_rstn         <= wr_reg_data[0]; end
            // 0x000D: 心跳。当前有效逻辑里 heart_rst 不会被超时置 1，
            // 但 0x5555AAAA 仍会清 heart_cnt，作为 PC 仍在线的观测点。
            16'h000D: begin
                            heart_beat          <= wr_reg_data[31:0];
                            heart_beat_flag     <= 1'b1;
                      end
            // 0x000E: PC ack。只有 scan_state[0]=1 时，后面的 pc_ack_r 逻辑才会保持这个值。
            16'h000E: begin pc_ack              <= wr_reg_data[31:0]; pc_ack_flag <= 1'b1; end
            // 0x0010~0x0012: offset 配置。0x0012 额外产生 wr_offset_flag，用于通知 FRAM/offset 链路写入。
            16'h0010: begin offset_adc1_adc2    <= wr_reg_data[31:0]; end
            16'h0011: begin offset_adc3_adc4    <= wr_reg_data[31:0]; end
            16'h0012: begin
                            offset_dacx_dacy    <= wr_reg_data[31:0];
                            wr_offset_flag      <= 1'b1;
                      end
            // 0x0013/0x0014: 行重复和分组扫描参数。
            // row_repeat 和 row_n 不允许为 0；上位机写 0 时硬件强制改成 1，避免后级除 0 或空循环。
            16'h0013: begin row_repeat          <= (wr_reg_data[15:0]==0)? 16'd1 : wr_reg_data[15:0]; end
            16'h0014: begin
                            row_m               <= wr_reg_data[31:16];
                            row_n               <= (wr_reg_data[15:0]==0)? 16'd1 : wr_reg_data[15:0];
                      end
            // 0x0200~0x0204: ultrafast/sync 扩展参数。
            // 注意：本 case 里 0x0200 出现了两次。Verilog case 命中第一个匹配项后就结束，
            // 因此后面的 sync2_pixel_tri_wigth 分支通常不可达。这里先按原代码保留，只把风险标出来。
            16'h0200:begin
                            sync1_pixel_tri_wigth <= wr_reg_data[15:0];
                      end
            16'h0201:begin
                            adc_acq_delay        <= wr_reg_data[31:0];
                      end
            16'h0202:begin
                            ultrafast_line_rec   <= {1'b0,wr_reg_data[31:1]};
                            ultrafast_mode       <= wr_reg_data[0];
                     end
            16'h0203: begin
                            sync_sig_delay1    <= wr_reg_data[31:16];
                            sync_sig_delay2    <= wr_reg_data[15:0];
                      end
            16'h0204: begin
                            acq_dead_time      <= wr_reg_data[31:0];
                      end
            // DL5 激光同步模式寄存器（地址 0x0205~0x020A）
            16'h0205: begin
                            laser_mode_en           <= wr_reg_data[0];
                      end
            16'h0206: begin
                            scan_delay_time         <= wr_reg_data[15:0];
                      end
            16'h0207: begin
                            blanker_delay_time      <= wr_reg_data[15:0];
                      end
            16'h0208: begin
                            blanker_time            <= wr_reg_data[15:0];
                      end
            16'h0209: begin
                            acq_data_delay_time     <= wr_reg_data[15:0];
                      end
            16'h020A: begin
                            acq_time                <= wr_reg_data[15:0];
                      end
            // 风险点：与上面的 0x0200 重复。若协议需要独立配置 sync2 宽度，应和上位机协议核对地址。
            16'h0200:begin
                            sync2_pixel_tri_wigth <= wr_reg_data[15:0];
                      end
            default:  begin
                            wr_offset_flag      <= 1'b0;
                            dacx_step_flag      <= 1'b0;
                            dacy_step_flag      <= 1'b0;
                            heart_beat_flag     <= 1'b0;
                            pc_ack_flag         <= 1'b0;
                      end
            endcase
        else begin
            wr_offset_flag      <= 1'b0;
            dacx_step_flag      <= 1'b0;
            dacy_step_flag      <= 1'b0;
            heart_beat_flag     <= 1'b0;
            pc_ack_flag         <= 1'b0;
        end
end

//------------------------------------------------------------------------------
// 3. 读寄存器表：PC 读地址时返回一个 32-bit 快照
//
// rd_reg_valid 是 LAN_WR_REG 解析完读 payload 后给出的一拍脉冲。
// 这里按 rd_reg_addr 把当前影子寄存器打包到 rd_reg_data。
// WR_RD_REG_TOP 会把 rd_reg_valid 延迟 3 拍后交给 LAN_RD_REG 打包响应，
// 所以 rd_reg_data 需要在这个 always 块里寄存住，而不是组合输出。
//
// 注意：
//   0x0200~0x0204 当前没有读回 case；PC 读这些扩展参数会落到 default=0x11223344。
//   0x0002 读回 adc_sample；虽然写入时 adc_sample 和 dac_sample 同步，但没有单独读 dac_sample 的地址。
//------------------------------------------------------------------------------
always@(posedge eth_clk or posedge eth_rst)
begin
    if(eth_rst)
        rd_reg_data <= 32'd0;
    else if(rd_reg_valid)
        case (rd_reg_addr)
        16'h0000: begin rd_reg_data <= {31'd0, clk_sel}; end
        16'h0001: begin rd_reg_data <= {7'd0,adc_len_single,adc_channel}; end
        16'h0002: begin rd_reg_data <= adc_sample; end
        16'h0003: begin rd_reg_data <= {20'd0, dacy_gain, dacx_gain, adc4_gain, adc3_gain, adc2_gain, adc1_gain}; end
        16'h0004: begin rd_reg_data <= {image_row, image_column}; end
        16'h0005: begin rd_reg_data <= {dacx_strat_level, dacx_end_level}; end
        16'h0006: begin rd_reg_data <= {dacx_tk_point, dacx_recovery_time}; end
        16'h0007: begin rd_reg_data <= {dacy_strat_level, dacy_end_level}; end
        16'h0008: begin rd_reg_data <= frame_waiting_time; end
        16'h000F: begin rd_reg_data <= dax_fall_time; end
        16'h0009: begin rd_reg_data <= {adc_interval,scan_mode,scan_state}; end
        16'h000A: begin rd_reg_data <= version_number; end
        16'h000B: begin rd_reg_data <= remote_result_reg[2]; end
        16'h000C: begin rd_reg_data <= {31'd0,remote_rstn}; end
        16'h000D: begin rd_reg_data <= heart_beat; end
        16'h0010: begin rd_reg_data <= offset_adc1_adc2; end
        16'h0011: begin rd_reg_data <= offset_adc3_adc4; end
        16'h0012: begin rd_reg_data <= offset_dacx_dacy; end
        16'h0013: begin rd_reg_data <= {16'd0,row_repeat}; end
        16'h0014: begin rd_reg_data <= {row_m,row_n}; end
        // DL5 激光同步模式寄存器读回
        16'h0205: begin rd_reg_data <= {31'd0, laser_mode_en}; end
        16'h0206: begin rd_reg_data <= {16'd0, scan_delay_time}; end
        16'h0207: begin rd_reg_data <= {16'd0, blanker_delay_time}; end
        16'h0208: begin rd_reg_data <= {16'd0, blanker_time}; end
        16'h0209: begin rd_reg_data <= {16'd0, acq_data_delay_time}; end
        16'h020A: begin rd_reg_data <= {16'd0, acq_time}; end
        default:  begin rd_reg_data <= 32'h11223344; end
        endcase
    else
        rd_reg_data <= rd_reg_data;
end

//------------------------------------------------------------------------------
// 4. 派生参数：把起止电平和点数换算成 DAC 每步增量
//
// 上位机写入的是容易理解的量：起始电平、结束电平、点数。
// DAC 发生器需要的是每一个扫描点应该增加多少。step_module 在对应 flag 为 1 的那一拍重算。
// X 方向 point 来自 dacx_tk_point；Y 方向 point 来自 image_row。
//------------------------------------------------------------------------------
step_module dax_step_module(
    .clk                (eth_clk),
    .rst                (eth_rst),
    .cal_en             (dacx_step_flag),
    .point              (dacx_tk_point),
    .strat_level        (dacx_strat_level),
    .end_level          (dacx_end_level),
    .step_o             (dacx_step)
    );
step_module day_step_module(
    .clk                (eth_clk),
    .rst                (eth_rst),
    .cal_en             (dacy_step_flag),
    .point              (image_row),
    .strat_level        (dacy_strat_level),
    .end_level          (dacy_end_level),
    .step_o             (dacy_step)
    );

//------------------------------------------------------------------------------
// 5. 心跳：当前代码只计数和清计数，不会因为超时触发 heart_rst
//
// 历史版本的注释块里曾经有“超时置 heart_rst=1”的写法，但现在有效代码在超时分支仍赋 0。
// 因此 heart_rst 目前不会主动软复位寄存器表；0x000D 写 0x5555AAAA 的主要作用是清 heart_cnt。
//------------------------------------------------------------------------------
//reg [31:0]  heart_cnt;
//always@(posedge eth_clk or negedge eth_rst)
//begin
//    if(eth_rst) begin
//        heart_rst <= 1'b1;
//        heart_cnt <= 32'd0;
//    end
//    else if(heart_beat_flag==1 && heart_beat==32'h5555AAAA) begin
//        heart_rst <= 1'b0;
//        heart_cnt <= 32'd0;
//    end
//    else if(heart_cnt < 187500000)               //1.5S
//        heart_cnt <= heart_cnt + 1'b1;
//    else begin
//        heart_rst <= 1'b1;
//        heart_cnt <= 32'd0;
//    end
//end
reg [31:0]  heart_cnt;
always@(posedge eth_clk or posedge eth_rst)
begin
    if(eth_rst) begin
        heart_rst <= 1'b0;
        heart_cnt <= 32'd0;
    end
    else if(heart_beat_flag==1 && heart_beat==32'h5555AAAA) begin
        heart_rst <= 1'b0;
        heart_cnt <= 32'd0;
    end
    else if(heart_cnt < 187500000)               //1.5S
        heart_cnt <= heart_cnt + 1'b1;
    else begin
        heart_rst <= 1'b0;
        heart_cnt <= 32'd0;
    end
end

//------------------------------------------------------------------------------
// 6. pc_ack 输出门控：只有扫描启动状态下才把 PC ack 保持给后级
//
// pc_ack 来自写地址 0x000E；pc_ack_flag 是一拍写入事件。
// 当 scan_state[0]=0 时，pc_ack_r 被清 0；扫描有效时才允许 pc_ack_r 更新并保持。
// 这让后级看到的是“扫描期间有效的 PC 确认值”，而不是任意时刻写入的旧值。
//------------------------------------------------------------------------------
always@(posedge eth_clk or posedge eth_rst)
begin
    if(eth_rst)
        pc_ack_r <= 32'h00000000;
    else if(scan_state[0]==0)
        pc_ack_r <= 32'h00000000;
    else if(pc_ack_flag==1)
        pc_ack_r <= pc_ack;
    else
        pc_ack_r <= pc_ack_r;
end

endmodule

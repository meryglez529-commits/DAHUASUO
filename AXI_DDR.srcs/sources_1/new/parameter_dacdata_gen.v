`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : parameter_dacdata_gen
// Create Date : 2020/07/09
//
// 一句话先抓住本模块：
//   parameter_dacdata_gen 是 DL1(DAC 扫描输出链路)里的波形预生成器。
//   它按照 PC/ETH 配置好的扫描参数，逐拍算出一整帧扫描所需的
//   DAX、DAY、adc_tri 和 sync 标志，然后打包成 35-bit FIFO 写入流。
//
// 这不是直接驱动 DAC 引脚的模块：
//   上游 dacdata_config 在 eth_clk 域给本模块参数和复位/触发；
//   本模块也跑在 eth_clk 域，端口名 ui_clk 是历史遗留命名；
//   下游 dac_output 通过异步 FIFO 在 dac_dco 域读出 35-bit 数据，
//   再拆成 DAX_DATA、DAY_DATA、adc_tri 和 sync 输出。
//
// 读代码时先分清几个单位：
//   1) 一个 FIFO word = 一个未来的 DAC 输出拍。
//   2) DAX/DAY 是 16-bit DAC 码值，但内部用 64-bit 定点数累计：
//      [63:48] 是真正输出的 16-bit 整数部分，[47:0] 是小数部分。
//   3) 一个像素点会保持 dac_sample 个 FIFO word；这段时间 adc_tri=1，
//      后级 ADC 也在这段稳定 DAC 电平上完成平均采样。
//   4) Tb/下降斜坡/帧等待都会写入 FIFO，但 adc_tri=0，表示只移动或等待，
//      不要求 ADC 把这些拍当成有效像素。
//
// 本文件里的二维坐标按“扫描顺序”理解：
//   - x_idx 是一条扫描线内部的点序号，范围 0 .. dacx_tk_point-1。
//   - line_idx 是第几条扫描线，范围 0 .. image_row-1。
//   - 一条扫描线内 DAY 不变，DAX 从 dacx_strat_level 开始逐点加 dacx_step。
//   - 一条扫描线结束后，DAX 回到 dacx_strat_level，DAY 再按 dacy_step 换到下一条线。
//
// 所以逻辑零点不是 Verilog 里的 0，而是第一条线第一个有效像素：
//   x_idx=0, line_idx=0  ->  (DAX, DAY) = (dacx_strat_level, dacy_strat_level)。
// 顶层 ETH_TOP 还会做 65535-DAX/DAY 反相；这里的坐标说明指的是本模块输出到 FIFO 前的逻辑 DAC 码值。
//////////////////////////////////////////////////////////////////////////////////
module parameter_dacdata_gen(
    // 时钟/复位：实际由 dacdata_config 接 eth_clk(125MHz)，低有效复位来自 scan_state 上升沿后的脉冲。
    input           ui_clk,
    input           rstn,

    // 扫描几何和像素节奏。
    input [15:0]    row_repeat,       // 每条扫描线重复扫描多少次；重复期间 DAY 不变，只把 DAX 再从头扫一遍。
    input [31:0]    dac_sample,       // 每个像素点保持多少拍；State 3 中 adc_tri 在这些拍为 1。
    input [15:0]    image_row,        // 一帧包含多少条扫描线(line_idx 数量)。
    input [15:0]    dacx_strat_level, // X 起始 DAC 码值，拼写 strat 保留原工程命名。
    input [63:0]    dacx_step,        // 同一条扫描线内，相邻 x_idx 之间的 64-bit 定点步进。
    input [15:0]    dacx_tk_point,    // 一条扫描线内有多少个 X 方向像素点。
    input [15:0]    dacx_recovery_time, // 线首恢复时间，后面乘 50 转成 FIFO word 数。
    input [15:0]    dacy_strat_level, // Y 起始 DAC 码值。
    input [63:0]    dacy_step,        // 换到下一条扫描线时，DAY 增加的 64-bit 定点步进。
    input [31:0]    frame_waiting_time, // 帧结束后等待多少 FIFO word 再回到下一帧。
    input [31:0]    dax_fall_time,    // 线尾 X 下降斜坡持续多少 FIFO word；上游已按 us*50 预处理。
    input [15:0]    dacx_pp_level,    // X 轴峰峰值(end-start)，用来计算下降斜坡每拍减多少。
    input [15:0]    sync1_pixel_tri_wigth, // sync1 在一个像素采样窗口前部保持为 1 的拍数。
    input [15:0]    sync2_pixel_tri_wigth,// sync2 在一个像素采样窗口前部保持为 1 的拍数。

    // 交错/触发/超快模式控制。
    input [15:0]    row_m,
    input [15:0]    row_n,
    input           clk_sel,          // 1=每条扫描线开始前等 TRIGGER_IN；0=自由连续扫描。
    input           TRIGGER_IN,       // 来自 dacdata_config 的同步后上升沿脉冲。
    input           ultrafast_mode,   // 1=线首恢复时间改用 ultrafast_line_rec，sync 输出由后级放行。
    input   [31:0]  ultrafast_line_rec,

    // 历史保留端口：本模块当前不驱动这两个信号，超快行号实际由 adcdata_acq 生成并回传。
    output reg [15:0]line_count,
    output reg       line_count_en,

    // DL5 激光同步模式新增端口
    input           laser_mode_en,              // 1=激光模式，0=普通模式
    input           laser_sync_rise_eth,        // eth_clk 域，已 CDC + 边沿检测的 laser 脉冲
    input   [15:0]  scan_delay_time,            // 8ns 步进 (eth_clk 周期)
    output reg      laser_toggle,               // 给 dac_output 做触发独立 CDC 的 toggle 信号
    output [4:0]    dl5_dbg_current_state,
    output [15:0]   dl5_dbg_scan_delay_cnt,
    output [31:0]   dl5_dbg_dac_sample_cnt,
    output [15:0]   dl5_dbg_dacx_tk_point_cnt,

    // 写给 dac_output 内部异步 FIFO 的 35-bit 参数流。
    output reg      para_config_wr_en,
    output [34:0]   para_config_data,
    input           para_config_prog_full,
    input           para_config_wr_rst_busy
    );

//------------------------------------------------------------------------------
// 1. 时间单位换算：把“用户眼里的时间”换成“FIFO word 数”
//
// 下游 dac_output 在 dac_dco(50MHz) 域一拍读出一个 FIFO word，所以这里
// 只要写入 N 个 word，下游最终就会输出 N 个 dac_dco 拍。用户配置的线首
// 恢复时间按微秒理解，1us = 50 个 dac_dco 拍，因此乘以 50。
//
// 乘 50 用移位加法实现：50 = 32 + 16 + 2，即 <<5 + <<4 + <<1。
//------------------------------------------------------------------------------
wire[31:0] dacx_tb_point_reg;
assign      dacx_tb_point_reg = (dacx_recovery_time<<5)+(dacx_recovery_time<<4)+(dacx_recovery_time<<1);
wire[35:0]ultrafast_line_rec_reg;
assign      ultrafast_line_rec_reg = (ultrafast_line_rec<<5)+(ultrafast_line_rec<<4)+(ultrafast_line_rec<<1);

reg [4:0]   current_state;   // DL5 扩到 5 位以容纳 State 14/15/16

reg [35:0]  dacx_tb_point_cnt;
reg [31:0]  dac_sample_cnt;
reg [15:0]  dacx_tk_point_cnt;
reg [15:0]  row_repeat_cnt;
reg [15:0]  image_row_cnt;
reg [31:0]  frame_waiting_cnt;
//------------------------------------------------------------------------------
// 2. 输出数据模型：64-bit 定点坐标 -> 35-bit FIFO word
//
// dax_level/day_level 是内部坐标，真正进 FIFO 的只有高 16 位。
// 低 48 位让很小的步进也能逐拍累计，避免“每步小于 1 个 DAC LSB 时
// 一直不动”的台阶误差。
//
// FIFO word 的位分配固定如下：
//   [34]    sync_pixel_tri2
//   [33]    sync_pixel_tri1
//   [32]    adc_tri
//   [31:16] DAX_DATA
//   [15:0]  DAY_DATA
//------------------------------------------------------------------------------
reg [63:0]  dax_level;
reg [63:0]  day_level;
reg         sync_pixel_tri2;     // fifo[34]
reg         sync_pixel_tri1;     // fifo[33]
reg         adc_tri;             // fifo[32]
reg [15:0]  DAX_DATA;            // fifo[31:16]
reg [15:0]  DAY_DATA;            // fifo[15:0]
// 激光模式下 FIFO[32]/[33]/[34] 全部清零，trigger 走独立 toggle-FF 桥
wire        fifo_bit32 = laser_mode_en ? 1'b0 : adc_tri;
wire        fifo_bit33 = laser_mode_en ? 1'b0 : sync_pixel_tri1;
wire        fifo_bit34 = laser_mode_en ? 1'b0 : sync_pixel_tri2;
wire        line_start_allowed = laser_mode_en || (clk_sel == 1'b0) || TRIGGER_IN;
assign      para_config_data = {fifo_bit34, fifo_bit33, fifo_bit32, DAX_DATA, DAY_DATA};

//------------------------------------------------------------------------------
// 3. 三个硬件除法器：提前算出交错扫描和下降斜坡的参数
//
// row_step_div:
//   这里的 row_* 是原工程命名，按本模块扫描模型应理解为“扫描线序号”。
//   image_row / (row_m + row_n)，商 step 表示一个交错大步能重复多少次，
//   余数 remain 留给 State 10 做尾部扫描线处理。
//
// row_cycle_div:
//   row_m / row_n，商再 +1 得到 cycle，表示交错扫描需要回到多少个
//   line_idx 起始偏移，才能把跳过的扫描线补扫回来。
//
// dax_step_div:
//   {dacx_pp_level,48'd0} / (dax_fall_time + 1)，得到线尾下降斜坡每拍
//   应从 dax_level 里减掉的 64-bit 定点步进。
//------------------------------------------------------------------------------
wire        div1_valid;
wire[31:0]  div1_data;
wire        div2_valid;
wire[31:0]  div2_data;
wire[15:0]  step;
wire[15:0]  cycle;
wire[15:0]  remain;
assign      step    = div1_data[31:16];
assign      remain  = div1_data[15:0];
assign      cycle   = div2_data[31:16] + 1'b1;
//assign      step   = image_row/(row_m + row_n);
//assign      cycle = (row_m/row_n) + 1'b1;
//assign      remain = image_row%(row_m + row_n);

wire        div3_valid;
wire[95:0]  div3_data;
wire[63:0]  dax_fall_step;  // 64-bit fixed-point fall step, same scale as dax_level.
assign      dax_fall_step = div3_data[95:32];
div_gen_2 row_step_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  (1'b1),
    .s_axis_divisor_tdata   (row_m + row_n),
    .s_axis_dividend_tvalid (1'b1),
    .s_axis_dividend_tdata  (image_row),
    .m_axis_dout_tvalid     (div1_valid),
    .m_axis_dout_tdata      (div1_data)
    );
div_gen_2 row_cycle_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  (1'b1),
    .s_axis_divisor_tdata   (row_n),
    .s_axis_dividend_tvalid (1'b1),
    .s_axis_dividend_tdata  (row_m),
    .m_axis_dout_tvalid     (div2_valid),
    .m_axis_dout_tdata      (div2_data)
    );

div_gen_3 dax_step_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  ( 1'b1),
    .s_axis_divisor_tdata   ( dax_fall_time + 1),
    .s_axis_dividend_tvalid ( 1'b1),
    .s_axis_dividend_tdata  ({dacx_pp_level,48'd0}),
    .m_axis_dout_tvalid     ( div3_valid),
    .m_axis_dout_tdata      ( div3_data)
    );


reg [15:0]  row_n_cnt;
reg [15:0]  step_cnt;
reg [15:0]  cycle_cnt;
reg [15:0]  remain_cnt;
reg [15:0]  step_count;

reg [31:0]  dax_fall_cnt;
reg         s13_wait_cnt;  // C3-lite: State 13 等待计数器（0~1）
reg [35:0]  dacx_tb_point;

// DL5 激光模式新增计数器
reg [15:0]  scan_delay_cnt;

// DL5_UNIT_003：State 2 在激光模式下只写 2 个 dacx_strat word，
// 之后纯计时不写，让读侧消化 State 13 留下的 FIFO 积压。
// 写满 2 次后停止写，dacx_tb_point_cnt 仍跑满（行间隔不变）。
reg [1:0]   s2_write_cnt;

assign dl5_dbg_current_state     = current_state;
assign dl5_dbg_scan_delay_cnt    = scan_delay_cnt;
assign dl5_dbg_dac_sample_cnt    = dac_sample_cnt;
assign dl5_dbg_dacx_tk_point_cnt = dacx_tk_point_cnt;

//------------------------------------------------------------------------------
// 4. 主状态机：把一帧扫描拆成“线首等待 -> 像素采样 -> 线尾回扫 -> 换线/换帧”
//
// 正常读法：
//   State 0  : 装入 DAX/DAY 起始电平，并选择普通/超快模式的 Tb 长度。
//   State 1  : 等待一条扫描线开始；外触发模式下要等 TRIGGER_IN 脉冲。
//   State 2  : Tb，线首恢复/稳定时间，写 FIFO 但 adc_tri=0。
//   State 3  : 一个像素点的采样窗口，DAX/DAY 保持不变，adc_tri=1。
//   State 4  : x_idx 前进一步，决定本扫描线下一个像素还是进入线尾。
//   State 12/13 : 线尾 X 下降斜坡，写 FIFO 但 adc_tri=0。
//   State 5  : 扫描线重复计数；同一条扫描线可重复扫多次。
//   State 6~10 : DAY/line_idx 更新和交错扫描顺序控制。
//   State 11 : 帧间等待，输出回到起始电平但不触发 ADC。
//
// 流控合同：
//   只有 para_config_prog_full=0 且 wr_rst_busy=0 时才写 FIFO 并推进状态。
//   FIFO 快满时状态机会原地停住，保证不会丢掉任何一个未来 DAC 输出拍。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        current_state       <= 0;

        dacx_tb_point_cnt   <= 36'd0;
        dac_sample_cnt      <= 0;
        dacx_tk_point_cnt   <= 16'd0;
        row_repeat_cnt      <= 16'd0;
        image_row_cnt       <= 16'd0;
        frame_waiting_cnt   <= 32'd0;

        para_config_wr_en   <= 1'b0;
        sync_pixel_tri1      <= 1'b0;
        sync_pixel_tri2      <= 1'b0;
        adc_tri             <= 1'b0;
        dax_level           <= 64'h8000_0000_0000_0000;
        day_level           <= 64'h8000_0000_0000_0000;
        DAX_DATA            <= 16'h8000;
        DAY_DATA            <= 16'h8000;

        row_n_cnt           <= 0;
        step_cnt            <= 0;
        cycle_cnt           <= 0;
        remain_cnt          <= 0;
        step_count          <= 0;

        dax_fall_cnt        <= 0;
        s13_wait_cnt        <= 0;  // C3-lite

        // DL5 激光模式信号复位
        scan_delay_cnt      <= 16'd0;
        laser_toggle        <= 1'b0;
        s2_write_cnt        <= 2'd0;
    end
    else
        case (current_state)
        // State 0: 装载一帧/一条扫描线开始时的基准电平。
        //
        // 逻辑坐标回到本帧零点：x_idx=0、line_idx=0。
        // 对应 DAC 码值就是 DAX=dacx_strat_level、DAY=dacy_strat_level。
        // Tb 长度根据模式选择：
        //   普通模式用 dacx_recovery_time*50；
        //   超快模式用 ultrafast_line_rec*50。
        // 这里不写 FIFO，只准备下一步的扫描合同。
        0:
        begin
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            sync_pixel_tri1          <= 1'b0;
            sync_pixel_tri2          <= 1'b0;
            dax_level               <= {dacx_strat_level,48'd0};
            day_level               <= {dacy_strat_level,48'd0};
            current_state           <= 1;
            if(ultrafast_mode == 1'b1)
                dacx_tb_point   <= ultrafast_line_rec_reg;
            else
                dacx_tb_point   <= dacx_tb_point_reg;
        end

        // State 1: 等待一条扫描线真正开始。
        //
        // clk_sel=1 时，每条扫描线都要等外部 TRIGGER_IN 脉冲，适合和外部设备同步；
        // 激光模式下 D15/TRIGGER_IN 已复用为 laser_sync_in，因此这里直接放行行首，
        // 真正的逐像素推进交给 State 14 等 laser 上升沿。
        1:
        begin
            para_config_wr_en       <= 1'b0;
            sync_pixel_tri1          <= 1'b0;
            sync_pixel_tri2          <= 1'b0;
            adc_tri                 <= 1'b0;
            if(line_start_allowed) begin
                if(dacx_tb_point == 0)                              // Tb=0: skip recovery, enter Tk directly.
                    current_state       <= 3;
                else                                                // Tb>0: output recovery samples first.
                    current_state       <= 2;
            end
            else
                current_state       <= 1;
        end

        // State 2: Tb 线首恢复段。
        //
        // 普通模式（laser_mode_en=0）：每拍写 1 个 word，写满 dacx_tb_point 个，
        //   让 DAC 在 dacx_strat 上停留 dacx_tb_point × 20ns ≈ recovery µs。
        //
        // DL5_UNIT_003 激光模式（laser_mode_en=1）：只在前 2 拍写 dacx_strat word，
        //   之后状态机继续计时但不写。读侧在 State 2 + State 14 期间消化 State 13
        //   留下的 FIFO 积压，让下一个 laser 来时 FIFO 已在地板（2 word）。
        //   行间隔不变（dacx_tb_point_cnt 仍跑满），DAC 输出 dacx_strat 由 FIFO 中
        //   2 个锚点 word + State 14 期间 FIFO 空时 DAC 自动保持来维持。
        2:                                                      //Tb
        begin
            if (laser_mode_en) begin
                // 激光模式：只写 2 次
                if (s2_write_cnt < 2'd2 && para_config_prog_full == 0
                    && para_config_wr_rst_busy == 0) begin
                    para_config_wr_en   <= 1'b1;
                    adc_tri             <= 1'b0;
                    sync_pixel_tri1      <= 1'b0;
                    sync_pixel_tri2      <= 1'b0;
                    DAX_DATA            <= dax_level[63:48];
                    DAY_DATA            <= day_level[63:48];
                    s2_write_cnt        <= s2_write_cnt + 1'b1;
                end
                else begin
                    para_config_wr_en   <= 1'b0;
                end
                // 计时器仍跑满 dacx_tb_point 拍（行间隔不变）
                if (dacx_tb_point_cnt < dacx_tb_point - 1) begin
                    dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
                    current_state       <= 2;
                end
                else begin
                    dacx_tb_point_cnt   <= 0;
                    s2_write_cnt        <= 2'd0;
                    current_state       <= 14;
                end
            end
            else begin
                // 普通模式：原行为不变
                if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                    para_config_wr_en       <= 1'b1;
                    adc_tri                 <= 1'b0;
                    sync_pixel_tri1          <= 1'b0;
                    sync_pixel_tri2          <= 1'b0;
                    DAX_DATA                <= dax_level[63:48];
                    DAY_DATA                <= day_level[63:48];
                    if(dacx_tb_point_cnt < dacx_tb_point - 1) begin
                        dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
                        current_state       <= 2;
                    end
                    else begin
                        dacx_tb_point_cnt   <= 0;
                        current_state       <= 3;
                    end
                end
                else
                    para_config_wr_en       <= 1'b0;
            end
        end

        // State 3: 一个像素点的有效采样窗口。
        //
        // 对同一个 (x_idx,line_idx) 像素，连续写 dac_sample 个 FIFO word：
        //   DAX/DAY 保持不变；
        //   adc_tri=1，告诉 DL2 在稳定电平期间做平均采样；
        //   sync1/sync2 只在窗口前 sync*_pixel_tri_wigth 拍为 1。
        // 写满 dac_sample 拍后再到 State 4 更新 x_idx 对应的 DAX 坐标。
        3:                                                      //one Tk point
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b1;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(dac_sample_cnt < dac_sample - 1) begin
                    dac_sample_cnt      <= dac_sample_cnt+1'b1;
                    current_state       <= 3;
                end
                else begin
                    dac_sample_cnt      <= 0;
                    current_state       <= 4;
                end
                if(dac_sample_cnt < sync1_pixel_tri_wigth - 1)
                    sync_pixel_tri1          <= 1'b1;
                else
                    sync_pixel_tri1          <= 1'b0;
                if(dac_sample_cnt < sync2_pixel_tri_wigth - 1)
                    sync_pixel_tri2          <= 1'b1;
                else
                    sync_pixel_tri2          <= 1'b0;
            end
            else
                para_config_wr_en       <= 1'b0;
        end

        // State 4: 同一条扫描线内部的 X 坐标步进。
        //
        // 本状态不写 FIFO，只更新内部定点坐标。只要本扫描线还有像素，就让
        // dax_level += dacx_step 并回到 State 3；整条线扫完后进入线尾下降段。
        4:
        begin
            para_config_wr_en       <= 1'b0;
            if(dacx_tk_point_cnt < dacx_tk_point - 1) begin         // One Tk is done, advance to the next X pixel.
                dacx_tk_point_cnt   <= dacx_tk_point_cnt + 1'b1;
                dax_level           <= dax_level + dacx_step;
                day_level           <= day_level;
                // DL5 激光模式：下一个像素回 State 14 等 laser；普通模式回 State 3
                if (laser_mode_en) current_state <= 14;
                else               current_state <= 3;
            end
            else begin                                              // All X pixels in this row are done.
                dacx_tk_point_cnt   <= 16'd0;
                current_state       <= 12;
            end
        end
        // State 12/13: 线尾 X 下降斜坡。
        //
        // State 12 先判断是否需要下降斜坡，并提前从 dax_level 减去一步；
        // State 13 把下降过程中的每个 DAX/DAY 写入 FIFO。adc_tri 始终为 0，
        // 因为这段是回扫/消隐，不是有效像素。每写一拍就回 State 12 再减一步，
        // 直到 dax_fall_time 计满。
        12:
        begin
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            sync_pixel_tri1          <= 1'b0;
            sync_pixel_tri2          <= 1'b0;
            if(dax_fall_time == 0)
                current_state       <= 5;
            else begin
                current_state       <= 13;
                dax_level           <= dax_level - dax_fall_step;
                day_level           <= day_level;
            end
        end
        13:
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                adc_tri                 <= 1'b0;
                sync_pixel_tri1         <= 1'b0;
                sync_pixel_tri2         <= 1'b0;

                // C3-lite: 激光模式限速到 3 拍/word（写速率 ~41.67MHz < 50MHz 读侧）
                // 第 1 拍写 1 个 word，第 2 拍等待不写（避免重复写 FIFO）
                if (laser_mode_en) begin
                    if (s13_wait_cnt < 1'd1) begin
                        // 第 1 拍：写 word
                        para_config_wr_en   <= 1'b1;
                        DAX_DATA            <= dax_level[63:48];
                        DAY_DATA            <= day_level[63:48];
                        s13_wait_cnt        <= s13_wait_cnt + 1'b1;
                        current_state       <= 13;
                    end else begin
                        // 第 2 拍：等待，不写
                        para_config_wr_en   <= 1'b0;
                        s13_wait_cnt        <= 0;
                        if(dax_fall_cnt < dax_fall_time - 1) begin
                            current_state   <= 12;
                            dax_fall_cnt    <= dax_fall_cnt + 1'b1;
                        end else begin
                            current_state   <= 5;
                            dax_fall_cnt    <= 0;
                        end
                    end
                end else begin
                    // 普通模式：保持 2 拍/word（原行为不变）
                    para_config_wr_en       <= 1'b1;
                    DAX_DATA                <= dax_level[63:48];
                    DAY_DATA                <= day_level[63:48];
                    if(dax_fall_cnt < dax_fall_time - 1) begin
                        current_state   <= 12;
                        dax_fall_cnt    <= dax_fall_cnt + 1'b1;
                    end else begin
                        current_state   <= 5;
                        dax_fall_cnt    <= 0;
                    end
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end
        // State 5: 同一条扫描线的重复扫描判断。
        //
        // row_repeat>1 时，DAX 回到 dacx_strat_level，DAY 保持不变，
        // 再从 State 1 重扫同一个 line_idx；重复次数用完以后，
        // 才进入后面的 DAY/line_idx 更新和交错扫描逻辑。
        5:
        begin
            para_config_wr_en       <= 1'b0;
            if(row_repeat_cnt < row_repeat - 1) begin
                row_repeat_cnt      <= row_repeat_cnt + 1'b1;
                current_state       <= 1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level;
            end
            else begin
                row_repeat_cnt      <= 0;
                if(remain_cnt == 0)
                    current_state   <= 6;
                else
                    current_state   <= 10;
            end
        end
        // State 6~9: 交错扫描的 line_idx 顺序控制。
        //
        // 这几个状态只移动 DAY，不写 FIFO。可以把它理解成“决定下一条扫描线先扫谁”：
        //   State 6 在当前 row_n 小组内部按 dacy_step 前进到下一条扫描线；
        //   State 7 跨过 row_m 行，跳到下一条交错带；
        //   State 8/9 在一轮交错带结束后，回到新的起始偏移，把之前跳过的扫描线补上。
        6:
        begin
            para_config_wr_en       <= 1'b0;
            if(row_n_cnt < row_n - 1) begin
                row_n_cnt           <= row_n_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level + dacy_step;
                current_state       <= 1;
            end
            else begin
                row_n_cnt           <= 0;
                current_state       <= 7;
            end
        end
        7:
        begin
            para_config_wr_en       <= 1'b0;
            if(step_cnt < step - 1) begin
                step_cnt            <= step_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                //day_level           <= day_level + row_m *dacy_step + dacy_step;
                // 意图上等价于 day_level += (row_m + 1) * dacy_step：
                // 跳过 row_m 条扫描线，再落到下一条需要扫描的交错带。
                day_level           <= day_level + ((row_m*dacy_step[63:32]<<32) + row_m*dacy_step[31:0]) + dacy_step;
                current_state       <= 1;
            end
            else begin
                step_cnt            <= 0;
                current_state       <= 8;
            end
        end
        8:
        begin
            para_config_wr_en       <= 1'b0;
            if(cycle_cnt < cycle - 1) begin
                cycle_cnt           <= cycle_cnt + 1'b1;
                step_count          <= (cycle_cnt + 1)*row_n;
                current_state       <= 9;
            end
            else begin
                cycle_cnt           <= 0;
                current_state       <= 10;
            end
        end
        9:
        begin
            para_config_wr_en       <= 1'b0;
            dax_level               <= {dacx_strat_level,48'd0};
         //   day_level               <= {dacy_strat_level,48'd0} + step_count*dacy_step;
            // 从 DAY 起点重新定位到新的交错起始偏移，然后回 State 1 扫这条线。
            day_level               <= {dacy_strat_level,48'd0} + ((step_count*dacy_step[63:32]<<32) + step_count*dacy_step[31:0]);
            current_state           <= 1;
        end

        // State 10: 处理 image_row/(row_m+row_n) 除不尽的尾部扫描线。
        //
        // remain 表示交错扫描主循环之外还剩几条扫描线。尾部线扫完后，DAX/DAY 都回帧起点；
        // 如果 frame_waiting_time=0，就直接开始下一帧，否则进入 State 11 输出帧间等待段。
        10:
        begin
            para_config_wr_en       <= 1'b0;
            if(remain_cnt < remain) begin
                remain_cnt          <= remain_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level + dacy_step;
                current_state       <= 1;
            end
            else begin
                remain_cnt          <= 0;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= {dacy_strat_level,48'd0};
                if(frame_waiting_time == 0)                         // no frame waiting,return to Tb
                    current_state   <= 1;
                else                                                //frame waiting,run to next
                    current_state   <= 11;
            end
        end
        // State 11: 帧间等待。
        //
        // 输出帧起点 DAX/DAY，adc_tri=0，让下游 DAC 保持在逻辑零点电平等待下一帧。
        // 这段仍然写 FIFO，因此等待时间也会被 dac_output 按 dac_dco 节拍真实输出。
        11:
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b0;
                sync_pixel_tri1          <= 1'b0;
                sync_pixel_tri2          <= 1'b0;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(frame_waiting_cnt < frame_waiting_time - 1) begin
                    frame_waiting_cnt   <= frame_waiting_cnt + 1'b1;
                    current_state       <= 11;
                end
                else begin
                    frame_waiting_cnt   <= 0;
                    current_state       <= 1;
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end

        // State 14: 激光模式专用——等 laser 上升沿。
        //
        // 进入条件：
        //   - 帧首/行首 Tb（State 2）写完后，激光模式跳到 14
        //   - 行内每个像素（State 4）写完后，激光模式回到 14
        //
        // 行为：
        //   - 不写 FIFO，让读侧消化前一像素的积压 word
        //   - 检测到 laser_sync_rise_eth 时翻转 laser_toggle，
        //     送给 dac_output 在 ui_clk 域生成 laser_pulse_ui，
        //     用作 acq/blanker 状态机的边沿源
        //   - 状态机内门控 toggle 翻转：行切换/Tb 期间到达的 laser 不会让 toggle 翻转
        14:
        begin
            para_config_wr_en       <= 1'b0;
            if (laser_sync_rise_eth) begin
                laser_toggle        <= ~laser_toggle;     // State 14 内门控
                scan_delay_cnt      <= 16'd0;
                current_state       <= 15;
            end
        end

        // State 15: 激光模式专用——scan_delay 倒计时。
        //
        // 行为：
        //   - 不写 FIFO
        //   - 倒计时 scan_delay_time 个 eth_clk 拍（8ns 步进）
        //   - scan_delay_time=0 时立即跳到 State 16
        15:
        begin
            para_config_wr_en       <= 1'b0;
            if (scan_delay_time == 16'd0) begin
                current_state       <= 16;
            end
            else if (scan_delay_cnt < scan_delay_time - 1) begin
                scan_delay_cnt      <= scan_delay_cnt + 1'b1;
            end
            else begin
                scan_delay_cnt      <= 16'd0;
                current_state       <= 16;
            end
        end

        // State 16: 激光模式专用——写 dac_sample 个像素 word 到 FIFO。
        //
        // 行为：
        //   - 写 dac_sample 个 word，DAX/DAY = 当前像素坐标
        //   - 激光模式下 FIFO[32]/[33]/[34] 在拼接 mux 处强制为 0
        //   - 写完后进 State 4，由 State 4 决定是行内下一像素（回 14）还是进 12 做行尾斜坡
        //   - 复用 dac_sample_cnt（State 3/16 激光模式互斥，不冲突）
        16:
        begin
            if (para_config_prog_full == 0 && para_config_wr_rst_busy == 0) begin
                para_config_wr_en   <= 1'b1;
                adc_tri             <= 1'b0;
                sync_pixel_tri1     <= 1'b0;
                sync_pixel_tri2     <= 1'b0;
                DAX_DATA            <= dax_level[63:48];
                DAY_DATA            <= day_level[63:48];
                if (dac_sample_cnt < dac_sample - 1) begin
                    dac_sample_cnt  <= dac_sample_cnt + 1'b1;
                    current_state   <= 16;
                end
                else begin
                    dac_sample_cnt  <= 0;
                    current_state   <= 4;
                end
            end
            else
                para_config_wr_en   <= 1'b0;
        end

        // 兜底分支：如果状态寄存器异常，回到和复位近似的安全中点电平。
        default:
        begin
            current_state       <= 0;

            dacx_tb_point_cnt   <= 32'd0;
            dac_sample_cnt      <= 32'd0;
            dacx_tk_point_cnt   <= 16'd0;
            row_repeat_cnt      <= 16'd0;
            image_row_cnt       <= 16'd0;
            frame_waiting_cnt   <= 32'd0;

            para_config_wr_en   <= 1'b0;
            adc_tri             <= 1'b0;
            sync_pixel_tri1          <= 1'b0;
            sync_pixel_tri2          <= 1'b0;
            dax_level           <= 64'h8000_0000_0000_0000;
            day_level           <= 64'h8000_0000_0000_0000;
            DAX_DATA            <= 16'h8000;
            DAY_DATA            <= 16'h8000;

            row_n_cnt           <= 0;
            step_cnt            <= 0;
            cycle_cnt           <= 0;
            remain_cnt          <= 0;
            step_count          <= 0;

            dax_fall_cnt        <= 0;
            s13_wait_cnt        <= 0;  // C3-lite

            // DL5 激光模式信号在 default 分支同样复位
            scan_delay_cnt      <= 16'd0;
            laser_toggle        <= 1'b0;
            s2_write_cnt        <= 2'd0;
        end
        endcase
end

// ila_1 dac_ila(
//   .clk        (ui_clk),
//   .probe0     (dax_fall_cnt),
//   .probe1     (dax_fall_time)
//   );


endmodule

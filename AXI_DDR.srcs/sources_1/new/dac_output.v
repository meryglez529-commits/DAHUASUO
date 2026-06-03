`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : dac_output
// Create Date : 2020/06/01
//
// 一句话先抓住本模块：
//   dac_output 是 DL1(DAC 扫描输出链路)的“跨时钟输出端”。
//   它不计算扫描波形，只负责把 parameter_dacdata_gen 已经算好的
//   35-bit 扫描 word 从 eth_clk 域搬到 dac_dco 域，然后拆成：
//     DAX_DATA、DAY_DATA、adc_tri、sync_pixel_tri1、sync_pixel_tri2。
//
// 上下游关系：
//   parameter_dacdata_gen(eth_clk) 写入：
//     {sync2, sync1, adc_tri, DAX[15:0], DAY[15:0]}
//   dac_output(dac_dco) 逐拍读出并输出：
//     - DAX/DAY 给顶层，顶层再做 65535-DAX/DAY 反相后送 AD9747；
//     - adc_tri 给 ADC 链路，表示当前 DAC 点是有效采样窗口；
//     - sync1/sync2 给外部同步接口，只在 ultrafast_mode 下输出。
//
// 本文件里有三个时钟域：
//   eth_clk      : FIFO 写侧，由 parameter_dacdata_gen 驱动。
//   dac_dco_bufg : FIFO 读侧，也是 DAX/DAY/adc_tri 的输出节拍。
//   ui_clk       : sync1/sync2 的延时和脉宽整形，提供更细的 5ns 级控制。
//////////////////////////////////////////////////////////////////////////////////
  module dac_output(
    // 时钟/控制。
    input               eth_clk,                 // FIFO 写侧时钟，来自上游参数波形生成器。
    input               ui_clk,                  // sync 延时整形时钟，通常比 dac_dco 更快。
    input               rstn,                    // 低有效复位，来自 dacdata_config 的扫描启动复位链。
    input               scan_state,              // 1=允许 adc_tri 输出；0=停扫时 ADC 触发强制拉低。
    input               dac_dco,                 // AD9747 DCO，经过 BUFG 后作为 FIFO 读侧和 DAC 输出节拍。
    input       [3:0]   scan_mode,               // 4'h1=参数扫描模式，本模块才持续读 35-bit FIFO。
    input               ultrafast_mode,          // 1=允许 sync1/sync2 输出；0=sync 输出屏蔽。
    input       [15:0]  sync1_pixel_tri_wigth,   // sync1 原始像素脉宽，后面 <<2 转到 ui_clk 拍数。
    input       [15:0]  sync2_pixel_tri_wigth,   // sync2 原始像素脉宽，后面 <<2 转到 ui_clk 拍数。
    input       [15:0]  sync_sig_delay1,         // sync1 在 ui_clk 域的额外延时。
    input       [15:0]  sync_sig_delay2,         // sync2 在 ui_clk 域的额外延时。

    // 拆包后的业务输出。
    output reg [15:0]   DAX_DATA,                // 本模块输出的逻辑 DAC X 码值；顶层会再做 65535-DAX_DATA。
    output reg [15:0]   DAY_DATA,                // 本模块输出的逻辑 DAC Y 码值；顶层会再做 65535-DAY_DATA。
    output reg          adc_tri,                 // ADC 有效采样窗口，高电平期间 ADC 链路采集/平均当前 DAC 点。
    output reg          sync_pixel_tri1,         // 外部同步/blank 信号 1，最终低有效：这里会输出 ~sync_pixel_tri1_reg。
    output              sync_pixel_tri2,         // 外部同步/触发信号 2，高有效，顶层接到 TRIGGER_OUT。

    // 上游写入的 35-bit 扫描 word，以及返回给上游的 FIFO 写侧流控。
    input               para_config_wr_en,
    input       [34:0]  para_config_data,
    output              para_config_prog_full,
    output              para_config_wr_rst_busy,

    // DL5 激光同步模式新增端口
    input               laser_mode_en,           // eth_clk 域，进来同步到 dac_dco 和 ui_clk
    input               laser_toggle,            // eth_clk 域 toggle，由 parameter_dacdata_gen 输出
    input       [15:0]  blanker_delay_time,      // ui_clk 拍数（5ns 步进）
    input       [15:0]  blanker_time,            // ui_clk 拍数（5ns 步进）
    input       [15:0]  acq_data_delay_time,     // 上位机配 dac_dco 拍数（20ns 步进），内部 <<2 转 ui_clk 拍
    input       [15:0]  acq_time                 // 同上
    );

//------------------------------------------------------------------------------
// 1. 时钟进入和控制信号同步
//
// dac_dco 是 DAC 输出的真实节拍，先经 BUFG 进全局时钟网络。
// rstn 需要分别同步到 dac_dco 和 ui_clk 两个域。
// scan_mode/ultrafast_mode 是 eth_clk 域来的慢速控制量，这里在 dac_dco 域
// 打两拍后使用，避免读 FIFO 的状态机看到毛刺或亚稳态。
//------------------------------------------------------------------------------
wire        dac_dco_bufg;
BUFG bufg_dco(.O(dac_dco_bufg),.I(dac_dco));
wire        dac_rstn;
wire        ui_rstn;
sync_module sync1(.data_in(rstn),.clk_in(dac_dco_bufg),.data_out(dac_rstn));
sync_module sync2(.data_in(rstn),.clk_in(ui_clk),.data_out(ui_rstn));
reg [3:0]   scan_mode_r0;
reg [3:0]   scan_mode_r1;
always@(posedge dac_dco_bufg or negedge dac_rstn)
begin
    if(~dac_rstn) begin
        scan_mode_r0 <= 0;
        scan_mode_r1 <= 0;
    end
    else begin
        scan_mode_r0 <= scan_mode;
        scan_mode_r1 <= scan_mode_r0;
    end
end
reg ultrafast_mode_r0;
reg ultrafast_mode_r1;
always@(posedge dac_dco_bufg or negedge dac_rstn)
begin
    if(~dac_rstn) begin
        ultrafast_mode_r0 <= 0;
        ultrafast_mode_r1 <= 0;
    end
    else begin
        ultrafast_mode_r0 <= ultrafast_mode;
        ultrafast_mode_r1 <= ultrafast_mode_r0;
    end
end

//------------------------------------------------------------------------------
// 1.1 DL5 激光同步模式控制信号同步链
//
// laser_mode_en 是 eth_clk 域的静态控制位，分别同步到 dac_dco 和 ui_clk 两个域。
// 配置类静态量（blanker_*, acq_*）只用在 ui_clk 域，做双 FF 同步。
// laser_toggle 是 eth_clk 域的事件 toggle，3 级 FF + 异或后在 ui_clk 域生成
// laser_pulse_ui，作为 acq 状态机和 sync1 整形器的共享边沿源。
//------------------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg laser_mode_en_d0, laser_mode_en_dac;
(* ASYNC_REG = "TRUE" *) reg laser_mode_en_u0, laser_mode_en_ui;
always@(posedge dac_dco_bufg or negedge dac_rstn) begin
    if(!dac_rstn) {laser_mode_en_dac, laser_mode_en_d0} <= 2'b0;
    else          {laser_mode_en_dac, laser_mode_en_d0} <= {laser_mode_en_d0, laser_mode_en};
end
always@(posedge ui_clk or negedge ui_rstn) begin
    if(!ui_rstn) {laser_mode_en_ui, laser_mode_en_u0} <= 2'b0;
    else         {laser_mode_en_ui, laser_mode_en_u0} <= {laser_mode_en_u0, laser_mode_en};
end

// 上位机配置参数同步到 ui_clk 域（ui_clk 域 acq/blanker 状态机使用）
(* ASYNC_REG = "TRUE" *) reg [15:0] blanker_delay_d0, blanker_delay_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0] blanker_time_d0,  blanker_time_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0] acq_delay_d0,     acq_delay_ui;
(* ASYNC_REG = "TRUE" *) reg [15:0] acq_time_d0,      acq_time_ui;
always@(posedge ui_clk) begin
    {blanker_delay_ui, blanker_delay_d0} <= {blanker_delay_d0, blanker_delay_time};
    {blanker_time_ui,  blanker_time_d0}  <= {blanker_time_d0,  blanker_time};
    {acq_delay_ui,     acq_delay_d0}     <= {acq_delay_d0,     acq_data_delay_time};
    {acq_time_ui,      acq_time_d0}      <= {acq_time_d0,      acq_time};
end

// laser_toggle 跨域到 ui_clk + 边沿检测（3 级 FF + 异或）
(* ASYNC_REG = "TRUE" *) reg laser_tog_u0, laser_tog_u1, laser_tog_u2;
always@(posedge ui_clk or negedge ui_rstn) begin
    if(!ui_rstn) {laser_tog_u2, laser_tog_u1, laser_tog_u0} <= 3'b0;
    else         {laser_tog_u2, laser_tog_u1, laser_tog_u0} <= {laser_tog_u1, laser_tog_u0, laser_toggle};
end
wire laser_pulse_ui = laser_mode_en_ui && (laser_tog_u2 ^ laser_tog_u1);

// acq_pulse_ui 前向声明：line 257/265 的 adc_tri mux 引用 acq_pulse_ui，
// 实际驱动逻辑在第 5.5 节 acq 状态机里（避免 Vivado "use before declaration" 警告）
reg acq_pulse_ui;

//------------------------------------------------------------------------------
// 2. 35-bit 异步 FIFO：eth_clk -> dac_dco
//
// 这是 DL1 的主要 CDC 边界。
// 写侧：
//   parameter_dacdata_gen 在 eth_clk 域写入 35-bit word。
// 读侧：
//   本模块在 dac_dco_bufg 域按 DAC 输出节拍读出。
//
// prog_full 返回给上游做反压：FIFO 快满时，parameter_dacdata_gen 会暂停
// 状态机推进，保证不会丢掉任何未来的 DAC 输出拍。
//------------------------------------------------------------------------------
reg         para_config_rd_en;
wire [34:0] para_config_dout;
wire        para_config_prog_empty;
wire        para_config_rd_rst_busy;
fifo_generator_4 fifo_para_config(
.wr_clk         (eth_clk),
.rst            (!(rstn&dac_rstn)),
.rd_clk         (dac_dco_bufg),
.din            (para_config_data),
.wr_en          (para_config_wr_en),
.rd_en          (para_config_rd_en),
.dout           (para_config_dout),
.prog_full      (para_config_prog_full),
.prog_empty     (para_config_prog_empty),
.wr_rst_busy    (para_config_wr_rst_busy),
.rd_rst_busy    (para_config_rd_rst_busy)
);

//------------------------------------------------------------------------------
// 3. FIFO 读状态机
//
// 这个状态机很简单：scan_mode=4'h1 时进入参数扫描模式，只要 FIFO 不空、
// 读侧不 busy，就每个 dac_dco 拍读一个 35-bit word。
//
// 真正复杂的波形顺序已经由 parameter_dacdata_gen 写入 FIFO；
// 本状态机只负责“按下游 DAC 节拍持续读”。
//------------------------------------------------------------------------------
reg [1:0]   current_state;
parameter   IDLE = 2'b00;
parameter   para_config = 2'b01;
always@(posedge dac_dco_bufg or negedge dac_rstn)
begin
    if(!dac_rstn) begin
        current_state           <= IDLE;
        para_config_rd_en       <= 1'b0;
    end
    else
        case (current_state)
        IDLE:
        begin
            case(scan_mode_r1)
            4'h1:   begin current_state <= para_config;end         // Parameter scan: consume para_config FIFO.
//          4'h2:   begin current_state <= free1_config; end
//          4'h4:   begin current_state <= free2_config; end
            default:begin current_state <= IDLE; end
            endcase
        end
        para_config:
        begin
            current_state           <= para_config;
            if (para_config_prog_empty == 0  && para_config_rd_rst_busy == 0)
                para_config_rd_en   <= 1'b1;
            else
                para_config_rd_en   <= 1'b0;
        end
        default:
        begin
            current_state           <= IDLE;
            para_config_rd_en       <= 1'b0;
        end
        endcase
end

//------------------------------------------------------------------------------
// 4. 35-bit word 拆包：把“未来一个 DAC 输出拍”变成真实输出信号
//
// FIFO word 格式由 parameter_dacdata_gen 固定：
//   [34]    sync2 原始像素标志
//   [33]    sync1 原始像素标志
//   [32]    adc_tri
//   [31:16] DAX_DATA
//   [15:0]  DAY_DATA
//
// para_config_rd_en_r 是读使能打一拍，用来对齐 FIFO dout 的有效时刻。
// scan_state=0 时，DAX/DAY 保持最后码值不跳变，但 adc_tri 强制为 0；
// 这就是“停止扫描后 DAC 输出保持”的行为。
// sync1/sync2 还额外要求 ultrafast_mode=1 才放行，普通模式下被屏蔽。
//------------------------------------------------------------------------------
reg         para_config_rd_en_r;
reg         scan_state_r0;
reg         scan_state_r1;
reg         sync1_pixel_tri;
reg         sync2_pixel_tri;
always@(posedge dac_dco_bufg or negedge dac_rstn)
begin
    if(!dac_rstn) begin
        para_config_rd_en_r <= 1'b0;
        adc_tri             <= 1'b0;
        sync1_pixel_tri      <= 1'b0;
        sync2_pixel_tri      <= 1'b0;
        DAX_DATA            <= 16'h8000;
        DAY_DATA            <= 16'h8000;
        scan_state_r0       <= 0;
        scan_state_r1       <= 0;
    end
    else begin
        para_config_rd_en_r <= para_config_rd_en;
        scan_state_r0       <= scan_state;
        scan_state_r1       <= scan_state_r0;
        if(para_config_rd_en_r) begin
            sync1_pixel_tri      <= (scan_state_r1 && ultrafast_mode_r1) ? para_config_dout[33] : 1'b0;
            sync2_pixel_tri      <= (scan_state_r1 && ultrafast_mode_r1) ? para_config_dout[34] : 1'b0;
            // 激光模式：adc_tri 来自 ui_clk 域 acq 状态机的 acq_pulse_ui（单 FF 采样）
            // 普通模式：adc_tri 来自 FIFO[32]
            adc_tri             <= laser_mode_en_dac ? (scan_state_r1 ? acq_pulse_ui : 1'b0)
                                                     : (scan_state_r1 ? para_config_dout[32] : 1'b0);
            DAX_DATA            <= para_config_dout[31:16];
            DAY_DATA            <= para_config_dout[15:0];
        end
        else begin
            // 激光模式下即使 rd_en_r=0 也要让 adc_tri 跟随 acq_pulse_ui，
            // 否则 FIFO 排空时 adc_tri 会误清零
            adc_tri             <= laser_mode_en_dac ? (scan_state_r1 ? acq_pulse_ui : 1'b0) : 1'b0;
            sync1_pixel_tri      <= 1'b0;
            sync2_pixel_tri      <= 1'b0;
            DAX_DATA            <= DAX_DATA;
            DAY_DATA            <= DAY_DATA;
        end
    end
end

//------------------------------------------------------------------------------
// 5. sync 原始像素标志跨到 ui_clk，并把宽度从 dac_dco 拍换成 ui_clk 拍
//
// parameter_dacdata_gen 产生的 sync1/sync2 原始标志本来和像素窗口对齐，
// 随 FIFO 先到 dac_dco 域。这里再用两拍寄存器送进 ui_clk 域，用更快的
// ui_clk 做延时和宽度整形。
//
// 当前设计假设 ui_clk 是 dac_dco 的 4 倍，所以原始宽度参数左移 2：
//   sync*_pixel_tri_wigth_r = sync*_pixel_tri_wigth * 4
//------------------------------------------------------------------------------
reg [31:0]  sync1_pixel_tri_wigth_r;
reg sync1_pixel_tri_r0 = 0;
reg sync1_pixel_tri_r1 = 0;
always@(posedge ui_clk)begin
    sync1_pixel_tri_r0 <= sync1_pixel_tri;
    sync1_pixel_tri_r1 <= sync1_pixel_tri_r0;
    sync1_pixel_tri_wigth_r <= (sync1_pixel_tri_wigth<<2);
end

//------------------------------------------------------------------------------
// 5.5 DL5 acq 状态机（ui_clk 域）
//
// 与 sync1 整形器并列，共享 laser_pulse_ui 边沿源。检测到边沿后，等
// acq_data_delay_time × 20ns（内部 <<2 转 ui_clk 拍数）→ 拉高 acq_pulse_ui
// 并保持 acq_time × 20ns，然后回 IDLE。
//
// adc_tri（dac_dco 域）单 FF 采样 acq_pulse_ui：约束 acq_time ≥ 2，使脉宽
// ≥ 40ns，远大于 dac_dco 周期（20ns），单级寄存器即可恢复亚稳态。
//------------------------------------------------------------------------------
reg [31:0] acq_delay_used;
reg [31:0] acq_time_used;
always@(posedge ui_clk) begin
    acq_delay_used <= {14'd0, acq_delay_ui} << 2;   // 20ns 步进 → ui_clk 拍数
    acq_time_used  <= {14'd0, acq_time_ui}  << 2;
end

reg [31:0] acq_delay_cnt;
reg [31:0] acq_time_cnt;
reg [1:0]  acq_state;
// acq_pulse_ui 已在 1.1 节前向声明
parameter ACQ_IDLE  = 2'd0;
parameter ACQ_DELAY = 2'd1;
parameter ACQ_HIGH  = 2'd2;

always@(posedge ui_clk or negedge ui_rstn) begin
    if (!ui_rstn) begin
        // ui_rstn 来自 dacdata_config 在 scan_state 上升沿产生的 6 拍复位脉冲，
        // 上位机切换 laser_mode_en 走"停扫描→改模式→开扫描"流程，自动清状态机
        acq_state     <= ACQ_IDLE;
        acq_delay_cnt <= 0;
        acq_time_cnt  <= 0;
        acq_pulse_ui  <= 0;
    end
    else case (acq_state)
        ACQ_IDLE: begin
            acq_pulse_ui <= 0;
            if (laser_pulse_ui) begin
                acq_delay_cnt <= 0;
                acq_state     <= (acq_delay_used == 0) ? ACQ_HIGH : ACQ_DELAY;
            end
        end
        ACQ_DELAY: begin
            if (acq_delay_cnt < acq_delay_used - 1) begin
                acq_delay_cnt <= acq_delay_cnt + 1'b1;
            end
            else begin
                acq_delay_cnt <= 0;
                acq_time_cnt  <= 0;
                acq_pulse_ui  <= 1'b1;
                acq_state     <= ACQ_HIGH;
            end
        end
        ACQ_HIGH: begin
            acq_pulse_ui <= 1'b1;
            if (acq_time_cnt < acq_time_used - 1) begin
                acq_time_cnt <= acq_time_cnt + 1'b1;
            end
            else begin
                acq_time_cnt <= 0;
                acq_pulse_ui <= 0;
                acq_state    <= ACQ_IDLE;
            end
        end
        default: acq_state <= ACQ_IDLE;
    endcase
end

//------------------------------------------------------------------------------
// 5.6 sync1 整形器入口 mux（DL5 复用现有 sync1 状态机做 blanker）
//
// 普通/超快模式：输入 = sync1_pixel_tri_r1，delay = sync_sig_delay1，width = sync1_pixel_tri_wigth_r
// 激光模式：    输入 = laser_pulse_ui，    delay = blanker_delay_ui， width = blanker_time_ui
//------------------------------------------------------------------------------
wire        sync1_trig_used  = laser_mode_en_ui ? laser_pulse_ui    : sync1_pixel_tri_r1;
wire [15:0] sync1_delay_used = laser_mode_en_ui ? blanker_delay_ui  : sync_sig_delay1;
wire [31:0] sync1_width_used = laser_mode_en_ui ? {16'd0, blanker_time_ui}
                                                : sync1_pixel_tri_wigth_r;

reg [31:0]  sync2_pixel_tri_wigth_r;
reg sync2_pixel_tri_r0 = 0;
reg sync2_pixel_tri_r1 = 0;
always@(posedge ui_clk)begin
    sync2_pixel_tri_r0 <= sync2_pixel_tri;
    sync2_pixel_tri_r1 <= sync2_pixel_tri_r0;
    sync2_pixel_tri_wigth_r <= (sync2_pixel_tri_wigth<<2);
end
parameter       IDLE1 = 4'b0001;
parameter       S0 = 4'b0010;
parameter       S1 = 4'b0100;
parameter       S2 = 4'b1000;
reg     [3:0]   sync1_state;
reg             sync_pixel_tri1_reg;
reg     [31:0]  sync_sig_delay1_cnt;

//------------------------------------------------------------------------------
// 6. sync1 延时/脉宽状态机
//
// 输入 sync1_pixel_tri_r1 表示“这个像素窗口前部需要产生 sync1”。
// 输出 sync_pixel_tri1_reg 是整形后的高有效内部脉冲：
//   sync_sig_delay1=0 : 立即输出，宽度为 sync1_pixel_tri_wigth_r。
//   sync_sig_delay1>0 : 先等待 sync_sig_delay1 个 ui_clk 拍，再输出指定宽度。
//
// 注意最终端口 sync_pixel_tri1 会取反，所以外部看到的是低有效脉冲。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge ui_rstn)
    if(!ui_rstn)begin
        sync1_state <= IDLE1;
        sync_sig_delay1_cnt <= 32'd0;
    end
    else case(sync1_state)
            IDLE1:if(sync1_trig_used)begin
                    sync1_state         <= S0;
                  end
                  else begin
                    sync_pixel_tri1_reg <= 0;
                    sync1_state         <= IDLE1;
                  end

       S0:begin
                  if(sync1_delay_used == 16'd0)begin
                    if(sync_sig_delay1_cnt == sync1_width_used)begin
                        sync_sig_delay1_cnt <= 32'd0;
                        sync_pixel_tri1_reg <= 0;
                        sync1_state         <= IDLE1;
                    end
                    else begin
                        sync_sig_delay1_cnt <= sync_sig_delay1_cnt + 1'b1;
                        sync_pixel_tri1_reg <= 1;
                        sync1_state         <= S0;
                    end
                  end
                  else begin
                    sync_pixel_tri1_reg <= 0;
                    sync1_state         <= S1;
                  end
          end
       S1:begin
                    if(sync_sig_delay1_cnt == sync1_delay_used - 1)begin
                        sync_sig_delay1_cnt <= 32'd0;
                        sync_pixel_tri1_reg <= 1;
                        sync1_state         <= S2;
                    end
                    else begin
                        sync_sig_delay1_cnt <= sync_sig_delay1_cnt + 1'b1;
                        sync_pixel_tri1_reg <= 0;
                        sync1_state         <= S1;
                    end
          end
       S2:begin
                    if(sync_sig_delay1_cnt == sync1_width_used - 1)begin
                        sync_sig_delay1_cnt <= 32'd0;
                        sync_pixel_tri1_reg <= 0;
                        sync1_state         <= IDLE1;
                    end
                    else begin
                        sync_sig_delay1_cnt <= sync_sig_delay1_cnt + 1'b1;
                        sync_pixel_tri1_reg <= 1;
                        sync1_state         <= S2;
                    end
       end
       default:begin
                        sync1_state <= IDLE1;
                        sync_sig_delay1_cnt <= 32'd0;
       end
        endcase



always@(posedge ui_clk or negedge ui_rstn)
 if(!ui_rstn)
    sync_pixel_tri1 <= 1'b0;
 else if(ultrafast_mode_r1 || laser_mode_en_ui)
    sync_pixel_tri1 <=  (~sync_pixel_tri1_reg);
 else
    sync_pixel_tri1 <= 1'b0;

// ILA 调试：激光模式下观察 laser_pulse_ui 是否进入 sync1/blanker 整形器。
ila_1 sync1_test (
	.clk(ui_clk), // input wire clk


	.probe0(sync1_trig_used), // input wire [0:0]  probe0
	.probe1(sync1_width_used), // input wire [31:0]  probe1
	.probe2(sync1_state), // input wire [3:0]  probe2
	.probe3(laser_pulse_ui), // input wire [0:0]  probe3
	.probe4(sync_sig_delay1_cnt), // input wire [31:0]  probe4
	.probe5(sync1_delay_used), // input wire [15:0]  probe5
	.probe6(sync_pixel_tri1) // input wire [0:0]  probe6
);

parameter       IDLE2 = 4'b0001;
parameter       S02 = 4'b0010;
parameter       S12 = 4'b0100;
parameter       S22 = 4'b1000;
reg     [3:0]   sync2_state;
reg     [31:0]  sync_sig_delay2_cnt;
reg             sync_pixel_tri2_reg;

//------------------------------------------------------------------------------
// 7. sync2 延时/脉宽状态机
//
// 逻辑和 sync1 平行，但最终不取反：
//   sync_pixel_tri2 = sync_pixel_tri2_reg
//
// 顶层把 sync_pixel_tri2 接到 TRIGGER_OUT，因此它可以作为外部高有效像素
// 同步/触发信号使用。只有 ultrafast_mode 下，上游拆包阶段才会放行 sync2
// 原始标志；普通模式下这里没有输入脉冲，自然不会输出触发。
//------------------------------------------------------------------------------
always@(posedge ui_clk or negedge ui_rstn)
    if(!ui_rstn)begin
        sync2_state <= IDLE2;
        sync_sig_delay2_cnt <= 32'd0;
    end
    else case(sync2_state)
            IDLE2:if(sync2_pixel_tri_r1)begin
                    sync2_state         <= S02;
                  end
                  else begin
                    sync_pixel_tri2_reg <= 0;
                    sync2_state         <= IDLE2;
                  end

       S02:begin
                  if(sync_sig_delay2 == 16'd0)begin
                    if(sync_sig_delay2_cnt == sync2_pixel_tri_wigth_r)begin
                        sync_sig_delay2_cnt <= 32'd0;
                        sync_pixel_tri2_reg <= 0;
                        sync2_state         <= IDLE2;
                    end
                    else begin
                        sync_sig_delay2_cnt <= sync_sig_delay2_cnt + 1'b1;
                        sync_pixel_tri2_reg <= 1;
                        sync2_state         <= S02;
                    end
                  end
                  else begin
                    sync_pixel_tri2_reg <= 0;
                    sync2_state         <= S12;
                  end
          end
       S12:begin
                    if(sync_sig_delay2_cnt == sync_sig_delay2 - 1)begin
                        sync_sig_delay2_cnt <= 32'd0;
                        sync_pixel_tri2_reg <= 1;
                        sync2_state         <= S22;
                    end
                    else begin
                        sync_sig_delay2_cnt <= sync_sig_delay2_cnt + 1'b1;
                        sync_pixel_tri2_reg <= 0;
                        sync2_state         <= S12;
                    end
          end
       S22:begin
                    if(sync_sig_delay2_cnt == sync2_pixel_tri_wigth_r - 1)begin
                        sync_sig_delay2_cnt <= 32'd0;
                        sync_pixel_tri2_reg <= 0;
                        sync2_state         <= IDLE2;
                    end
                    else begin
                        sync_sig_delay2_cnt <= sync_sig_delay2_cnt + 1'b1;
                        sync_pixel_tri2_reg <= 1;
                        sync2_state         <= S22;
                    end
       end
       default:begin
                        sync2_state <= IDLE2;
                        sync_sig_delay2_cnt <= 32'd0;
       end
        endcase
assign sync_pixel_tri2 = sync_pixel_tri2_reg;

// ILA 调试：观察 sync2 原始输入、宽度、状态机、计数器和最终外部输出。
ila_1 sync2_test (
	.clk(ui_clk), // input wire clk


	.probe0(sync2_pixel_tri_r1), // input wire [0:0]  probe0
	.probe1(sync2_pixel_tri_wigth_r), // input wire [31:0]  probe1
	.probe2(sync2_state), // input wire [3:0]  probe2
	.probe3(sync_pixel_tri2_reg), // input wire [0:0]  probe3
	.probe4(sync_sig_delay2_cnt), // input wire [31:0]  probe4
	.probe5(sync_sig_delay2), // input wire [15:0]  probe5
	.probe6(sync_pixel_tri2) // input wire [0:0]  probe6
);

//------------------------------------------------------------------------------
// 8. DAC 输出侧 ILA
//
// 这个 ILA 在 dac_dco 域观察拆包后的 sync1、DAX、DAY。
// 如果想确认 FIFO 是否按 DAC 节拍稳定输出，可以优先看这三个信号。
//------------------------------------------------------------------------------
  ila_2 dac_ila(
  .clk              (dac_dco_bufg),
  .probe0           (sync1_pixel_tri),
  .probe1           (DAX_DATA),
  .probe2           (DAY_DATA)
  );




endmodule

# DL5 设计：飞秒激光同步采集模式（新功能）

> 状态：**架构定稿 v3，进入 plan / 实现阶段**
> 来源需求：[AXI_DDR.srcs/大化所新方案设计.md](../../../AXI_DDR.srcs/大化所新方案设计.md)
> 起草时间：2026-05-22
> v1 → v2 改动（2026-05-22 17:xx）：
> 1. 修正 acq 段单位为 20ns 步进（v1 误写 5ns）
> 2. 状态机从串行 6 态改为**并行 3 态**（blanker 和 acq 两段独立倒数，需求表语义）
> 3. 新增第 6 个寄存器 `laser_period` —— 激光器频率参数，**一个激光周期才切像素**（方案 B）
> 4. **去掉新增 `blanker_out` 物理引脚**：blanker 复用 `sync_pixel_tri1` → `TRIG_BLANK` 引脚，acq_tri 复用内部 `adc_tri` wire（直接送 DL2 adcdata_config，**`adc_tri` 本来就不是物理引脚**），sync2 → `TRIGGER_OUT` 引脚输出 `laser_event_busy` 标志。物理引脚和 xdc 完全不动
> 5. Laser Sync 输入仍是新增 IO，硬件未定先在顶层占位
>
> v2 → v3 改动（2026-05-22 用户拍板 P0 三决策）：
> 1. **时钟选 `ui_clk`**：`laser_sync_blanker_ctrl` 用现有 `ui_clk`（MIG 200MHz，已经在 dacdata_config 里），不另拉 `clk200m`。CDC 边界变为 `ui_clk ↔ eth_clk` / `ui_clk ↔ dac_dco`。所有提到 "clk200m" 的地方按 ui_clk 理解
> 2. **blanker 极性 = 低有效**：与现有 sync_pixel_tri1 输出极性保持一致（dac_output 末级取反）。在 dac_output 内部 mux 时，让 `blanker_pulse` 走和 `sync_pixel_tri1_reg` 同一条 `~` 反相路径
> 3. **acq 延时寄存器新建独立的 `acq_data_delay_time`**：不复用 0x0201 现有 `adc_acq_delay`（功能不同：`adc_acq_delay` 是 ADC 平均采集流水线内部的"采样点扣除/state 1 等待"，作用在 adc_dco 域；`acq_data_delay_time` 是 adc_tri 信号本身的"产生延时"，作用在 ui_clk 域。两者串联，互不冲突）
> 4. 文档表述纠正：原 v2 表里把"adc_tri 复用 adc_tri 引脚"作为 IO 复用条目是错的。`adc_tri` 在本工程里**没有物理引脚**，它是 dacdata_config → adcdata_config 的内部 wire。laser 模式下把 `laser_acq_pulse` 灌进这条内部 wire 就替换了 DL2 的 ADC 触发源，不涉及 xdc 改动

---

## 0. 一句话先抓住

新增一条 **"激光作主、FPGA 作从"** 的数据通路：飞秒激光器以固定频率（例如 500KHz）发送脉冲，FPGA 在 ui_clk(200MHz) 域按"延时 → blanker / 延时 → acq"的并行时序响应；每个激光周期对应一个像素，在周期末 (`t_cnt = laser_period`) 切下一个像素。

旧模式（FPGA 自己倒数 `dac_sample` 拍）保留不动，由 `laser_mode_en` 寄存器位切换。

---

## 1. 主从关系反转

| 项 | 旧模式（laser_mode_en=0） | 新模式（laser_mode_en=1） |
|---|---|---|
| 谁是时间基准 | FPGA `dac_dco` (50MHz) 内部计数 | **外部飞秒激光器脉冲（典型 500KHz）** |
| 一个像素停多久 | `dac_sample` × 20ns | **一个激光周期 = `laser_period` × 5ns**（500KHz → 2000ns → 400 拍） |
| 切像素由谁决定 | `parameter_dacdata_gen` State 3 倒数完 | `t_cnt` 到 `laser_period` 时发 `pixel_done_pulse` |
| blanker 输出 | 无 | 收到激光脉冲后延 `blanker_delay_time`（5ns 步进），保持 `blanker_time`（5ns 步进）。最终 IO 引脚 **`TRIG_BLANK`(B16)** 极性保持低有效 |
| acq 输出 | adc_tri 在 State 3 期间持续 | 收到激光脉冲后延 `acq_data_delay_time`（20ns 步进 → ×4），保持 `acq_time`（20ns 步进 → ×4）。**注意**：与现有 `adc_acq_delay`（0x0201, ADC 内部死区控制）不是同一参数，新建独立寄存器 |
| blanker / acq 时序关系 | — | **并行**（两段从同一个激光上升沿独立起算） |

---

## 2. 整体架构图

```
                                    ┌──────────────────────────────────┐
                                    │ command_monitor_new (eth_clk)    │
                                    │   寄存器 → 6 个新参数 + mode_en   │
                                    └──┬──────┬───────────────────────┘
                       laser_mode_en  │      │ 6 个时间参数
                                       │      │ (clk200m 拍数)
              ┌────────────────────────┘      └──────────────────────────┐
              │                                                          │
              ▼ eth_clk                                       eth_clk  ▼ ▼ clk200m
   ┌──────────────────────────┐  pixel_done_pulse  ┌──────────────────────────────┐
   │ parameter_dacdata_gen    │◄───────────────────│ laser_sync_blanker_ctrl       │  ★ 新增
   │  - State 3 加 mode 分支  │     (pulse CDC)    │  Laser Sync IO → CDC + 边沿    │
   │  - mode=0: 倒数 dac_sample│                    │  3 段状态机:                  │
   │  - mode=1: 等 pixel_done  │                    │   IDLE → BUSY → DONE          │
   │  - 其它 13 个 state 不变  │                    │  内部并行 4 路计数:            │
   └────────┬──────────────────┘                    │    blanker_window 区间检测    │
            │ 35-bit FIFO 写                         │    acq_window 区间检测        │
            ▼                                       │    laser_event_busy = BUSY    │
   ┌──────────────────────────┐                     │    period_done = (t_cnt==Tp)  │
   │ fifo_generator_4 (35-bit)│                     │  输出（clk200m 域）:           │
   │   (现有 IP, 不动)         │                     │    blanker_pulse              │
   └────────┬─────────────────┘                     │    laser_acq_pulse            │
            │ (eth_clk → dac_dco)                   │    laser_event_busy           │
            ▼                                       │    pixel_done_pulse → eth_clk │
   ┌──────────────────────────────────────────┐     └─┬──────┬──────────┬──────────┘
   │ dac_output (dac_dco)                     │       │      │          │
   │  ┌─────────────────────────────────┐     │       │      │          │
   │  │ DAX / DAY: 来自 FIFO, 不变       │     │       │      │          │
   │  └─────────────────────────────────┘     │       │      │          │
   │  ┌─────────────────────────────────┐     │       │      │          │
   │  │ adc_tri = mux(mode, FIFO, laser_acq_pulse)    │       │      │          │
   │  │ sync1   = mux(mode, FIFO, blanker_pulse)      │       │      │          │
   │  │ sync2   = mux(mode, FIFO, laser_event_busy)   │       │      │          │
   │  └─────────────────────────────────┘     │       │      │          │
   └────────┬─────────────────────────────────┘       │      │          │
            ▼                                         │      │          │
        IO 引脚（物理不变，xdc 不动）                  │      │          │
        DAX / DAY (AD9747)                          │      │          │
        adc_tri    引脚 = laser_acq_pulse  ◄───────┘      │          │
        sync1     引脚 = blanker_pulse    ◄──────────────┘          │
        sync2     引脚 = laser_event_busy ◄─────────────────────────┘

   外部输入: Laser Sync (2.5V TTL, SMA, 50ns 高电平脉冲)
            ──────────────────────────────────────────► clk200m 域 CDC
```

---

## 3. 关键设计决策（来自 2026-05-22 用户回答）

| 决策点 | 选择 | 对设计的影响 |
|---|---|---|
| 1 个激光脉冲 = 1 个像素 | ✅ | FPGA 不需要 dwell 计数器 |
| IO 引脚硬件未定 | 仅 Laser Sync 是新增（占位） | blanker / acq / sync 全部复用现有引脚 / 内部 wire |
| sync_pixel_tri1 复用为 blanker | ✅ | dac_output 内部 mux；最终物理引脚 `TRIG_BLANK`(B16) |
| sync_pixel_tri2 跟随激光事件 | ✅ → 具体化为 `laser_event_busy` | 整个事件期间高，DONE 后拉低；用作外设的"事件指示"；最终物理引脚 `TRIGGER_OUT`(G16) |
| acq 触发源 | 内部 `adc_tri` wire（不涉及 IO） | dac_output 内 mux 把 `laser_acq_pulse` 替换 FIFO[32]，直接送 DL2 adcdata_config |
| 超时处理 | 不做 | 没有看门狗 |
| 切像素策略（v2 新增） | **方案 B：等 `t_cnt = laser_period` 才切** | 新增第 6 个寄存器 `laser_period`；`pixel_done_pulse` 由 `period_done` 触发 |
| blanker / acq 时序关系（v2 修正） | **并行**（两段从激光上升沿独立倒数） | 状态机简化为 3 态 + 2 个并行 window 比较器 |
| 200MHz 时钟源（v3 拍板）| **`ui_clk`**（MIG） | dacdata_config 现有端口，不另拉时钟；与现有 `clk200m`（sysclk PLL）频率相同但不同源，本设计统一用 ui_clk |
| blanker 极性（v3 拍板）| **与现有 sync_pixel_tri1 一致 = 低有效** | dac_output 内 mux 让 `blanker_pulse` 走现有的 ~ 取反路径 |
| acq 延时寄存器（v3 拍板）| **新建独立 `acq_data_delay_time`**，不复用 0x0201 | 功能不同（adc_dco 域 vs ui_clk 域，串联关系）；命令表新增 0x0208 |
| scan_state 门控（v3 新增）| **方案 A**：模块内用 `mode_en & scan_state` 作为激活条件 | scan_state=0 时强制 IDLE，所有输出归 0 |
| State 3 新模式实现（v3 澄清）| **one-shot 写 1 个 FIFO word**，然后停 wr_en 等 pixel_done | 新增内部 `laser_pixel_written` 标志；R1 已确认 dac_output 自保持 DAX/DAY |

---

## 4. `laser_sync_blanker_ctrl` 模块设计

### 4.1 端口

```verilog
module laser_sync_blanker_ctrl (
    // 时钟与复位（ui_clk 域，200MHz，来自 MIG）
    input               ui_clk,
    input               rstn,

    // 模式与参数（来自 eth_clk 域，进 ui_clk 前在外部做双 FF 同步）
    input               laser_mode_en,        // 1-bit
    input  [15:0]       blanker_delay_time,   // 单位 = ui_clk 拍 = 5ns
    input  [15:0]       blanker_time,         // 单位 = 5ns
    input  [15:0]       acq_data_delay_time,  // 单位 = 20ns 步进 (内部 ×4 转 5ns 拍)
    input  [15:0]       acq_time,             // 单位 = 20ns 步进 (内部 ×4 转 5ns 拍)
    input  [31:0]       laser_period,         // 单位 = ui_clk 拍 = 5ns (500KHz → 400)

    // 外部异步输入（顶层送进来，本模块内做 CDC 与上升沿检测）
    input               laser_sync_in,        // 异步, 50ns 高电平脉冲

    // ui_clk 域输出（语义层面）
    output reg          blanker_pulse,        // BUSY 期间 blanker 时间窗内为 1（**送 mux 时仍是高有效内部信号**；最终物理引脚 TRIG_BLANK 经 dac_output 末级 ~ 取反为低有效）
    output reg          laser_acq_pulse,      // BUSY 期间 acq 时间窗内为 1，**直接驱动 dac_output 内部 adc_tri mux**
    output reg          laser_event_busy,     // BUSY 状态期间为 1，IDLE/DONE 为 0；最终送 sync2 → TRIGGER_OUT 引脚（保持高有效）

    // CDC 后的脉冲（已同步到 eth_clk 域）
    output              pixel_done_pulse_eth  // 1 拍脉冲，给 parameter_dacdata_gen
);
```

### 4.2 内部状态机（3 态）

| 状态 | 含义 | `t_cnt` 行为 | 输出 | 转出条件 |
|---|---|---|---|---|
| `IDLE` | 等激光脉冲 | 保持 0 | 全部 0 | `laser_pulse_edge` & `laser_mode_en` → `BUSY` |
| `BUSY` | 一个激光事件进行中 | 每拍 +1 | 见下面 4 个并行表达式 | `t_cnt == laser_period - 1` → `DONE` |
| `DONE` | 一拍 | 复位 0 | 全部 0；输出 `pixel_done_pulse_clk200m=1` | 立刻 → `IDLE` |

### 4.3 BUSY 状态的并行输出（组合或锁存）

定义 4 个内部计数终点（在 BUSY 入口或参数变化时预算好）：

```verilog
wire [31:0] blanker_start_5ns = {16'd0, blanker_delay_time};
wire [31:0] blanker_end_5ns   = blanker_start_5ns + {16'd0, blanker_time};

wire [31:0] acq_start_5ns     = {14'd0, acq_data_delay_time, 2'd0};   // ×4
wire [31:0] acq_end_5ns       = acq_start_5ns + {14'd0, acq_time, 2'd0}; // ×4
```

输出表达式（在 BUSY 状态内 always 块）：

```verilog
blanker_pulse    <= (current_state == BUSY) && (t_cnt >= blanker_start_5ns) && (t_cnt < blanker_end_5ns);
laser_acq_pulse  <= (current_state == BUSY) && (t_cnt >= acq_start_5ns)     && (t_cnt < acq_end_5ns);
laser_event_busy <= (current_state == BUSY);
```

### 4.4 时序图（一个激光周期内）

```
                t=0                           t=laser_period
                 │                                  │
laser_sync_in ───┘└────────────────...──────────────┘└───────► (下个周期)
                 │← 50ns →                         │
state          IDLE│        BUSY                   │DONE│ IDLE
                 │                                  │
                 │ ←── blanker_delay ──┤           │
blanker_pulse ─0─┤────0─0─0───────────┤1 ─ 1 ─ 0──┤───0─...
                                       │← b_time→│
                 │
                 │ ←── acq_delay ──────────┤      │
laser_acq_pulse 0│─────0─0─0─0─0─────────┤1─1─1─0│───0─...
                                          │acq_t │
                 │
laser_event_busy 0│←───── BUSY 全程 ──────────────►│0
                                                   │
pixel_done_pulse_clk200m ────────────────────────── ┤1│ 0  (仅 1 拍)
                                                   │
                                          (经 CDC) │
pixel_done_pulse_eth ──────────────────────────────┤1│ 0  (eth_clk 域 1 拍)
```

边界与不变量：

- `blanker_end_5ns ≤ laser_period`（上位机参数防呆，FPGA 不查）
- `acq_end_5ns ≤ laser_period`（同上）
- 第二个激光脉冲在 BUSY/DONE 期间到达：被忽略（IDLE 才接受）
- `blanker_start = blanker_end`（即 `blanker_time = 0`）：blanker_pulse 始终为 0，等价"关闭 blanker"
- `acq_start = acq_end`：同理，等价"关闭 acq"

### 4.5 输入边界处理

| 输入 | 处理 |
|---|---|
| `laser_sync_in` | 3 级 FF 同步到 ui_clk → 上升沿检测 → `laser_pulse_edge`（1 拍） |
| 6 个寄存器参数 + mode_en | 在外层 `dacdata_config` 做 CDC（双 FF + ASYNC_REG），稳态后送入 |

### 4.6 输出边界处理

| 输出 | 去向 | 同步方式 |
|---|---|---|
| `blanker_pulse` / `laser_acq_pulse` / `laser_event_busy` | `dac_output`（dac_dco 50MHz 域）的 mux | ui_clk → dac_dco 双 FF 同步。**约束**：脉宽 ≥ 2 个 dac_dco 周期 = 40ns。`acq_time ≥ 2`（=40ns）；`blanker_time ≥ 8`（=40ns）；`laser_event_busy` 是整个 BUSY 期间，远大于 40ns，不受限 |
| `pixel_done_pulse_ui_clk` | eth_clk 域的 `parameter_dacdata_gen` | pulse synchronizer（XPM 或 toggle-FF） |

### 4.7 scan_state 门控（v3 新增）

`scan_state=0`（停扫）期间，激光脉冲到达不应该产生 `pixel_done_pulse` 或扰动 `parameter_dacdata_gen` 的状态。两种实现选择：

- **方案 A（推荐）**：在 `laser_sync_blanker_ctrl` 内部用 `laser_mode_en & scan_state` 作为状态机激活条件；scan_state=0 时强制 IDLE，所有输出归 0。
- 方案 B：让 mux 在 dac_output 内继续走"scan_state=0 → adc_tri=0"的现有逻辑，状态机仍跑但 mux 屏蔽。

方案 A 更干净，避免无谓的 CDC 抖动。实现时 scan_state 也要从 eth_clk → ui_clk 双 FF 同步（CDC 表追加一条）。

---

## 5. 其它文件的改动

### 5.1 `parameter_dacdata_gen.v` (State 3 加 mode 分支 + one-shot 写 FIFO)

v3 关键澄清：新模式下 State 3 必须**只写 1 个 FIFO word** 后停止 wr_en，否则会用同一像素电平把整个激光周期的 FIFO 填满（dac_dco 读侧 50MHz × 2us = 100 个 word，但写侧 eth_clk 125MHz × 2us = 250 个 word，反压能挡，但不优雅且会让停止扫描时残留垃圾）。需要一个 one-shot 标志。

R1 已确认：`dac_output.v:212-217` 在 `para_config_rd_en=0` 时把 DAX/DAY 自保持，所以"只写 1 word 让 DAC 切电平，然后空等"是可行的。

```verilog
// 新增输入端口
input  laser_mode_en,           // eth_clk 域（同域，已经在 command_monitor_new 输出）
input  pixel_done_pulse,        // 来自 laser_sync_blanker_ctrl，已 CDC 到 eth_clk，单拍

// 内部新增 reg
reg laser_pixel_written;        // State 3 当前像素是否已经写过 1 个 FIFO word

// State 3 内部改：
3:                              // one Tk point
begin
    if(laser_mode_en) begin
        // === 新模式分支 ===
        sync_pixel_tri1 <= 1'b0;
        sync_pixel_tri2 <= 1'b0;
        if(!laser_pixel_written) begin
            // 第一次进 State 3：写 1 个 FIFO word 让 DAC 切到当前像素电平
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en   <= 1'b1;
                adc_tri             <= 1'b0;   // FIFO[32] 在 laser 模式被 dac_output mux 丢弃
                DAX_DATA            <= dax_level[63:48];
                DAY_DATA            <= day_level[63:48];
                laser_pixel_written <= 1'b1;
            end
            // FIFO 满则原地等
        end else begin
            // 已经写过：停止 wr_en，DAC 自保持，等激光周期结束
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            if(pixel_done_pulse) begin
                laser_pixel_written <= 1'b0;   // 清标志，准备下一像素
                current_state       <= 4;
            end
        end
    end else begin
        // === 旧模式分支（保留原 14 态逻辑，不变）===
        if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
            para_config_wr_en       <= 1'b1;
            adc_tri                 <= 1'b1;
            DAX_DATA                <= dax_level[63:48];
            DAY_DATA                <= day_level[63:48];
            if(dac_sample_cnt < dac_sample - 1) begin
                dac_sample_cnt      <= dac_sample_cnt + 1'b1;
                current_state       <= 3;
            end else begin
                dac_sample_cnt      <= 0;
                current_state       <= 4;
            end
            sync_pixel_tri1 <= (dac_sample_cnt < sync1_pixel_tri_wigth - 1);
            sync_pixel_tri2 <= (dac_sample_cnt < sync2_pixel_tri_wigth - 1);
        end else
            para_config_wr_en <= 1'b0;
    end
end
```

注意：`laser_pixel_written` 必须在复位、State 0/1（每条扫描线开始前）和进 State 4 时显式清 0。

### 5.2 `dac_output.v` (3 个 mux，无新增物理端口)

读完 `dac_output.v` 后对齐到实际信号名（不再是意图描述）：

```verilog
// 新增输入端口（信号层，无 IO）
input  laser_mode_en,
input  blanker_pulse,        // ui_clk 域，来自 laser_sync_blanker_ctrl
input  laser_acq_pulse,      // ui_clk 域
input  laser_event_busy,     // ui_clk 域

// 关键 mux 位置（对齐现有代码）：
//   adc_tri：mux 在 dac_output.v:208 的 always 块输出上
//       旧：adc_tri <= (scan_state_r1) ? para_config_dout[32] : 1'b0;
//       新：adc_tri <= laser_mode_en_dac
//                    ? (scan_state_r1 ? laser_acq_pulse_dac : 1'b0)
//                    : (scan_state_r1 ? para_config_dout[32] : 1'b0);
//
//   sync1 (TRIG_BLANK 引脚)：mux 在末级取反前
//       现有：sync_pixel_tri1 <= ultrafast_mode_r1 ? (~sync_pixel_tri1_reg) : 1'b0;
//       新： 先把内部 reg 选择源 mux，再让现有的 ~ 取反路径生效
//             sync_pixel_tri1_src = laser_mode_en_dac ? blanker_pulse_dac : sync_pixel_tri1_reg;
//             sync_pixel_tri1     = (laser_mode_en_dac || ultrafast_mode_r1) ? ~sync_pixel_tri1_src : 1'b0;
//       这样 blanker 输出在物理引脚保持低有效，与现有 sync1 极性一致。
//
//   sync2 (TRIGGER_OUT 引脚)：mux 在 sync_pixel_tri2_reg 之前
//       现有：assign sync_pixel_tri2 = sync_pixel_tri2_reg;
//       新： assign sync_pixel_tri2 = laser_mode_en_dac ? laser_event_busy_dac : sync_pixel_tri2_reg;
//       （laser_event_busy 高有效直接送，不再走 ui_clk 延迟状态机）
//
// 所有 *_dac 后缀变量都是 ui_clk → dac_dco 双 FF 同步后的版本。
// laser_acq_pulse 进入 dac_dco 域后直接覆盖 adc_tri，DL2 的 adcdata_config 看到的就是 laser 触发。
```

物理引脚和 xdc **完全不动**：blanker → `TRIG_BLANK`(B16, LVCMOS33, 低有效)，laser_event_busy → `TRIGGER_OUT`(G16, LVCMOS33, 高有效)。

### 5.3 `dacdata_config.v` (例化新模块 + CDC)

- 例化 `laser_sync_blanker_ctrl`，传入 **`ui_clk`**（dacdata_config 现有端口，不新增时钟）
- `laser_mode_en` + 6 个时间参数从 eth_clk → ui_clk 双 FF 同步（`ASYNC_REG=TRUE`）
- `pixel_done_pulse` 从 ui_clk → eth_clk pulse 同步（toggle-FF 或 XPM_CDC_PULSE）
- `blanker_pulse / laser_acq_pulse / laser_event_busy` 从 ui_clk → dac_dco 双 FF 同步，再给 `dac_output`
- `laser_mode_en` 单独再做一份 eth_clk → dac_dco 同步给 `dac_output` 内 mux 使用

### 5.4 `command_monitor_new.v` (6 个新寄存器)

地址分配在 0x0205 起接续现有的 0x0200~0x0204 扩展段（不动现有寄存器；不修 0x0200 重复 case 的旧 bug，先聚焦 DL5）：

| 地址 | 寄存器 | 位宽 | 单位 | 用途 |
|---|---|---|---|---|
| `0x0205` | `laser_mode_en` | 1（bit[0]） | — | 模式切换；其余 31 位保留 |
| `0x0206` | `blanker_delay_time` | 16（bit[15:0]） | ui_clk 拍数（5ns） | 上位机直接写拍数 |
| `0x0207` | `blanker_time` | 16（bit[15:0]） | 5ns 拍 | 最小允许值 = 8（=40ns，CDC 安全） |
| `0x0208` | `acq_data_delay_time` | 16（bit[15:0]） | 20ns 步进 | 上位机写步进数，FPGA 内 ×4 转 5ns 拍。**与现有 0x0201 `adc_acq_delay` 不同**：后者作用在 adc_dco 域控制 ADC 内部死区/state 1 等待，本寄存器作用在 ui_clk 域控制 adc_tri 信号产生延时 |
| `0x0209` | `acq_time` | 16（bit[15:0]） | 20ns 步进 | 最小允许值 = 2（=40ns） |
| `0x020A` | `laser_period` | 32 | ui_clk 拍数（5ns） | 500KHz → 400；100KHz → 2000；上位机直接换算成拍数下发 |

约束（上位机保证 + FPGA 不做硬防呆）：
- `blanker_end ≤ laser_period` 且 `acq_end ≤ laser_period`
- `laser_mode_en` 仅在 `scan_state=0` 时切换
- 寄存器写入顺序：先写 6 个参数 → 等 ~3 个 ui_clk 拍（让 CDC 稳定）→ 再开 `laser_mode_en`

### 5.5 `ETH_TOP.v` (顶层只加一个输入端口)

```verilog
// 顶层新增端口（只有 1 个 IO，xdc 暂不约束）
input   laser_sync_in,        // 飞秒激光同步信号 (2.5V TTL, 异步, 50ns 脉冲)
//                                等硬件给引脚号后在 fpga_pin.xdc 加约束

// blanker_out 不再是新端口！物理引脚复用 sync1。
```

### 5.6 `fpga_pin.xdc` (基本不动)

只待补 1 行（Laser Sync 输入引脚）：

```tcl
# 待补：Laser Sync 输入引脚（硬件确认后追加）
# set_property PACKAGE_PIN <X>  [get_ports laser_sync_in]
# set_property IOSTANDARD LVCMOS25 [get_ports laser_sync_in]
```

sync1 / sync2 / adc_tri 的 IO 约束 **完全不动**，只是新模式下输出语义切换，引脚电气属性保持原样（3.3V LVCMOS33）。

> ⚠️ **电平注意**：blanker 需求是 3.3V TTL，sync1 现有引脚就是 LVCMOS33，匹配。如果硬件实际接束闸驱动有外围电路约束，确认即可。

---

## 6. CDC 边界全清单

| # | 跨域 | 信号 | 同步方式 | 注意 |
|---|---|---|---|---|
| 1 | 异步外部 → ui_clk | `laser_sync_in` 上升沿 | 3 级 FF + 边沿检测 | 50ns 脉宽远 > 2 个 ui_clk 周期，安全 |
| 2 | eth_clk → ui_clk | `laser_mode_en` + 6 参数 | 双 FF + `ASYNC_REG=TRUE` + `set_max_delay -datapath_only` | 参数变化频率低 |
| 3 | ui_clk → eth_clk | `pixel_done_pulse` | pulse synchronizer（toggle-FF 或 `XPM_CDC_PULSE`） | 必须是脉冲安全的 CDC |
| 4 | ui_clk → dac_dco | `blanker_pulse / laser_acq_pulse` | 双 FF | **脉宽约束**：blanker_time ≥ 8（=40ns）；acq_time ≥ 2（=40ns） |
| 5 | ui_clk → dac_dco | `laser_event_busy` | 双 FF | BUSY 期间远 > 40ns，无忧 |
| 6 | eth_clk → dac_dco | `laser_mode_en` (mux 选择信号) | 双 FF + `ASYNC_REG=TRUE` | 与现有 `ultrafast_mode` 同款，dac_output 内既有同步链可复用 |

> blanker_pulse 不再走单独 IO，所以原 v1 表里的"→ IO 直接出"那条删除。
> 注：`ui_clk` 与现有 `clk200m`（来自 sysclk PLL）频率相同（200MHz）但不同源；本设计统一使用 `ui_clk`（来自 MIG），dacdata_config 内已经有这个端口。

---

## 7. 测试与验证策略

### 7.1 单元仿真：`AI-work/sim/tb_laser_sync_blanker_ctrl.v`

| 用例 | 输入序列 | 预期输出 |
|---|---|---|
| TC1 | mode_en=0，激光脉冲来一发 | 所有输出恒 0，无 pixel_done_pulse |
| TC2 | mode_en=1，laser_period=400 (2us)，bd=20 (100ns)，bt=40 (200ns)，acq_d=10 (200ns)，acq_t=20 (400ns) | t=0~99ns：blanker=0, acq=0；t=100~299ns：blanker=1；t=200~599ns：acq=1（与 blanker 后段重叠，独立）；t=2000ns：pixel_done_pulse；laser_event_busy 在 t=0~2000ns 全程为 1 |
| TC3 | mode_en=1，连续 3 发激光脉冲，间隔 2us | 3 次完整事件链，3 个 pixel_done_pulse |
| TC4 | mode_en=1，blanker_delay=0 | t=0 立刻拉 blanker（这里要确认状态机第一拍能否输出，可能需要预算优化） |
| TC5 | mode_en=1，事件未结束时第二个激光脉冲到达（间隔 < laser_period） | 当前事件继续，新脉冲被忽略 |
| TC6 | mode_en=1，blanker_time=0 | blanker_pulse 全程为 0 |
| TC7 | mode_en=1，acq_time=0 | laser_acq_pulse 全程为 0 |

testbench 用 `$display("PASS")` / `$display("FAIL")`，关键信号导 csv 到 `sim_out/`。

### 7.2 集成仿真

复用现有 `fram_test.v` 或新写一个 `tb_dl5_integration.v`：

- 模拟 PC 写 6 个寄存器 → 等参数稳定 → mode_en=1
- 模拟 `parameter_dacdata_gen` 走到 State 3
- 模拟激光脉冲（500KHz）连续到达
- 验证：DAX/DAY 切换、blanker/adc_tri/sync2 输出时序、状态机切到 State 4

### 7.3 综合验证

- WNS ≥ 0，重点看 clk200m ↔ dac_dco ↔ eth_clk 三域路径
- 资源占用增量 < 2%
- DRC 报告检查 CDC 警告

### 7.4 上板验证（用户执行）

ILA 探针建议挂：

| 信号 | 时钟域 | 用途 |
|---|---|---|
| `laser_sync_in_sync2` | clk200m | 看激光脉冲是否被正确同步 |
| `current_state` | clk200m | 看状态机跳转 |
| `t_cnt` | clk200m | 看周期内进度 |
| `blanker_pulse / laser_acq_pulse / laser_event_busy` | clk200m | 看输出时序 |
| `pixel_done_pulse_clk200m` | clk200m | 看周期结束 |

---

## 8. 待确认风险 / 后续问题

| 编号 | 风险 / 问题 | 状态 / 影响 |
|---|---|---|
| R1 | `dac_output.v` 在新模式下 State 3 只写 1 个 FIFO word 时，DAC 输出会保持还是被覆盖？ | **已解决**（v3）：`dac_output.v:212-217` 在 `para_config_rd_en=0` 时自保持 DAX/DAY，可行。State 3 用 `laser_pixel_written` one-shot 标志确保只写 1 word |
| R2 | 6 个新寄存器的地址映射 | **已决（v3）**：0x0205~0x020A 接续现有扩展段；不修 0x0200 重复 case 旧 bug |
| R3 | `acq_time ≥ 2`、`blanker_time ≥ 8` 防呆位置 | **已决（v3）**：上位机保证，FPGA 不夹紧 |
| R4 | `blanker_end ≤ laser_period`、`acq_end ≤ laser_period` 是否要 FPGA 防呆？ | **已决（v3）**：上位机保证，FPGA 不做 |
| R5 | 上位机的 6 个寄存器写入顺序：先写参数再开 mode_en | **已决（v3）**：写入顺序 6 参数 → 等 ~3 ui_clk 拍 → 开 mode_en；并要求 mode_en 只在 scan_state=0 时切换 |
| R6 | OV5640 摄像头链路和新功能是否冲突？目前看独立 | 等综合时序看 |
| R7 | Laser Sync 引脚电平 2.5V TTL，FPGA bank 是否支持 LVCMOS25？需要硬件确认 | xdc 阶段处理 |
| R8 | sync2 在新模式语义改成 `laser_event_busy`，外设是否真的需要这个信号？ | **OPEN-QUESTIONS Q12**，等用户实际接外设时确认 |
| R9 | `laser_period` 32-bit 够不够？ | 充足（最低 50KHz=4000，1KHz=200000，远未到 32-bit 极限） |
| R10（v3）| blanker 极性 | **已决（v3）**：与现有 sync_pixel_tri1 物理引脚极性一致 = 低有效；mux 复用现有 ~ 取反路径 |
| R11（v3）| acq_data_delay_time 与 0x0201 adc_acq_delay 关系 | **已决（v3）**：功能不同（前者作用 ui_clk 域控制 adc_tri 产生延时，后者作用 adc_dco 域控制 ADC 内部死区），新建独立寄存器，互不冲突 |
| R12（v3）| 200MHz 时钟选 ui_clk 还是 clk200m | **已决（v3）**：用 `ui_clk`（dacdata_config 现有端口，零成本接入） |
| R13（v3）| scan_state 门控 | **已决（v3）**：方案 A，`laser_sync_blanker_ctrl` 内部用 `mode_en & scan_state` 作为激活条件，scan_state=0 强制 IDLE |

---

## 9. 后续 plan 步骤预告（v3 更新）

R1、R2、R10~R13 已解决，无须再做"先读两个底层模块"前置步骤。直接进入实现：

1. **写 `laser_sync_blanker_ctrl.v` + 单元 testbench**：放在 `AXI_DDR.srcs/sources_1/new/` + `AI-work/sim/tb_laser_sync_blanker_ctrl.v`；用 xsim 跑 TC1~TC7
2. **改 `parameter_dacdata_gen.v` State 3**：加 mode 分支 + `laser_pixel_written` one-shot 标志；用现有 fram_test 或新写 dl5_param_tb 跑回归确保旧模式不变
3. **改 `dac_output.v`**：加 4 个新输入端口（laser_mode_en + 3 个激光信号）；在现有 sync1 取反路径、sync2 输出路径、adc_tri 输出路径上 mux
4. **改 `dacdata_config.v`**：例化 `laser_sync_blanker_ctrl`（接 ui_clk）+ 6 处 CDC（eth_clk→ui_clk×2，ui_clk→eth_clk×1，ui_clk→dac_dco×3）
5. **改 `command_monitor_new.v`**：加 6 个寄存器（0x0205~0x020A）+ 6 个输出端口；reset 默认值给安全值
6. **改 `ETH_TOP.v`**：拉 1 个输入端口（laser_sync_in）+ 6 个新 wire + 例化更新
7. **集成仿真**：写 `AI-work/sim/tb_dl5_integration.v` 跑完整链路
8. **综合验证**：WNS ≥ 0 / 资源单项变化 < 5% / DRC 无 ERROR
9. **等硬件给 Laser Sync 引脚号 → 补 xdc 1 行**

每步独立 commit，遵循 RULES.md。综合次数遵守 RULES.md 的"单日 ≤ 4 次"刹车。

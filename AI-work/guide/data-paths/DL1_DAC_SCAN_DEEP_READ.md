# DL1 精读：DAC 扫描输出与触发链路

## 0. 心智模型（先理解再看代码）

DL1 的本质是一个**扫描波形发生器**：PC 通过以太网配置扫描参数，FPGA 按照这些参数生成 X/Y 两路 DAC 波形（驱动电子束偏转），同时在每个像素点产生 `adc_tri` 触发 ADC 采集。

```
PC 寄存器参数 (eth_clk 域)
    ↓
┌─────────────────────────────────────────────────────────────────┐
│ dacdata_config (顶层包装)                                        │
│                                                                  │
│  ┌──────────────────────────┐     ┌──────────────────────────┐  │
│  │ parameter_dacdata_gen    │     │ dac_output               │  │
│  │ (eth_clk 域)             │     │ (dac_dco 域)             │  │
│  │                          │     │                          │  │
│  │ 14 态状态机              │     │ fifo_generator_4         │  │
│  │ 生成 35-bit 参数流：     │────►│ (eth_clk → dac_dco CDC)  │  │
│  │ {sync2,sync1,adc_tri,   │     │       ↓                  │  │
│  │  DAX[15:0],DAY[15:0]}   │     │ 拆包 → DAX/DAY/adc_tri  │  │
│  │                          │     │       ↓                  │  │
│  └──────────────────────────┘     │ sync 延迟状态机          │  │
│                                    │ (ui_clk 域)             │  │
│                                    └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
    ↓                    ↓                    ↓
  DAX_DATA            DAY_DATA            adc_tri → ADC 采集链
    ↓                    ↓                sync_pixel_tri1/2 → 同步输出
 65535-DAX           65535-DAY
    ↓                    ↓
 dac_p1d[15:0]      dac_p2d[15:0]  → AD9747 物理端口
```

**关键理解**：整条链路的核心是 `parameter_dacdata_gen` 的 14 态状态机。它不是实时计算波形，而是**预先把整帧扫描的每一拍 DAC 值都算好**，写进 FIFO，由 `dac_output` 在 `dac_dco` 域逐拍读出。这是一种"预计算 + FIFO 缓冲"的架构。

### 数据流方向

```
PC/ETH → WR_REG_* → command_monitor_new → dacdata_config → parameter_dacdata_gen
    → async FIFO (fifo_generator_4) → dac_output → DAX_DATA/DAY_DATA → dac_p1d/dac_p2d
```

### 时钟域分布

| 时钟域 | 频率 | 覆盖的逻辑 |
|---|---|---|
| `eth_clk` | 125 MHz | 寄存器参数、parameter_dacdata_gen 波形计算、FIFO 写侧 |
| `dac_dco` | 50 MHz | dac_output 主状态机、DAX/DAY/adc_tri 输出、FIFO 读侧 |
| `ui_clk` | 200 MHz | sync 延迟状态机（精细脉冲宽度控制） |

---

## 1. dacdata_config.v — DL1 顶层包装

**文件**：`AXI_DDR.srcs/sources_1/new/dacdata_config.v`

**一句话**：不做波形计算，只做三件事 — 生成复位脉冲、同步外部触发、例化波形生成器和输出模块。

### 1.1 复位机制（dacdata_config.v:74-91）

```verilog
rstn_r0 <= (scan_state_r0==0 && scan_state==1) ? 0 : 1;
rstn_r1 <= {rstn_r1[4:0], rstn_r0};
rstn_r2 =  rstn_r1[5] & rstn_r1[4] & ... & rstn_r1[0];  // 6 拍全 1 才释放
```

**含义**：
- `scan_state` 从 0→1 的上升沿产生一个**至少 6 拍的复位脉冲**给波形生成器
- 这确保每次启动扫描时状态机从头开始
- 停止扫描（`scan_state=0`）时**不复位** — DAC 输出保持最后值不跳变
- 这是"new function,when stop scan,DAC_output continue"注释的含义

### 1.2 dax_fall_time_r 的乘法（dacdata_config.v:69）

```verilog
dax_fall_time_r <= (dax_fall_time<<5) + (dax_fall_time<<4) + (dax_fall_time<<1);
//              = dax_fall_time * (32 + 16 + 2) = dax_fall_time * 50
```

**含义**：用户设置的 `dax_fall_time` 单位是"dac_dco 拍"（50 MHz），乘以 50 不是频率转换，而是因为 `parameter_dacdata_gen` 运行在 eth_clk (125 MHz) 域，每个 dac_dco 拍对应 125/50 = 2.5 个 eth_clk 拍... 但这里乘的是 50 而不是 2.5。

实际含义：`dacx_recovery_time` 也用同样的 ×50 公式（见 parameter_dacdata_gen.v:55）。这说明**用户参数的单位是"微秒"**，乘 50 转成 dac_dco 拍数（50 MHz × 1 µs = 50 拍）。但 parameter_dacdata_gen 运行在 eth_clk 域，所以这个拍数实际对应 eth_clk 的拍数 — 意味着 FIFO 写入速率和 dac_dco 读出速率之间有 125/50 = 2.5 倍的速度差，FIFO 会逐渐积累数据。

### 1.3 dacx_pp_level（dacdata_config.v:70）

```verilog
dacx_pp_level <= dacx_end_level - dacx_strat_level;
```

X 轴 DAC 的峰峰值（end - start），用于计算下降斜坡的步进。

### 1.4 TRIGGER_IN 同步（dacdata_config.v:93-106）

```verilog
TRIGGER_IN_r0 <= TRIGGER_IN;
TRIGGER_IN_r1 <= TRIGGER_IN_r0;
TRIGGER_IN_Rise = (!TRIGGER_IN_r1) && TRIGGER_IN_r0;  // 上升沿检测
```

两拍同步 + 上升沿检测。当 `clk_sel=1` 时，`parameter_dacdata_gen` 的状态 1 会等这个上升沿才开始每行扫描。

### 1.5 关键例化连接

| 端口 | 实际连接 | 注意点 |
|---|---|---|
| `parameter_dacdata_gen.ui_clk` | `eth_clk` (125 MHz) | 端口名有误导性，不是 MIG 的 ui_clk |
| `parameter_dacdata_gen.rstn` | `rstn_r2` | scan_state 上升沿触发复位 |
| `parameter_dacdata_gen.dax_fall_time` | `dax_fall_time_r` (×50 后) | 已转换为拍数 |
| `parameter_dacdata_gen.TRIGGER_IN` | `TRIGGER_IN_Rise` | 上升沿脉冲 |
| `dac_output.eth_clk` | `eth_clk` | FIFO 写时钟 |
| `dac_output.dac_dco` | `dac_dco` (50 MHz) | FIFO 读时钟 + DAC 输出时钟 |

---

## 2. parameter_dacdata_gen.v — 扫描波形核心（最重要）

**文件**：`AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v`

**一句话**：一个 14 态状态机，按照扫描参数逐拍计算 X/Y DAC 值和触发信号，写入 35-bit FIFO。每写一拍 = DAC 输出一个采样点。

### 2.1 输出格式（parameter_dacdata_gen.v:74）

```verilog
para_config_data = {sync_pixel_tri2, sync_pixel_tri1, adc_tri, DAX_DATA[15:0], DAY_DATA[15:0]}
//                  [34]              [33]              [32]     [31:16]          [15:0]
```

### 2.2 DAC 值的定点表示

DAC 内部用 64-bit 定点数 `dax_level` / `day_level` 做累加，只取高 16 位作为实际输出：

```verilog
dax_level <= {dacx_strat_level, 48'd0};   // 初始值：高 16bit 是 DAC 码值，低 48bit 是小数
DAX_DATA  <= dax_level[63:48];             // 只取整数部分
dax_level <= dax_level + dacx_step;        // step 是 64-bit 定点步进
```

**为什么用 64-bit**：DAC 只有 16bit 精度，但每行可能有几百到几万个像素点。如果 X 轴总变化量（如 10000 码值）除以像素数（如 50000），每步不到 1 个 LSB。用 64-bit 定点可以积累微小步进，避免阶梯效应。

### 2.3 三个硬件除法器（parameter_dacdata_gen.v:94-121）

| 除法器 | 被除数 | 除数 | 输出 | 用途 |
|---|---|---|---|---|
| `row_step_div` | `image_row` | `row_m + row_n` | `step` (商), `remain` (余数) | 交错扫描：image_row 行分成多少"步" |
| `row_cycle_div` | `row_m` | `row_n` | `cycle` = 商 + 1 | 交错扫描的循环次数 |
| `dax_step_div` | `{dacx_pp_level, 48'd0}` | `dax_fall_time + 1` | `dax_fall_step` (64-bit) | X 轴下降斜坡的每拍步进 |

**交错扫描含义**：`row_m` 和 `row_n` 实现类似隔行扫描的功能。比如 `row_m=2, row_n=1` 表示"每扫 2 行跳 1 行"，状态 6-9 按这个模式遍历所有行。

### 2.4 状态机全景（14 个状态）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  State 0: 初始化                                                            │
│    dax_level = {dacx_strat_level, 48'd0}                                    │
│    day_level = {dacy_strat_level, 48'd0}                                    │
│    选择 dacx_tb_point (普通 vs ultrafast)                                    │
│         ↓                                                                   │
│  State 1: 等待开始                                                          │
│    if clk_sel=1: 等 TRIGGER_IN 上升沿                                       │
│    if dacx_tb_point=0: → State 3 (无恢复时间)                               │
│    else: → State 2 (有恢复时间)                                             │
│         ↓                                                                   │
│  State 2: Tb（恢复时间/回扫消隐）                                            │
│    输出当前 DAX/DAY，adc_tri=0（不采集）                                     │
│    持续 dacx_tb_point 拍                                                    │
│         ↓                                                                   │
│  State 3: Tk（一个像素点的采集）                                             │
│    adc_tri=1，输出 DAX/DAY                                                  │
│    sync_pixel_tri1/2 在前 N 拍为高                                           │
│    持续 dac_sample 拍（= ADC 平均采样数）                                    │
│         ↓                                                                   │
│  State 4: 像素步进                                                          │
│    dax_level += dacx_step（X 轴前进一步）                                    │
│    if 还有像素: → State 3                                                   │
│    if 本行所有像素完: → State 12                                             │
│         ↓                                                                   │
│  State 12: 下降斜坡判断                                                     │
│    if dax_fall_time=0: → State 5（无下降）                                   │
│    else: dax_level -= dax_fall_step → State 13                              │
│         ↓                                                                   │
│  State 13: 下降斜坡输出                                                     │
│    逐拍输出下降中的 DAX/DAY，adc_tri=0                                       │
│    持续 dax_fall_time 拍                                                    │
│         ↓                                                                   │
│  State 5: 行重复判断                                                        │
│    if row_repeat 未完: dax_level 回起点 → State 1（重扫本行）                │
│    if 行重复完: → State 6 或 State 10                                       │
│         ↓                                                                   │
│  State 6: 交错扫描 - row_n 行步进                                           │
│    day_level += dacy_step（Y 轴前进一行）                                    │
│    dax_level 回起点                                                         │
│    重复 row_n 次 → State 1                                                  │
│         ↓                                                                   │
│  State 7: 交错扫描 - step 大步进                                            │
│    day_level += (row_m * dacy_step) + dacy_step（跳过 row_m 行）             │
│    重复 step 次 → State 1                                                   │
│         ↓                                                                   │
│  State 8: 交错扫描 - cycle 循环                                             │
│    计算 step_count = (cycle_cnt+1) * row_n                                  │
│    重复 cycle 次 → State 9                                                  │
│         ↓                                                                   │
│  State 9: 交错扫描 - 跳转到正确 Y 位置                                      │
│    day_level = start + step_count * dacy_step                               │
│    → State 1                                                                │
│         ↓                                                                   │
│  State 10: 余数行处理                                                       │
│    处理 image_row % (row_m+row_n) 的剩余行                                   │
│    全部完成后 → State 11 或回 State 1                                        │
│         ↓                                                                   │
│  State 11: 帧等待                                                           │
│    输出起始电平，adc_tri=0                                                   │
│    持续 frame_waiting_time 拍                                               │
│    → State 1（开始下一帧）                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 扫描时序图（简化：一行 4 个像素，dac_sample=3）

```
时间轴 →

State:  |  2(Tb)  |  3  |  3  |  3  | 4 |  3  |  3  |  3  | 4 |  3  |  3  |  3  | 4 |  3  |  3  |  3  | 4 | 12/13(fall) | 5 |
        |←──Tb──→|←─pixel 0──→|step|←─pixel 1──→|step|←─pixel 2──→|step|←─pixel 3──→|step|←──fall──→|    |
adc_tri:|  0 0 0  |  1  1  1  | 0  |  1  1  1  | 0  |  1  1  1  | 0  |  1  1  1  | 0  |  0 0 0 0  | 0  |
DAX:    | start   | start     |    | start+step |    | start+2s   |    | start+3s   |    | 下降斜坡  |    |
DAY:    | y_start | y_start   |    | y_start    |    | y_start    |    | y_start    |    | y_start   |    |
sync1:  |  0 0 0  |  1  1  0  | 0  |  1  1  0  | 0  |  1  1  0  | 0  |  1  1  0  | 0  |  0 0 0 0  | 0  |
```

**关键时序关系**：
- `adc_tri` 在整个 `dac_sample` 期间保持为 1（State 3 的全部拍数）
- `sync_pixel_tri1/2` 只在 `dac_sample` 的前 `sync_pixel_tri_wigth` 拍为 1
- State 4 只占 1 拍（步进计算），不写 FIFO（`para_config_wr_en=0`）
- 下降斜坡（State 12/13）期间 `adc_tri=0`，DAC 值逐拍递减

### 2.6 一行扫描的完整参数关系

| 参数 | 含义 | 影响的拍数 |
|---|---|---|
| `dacx_tb_point` | 行首恢复时间（Tb），单位：eth_clk 拍 | State 2 持续拍数 |
| `dacx_tk_point` | 一行有多少个像素点 | State 3→4 循环次数 |
| `dac_sample` | 每个像素点持续多少拍（= ADC 平均采样数） | State 3 持续拍数 |
| `dacx_step` | X 轴每像素步进（64-bit 定点） | State 4 累加值 |
| `dacy_step` | Y 轴每行步进（64-bit 定点） | State 6/7 累加值 |
| `dax_fall_time` | 行尾下降斜坡拍数（×50 后） | State 13 持续拍数 |
| `row_repeat` | 同一行重复扫描次数 | State 5 循环次数 |
| `frame_waiting_time` | 帧间等待拍数 | State 11 持续拍数 |

### 2.7 一行的总拍数公式

```
一行总拍数 = Tb + (dac_sample × dacx_tk_point) + dax_fall_time_r
           = dacx_tb_point + (dac_sample × dacx_tk_point) + (dax_fall_time × 50)
```

一帧总拍数 ≈ 一行总拍数 × row_repeat × image_row + frame_waiting_time

### 2.8 FIFO 反压机制

```verilog
if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
    para_config_wr_en <= 1'b1;
    // ... 正常输出
end
else
    para_config_wr_en <= 1'b0;  // FIFO 满了就暂停，状态机不前进
```

当 `fifo_generator_4` 快满时，状态机**原地等待**不前进。这保证了写入速率不会超过 `dac_dco` 域的读出速率。

---

## 3. dac_output.v — CDC 跨域 + DAC 物理输出

**文件**：`AXI_DDR.srcs/sources_1/new/dac_output.v`

**一句话**：从 FIFO 读出 35-bit 参数流，在 `dac_dco` 域拆包输出 DAX/DAY/adc_tri，并在 `ui_clk` 域生成可配置延迟的 sync 脉冲。

### 3.1 模块内部结构

```
eth_clk 域                          dac_dco 域 (50 MHz)
┌──────────────┐                   ┌──────────────────────────┐
│para_config_  │                   │ 状态机 (IDLE/para_config)│
│  wr_en/data  │──► fifo_gen_4 ──►│ para_config_rd_en        │
│              │    (CDC FIFO)     │       ↓                  │
└──────────────┘                   │ 拆包 dout[34:0]         │
                                   │   → adc_tri             │
                                   │   → DAX_DATA            │
                                   │   → DAY_DATA            │
                                   │   → sync1/2_pixel_tri   │
                                   └──────────────────────────┘
                                              ↓ (sync 信号跨到 ui_clk)
                                   ┌──────────────────────────┐
                                   │ ui_clk 域 (200 MHz)      │
                                   │ sync1 延迟状态机         │
                                   │ sync2 延迟状态机         │
                                   │   → sync_pixel_tri1     │
                                   │   → sync_pixel_tri2     │
                                   └──────────────────────────┘
```

### 3.2 fifo_generator_4（dac_output.v:81-93）

```verilog
fifo_generator_4 fifo_para_config(
    .wr_clk     (eth_clk),          // 写时钟 125 MHz
    .rd_clk     (dac_dco_bufg),     // 读时钟 50 MHz
    .rst        (!(rstn & dac_rstn)),
    .din        (para_config_data), // 35-bit
    .wr_en      (para_config_wr_en),
    .rd_en      (para_config_rd_en),
    .dout       (para_config_dout), // 35-bit
    .prog_full  (para_config_prog_full),   // 反馈给写侧暂停
    .prog_empty (para_config_prog_empty),  // 读侧判断是否有数据
);
```

**CDC 方向**：eth_clk (125 MHz) → dac_dco (50 MHz)。写快读慢，所以 `prog_full` 是主要的流控信号。

### 3.3 dac_dco 域状态机（dac_output.v:95-129）

只有两个状态：

| 状态 | 行为 |
|---|---|
| `IDLE` | 等 `scan_mode_r1 == 4'h1`（参数扫描模式）才进入工作 |
| `para_config` | 只要 FIFO 非空（`prog_empty=0`）就持续读取 |

**极简设计**：这个状态机几乎就是"一直读"，真正的波形逻辑全在 `parameter_dacdata_gen` 里。

### 3.4 FIFO 输出拆包（dac_output.v:136-167）

```verilog
always@(posedge dac_dco_bufg or negedge dac_rstn)
    if(para_config_rd_en_r) begin
        adc_tri  <= (scan_state_r1) ? para_config_dout[32] : 1'b0;
        DAX_DATA <= para_config_dout[31:16];
        DAY_DATA <= para_config_dout[15:0];
        sync1_pixel_tri <= (scan_state_r1 && ultrafast_mode_r1) ? para_config_dout[33] : 1'b0;
        sync2_pixel_tri <= (scan_state_r1 && ultrafast_mode_r1) ? para_config_dout[34] : 1'b0;
    end
    else begin
        adc_tri  <= 1'b0;
        DAX_DATA <= DAX_DATA;  // 保持
        DAY_DATA <= DAY_DATA;  // 保持
    end
```

**关键行为**：
- `adc_tri` 只在 `scan_state=1` 时才输出，停止扫描时强制为 0
- `sync1/2` 额外要求 `ultrafast_mode=1` 才输出（普通模式不产生 sync）
- FIFO 没数据时 DAX/DAY **保持最后值**（不归零），这就是"停止扫描后 DAC 不跳变"的实现

### 3.5 sync 延迟状态机（dac_output.v:187-264）

sync1 和 sync2 各有一个独立的 4 态状态机，运行在 `ui_clk` (200 MHz) 域：

```
IDLE → S0 (无延迟直接输出) 或 S1 (延迟等待) → S2 (延迟后输出) → IDLE
```

| 参数 | 作用 |
|---|---|
| `sync_sig_delay1` | sync1 的延迟拍数（ui_clk 拍，0 = 无延迟） |
| `sync1_pixel_tri_wigth_r` | sync1 脉冲宽度 = `sync1_pixel_tri_wigth << 2`（×4，因为 ui_clk 是 dac_dco 的 4 倍） |

**为什么在 ui_clk 域**：dac_dco 只有 50 MHz（20 ns 分辨率），而 sync 脉冲可能需要更精细的延迟控制。ui_clk = 200 MHz 提供 5 ns 分辨率。

### 3.6 sync_pixel_tri1 的反相输出（dac_output.v:258-264）

```verilog
if(ultrafast_mode_r1)
    sync_pixel_tri1 <= (~sync_pixel_tri1_reg);  // 注意：取反！
else
    sync_pixel_tri1 <= 1'b0;
```

**sync1 是低电平有效**（取反后输出），而 sync2 是直接输出（`assign sync_pixel_tri2 = sync_pixel_tri2_reg`，dac_output.v:346）。这个不对称可能是硬件接口要求。

---

## 4. 顶层连接（ETH_TOP.v）

### 4.1 DAC 输出反相（ETH_TOP.v:641-642）

```verilog
assign dac_p1d = 65535 - DAX_DATA;
assign dac_p2d = 65535 - DAY_DATA;
```

AD9747 的模拟输出和数字输入是反相关系（或者板级电路有反相），所以顶层做码值取反。

### 4.2 adc_tri 的去向（ETH_TOP.v:571, 589）

```verilog
wire adc_tri;  // dacdata_config 输出
// → 送入 adcdata_config U5 的 .adc_tri 端口
```

`adc_tri` 是 DL1 和 DL2 的**唯一交汇点**：DL1 产生触发，DL2 响应触发开始采集。

### 4.3 sync 输出（ETH_TOP.v:572）

```verilog
assign TRIGGER_OUT = sync_pixel_tri2;
```

`sync_pixel_tri2` 直接连到顶层 `TRIGGER_OUT` 端口，作为外部同步信号输出。

---

## 5. DL1 与 DL2 的时序耦合

```
DL1 (parameter_dacdata_gen)          DL2 (adcdata_acq)
─────────────────────────           ─────────────────────
State 3: adc_tri=1                  检测 adc_tri 上升沿
         持续 dac_sample 拍          开始对 ADC 数据求平均
         DAX/DAY 保持不变            累加 dac_sample 个采样值
State 4: adc_tri=0                  平均完成，输出一个像素点
         DAX 步进到下一像素
```

**关键约束**：`dac_sample` 参数同时控制两件事：
1. DL1 中每个像素点 DAC 保持不变的拍数
2. DL2 中 ADC 对每个像素点求平均的采样数

这保证了 DAC 输出稳定期间 ADC 正好完成一次平均采集。

---

## 6. 扫描模式详解

### 6.1 普通逐行扫描（row_m=1, row_n=1, row_repeat=1）

```
行 0: X 从 start 扫到 end，Y = y_start
行 1: X 从 start 扫到 end，Y = y_start + dacy_step
行 2: X 从 start 扫到 end，Y = y_start + 2*dacy_step
...
行 N-1: 最后一行
帧等待 → 回到行 0
```

### 6.2 行重复模式（row_repeat > 1）

每行扫描 `row_repeat` 次后才移到下一行。用于信号平均提高信噪比。

### 6.3 交错扫描模式（row_m > 1 或 row_n > 1）

类似电视隔行扫描。例如 `row_m=2, row_n=1, image_row=6`：
- step = 6/(2+1) = 2, remain = 0, cycle = 2/1 + 1 = 3
- 第一轮 (cycle 0): 扫行 0, 1 (row_n=1 行 + step 跳)
- 第二轮 (cycle 1): 扫行 2, 3
- 第三轮 (cycle 2): 扫行 4, 5

### 6.4 外部触发模式（clk_sel=1）

State 1 等待 `TRIGGER_IN` 上升沿才开始每行扫描。用于和外部设备同步。

### 6.5 超快模式（ultrafast_mode=1）

- `dacx_tb_point` 使用 `ultrafast_line_rec` 参数（而非 `dacx_recovery_time`）
- sync1/2 信号才会输出（普通模式 sync 被屏蔽）
- `line_count` / `line_count_en` 输出行号（给 LAN_TX_FREAME 的超快模式旁路用）

---

## 7. CDC 和风险分析

| CDC 边界 | 写时钟 | 读时钟 | 机制 | 风险 |
|---|---|---|---|---|
| `fifo_generator_4` | eth_clk (125 MHz) | dac_dco (50 MHz) | 异步 FIFO | 低：有 prog_full/prog_empty 流控 |
| `scan_mode` → dac_dco 域 | eth_clk | dac_dco | 两拍同步 | 低：只在 IDLE 时采样，不会中途变化 |
| `scan_state` → dac_dco 域 | eth_clk | dac_dco | 两拍同步 | 低：单 bit |
| `ultrafast_mode` → dac_dco 域 | eth_clk | dac_dco | 两拍同步 | 低：单 bit |
| `rstn` → dac_dco 域 | eth_clk | dac_dco | `sync_module` | 低：专用同步模块 |
| `sync1/2_pixel_tri` → ui_clk 域 | dac_dco | ui_clk | 两拍同步 | 中：50→200 MHz，脉冲宽度可能有 1 拍 jitter |
| 寄存器参数 → eth_clk 域 | eth_clk | eth_clk | 同域 | 无 CDC 问题 |

**主要风险**：
1. `sync_pixel_tri` 从 dac_dco (50 MHz) 跨到 ui_clk (200 MHz) 用两拍同步，可能引入 5-20 ns 的不确定延迟。对于 sync 脉冲的绝对时序精度有影响。
2. `parameter_dacdata_gen` 的 `ui_clk` 端口实际接的是 `eth_clk`，如果有人误以为是 200 MHz 来计算时序会出错。

---

## 8. 关键证据索引

| 证据 | 文件位置 |
|---|---|
| 顶层 DAC 反相输出 | `ETH_TOP.v:641-642` |
| dacdata_config 例化 | `ETH_TOP.v:643-679` |
| TRIGGER_OUT 连接 | `ETH_TOP.v:572` |
| adc_tri 连接到 adcdata_config | `ETH_TOP.v:589` |
| 复位脉冲生成 | `dacdata_config.v:74-91` |
| ×50 乘法 | `dacdata_config.v:69` |
| TRIGGER_IN 同步 | `dacdata_config.v:93-106` |
| parameter_dacdata_gen 接 eth_clk | `dacdata_config.v:113` |
| 35-bit 输出格式 | `parameter_dacdata_gen.v:74` |
| 64-bit 定点 DAC 值 | `parameter_dacdata_gen.v:67-68, 148-149, 169` |
| 三个硬件除法器 | `parameter_dacdata_gen.v:94-121` |
| State 3 (Tk 采集点) | `parameter_dacdata_gen.v:221-247` |
| State 12/13 (下降斜坡) | `parameter_dacdata_gen.v:262-297` |
| State 6-9 (交错扫描) | `parameter_dacdata_gen.v:317-366` |
| FIFO 反压 | `parameter_dacdata_gen.v:202, 223, 279, 389` |
| fifo_generator_4 例化 | `dac_output.v:81-93` |
| dac_dco 域拆包 | `dac_output.v:136-167` |
| sync1 延迟状态机 | `dac_output.v:194-254` |
| sync1 反相输出 | `dac_output.v:258-264` |
| sync2 直接输出 | `dac_output.v:346` |

---

## 9. 读完应能回答的问题

```
1. DL1 的波形不是实时计算的，而是 parameter_dacdata_gen 预计算好写入 FIFO，
   dac_output 在 dac_dco 域逐拍读出。FIFO 解耦了计算速率和输出速率。

2. adc_tri 是 DL1 产生、DL2 消费的唯一交汇信号。它在每个像素点的
   dac_sample 拍期间保持为 1，ADC 在此期间完成平均采集。

3. DAC 值用 64-bit 定点数累加，只取高 16bit 输出，避免小步进的阶梯效应。

4. 交错扫描通过 row_m/row_n 参数和 State 6-9 实现，类似电视隔行扫描。

5. sync_pixel_tri1 是低电平有效（取反输出），sync_pixel_tri2 是高电平有效。
   两者都只在 ultrafast_mode=1 时才输出。

6. 停止扫描时 DAC 保持最后输出值不归零，因为复位只在 scan_state 上升沿触发。
```


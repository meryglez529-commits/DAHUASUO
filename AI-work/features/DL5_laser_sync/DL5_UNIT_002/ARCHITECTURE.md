# DL5 UNIT_002 架构设计（方案 J：写侧 scan_delay + 触发独立 CDC + 保留 Tb/斜坡）

> 配套需求文档：[REQUIREMENTS.md](REQUIREMENTS.md)
> 原则：保留所有现有功能，`laser_mode_en=0` 时行为零变化（普通模式 State 0~13 全部一行不改）。

## 1. 设计原则与关键决策

### 1.1 触发路径与数据路径分离

激光模式有两种"延时"语义，对应两条独立路径：

| 延时 | 起点 | 终点 | 路径 |
|---|---|---|---|
| `scan_delay_time` | laser 上升沿 | DAC 输出更新到新像素坐标 | 写侧 State 15 倒计时 → FIFO → 读侧无脑读 |
| `acq_data_delay_time` | laser 上升沿 | adc_tri 拉高（开始采集） | laser → 独立 CDC → dac_dco 域 acq 状态机 |
| `blanker_delay_time` | laser 上升沿 | sync_pixel_tri1 拉低（blanker 关） | laser → 独立 CDC → ui_clk 域 blanker 状态机 |

**关键**：
- 数据路径（DAX/DAY）走原来的 35-bit FIFO，写侧节奏决定 DAC 输出节奏
- 触发路径（acq、blanker）走独立的 toggle-FF / 握手桥，**不依赖 FIFO 水位**
- 这样保证 acq/blanker 起算时刻精确，与 FIFO 积压完全解耦

### 1.2 scan_delay 在写侧做，不在读侧做

`scan_delay_time` 控制"laser 之后多久 DAC 输出新坐标"，最终延时由两段构成：

```
laser → State 14 检测 → State 15 倒计时(scan_delay_time × 8ns)
      → State 16 写入第一个像素 word
      → FIFO 传输（积压排空时间）
      → 读侧读出 → DAC 输出新坐标
```

写侧倒计时 + FIFO 积压一起决定 DAC 实际更新时刻。如果把 scan_delay 放到读侧 dac_dco 域：
- 步进只能 20ns（dac_dco 周期），无法满足几十 ns 的精度要求
- 需要重写 dac_output.v 的读 FIFO 逻辑（现有逻辑是无脑读），改动范围大
- FIFO 积压问题没消失，只是换了位置

放在写侧的优点：
- 步进 8ns（eth_clk 周期），上位机可配几十 ns 的 scan_delay
- dac_output.v 完全不用改读侧节奏
- FIFO 积压由 1.3 节的分析覆盖，**只影响第一个像素，且第一个像素是行起点坐标，与 Tb 输出坐标相同，无差异**

### 1.3 FIFO 积压不影响功能正确性

写侧速率 125MHz，读侧 50MHz，写/读 = 2.5×。State 16 写完 dac_sample 个 word 时，FIFO 内积压 ≈ 0.6 × dac_sample 个 word。

逐个像素分析积压影响：

| 像素位置 | laser 到来时 FIFO 残留内容 | 残留 word 的 DAX/DAY | 第一个新像素 word 的 DAX/DAY | 是否有差异 |
|---|---|---|---|---|
| 帧首第 1 个像素（x=0,line=0） | Tb word（行起点坐标） | (dacx_strat, dacy_strat) | (dacx_strat, dacy_strat) | **无差异** ✅ |
| 行首像素（x=0, line>0） | Tb word（行起点坐标） | (dacx_strat, day_level) | (dacx_strat, day_level) | **无差异** ✅ |
| 行内像素（x>0） | 上一像素 word | (dax_level_prev, day) | (dax_level_prev + dacx_step, day) | 有差异，**但残留排空 < 像素周期** |
| 行尾后第 1 个像素（下一行 x=0） | 斜坡 word（DAX 渐降） | (dax_level_falling, day) | (dacx_strat, new_day) | 有差异，**但残留排空 < laser 周期** |

**行内像素的关键计算**：
- State 16 写完 dac_sample 个 word，进 State 14 等 laser
- 此时 FIFO 积压 = 0.6 × dac_sample 个 word
- 排空时间 = 0.6 × dac_sample × 20ns = dac_sample × 12ns
- 下一个 laser 周期至少 = scan_delay + dac_sample × 20ns + acq 时间 > dac_sample × 20ns
- **dac_sample × 12ns < dac_sample × 20ns**，所以下一个 laser 到来前 FIFO 必然已经排空 ✅

**行尾斜坡的关键计算**：
- State 13 写 dax_fall_time 个斜坡 word
- 写完进 State 5/6/.../14，期间不写 FIFO
- 斜坡排空时间 = 0.6 × dax_fall_time × 20ns = dax_fall_time × 12ns
- 加上 State 14 等 laser 的时间，足以让 FIFO 排空
- **要求**：laser 周期 > dax_fall_time × 12ns + scan_delay + 处理裕量

### 1.4 保留 State 2/13，激光模式下也照常写

| State | 普通模式行为 | 激光模式行为 | 决策依据 |
|---|---|---|---|
| State 2（Tb） | 写 Tb word，DAX/DAY=行起点 | **照常写** | Tb word 的坐标和第一个像素坐标相同，FIFO 残留对功能无影响 |
| State 11（帧间等待） | 写等待 word，DAX/DAY=帧起点 | **照常写** | 同 State 2，残留无影响 |
| State 13（线尾斜坡） | 写斜坡 word，DAX 渐降 | **照常写** | 排空时间 < laser 周期，residual 在下一 laser 前清空 |

**好处**：写侧状态机分支改动最小，普通模式 State 2/11/13 完全不动。

### 1.5 复用现有 35-bit FIFO，FIFO 位定义不变

35-bit word 仍然是 `{sync2, sync1, adc_tri, DAX[15:0], DAY[15:0]}`。

激光模式下：
- FIFO[32]/[33]/[34] 全部为 0（写侧不再用它们传 trigger 语义）
- 读侧 dac_output.v 拆包逻辑完全不动
- adc_tri / sync_pixel_tri1 输出来自独立的 acq / blanker 状态机，**不再来自 FIFO**

### 1.6 触发独立 CDC：单条 toggle-FF 桥（eth_clk → ui_clk）

laser 在 eth_clk 域被 3 级 FF + 边沿检测后产生 `laser_sync_rise_eth`。acq 和 blanker 状态机**都搬到 ui_clk 域共享同一个边沿源**，所以只需要一条 CDC 桥：

```
eth_clk 域（State 14 内门控）:
  reg laser_toggle;
  always @(posedge eth_clk)
      if (laser_mode_en && laser_sync_rise_eth && current_state == 4'd14)
          laser_toggle <= ~laser_toggle;

ui_clk 域（共享给 acq 和 blanker）:
  (* ASYNC_REG *) reg [2:0] tog_sync_ui;
  always @(posedge ui_clk) tog_sync_ui <= {tog_sync_ui[1:0], laser_toggle};
  wire laser_pulse_ui = tog_sync_ui[2] ^ tog_sync_ui[1];  // 1 拍 ui_clk 脉冲
```

延时：1 个 eth_clk + 2-3 个 ui_clk ≈ 18ns。

**取消 dac_dco 域的 toggle 同步链**：dac_dco 域不再需要直接看 laser 边沿，acq 状态机搬到 ui_clk 域生成 acq_pulse_ui，再由 dac_dco 域 adc_tri 寄存器单 FF 采样（见 1.8）。

### 1.7 现有 sync1 整形器复用，输入切换到 laser_pulse_ui

现有 [dac_output.v:267-327](../../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L267-L327) 的 sync1 状态机检测 `sync1_pixel_tri_r1` 上升沿 → 等 delay → 输出 width。

激光模式下入口 mux：
```
sync1_input_used = laser_mode_en_ui ? laser_pulse_ui : sync1_pixel_tri_r1
delay_used       = laser_mode_en_ui ? blanker_delay_time : sync_sig_delay1
width_used       = laser_mode_en_ui ? blanker_time       : (sync1_pixel_tri_wigth << 2)
```

**不需要新模块**。

### 1.8 acq 状态机新增（ui_clk 域，与 blanker 共享 laser_pulse_ui）

acq 状态机和 blanker 共享 `laser_pulse_ui` 边沿源，搬到 ui_clk 域：

- 输入：`laser_pulse_ui`
- 计数器内部使用 ui_clk 拍数（5ns 单位）
- 上位机配置仍按 20ns 步进（与现有 sync1 一致），ui_clk 域 `<<2`：
  ```
  acq_delay_used = acq_data_delay_time << 2;   // 20ns 步进 → ui_clk 拍数
  acq_time_used  = acq_time            << 2;
  ```
- 输出 `acq_pulse_ui` 持续 `acq_time × 20ns`

**adc_tri 跨域：单 FF 采样（不双 FF）**

`adc_tri` 仍是 dac_dco 域寄存器，激光模式下用它直接采样 `acq_pulse_ui`：
```
adc_tri = laser_mode_en_dac ? (scan_state_r1 ? acq_pulse_ui : 0)   // 单 FF 采样
                            : (scan_state_r1 ? para_config_dout[32] : 0)
```

**为什么不双 FF**：
- `acq_pulse_ui` 宽度 = `acq_time × 20ns`，远大于 1 个 dac_dco 周期（20ns）
- 起止边沿在 dac_dco 域只有 ±1 拍抖动（±20ns），相对采集窗口 us 量级可忽略
- 亚稳态恢复时间 (ns 级) << dac_dco 周期 (20ns)，单级寄存器即可恢复
- 与现有 sync_pixel_tri1 的处理方式一致（ui_clk 直出，未做下游 CDC）

**约束**：`acq_time ≥ 2`（即至少 40ns），保证 dac_dco 至少能采到一拍高电平。`acq_time = 1` 是边界，可能因抖动丢失。

### 1.9 状态机紧耦合，避免 blanker/acq 误闪

laser 检测发生在 **eth_clk 域 State 14** 内：
- 状态机只在 State 14 才接受 laser 上升沿（其他状态忽略）
- 行切换（State 12/13/5~10）/ Tb（State 2）/ scan_delay（State 15）/ 写像素（State 16）期间到达的 laser 被忽略
- blanker / acq 在没有 laser_toggle 翻转时不动作 ✅

### 1.10 步进精度

| 信号 | 上位机配置步进 | 内部时钟域 | 内部展开 | 说明 |
|---|---|---|---|---|
| scan_delay_time | 8ns | eth_clk | 直接 | 满足几十 ns 精度 |
| acq_data_delay_time | 20ns | ui_clk | `<<2` | 与现有 sync 配置兼容 |
| acq_time | 20ns | ui_clk | `<<2` | 同上 |
| blanker_delay_time | 5ns | ui_clk | 直接 | 与现有 sync_sig_delay1 一致 |
| blanker_time | 5ns | ui_clk | 直接 | 与现有 sync1_pixel_tri_wigth 不同（不左移） |

## 2. 整体流程

```
                              ┌─ laser_sync_in (异步)
                              │
                              ▼
                    eth_clk 3 级 FF + 边沿检测 → laser_sync_rise_eth
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
   parameter_dacdata_gen                laser_toggle (eth_clk)
   State 14 检测到 laser              (在 State 14 内门控翻转)
              │                               │
              ▼                               ▼
   State 15: scan_delay 倒计时       3 级 FF 同步到 ui_clk
   (eth_clk × scan_delay_time)              │
              │                               ▼
              ▼                       laser_pulse_ui (1 拍 5ns 脉冲)
   State 16: 写 dac_sample 个                │
   像素 word 到 FIFO              ┌─────────┴─────────┐
              │                    ▼                   ▼
              ▼              acq 状态机          sync1 整形器
        35-bit FIFO         (ui_clk 域)         (ui_clk 域，复用)
        (eth_clk → dac_dco) acq_delay×4 →       blanker_delay →
              │             acq_time×4          blanker_time
              ▼                    │                   │
   读侧无脑读（dac_output.v          ▼                   ▼
   原逻辑不动）                acq_pulse_ui     sync_pixel_tri1_reg
              │                    │                   │
              ▼                    ▼                   ▼
   DAX/DAY                dac_dco 单 FF 采样     取反 + mux
   (跟随 FIFO 输出)              │                   │
                                  ▼                   ▼
                           adc_tri (mux)      sync_pixel_tri1

普通模式状态流: 0 → 1 → 2(Tb,写) → 3(像素,写) → 4 → 3 → ... → 12 → 13(斜坡,写) → 5 → ...
激光模式状态流: 0 → 1 → 2(Tb,写) → 14(等laser) → 15(scan_delay) → 16(写像素) → 4 → 14 → ...
                                                                              └──→ 12 → 13(斜坡,写) → 5 → ...
```

## 3. 模块分解

### 3.1 修改 `parameter_dacdata_gen.v`

**新增端口**：
```verilog
input           laser_mode_en,
input           laser_sync_rise_eth,        // eth_clk 域，已 CDC + 边沿检测的 laser 脉冲
input   [15:0]  scan_delay_time,            // 8ns 步进 (eth_clk 周期)
output reg      laser_toggle,               // 给 dac_output 做触发独立 CDC 的 toggle 信号
```

**新增内部信号**：
```verilog
reg [15:0]  scan_delay_cnt;
// State 16 直接复用现有 dac_sample_cnt（State 3/16 激光模式互斥，进入时清零即可）
```

**FIFO word 拼接 mux**（激光模式 sync 位清零，避免误触发普通模式 adc_tri 路径）：
```verilog
wire fifo_bit32 = laser_mode_en ? 1'b0 : adc_tri;
wire fifo_bit33 = laser_mode_en ? 1'b0 : sync_pixel_tri1;
wire fifo_bit34 = laser_mode_en ? 1'b0 : sync_pixel_tri2;
assign para_config_data = {fifo_bit34, fifo_bit33, fifo_bit32, DAX_DATA, DAY_DATA};
```

**laser_toggle 生成**（State 14 内门控，行切换/Tb 期间到达的 laser 被丢弃）：
```verilog
always @(posedge ui_clk or negedge rstn) begin
    if (!rstn) laser_toggle <= 1'b0;
    else if (laser_mode_en && laser_sync_rise_eth && current_state == 4'd14)
        laser_toggle <= ~laser_toggle;
end
```

**State 2 末尾改动**（普通模式不变，Tb 照常写）：
```verilog
else begin
    dacx_tb_point_cnt <= 0;
    if (laser_mode_en) current_state <= 14;
    else               current_state <= 3;
end
```

**State 4 末尾改动**（普通模式不变；行尾分支保留 → 12）：
```verilog
if (dacx_tk_point_cnt < dacx_tk_point - 1) begin
    dacx_tk_point_cnt <= dacx_tk_point_cnt + 1'b1;
    dax_level         <= dax_level + dacx_step;
    day_level         <= day_level;
    if (laser_mode_en) current_state <= 14;
    else               current_state <= 3;
end
else begin
    dacx_tk_point_cnt <= 16'd0;
    current_state     <= 12;
end
```

**新增 State 14：等 laser，不写 FIFO**
```verilog
14: begin
    para_config_wr_en <= 1'b0;
    if (laser_sync_rise_eth) begin
        scan_delay_cnt <= 0;
        current_state  <= 15;
    end
end
```

**新增 State 15：scan_delay 倒计时，不写 FIFO**
```verilog
15: begin
    para_config_wr_en <= 1'b0;
    if (scan_delay_time == 0) begin
        current_state <= 16;
    end
    else if (scan_delay_cnt < scan_delay_time - 1) begin
        scan_delay_cnt <= scan_delay_cnt + 1'b1;
    end
    else begin
        scan_delay_cnt <= 0;
        current_state  <= 16;
    end
end
```

**新增 State 16：写 dac_sample 个像素 word**（复用 dac_sample_cnt，State 3/16 互斥）
```verilog
16: begin
    if (para_config_prog_full == 0 && para_config_wr_rst_busy == 0) begin
        para_config_wr_en <= 1'b1;
        adc_tri           <= 1'b0;          // 激光模式下 FIFO[32] 不再承载 trigger
        sync_pixel_tri1   <= 1'b0;
        sync_pixel_tri2   <= 1'b0;
        DAX_DATA          <= dax_level[63:48];
        DAY_DATA          <= day_level[63:48];
        if (dac_sample_cnt < dac_sample - 1)
            dac_sample_cnt <= dac_sample_cnt + 1'b1;
        else begin
            dac_sample_cnt <= 0;
            current_state  <= 4;
        end
    end
    else
        para_config_wr_en <= 1'b0;
end
```

**State 3、State 5~13、State 11 完全不动。**

### 3.2 修改 `dac_output.v`

**新增端口**：
```verilog
input           laser_mode_en,           // eth_clk 域，进来同步到 dac_dco 和 ui_clk
input           laser_toggle,            // eth_clk 域 toggle，由 parameter_dacdata_gen 输出
input   [15:0]  blanker_delay_time,      // ui_clk 拍数（5ns 步进）
input   [15:0]  blanker_time,            // ui_clk 拍数（5ns 步进）
input   [15:0]  acq_data_delay_time,     // 上位机配 dac_dco 拍数（20ns 步进），内部 <<2 转 ui_clk 拍
input   [15:0]  acq_time,                // 同上
```

**新增同步链**：
- `laser_mode_en` 同步到 dac_dco 域 → `laser_mode_en_dac`（双 FF + ASYNC_REG）
- `laser_mode_en` 同步到 ui_clk 域 → `laser_mode_en_ui`（双 FF + ASYNC_REG）
- `laser_toggle` 同步到 ui_clk 域 → 边沿检测得 `laser_pulse_ui`（3 级 FF + 异或）
- `acq_data_delay_time` / `acq_time` 同步到 ui_clk 域（双 FF）
- `blanker_delay_time` / `blanker_time` 同步到 ui_clk 域（双 FF）

**取消 dac_dco 域的 toggle 同步链**：acq 状态机搬到 ui_clk 域，dac_dco 域 adc_tri 寄存器直接单 FF 采样 `acq_pulse_ui`。

**改动 1：laser_pulse_ui 生成**
```verilog
(* ASYNC_REG = "TRUE" *) reg laser_tog_u0, laser_tog_u1, laser_tog_u2;
always @(posedge ui_clk or negedge ui_rstn) begin
    if (!ui_rstn) {laser_tog_u0, laser_tog_u1, laser_tog_u2} <= 3'b0;
    else          {laser_tog_u2, laser_tog_u1, laser_tog_u0} <= {laser_tog_u1, laser_tog_u0, laser_toggle};
end
wire laser_pulse_ui = laser_mode_en_ui && (laser_tog_u2 ^ laser_tog_u1);
```

**改动 2：新增 acq 状态机（ui_clk 域，与 sync1 整形器并列）**

acq 状态机和 blanker（sync1 整形器）共享 `laser_pulse_ui` 边沿源。计数器内部使用 ui_clk 拍数（5ns），上位机配置按 20ns 步进，入口 `<<2` 展开：

```verilog
reg [31:0] acq_delay_used;
reg [31:0] acq_time_used;
always @(posedge ui_clk) begin
    acq_delay_used <= {14'd0, acq_data_delay_time} << 2;   // 20ns 步进 → ui_clk 拍数
    acq_time_used  <= {14'd0, acq_time}            << 2;
end

reg [31:0] acq_delay_cnt;
reg [31:0] acq_time_cnt;
reg [1:0]  acq_state;
reg        acq_pulse_ui;
parameter ACQ_IDLE = 2'd0, ACQ_DELAY = 2'd1, ACQ_HIGH = 2'd2;

always @(posedge ui_clk or negedge ui_rstn) begin
    if (!ui_rstn) begin
        // ui_rstn 来自 dacdata_config 在 scan_state 上升沿产生的 6 拍复位脉冲
        // 上位机切换 laser_mode_en 的标准流程：停扫描 → 改 laser_mode_en → 开扫描，
        // 开扫描时 rstn_r2 自动清零所有状态机，无需 laser_mode_en 单独门控复位
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
```

**改动 3：adc_tri 输出 mux（dac_dco 域单 FF 采样 acq_pulse_ui）**

现有 [dac_output.v:208](../../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L208)：
```verilog
adc_tri <= (scan_state_r1) ? para_config_dout[32] : 1'b0;
```
新：
```verilog
adc_tri <= laser_mode_en_dac ? (scan_state_r1 ? acq_pulse_ui : 1'b0)
                             : (scan_state_r1 ? para_config_dout[32] : 1'b0);
```

**单 FF 采样合理性**：
- `acq_pulse_ui` 持续 `acq_time × 20ns`（实际 acq_time ≥ 2 即 ≥ 40ns，远大于 dac_dco 周期 20ns）
- 起止边沿在 dac_dco 域只有 ±20ns 抖动，对 ADC 采集窗口无影响
- 与现有 sync_pixel_tri1（ui_clk 直出，未做下游 CDC）处理方式一致
- **使用约束**：`acq_time ≥ 2`（即上位机配置值 ≥ 2，对应 ≥ 40ns）

**改动 4：sync1 整形器入口 mux（ui_clk 域，与 acq 共用 laser_pulse_ui）**

现有 sync1 状态机的输入信号是 `sync1_pixel_tri_r1`，参数是 `sync_sig_delay1` / `sync1_pixel_tri_wigth_r`。激光模式下切换：
```verilog
wire        sync1_trig_used  = laser_mode_en_ui ? laser_pulse_ui : sync1_pixel_tri_r1;
wire [15:0] sync1_delay_used = laser_mode_en_ui ? blanker_delay_time : sync_sig_delay1;
wire [31:0] sync1_width_used = laser_mode_en_ui ? {16'd0, blanker_time}
                                                : ({14'd0, sync1_pixel_tri_wigth} << 2);
```
状态机 IDLE1 入口的 `if (sync1_pixel_tri_r1)` 改为 `if (sync1_trig_used)`，比较常量改为 `sync1_delay_used` 和 `sync1_width_used`。

**复位策略与现有 ultrafast_mode 一致**：sync1 整形器只用 `ui_rstn` 作为复位源，不为 `laser_mode_en` 单独加门控。上位机切模式遵循"停扫描→改模式→开扫描"流程，scan_state 上升沿产生的 `rstn_r2` 6 拍脉冲自动清状态机。

**改动 5：sync_pixel_tri1 输出门控扩展**

现有 [dac_output.v:331-337](../../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L331-L337) 受 `ultrafast_mode_r1` 门控。激光模式下也要输出：
```verilog
sync_pixel_tri1 <= ((ultrafast_mode_r1 || laser_mode_en_ui) ? ~sync_pixel_tri1_reg : 1'b0);
```

激光模式下 sync_pixel_tri2 不输出（保持现有 ultrafast_mode_r1 门控即可）。

### 3.3 修改 `dacdata_config.v`

**新增端口**：
```verilog
input           laser_mode_en,
input   [15:0]  scan_delay_time,
input   [15:0]  blanker_delay_time,
input   [15:0]  blanker_time,
input   [15:0]  acq_data_delay_time,
input   [15:0]  acq_time,
input           laser_sync_in,           // 异步外部信号
```

**新增 CDC 逻辑**（laser_sync_in 在 eth_clk 域做 3 级 FF + 上升沿检测）：
```verilog
(* ASYNC_REG = "TRUE" *) reg laser_sync_r0, laser_sync_r1, laser_sync_r2;
always @(posedge eth_clk or negedge eth_rstn) begin
    if (!eth_rstn) {laser_sync_r0, laser_sync_r1, laser_sync_r2} <= 3'b0;
    else           {laser_sync_r2, laser_sync_r1, laser_sync_r0} <= {laser_sync_r1, laser_sync_r0, laser_sync_in};
end
wire laser_sync_rise_eth = laser_sync_r1 && ~laser_sync_r2;
```

**接线**：
- parameter_dacdata_gen 收：`laser_mode_en` / `laser_sync_rise_eth` / `scan_delay_time`，输出：`laser_toggle`
- dac_output 收：`laser_mode_en` / `laser_toggle` / `blanker_delay_time` / `blanker_time` / `acq_data_delay_time` / `acq_time`

`laser_mode_en` / `blanker_*` / `acq_*` 都是 eth_clk 域的静态寄存器，在 dac_output 内部各自做双 FF 同步到 ui_clk / dac_dco。

### 3.4 修改 `command_monitor_new.v`

新增 6 个寄存器（地址 0x0205~0x020A）：

| 地址 | 寄存器 | 位宽 | 步进 |
|---|---|---|---|
| 0x0205 | laser_mode_en | [0] | — |
| 0x0206 | scan_delay_time | [15:0] | **8ns**（eth_clk 周期）|
| 0x0207 | blanker_delay_time | [15:0] | 5ns |
| 0x0208 | blanker_time | [15:0] | 5ns |
| 0x0209 | acq_data_delay_time | [15:0] | 20ns |
| 0x020A | acq_time | [15:0] | 20ns |

写入 case 加 6 条；读回 case 也加 6 条。

### 3.5 修改 `ETH_TOP.v`

**新增 1 个顶层端口**：
```verilog
input   laser_sync_in,          // 2.5V TTL 异步外部输入
```

**新增 6 个 wire** 把 command_monitor_new 输出连到 dacdata_config。

XDC 引脚约束：等硬件给引脚号，本期不动 XDC。

## 4. CDC 边界总览

| 边界 | 信号 | 同步方式 | 风险评估 |
|---|---|---|---|
| async → eth_clk | laser_sync_in | 3 级 FF + 上升沿检测 | 安全 |
| eth_clk → dac_dco (静态) | laser_mode_en | 双 FF + ASYNC_REG | 安全 |
| eth_clk → ui_clk (静态) | laser_mode_en, blanker_*, acq_data_delay_time, acq_time | 双 FF + ASYNC_REG | 安全 |
| eth_clk → ui_clk (事件) | laser_toggle | 3 级 FF + 异或 (toggle-FF 桥) | 安全 |
| ui_clk → dac_dco (电平) | acq_pulse_ui | 单 FF 采样（脉宽 ≥ 40ns >> 20ns dac_dco 周期） | 安全（约束 acq_time ≥ 2）|
| eth_clk → dac_dco (像素流) | 35-bit FIFO din | 现有异步 FIFO | 安全 |

**新增 1 个 toggle-FF 桥（laser_toggle，eth_clk → ui_clk），acq/blanker 共享同一个边沿源；adc_tri 单 FF 采样 acq_pulse_ui，0 个新模块。**

## 5. FIFO 积压时序分析

### 5.1 关键参数

- 写时钟 eth_clk = 125MHz（8ns 周期）
- 读时钟 dac_dco = 50MHz（20ns 周期）
- 写/读速率比 = 2.5×
- 每个 word 写入耗时 8ns，读出耗时 20ns

### 5.2 各场景积压量与排空时间

| 场景 | 积压来源 | 积压量（word） | 排空时间 | laser 周期下界 |
|---|---|---|---|---|
| 帧首第 1 个 laser | State 2 写 Tb_words | 0.6 × Tb_words | Tb_words × 12ns | 不影响（坐标相同）|
| 行内像素之间 | State 16 写 dac_sample 个 | 0.6 × dac_sample | dac_sample × 12ns | dac_sample × 20ns + scan_delay |
| 行首像素（非帧首） | State 2 写 Tb_words | 0.6 × Tb_words | Tb_words × 12ns | 不影响（坐标相同）|
| 行末后第 1 个像素 | State 13 写 dax_fall_time 个 | 0.6 × dax_fall_time | dax_fall_time × 12ns | dax_fall_time × 12ns + scan_delay + 裕量 |
| 帧末后第 1 个像素 | State 11 写 frame_waiting_time 个 | 0.6 × frame_waiting_time | frame_waiting_time × 12ns | 不影响（坐标相同）|

### 5.3 行末斜坡的约束公式

最严苛约束来自行末斜坡，下一行第 1 个 laser 到来前必须排空 + scan_delay 倒计时完成：

```
laser 周期 ≥ dax_fall_time × 12ns + scan_delay × 8ns + DAC settling 裕量
```

举例：
- dax_fall_time = 50（1us 斜坡），scan_delay = 10（80ns），裕量 = 100ns
- 要求 laser 周期 ≥ 50 × 12ns + 80ns + 100ns = 780ns
- 对应 laser 频率 ≤ 1.28MHz

实际 laser 频率几百 kHz 到 1MHz，**满足约束**。

### 5.4 不影响功能正确性的边界

帧首 / 行首 / 帧末 这三种情况，FIFO 残留 word 的 DAX/DAY **与第一个像素的 DAX/DAY 相同**（都是行起点 / 帧起点坐标），所以即使读侧消化残留时 laser 已到，DAC 输出依然正确。

行内像素之间，由于 dac_sample × 12ns < dac_sample × 20ns（一个像素的 dwell 时间），下一个 laser 到来前必然排空。

唯一需要约束 laser 周期的场景是**行末斜坡 → 下一行第 1 个像素**，约束公式见 5.3。

## 6. 验证策略

1. **回归（laser_mode_en=0）**：跑一帧扫描，DAX/DAY/adc_tri/sync_pixel_tri1/sync_pixel_tri2 与基线**逐拍一致**（普通模式状态机 0~13 一行不改）。

2. **激光模式正常流程**：按合理周期注入 laser 脉冲，验证：
   - State 14 等到 laser 才进 State 15
   - State 15 倒数 scan_delay × 8ns 后进 State 16
   - State 16 写 dac_sample 个像素 word（DAX/DAY = 当前像素坐标）后进 State 4
   - State 4 末尾激光模式回 State 14，普通模式回 State 3
   - laser_toggle 在每个 laser 上升沿翻转
   - acq_pulse_dac 在 laser 后 acq_data_delay 拍开始，持续 acq_time 拍
   - sync_pixel_tri1_reg 在 laser 后 blanker_delay 拍开始，持续 blanker_time 拍
   - adc_tri 引脚在激光模式下 = scan_state && acq_pulse_dac
   - sync_pixel_tri1 引脚在激光模式下 = ~sync_pixel_tri1_reg

3. **FIFO 积压不影响功能**：
   - 帧首：Tb word 写完后注入 laser，验证 DAC 输出 = 行起点坐标（与 Tb 输出相同）
   - 行内：dac_sample 写完后注入 laser，验证下一像素 DAC 输出 = 新坐标，无残留 Tb word 影响
   - 行末：State 13 斜坡写完后注入 laser，验证下一行第 1 个像素 DAC 输出 = 行起点坐标（要求 laser 周期 > 排空时间）

4. **触发独立 CDC**：
   - acq_pulse_dac 起算时刻不受 FIFO 水位影响（人为造成 FIFO 积压再触发 laser，验证 acq 时刻仍准确）
   - sync_pixel_tri1_reg 同上

5. **状态机紧耦合（无误闪）**：
   - 行切换期间（State 12/13/5~10）注入 laser：blanker / acq 是否触发？
   - 设计上 toggle-FF 不受状态机门控，**会触发** —— 这与方案 H/I 的语义不同
   - 如果需求是"行切换期间忽略 laser"，需要在 acq/blanker 状态机入口加 scan_state 门控
   - **建议**：保留触发，acq/blanker 自身倒计时受门控（比如 acq_pulse_dac & scan_state_r1）

6. **关键边界**：
   - **scan_delay_time = 0**：State 15 立即跳转到 State 16
   - **acq_data_delay_time = 0**：acq 状态机直接进 ACQ_HIGH
   - **blanker_delay_time = 0**：sync1 状态机直接进 S0（已有逻辑）
   - **第 1 个 laser 在 Tb 期间到达**：State 14 还没进入，laser 被忽略；但 toggle-FF 仍翻转 → acq/blanker 会触发一次"鬼影"
   - **解决方案**：toggle-FF 的源端加 `laser_mode_en && current_state == 14` 门控（见 3.1 修订）

7. **laser 周期约束**：
   - 配置 dax_fall_time / scan_delay 后，验证 laser 最高频率 ≤ 1 / (dax_fall_time × 12ns + scan_delay × 8ns + 100ns)
   - 仿真极限频率，FIFO prog_full 持续拉高视为反压正确

8. **综合**：
   - WNS ≥ 0
   - laser_sync_in 加 set_max_delay 约束
   - 各双 FF 路径加 ASYNC_REG 属性
   - laser_toggle 跨域路径加 set_max_delay
   - 资源占用增加 < 3%

9. **上板**：等硬件给引脚号后约束 XDC，由用户执行。

## 7. 与方案演进的对比

| 维度 | 方案 H | 方案 I | **方案 J** |
|---|---|---|---|
| trigger 路径 | FIFO[32]/[33] 占位写 | FIFO[32]/[33] 空 FIFO | **独立 toggle-FF 桥（eth_clk → ui_clk 单条）** |
| trigger 延时 | FIFO 深度 × 20ns（~10us） | 1-2 拍（理论值，实际 FIFO 不空时失效） | **18ns（eth_clk → ui_clk）确定** |
| acq/blanker 边沿源 | 各自 FIFO 位 | 各自 FIFO 位 | **共享 laser_pulse_ui** |
| State 2 | 激光模式不写 | 激光模式不写 | **照常写**（坐标=行起点，无影响） |
| State 13 | 激光模式不写 | 激光模式不写 | **照常写**（laser 周期足够即可） |
| State 11 | 激光模式不写 | 激光模式不写 | **照常写**（坐标=帧起点，无影响） |
| FIFO 积压风险 | 无（不写） | 高（Tb 残留导致 trigger 滞后） | **可量化**（行末斜坡约束 laser 周期） |
| scan_delay 位置 | 读侧 dac_dco 域 | 写侧 eth_clk 域 | **写侧 eth_clk 域**（8ns 步进） |
| acq 状态机域 | dac_dco | dac_dco | **ui_clk**（5ns 内部步进，与 sync1 整形器并列）|
| adc_tri 跨域 | 无 | 无 | **单 FF 采样 acq_pulse_ui** |
| 读侧 FIFO 节奏 | 改 | 改 | **不改**（dac_output.v 读 FIFO 状态机一行不动）|
| 写侧 State 改动 | State 14/15 + 占位写 | State 14/15/16 + 跳过 State 3 | **State 14/15/16 + Tb/斜坡保留** |
| 普通模式回归 | State 0~13 不动 | State 0~13 不动 | **State 0~13 完全不动** |
| 新增模块 | 0 | 0 | **0** |
| 新增 toggle-FF 桥 | 0 | 0 | **1（eth_clk → ui_clk）** |
| CDC 边界 | 3 | 3 | **5** |

**方案 J 的核心优势**：
1. acq/blanker 共享单条 toggle-FF 桥，CDC 路径最少
2. 写侧状态机改动最小，普通模式逐拍兼容
3. FIFO 积压量可量化，约束清晰（仅行末斜坡受 laser 周期约束）
4. 触发路径独立、延时确定（18ns）

## 8. 实施顺序

1. 改 `command_monitor_new.v`（加 6 个寄存器）
2. 改 `parameter_dacdata_gen.v`（State 2/4 分支 + 新增 14/15/16 + laser_toggle 在 State 14 内门控生成 + FIFO 拼接 mux）
3. 改 `dac_output.v`（加 laser_mode_en/laser_toggle 同步链 + ui_clk 域 acq 状态机（用 ui_rstn 复位）+ adc_tri 单 FF 采样 mux + sync1 入口 mux + 输出门控扩展）
4. 改 `dacdata_config.v`（laser_sync_in CDC + 端口透传 + 例化接线）
5. 改 `ETH_TOP.v`（顶层端口 + wire 连接）
6. 集成仿真：
   - 普通模式逐拍回归
   - 激光模式正常流程（acq/blanker/scan_delay 时序，注意 acq 走 ui_clk 5ns 内部精度）
   - FIFO 积压不影响功能（帧首/行内/行末三种边界）
   - State 14 门控验证（行切换期间 laser 不让 toggle 翻转 → acq/blanker 不触发）
   - 模式切换流程：停扫描 → 改 laser_mode_en → 开扫描，rstn_r2 自动清状态机
   - laser 周期上限验证
7. 综合验证（WNS、ASYNC_REG、set_max_delay、资源占用）

## 9. 状态

- 架构设计日期：2026-05-29
- 方案演进：A（ui_clk 检测）→ D（eth_clk 检测 + ui_clk 倒计时）→ E（按原生时钟域 + toggle-FF）→ F（复用 FIFO，但触发时机错）→ H（FIFO 复用 + State 14 触发 + 占位写）→ I（State 14/15/16 + 空 FIFO 策略）→ **J（写侧 scan_delay + 触发独立 CDC + 保留 Tb/斜坡 + acq/blanker 共享 ui_clk 边沿）**
- 关键改进：
  - 触发路径与数据路径分离：acq/blanker 共享单条 toggle-FF 桥（eth_clk → ui_clk），不受 FIFO 水位影响
  - acq 状态机搬到 ui_clk 域，与 sync1 整形器并列，共享 laser_pulse_ui，CDC 路径最少
  - adc_tri 在 dac_dco 域单 FF 采样 acq_pulse_ui（脉宽远大于 dac_dco 周期，工程上安全）
  - acq_data_delay_time / acq_time 上位机仍按 20ns 步进，ui_clk 域内部 `<<2` 展开
  - scan_delay 在写侧 eth_clk 域做（8ns 步进，满足几十 ns 精度需求）
  - State 2/11/13 在激光模式下照常写：FIFO 残留 word 的 DAX/DAY 与第一个像素坐标相同（行起点/帧起点），或排空时间 < laser 周期
  - 激光模式下 FIFO[32]/[33]/[34] 全部清零，adc_tri / sync_pixel_tri1 输出来自独立状态机
  - State 14 门控 toggle 源端，避免行切换/Tb 期间 acq/blanker 误闪
  - 复用现有 rstn_r2 复位机制（与 ultrafast_mode 的设计风格一致）：上位机切模式遵循"停扫描→改模式→开扫描"流程，scan_state 上升沿自动复位所有状态机，无需为 laser_mode_en 单独加门控
  - 唯一约束：laser 周期 > dax_fall_time × 12ns + scan_delay × 8ns + 100ns 裕量（实际 laser 周期远大于此）

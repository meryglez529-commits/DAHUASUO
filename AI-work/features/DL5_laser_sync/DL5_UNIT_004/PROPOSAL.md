# DL5_UNIT_004 实施方案：激光模式 ADC 采集点数独立控制

> **文档状态**：待审批  
> **创建日期**：2026-06-04  
> **前置依赖**：[DL5_UNIT_003](../DL5_UNIT_003/IMPLEMENTATION.md)（FIFO 水位优化，已上板验证通过）

---

## 0. 执行摘要

**问题**：当前代码中 `dac_output.v` 的 acq 状态机已用 `acq_time` 控制 `acq_pulse_ui` 脉宽，但 `adcdata_acq.v` 的 ADC 采集点数仍由 `adc_sample` 控制，两者解耦导致激光模式下 ADC 采集行为不符合预期。

**方案**：在 `adcdata_acq.v` 内增加激光模式分支，让 ADC 采集点数由 `acq_time` 控制，与普通模式（`adc_sample`）和超快模式（`adc_sample - 延时 - 死区`）独立。

**决策依据**：采纳**方案 1**（只改 `adcdata_acq.v`），不选方案 2（acq 状态机搬到 adc_dco 域），原因见 §2。

**验收标准**：
- ✅ 激光模式下 ADC 采集 `acq_time` 个点（不是 `adc_sample` 个）
- ✅ 普通模式 / 超快模式零影响（回归仿真必须 PASS）
- ✅ UNIT_003 的 DAC 侧成果（State 14/15/16、C3-lite）不回退
- ✅ 仿真验证通过，时序收敛

---

## 1. 问题现状分析

### 1.1 当前代码行为（UNIT_003 后）

**DAC 侧（已完成，保持不变）**：
```
laser 脉冲 → parameter_dacdata_gen State 14/15/16
         ↓
    dac_sample 个 FIFO word（DAC 坐标驻点）
         ↓
    dac_output 读出 → DAC 物理输出
```

**ADC 触发侧（已完成，保持不变）**：
```
laser 脉冲 → dac_output acq 状态机（ui_clk 域）
         ↓
    acq_delay_time × 20ns 延迟
         ↓
    acq_pulse_ui 保持 acq_time × 20ns 脉宽
         ↓ CDC 到 dac_dco 域（单 FF 采样）
    adc_tri 信号 → 广播给 4 路 adcdata_acq
```

**ADC 采集侧（❌ 问题所在）**：
```
adcdata_acq.v 收到 adc_tri 上升沿
         ↓
    等待 adc_interval 拍（普通模式）或 adc_acq_delay 拍（超快模式）
         ↓
    采集 adc_sample 个点 ❌ ← 应该是 acq_time 个点
         ↓
    累加 → 除法求平均 → 输出
```

### 1.2 问题根因

`adcdata_acq.v` 模块端口定义（Line 27-48）：
```verilog
module adcdata_acq(
    input               adc_tri,
    input       [31:0]  adc_sample,    // ← 仍然用这个
    input       [23:0]  adc_interval,
    input               ultrafast_mode,
    // ...
    // ❌ 缺少：laser_mode_en、acq_time 输入
);
```

采集点数计算（Line 103-107）：
```verilog
assign adc_valid_point = ultrafast_mode_r2 
    ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
    : image_column_r2 * adc_sample_r2;
// ❌ 没有 laser_mode_en 分支
```

### 1.3 问题场景示例

假设用户配置激光模式：
- `adc_sample` (0x0004) = 30（普通模式 DAC 保持拍数，上位机可能保留默认值）
- `acq_time` (0x020A) = 5（激光模式期望 ADC 采 5 个点，100ns 窗口）

**当前实际发生的事情**：
```
laser 脉冲 → acq_pulse_ui 持续 100ns（5 × 20ns）
         ↓ CDC 到 adc_dco 域
    adc_tri 触发 adcdata_acq
         ↓
    adcdata_acq 尝试采集 30 个点（用的是 adc_sample_r2）
         ↓
    ❌ 窗口只有 100ns，但要采 30 个点 × 20ns = 600ns
    ❌ 可能导致：后 25 个点采到无效数据，或状态机卡死
```

---

## 2. 方案对比与决策

### 2.1 方案 1：只改 adcdata_acq.v（✅ 采纳）

**核心思路**：
```verilog
// adcdata_acq.v 新增输入端口
input           laser_mode_en,
input   [31:0]  acq_time,

// 采集点数 mux
wire [31:0] adc_sample_src = laser_mode_en ? acq_time : adc_sample;

// 后续 CDC 和状态机统一使用 adc_sample_src
always @(posedge adc_dco) begin
    adc_sample_r0 <= adc_sample_src;  // 原来是 adc_sample
    // ...
end

// adc_valid_point 计算增加激光模式分支
assign adc_valid_point = laser_mode_en_r2 ? adc_sample_r2  // 激光模式：单像素
                       : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                       : image_column_r2 * adc_sample_r2;

// adc_interval 计算增加激光模式分支
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(laser_mode_en_r2)
        adc_interval_reg <= 32'd0;     // 激光模式无延迟，立刻采集
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;
    else
        adc_interval_reg <= adc_interval_r2;
```

**优点**：
1. ✅ 改动最小（只改 1 个文件 + 上层接线）
2. ✅ `adc_tri` 仍由 `dac_output.v` 统一产生，广播给 4 路 ADC，时序一致性好
3. ✅ 不影响普通模式 / 超快模式逻辑
4. ✅ 激光模式下 `adc_interval_reg = 0`，触发后立刻采集（符合预期）

**缺点**：
- 4 路 ADC 各自做 3 级 FF 同步，`laser_mode_en`/`acq_time` 参数会被打拍 4 次

### 2.2 方案 2：acq 状态机搬到 adc_dco 域（❌ 不采纳）

**核心思路**：把 `dac_output.v` 的 acq 状态机（ui_clk 域）搬到 `adcdata_acq.v` 内部（adc_dco 域），每路 ADC 独立运行。

**致命缺陷**：
1. ❌ **4 路 ADC 的 adc_dco 是独立时钟源**（各自的 ADC 芯片 DCO 输出）
2. ❌ 每路独立跑 `acq_delay_time` 计数会产生 **≤20ns 相位抖动**（dco 周期）
3. ❌ 4 路 ADC 采集窗口不对齐 → 多通道数据时序错乱

**方案 1 为什么没有这个问题**：
- `adc_tri` 由 `dac_output.v` 在 `ui_clk` 域统一产生
- 4 路 ADC 各自用 3 级 FF 同步 `adc_tri`，虽然有 CDC 延迟，但延迟是确定性的（3 拍 adc_dco）
- 相位差 ≤ 1 个 adc_dco 周期（20ns），且各路一致

**结论**：不采纳方案 2。

---

## 3. 方案 1 详细设计

### 3.1 改动文件清单

| 文件 | 改动内容 | 影响 |
|---|---|---|
| `adcdata_acq.v` | 新增 `laser_mode_en`/`acq_time` 输入，增加激光模式分支 | 核心改动 |
| `adcdata_config.v` | 透传 `laser_mode_en`/`acq_time` 到 4 路 `adcdata_acq` | 接线 |
| `ETH_TOP.v` | 顶层接线 `laser_mode_en`/`acq_time` | 接线 |
| `dac_output.v` | **不改动**（保持 UNIT_003 状态） | 零影响 |
| `parameter_dacdata_gen.v` | **不改动**（保持 UNIT_003 State 14/15/16）| 零影响 |

### 3.2 adcdata_acq.v 详细改动

#### 3.2.1 模块端口增加（Line 27 附近）

```verilog
module adcdata_acq(
    // 现有端口保持不变
    input               ui_clk,
    input               rstn,
    // ...
    input               ultrafast_mode,
    
    // 新增：DL5 激光模式控制（紧跟 ultrafast_mode）
    input               laser_mode_en,      // 1=激光模式，0=普通模式
    input       [31:0]  acq_time,           // 激光模式 ADC 采集点数（20ns 步进单位）
    
    // ADC 真实数据输入
    input               adc_dco,
    input       [15:0]  adc_data,
    // ...
);
```

#### 3.2.2 CDC 同步增加（Line 53 附近）

```verilog
// 现有 CDC 寄存器
reg         adc_tri_r0      = 0;
// ... 其他参数 ...
reg         ultrafast_mode_r0= 0;
reg         ultrafast_mode_r1= 0;
reg         ultrafast_mode_r2= 0;

// 新增：激光模式参数 CDC
reg         laser_mode_en_r0 = 0;
reg         laser_mode_en_r1 = 0;
reg         laser_mode_en_r2 = 0;
reg [31:0]  acq_time_r0      = 50;  // 默认值与 adc_sample 一致
reg [31:0]  acq_time_r1      = 50;
reg [31:0]  acq_time_r2      = 50;

// 同步逻辑
always @(posedge adc_dco) begin
    // 现有参数同步
    adc_tri_r0      <= adc_tri;
    // ...
    
    // 新增：激光模式参数同步
    laser_mode_en_r0 <= laser_mode_en;
    laser_mode_en_r1 <= laser_mode_en_r0;
    laser_mode_en_r2 <= laser_mode_en_r1;
    acq_time_r0      <= acq_time;
    acq_time_r1      <= acq_time_r0;
    acq_time_r2      <= acq_time_r1;
end
```

#### 3.2.3 adc_sample 源 mux（Line 86 附近，CDC 之前）

**关键设计点**：mux 必须在 CDC 之前，让 `adc_sample_r0/r1/r2` 统一同步最终选定的值。

```verilog
// 激光模式下用 acq_time 替换 adc_sample
wire [31:0] adc_sample_src = laser_mode_en ? acq_time : adc_sample;

always @(posedge adc_dco) begin
    adc_tri_r0      <= adc_tri;
    adc_tri_r1      <= adc_tri_r0;
    adc_tri_r2      <= adc_tri_r1;
    adc_interval_r0 <= adc_interval;
    adc_interval_r1 <= adc_interval_r0;
    adc_interval_r2 <= adc_interval_r1;
    adc_sample_r0   <= adc_sample_src;  // ← 改这里，原来是 adc_sample
    adc_sample_r1   <= adc_sample_r0;
    adc_sample_r2   <= adc_sample_r1;
    // ... 其他参数不变 ...
end
```

#### 3.2.4 adc_valid_point 计算增加激光分支（Line 103 附近）

```verilog
// 原逻辑：
// assign adc_valid_point = ultrafast_mode_r2 
//     ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
//     : image_column_r2 * adc_sample_r2;

// 新逻辑：激光模式优先级最高
assign adc_valid_point = laser_mode_en_r2 ? adc_sample_r2  // 激光模式：单像素，adc_sample_r2 已是 acq_time
                       : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                       : image_column_r2 * adc_sample_r2;
```

**说明**：
- 激光模式：`adc_valid_point = adc_sample_r2`（已经是 `acq_time`）
- 超快模式：`adc_sample_r2 - 延时 - 死区 - 2`
- 普通模式：`image_column × adc_sample_r2`（整行）

#### 3.2.5 adc_interval_reg 计算增加激光分支（Line 116 附近）

```verilog
// 原逻辑：
// always@(posedge adc_dco or negedge rstnr)
//     if(!rstnr)
//         adc_interval_reg <= 32'd19;
//     else if(ultrafast_mode_r2)
//         adc_interval_reg <= adc_acq_delay_r2;
//     else
//         adc_interval_reg <= adc_interval_r2;

// 新逻辑：激光模式优先级最高
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(laser_mode_en_r2)
        adc_interval_reg <= 32'd0;     // 激光模式无延迟，立刻采集
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;
    else
        adc_interval_reg <= adc_interval_r2;
```

**说明**：激光模式下触发延迟已由 `dac_output.v` 的 `acq_delay_time` 处理，ADC 侧收到 `adc_tri` 后立刻采集。

#### 3.2.6 line_count 逻辑复用超快模式（Line 182 附近）

激光模式下 `line_count` 的语义：
- 每 `image_column` 个 laser 脉冲 = 一行
- 复用超快模式的 `image_column_cnt` 计数逻辑

```verilog
// State 2 采集完成后（Line 182-196）
4'd2: begin
    // ... 现有采集逻辑 ...
    else if(ultrafast_mode_r2 == 1 || laser_mode_en_r2 == 1) begin  // ← 增加 laser_mode_en_r2
        adc_valid_point_cnt <= 0; 
        acq_en              <= 1'b0; 
        if(acq_dead_time_r2 == 32'd0)
            if(image_column_cnt == image_column_r2) begin 
                state               <= 4'd0;
                image_column_cnt    <= 16'd0;
                line_count          <= line_count + 1'b1;  // 行计数递增
                line_count_en       <= 1'b1;
            end
            else
                state               <= 4'd1;  // 继续等下一个触发
        else
            state               <= 4'd3;                       
    end 
    // ... 普通模式逻辑不变 ...
end
```

### 3.3 adcdata_config.v 改动（接线透传）

#### 3.3.1 模块端口增加

```verilog
module adcdata_config(
    // 现有端口
    input [31:0]        adc_sample,
    input               ultrafast_mode,
    
    // 新增：DL5 激光模式参数（透传给 4 路 ADC）
    input               laser_mode_en,
    input [31:0]        acq_time,
    
    // ...
);
```

#### 3.3.2 例化 4 路 adcdata_acq 时增加端口

```verilog
adcdata_acq    adcdata_acq_inst0(
    // 现有端口
    .adc_tri            (adc_tri),
    .adc_sample         (adc_sample),
    .ultrafast_mode     (ultrafast_mode),
    
    // 新增端口
    .laser_mode_en      (laser_mode_en),
    .acq_time           (acq_time),
    
    // ...
);

// 同样改动 adcdata_acq_inst1/inst2/inst3
```

### 3.4 ETH_TOP.v 改动（顶层接线）

```verilog
// dacdata_config 例化增加端口（已有 laser_mode_en，只需加 acq_time）
dacdata_config U5(
    // 现有端口
    .laser_mode_en      (laser_mode_en),
    
    // 新增端口
    .acq_time           (acq_time),
    
    // ...
);
```

**注意**：`laser_mode_en` 和 `acq_time` 已在 `command_monitor_new.v` 中定义（寄存器 0x0205 和 0x020A），ETH_TOP 只需接线。

---

## 4. 验证策略

### 4.1 单元仿真 testbench

复用 UNIT_003 的 `tb_dl5_unit_002.v`，增加激光模式 ADC 采集测试用例。

#### TC14：激光模式 ADC 采集点数验证

**配置**：
- `laser_mode_en = 1`
- `adc_sample` (0x0004) = 30（普通模式值，不应被使用）
- `acq_time` (0x020A) = 5（期望 ADC 采 5 个点）
- `image_column` = 16（16 个像素 = 1 行）

**验证点**：
1. ✅ 每个 laser 脉冲触发后，ADC 采集 **5 个点**（不是 30 个）
2. ✅ 采集延迟 = 0（`adc_interval_reg = 0`）
3. ✅ 16 个像素后 `line_count` 递增 1
4. ✅ 除法器输入点数 = 5（`adc_valid_point_cnt` 最大值）

#### TC15：acq_time 边界扫描

扫描 `acq_time ∈ {1, 2, 5, 10, 20}`，验证 ADC 采集点数正确。

#### TC1~TC13 回归验证

**必须全部 PASS**，确保普通模式 / 超快模式 / UNIT_003 成果不受影响。

### 4.2 综合与时序验证

- 运行 `run_synthesis.tcl` 和 `run_implementation.tcl`
- **验收标准**：
  - routed WNS ≥ 0
  - routed WHS ≥ 0
  - 资源增量 < 0.5%（新增 5 个寄存器 × 4 路 = 20 个寄存器，可忽略）

### 4.3 上板验证（可选）

如果时间允许，可在真实硬件上验证：
1. 配置激光模式，设置 `acq_time = 5`
2. 触发 16 个 laser 脉冲
3. 读取 ADC 数据，确认每个像素平均值由 5 个原始点计算而来

---

## 5. 风险与约束

### 5.1 硬约束（不可违反）

| 约束 | 来源 | 影响 |
|---|---|---|
| 普通模式 / 超快模式零影响 | 设计原则 | TC1~TC13 必须全部 PASS |
| UNIT_003 DAC 侧不回退 | 已上板验证通过 | `dac_output.v` / `parameter_dacdata_gen.v` 不改动 |
| `acq_time = 0` 防呆由上位机做 | 系统分工 | FPGA 不做除零防护（会导致除法器挂起）|
| `laser_mode_en` 只在 `scan_state=0` 时切换 | UNIT_002 设计 | 上位机必须遵守 |

### 5.2 已知风险

| 风险 | 概率 | 影响 | 缓解措施 |
|---|---|---|---|
| `acq_time` 与 `dac_sample` 不匹配 | 中 | DAC 驻点时间 ≠ ADC 采集窗口 | host-app 文档明确说明两者独立，用户需理解 |
| 4 路 ADC 参数 CDC 延迟 | 低 | 3 拍 adc_dco ≈ 60ns 延迟 | 可接受，触发本身已有 CDC 延迟 |
| `adc_sample_src` mux 时序 | 低 | eth_clk → adc_dco 跨域 | 已在 CDC 之前做 mux，安全 |
| 仿真覆盖不全 | 中 | 上板后发现边界问题 | 增加 TC15 边界扫描 |

### 5.3 不改的事

- ✅ 不改 `dac_output.v`（acq 状态机保持 UNIT_003 状态）
- ✅ 不改 `parameter_dacdata_gen.v`（State 14/15/16、C3-lite 保持）
- ✅ 不改 `command_monitor_new.v`（寄存器已定义）
- ✅ 不改普通模式 / 超快模式的采集逻辑
- ✅ 不新增寄存器（复用 0x020A）

---

## 6. 实施计划

### 6.1 实施顺序

1. **P0：改 `adcdata_acq.v`**（核心改动）
   - 新增端口
   - 增加 CDC
   - 增加 mux 和激光模式分支
2. **P1：改 `adcdata_config.v`**（接线透传）
3. **P2：改 `ETH_TOP.v`**（顶层接线）
4. **P3：增加 TC14/TC15 仿真用例**
5. **P4：运行回归仿真**（TC1~TC15 全部 PASS）
6. **P5：综合与时序验证**
7. **P6：（可选）上板验证**

### 6.2 验收清单

实施前打印这张清单，逐项勾选：

- [ ] `adcdata_acq.v` 新增 `laser_mode_en`/`acq_time` 输入端口
- [ ] CDC 同步增加 `laser_mode_en_r0/r1/r2` 和 `acq_time_r0/r1/r2`
- [ ] `adc_sample_src` mux 在 CDC 之前
- [ ] `adc_valid_point` 计算增加 `laser_mode_en_r2` 分支
- [ ] `adc_interval_reg` 计算增加 `laser_mode_en_r2` 分支（值为 0）
- [ ] State 2 结束条件增加 `|| laser_mode_en_r2`
- [ ] `adcdata_config.v` 透传参数到 4 路 ADC
- [ ] `ETH_TOP.v` 顶层接线 `acq_time`
- [ ] TC14 增加激光模式 ADC 采集点数验证
- [ ] TC15 增加 `acq_time` 边界扫描
- [ ] TC1~TC13 回归全部 PASS
- [ ] 综合 WNS ≥ 0
- [ ] Implementation routed WNS ≥ 0 且 WHS ≥ 0

---

## 7. 与其他单元的协同

### 7.1 与 UNIT_003 的关系

- ✅ **完全兼容**：UNIT_004 只改 ADC 侧，UNIT_003 的 DAC 侧（FIFO 水位优化、State 14/15/16、C3-lite）全部保留
- ✅ **不回退**：`dac_output.v` 的 acq 状态机已经使用 `acq_time` 控制脉宽，UNIT_004 只是让 ADC 采集点数也匹配

### 7.2 与 host-app 的协同

**上位机必须理解的新语义**：
1. 激光模式下 `dac_sample` (0x0004) 和 `acq_time` (0x020A) **独立配置**
   - `dac_sample`：DAC 坐标驻点时间（State 16 写多少个 FIFO word）
   - `acq_time`：ADC 采集点数（每个 laser 脉冲采多少个原始点求平均）
2. 两者可以不等（用户需理解权衡）：
   - `dac_sample > acq_time`：DAC 稳定时间长，ADC 采样窗口短（保守）
   - `dac_sample = acq_time`：DAC/ADC 严格对齐（推荐）
   - `dac_sample < acq_time`：❌ 不推荐，ADC 窗口超出 DAC 驻点

**建议 host-app 默认配置**：
```python
# 激光模式配置示例
laser_config = {
    "laser_mode_en": 1,           # 0x0205
    "dac_sample": 5,              # 0x0004，DAC 驻点 100ns
    "acq_time": 5,                # 0x020A，ADC 采 5 个点
    "scan_delay": 2,              # 0x0206，laser → DAC 延迟 16ns
    "blanker_delay": 10,          # 0x0207，50ns
    "blanker_time": 20,           # 0x0208，100ns
    "acq_delay": 5,               # 0x0209，100ns
}
```

---

## 8. 附录

### 8.1 相关寄存器速查

| 地址 | 名称 | 位宽 | 步进 | 说明 | 本方案是否修改 |
|---|---|---|---|---|---|
| `0x0004` | `adc_sample/dac_sample` | 32 | - | 普通模式 DAC/ADC 共用；激光模式 DAC 专用 | ❌ 语义扩展，RTL 不改 |
| `0x0205` | `laser_mode_en` | 1 | - | 1=激光模式，0=普通模式 | ❌ 已存在 |
| `0x020A` | `acq_time` | 16 | 20ns | 激光模式 ADC 采集点数 | ✅ 新增到 adcdata_acq |

### 8.2 关键文件位置

| 文件 | 路径 | 说明 |
|---|---|---|
| `adcdata_acq.v` | `AXI_DDR.srcs/sources_1/new/adcdata_acq.v` | ADC 采集状态机（核心改动） |
| `adcdata_config.v` | `AXI_DDR.srcs/sources_1/new/adcdata_config.v` | 4 路 ADC 配置器（透传参数）|
| `ETH_TOP.v` | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | 顶层（接线）|
| `dac_output.v` | `AXI_DDR.srcs/sources_1/new/dac_output.v` | ❌ 不改动 |
| `tb_dl5_unit_002.v` | `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/tb_dl5_unit_002.v` | 仿真 testbench（增加 TC14/TC15）|

### 8.3 参考文档

- [DL5_UNIT_003 IMPLEMENTATION.md](../DL5_UNIT_003/IMPLEMENTATION.md)：FIFO 水位优化实施细节
- [DL5_UNIT_003 BOARD_DEBUG_GUIDE.md](../DL5_UNIT_003/BOARD_DEBUG_GUIDE.md)：上板验证指南
- [DAC/ADC 协同原理](C:\Users\Administrator\.claude\projects\D--SGSC-SEM-dahuasuo-325T-V3-172-SGSC-SEM-dahuasuo-325T-V3-172-SGSC-SEM-325T-V3-171-fpga-prj\memory\dac-adc-coordination.md)：设计背景

---

**方案状态**：待审批  
**审批问题**：
1. 方案 1（只改 adcdata_acq.v）是否认可？
2. `adc_sample` 和 `acq_time` 独立配置的语义是否符合预期？
3. 激光模式下 `adc_interval_reg = 0`（无延迟）是否合理？
4. 验收清单是否完整？

请审批后我开始实施。

# DL5_UNIT_004 实施方案 V2：激光模式 ADC 采集点数独立控制

> **文档状态**：待审批  
> **版本**：V2（修正版）  
> **创建日期**：2026-06-04  
> **前置依赖**：[DL5_UNIT_003](../DL5_UNIT_003/IMPLEMENTATION.md)（FIFO 水位优化，已上板验证通过）

---

## 0. 执行摘要

**问题**：当前代码中 `dac_output.v` 的 acq 状态机已用 `acq_time` 控制 `acq_pulse_ui` 脉宽，但 `adcdata_acq.v` 的 ADC 采集点数仍由 `adc_sample` 控制，两者解耦导致激光模式下 ADC 采集行为不符合预期。

**核心原则**：**普通模式和超快模式的功能绝对不能变**。所有参数先正常 CDC，然后在使用时按模式选择。

**方案要点**：
1. ✅ `adc_sample` 和 `acq_time` **都做正常 CDC**，不在 CDC 之前 mux
2. ✅ 在 `adc_valid_point` / `adc_sample_reg` / `adc_interval_reg` **使用时按模式选择**
3. ✅ 普通模式 / 超快模式的所有逻辑路径保持原样

**验收标准**：
- ✅ TC1~TC13 回归全部 PASS（普通/超快模式零影响）
- ✅ TC14/TC15 激光模式 ADC 采集点数正确
- ✅ 综合时序收敛（WNS/WHS ≥ 0）

---

## 1. 核心设计原则

### 原则 1：所有参数先正常 CDC，不做 mux

```verilog
// ✅ 正确做法：所有参数都正常 CDC
always @(posedge adc_dco) begin
    adc_sample_r0 <= adc_sample;      // 原样 CDC
    adc_sample_r1 <= adc_sample_r0;
    adc_sample_r2 <= adc_sample_r1;
    
    acq_time_r0   <= acq_time;        // 新增，也正常 CDC
    acq_time_r1   <= acq_time_r0;
    acq_time_r2   <= acq_time_r1;
end

// ❌ 错误做法（V1 方案的问题）：CDC 之前 mux
wire [31:0] adc_sample_src = laser_mode_en ? acq_time : adc_sample;
adc_sample_r0 <= adc_sample_src;  // 这样会破坏超快模式
```

### 原则 2：在使用时按模式选择参数

```verilog
// ✅ 正确做法：使用时选择
assign adc_valid_point = laser_mode_en_r2   ? acq_time_r2                    // 激光模式用 acq_time
                       : ultrafast_mode_r2  ? (adc_sample_r2 - delays - 2)   // 超快模式用 adc_sample
                       : image_column_r2 * adc_sample_r2;                     // 普通模式用 adc_sample

assign adc_sample_reg = laser_mode_en_r2   ? acq_time_r2                     // 激光模式用 acq_time
                      : ultrafast_mode_r2  ? (adc_sample_r2 - delays - 2)    // 超快模式用 adc_sample
                      : adc_sample_r2;                                        // 普通模式用 adc_sample
```

### 原则 3：模式互斥由上位机保证

```verilog
// 约束（由上位机保证）：
// laser_mode_en 与 ultrafast_mode 不应同时为 1
//
// RTL 按优先级处理：
// 1. laser_mode_en_r2 == 1 → 激光模式分支
// 2. ultrafast_mode_r2 == 1 → 超快模式分支
// 3. 其他 → 普通模式分支
```

---

## 2. 详细改动设计

### 2.1 adcdata_acq.v 改动

#### 2.1.1 模块端口增加

```verilog
module adcdata_acq(
    // 现有端口保持不变
    input               ui_clk,
    input               rstn,
    input       [15:0]  row_repeat,
    input               adc_tri,
    input       [31:0]  adc_sample,        // 保持原样
    input       [15:0]  image_column,
    input       [23:0]  adc_interval,
    input               ultrafast_mode,
    input       [31:0]  acq_dead_time,
    input       [31:0]  adc_acq_delay,
    
    // 新增：DL5 激光模式参数
    input               laser_mode_en,     // 1=激光模式，0=普通模式
    input       [31:0]  acq_time,          // 激光模式 ADC 采集点数
    
    // ADC 数据输入
    input               adc_dco,
    input       [15:0]  adc_data,
    // ...
);
```

#### 2.1.2 CDC 同步：所有参数正常 CDC

```verilog
// 现有参数 CDC（保持不变）
reg         adc_tri_r0      = 0;
reg         adc_tri_r1      = 0;
reg         adc_tri_r2      = 0;
reg [31:0]  adc_sample_r0   = 50;
reg [31:0]  adc_sample_r1   = 50;
reg [31:0]  adc_sample_r2   = 50;
reg [15:0]  image_column_r0 = 1024;
reg [15:0]  image_column_r1 = 1024;
reg [15:0]  image_column_r2 = 1024;
reg [23:0]  adc_interval_r0 = 19;
reg [23:0]  adc_interval_r1 = 19;
reg [23:0]  adc_interval_r2 = 19;
reg         ultrafast_mode_r0= 0;
reg         ultrafast_mode_r1= 0;
reg         ultrafast_mode_r2= 0;
reg [23:0]  adc_acq_delay_r0 = 0;
reg [23:0]  adc_acq_delay_r1 = 0;
reg [23:0]  adc_acq_delay_r2 = 0;
reg [31:0]  acq_dead_time_r0 = 0;
reg [31:0]  acq_dead_time_r1 = 0;
reg [31:0]  acq_dead_time_r2 = 0;

// 新增：激光模式参数 CDC
reg         laser_mode_en_r0 = 0;
reg         laser_mode_en_r1 = 0;
reg         laser_mode_en_r2 = 0;
reg [31:0]  acq_time_r0      = 50;   // 默认值与 adc_sample 一致
reg [31:0]  acq_time_r1      = 50;
reg [31:0]  acq_time_r2      = 50;

// CDC 同步逻辑（所有参数正常同步，不做 mux）
always @(posedge adc_dco) begin
    // 现有参数同步（保持不变）
    adc_tri_r0      <= adc_tri;
    adc_tri_r1      <= adc_tri_r0;
    adc_tri_r2      <= adc_tri_r1;
    adc_interval_r0 <= adc_interval;
    adc_interval_r1 <= adc_interval_r0;
    adc_interval_r2 <= adc_interval_r1;
    adc_sample_r0   <= adc_sample;         // ← 保持原样，不 mux
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
    
    // 新增：激光模式参数同步
    laser_mode_en_r0 <= laser_mode_en;
    laser_mode_en_r1 <= laser_mode_en_r0;
    laser_mode_en_r2 <= laser_mode_en_r1;
    acq_time_r0      <= acq_time;
    acq_time_r1      <= acq_time_r0;
    acq_time_r2      <= acq_time_r1;
end
```

**关键**：`adc_sample_r0/r1/r2` 保持原样同步 `adc_sample`，不做任何 mux。

#### 2.1.3 adc_valid_point 计算：使用时按模式选择

```verilog
// 原代码（Line 107）：
// assign adc_valid_point = ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
//                                             : image_column_r2 * adc_sample_r2;

// 新代码：增加激光模式分支
wire[39:0] adc_valid_point;
assign adc_valid_point = laser_mode_en_r2   ? acq_time_r2                                                     // 激光模式：单像素，用 acq_time
                       : ultrafast_mode_r2  ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)  // 超快模式：用 adc_sample
                       : image_column_r2 * adc_sample_r2;                                                     // 普通模式：用 adc_sample
```

**关键点**：
- ✅ 激光模式使用 `acq_time_r2`（新参数）
- ✅ 超快模式使用 `adc_sample_r2`（原参数，保持不变）
- ✅ 普通模式使用 `adc_sample_r2`（原参数，保持不变）

#### 2.1.4 adc_interval_reg 计算：使用时按模式选择

```verilog
// 原代码（Line 118-124）：
// always@(posedge adc_dco or negedge rstnr)
//     if(!rstnr)
//         adc_interval_reg <= 32'd19;
//     else if(ultrafast_mode_r2)
//         adc_interval_reg <= adc_acq_delay_r2;
//     else
//         adc_interval_reg <= adc_interval_r2;

// 新代码：增加激光模式分支
reg [31:0] adc_interval_reg;
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(laser_mode_en_r2)
        adc_interval_reg <= 32'd0;             // 激光模式：无延迟，立刻采集
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;  // 超快模式：用 adc_acq_delay（保持不变）
    else
        adc_interval_reg <= adc_interval_r2;   // 普通模式：用 adc_interval（保持不变）
```

**关键点**：
- ✅ 激光模式：`adc_interval_reg = 0`（新行为）
- ✅ 超快模式：`adc_interval_reg = adc_acq_delay_r2`（保持不变）
- ✅ 普通模式：`adc_interval_reg = adc_interval_r2`（保持不变）

#### 2.1.5 adc_sample_reg 除法器分母：使用时按模式选择

```verilog
// 原代码（Line 243）：
// assign adc_sample_reg = ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
//                                            : adc_sample_r2;

// 新代码：增加激光模式分支
wire [31:0] adc_sample_reg;
assign adc_sample_reg = laser_mode_en_r2  ? acq_time_r2                                                      // 激光模式：用 acq_time
                      : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)   // 超快模式：用 adc_sample
                      : adc_sample_r2;                                                                        // 普通模式：用 adc_sample
```

**关键点**：
- ✅ 激光模式使用 `acq_time_r2`（除法器分母 = ADC 采集点数）
- ✅ 超快模式使用 `adc_sample_r2`（保持不变）
- ✅ 普通模式使用 `adc_sample_r2`（保持不变）

#### 2.1.6 State 2 采集完成条件：增加激光模式分支

```verilog
// 原代码（Line 182-203）：
//     else if(ultrafast_mode_r2 == 1)begin
//         // 超快模式：一个窗口结束后可能继续下一列
//         ...
//     end 
//     else begin
//         // 普通模式：一次触发只采一整行
//         ...
//     end

// 新代码：增加激光模式
4'd2:   begin
    if(adc_valid_point == 0) begin
        acq_en <= 1'b1;
        state  <= 4'd2;  
    end
    else if(adc_valid_point_cnt < adc_valid_point) begin
        adc_valid_point_cnt <= adc_valid_point_cnt + 1'b1;
        acq_en              <= 1'b1;
        state               <= 4'd2;
    end
    else if(ultrafast_mode_r2 == 1)begin
        // 超快模式（保持不变）
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
        // 激光模式（新增，复用超快模式的多窗口逻辑，但忽略 dead time）
        adc_valid_point_cnt <= 0; 
        acq_en              <= 1'b0; 
        if(image_column_cnt == image_column_r2) begin 
            state               <= 4'd0;
            image_column_cnt    <= 16'd0;
            line_count          <= line_count + 1'b1;
            line_count_en       <= 1'b1;
        end
        else
            state               <= 4'd1;  // 继续等下一个激光脉冲
    end 
    else begin
        // 普通模式（保持不变）
        adc_valid_point_cnt <= 0; 
        acq_en              <= 1'b0;   
        state               <= 4'd0;                        
    end  
end
```

**关键点**：
- ✅ 超快模式：`ultrafast_mode_r2 == 1` 分支（保持原样，包括 dead time 处理）
- ✅ 激光模式：`laser_mode_en_r2 == 1` 分支（新增，**强制跳过 dead time**）
- ✅ 普通模式：`else` 分支（保持原样）
- ✅ 优先级：超快模式先判断，激光模式次之，普通模式最后

### 2.2 adcdata_config.v 改动（接线透传）

```verilog
module adcdata_config(
    // 现有端口
    input [31:0]        adc_sample,
    input               ultrafast_mode,
    
    // 新增：DL5 激光模式参数
    input               laser_mode_en,
    input [31:0]        acq_time,
    
    // ...
);

// 例化 4 路 adcdata_acq 时增加端口
adcdata_acq adcdata_acq_inst0(
    // 现有端口
    .adc_tri            (adc_tri),
    .adc_sample         (adc_sample),
    .ultrafast_mode     (ultrafast_mode),
    
    // 新增端口
    .laser_mode_en      (laser_mode_en),
    .acq_time           (acq_time),
    
    // ...
);

// 同样改动 inst1/inst2/inst3
```

### 2.3 ETH_TOP.v 改动（顶层接线）

```verilog
dacdata_config U5(
    // 现有端口
    .laser_mode_en      (laser_mode_en),
    
    // 新增端口
    .acq_time           (acq_time),
    
    // ...
);
```

---

## 3. 兼容性保证

### 3.1 普通模式（laser_mode_en=0, ultrafast_mode=0）

| 参数 | 原逻辑 | 新逻辑 | 是否一致 |
|---|---|---|---|
| `adc_valid_point` | `image_column_r2 * adc_sample_r2` | `image_column_r2 * adc_sample_r2` | ✅ 完全一致 |
| `adc_interval_reg` | `adc_interval_r2` | `adc_interval_r2` | ✅ 完全一致 |
| `adc_sample_reg` | `adc_sample_r2` | `adc_sample_r2` | ✅ 完全一致 |
| State 2 分支 | `else` 分支 | `else` 分支 | ✅ 完全一致 |

**结论**：✅ **普通模式零影响**

### 3.2 超快模式（laser_mode_en=0, ultrafast_mode=1）

| 参数 | 原逻辑 | 新逻辑 | 是否一致 |
|---|---|---|---|
| `adc_valid_point` | `adc_sample_r2 - delays - 2` | `adc_sample_r2 - delays - 2` | ✅ 完全一致 |
| `adc_interval_reg` | `adc_acq_delay_r2` | `adc_acq_delay_r2` | ✅ 完全一致 |
| `adc_sample_reg` | `adc_sample_r2 - delays - 2` | `adc_sample_r2 - delays - 2` | ✅ 完全一致 |
| State 2 分支 | `ultrafast_mode_r2 == 1` 分支 | `ultrafast_mode_r2 == 1` 分支 | ✅ 完全一致 |
| dead time 处理 | 进入 State 3 | 进入 State 3 | ✅ 完全一致 |

**结论**：✅ **超快模式零影响**

### 3.3 激光模式（laser_mode_en=1, ultrafast_mode=0）

| 参数 | 新逻辑 | 说明 |
|---|---|---|
| `adc_valid_point` | `acq_time_r2` | 新功能：单像素采集点数 |
| `adc_interval_reg` | `0` | 新功能：无延迟 |
| `adc_sample_reg` | `acq_time_r2` | 新功能：除法器分母 |
| State 2 分支 | `laser_mode_en_r2 == 1` 分支 | 新功能：多窗口，无 dead time |

**结论**：✅ **新功能，不影响旧模式**

---

## 4. 模式互斥约束

### 4.1 硬约束

| 约束 | 来源 | 说明 |
|---|---|---|
| `laser_mode_en` 与 `ultrafast_mode` 互斥 | 系统设计 | 上位机不应同时设置两者为 1 |
| `laser_mode_en` 只在 `scan_state=0` 时切换 | UNIT_002 设计 | 运行中不切换模式 |

### 4.2 RTL 优先级（容错处理）

如果上位机错误地同时设置两者为 1，RTL 按以下优先级处理：

```verilog
// 优先级 1：超快模式（先判断，保护已有功能）
if (ultrafast_mode_r2 == 1) {
    // 超快模式逻辑
}
// 优先级 2：激光模式
else if (laser_mode_en_r2 == 1) {
    // 激光模式逻辑
}
// 优先级 3：普通模式
else {
    // 普通模式逻辑
}
```

**理由**：超快模式先判断，保护已有功能不被破坏。

---

## 5. 验证策略

### 5.1 单元仿真

#### TC14：激光模式 ADC 采集点数验证

**配置**：
- `laser_mode_en = 1`, `ultrafast_mode = 0`
- `adc_sample = 30`（不应被使用）
- `acq_time = 5`（期望采 5 个点）
- `image_column = 16`

**验证点**：
1. ✅ `adc_valid_point = 5`（不是 30）
2. ✅ `adc_sample_reg = 5`（除法器分母）
3. ✅ `adc_interval_reg = 0`
4. ✅ 16 个像素后 `line_count` 递增

#### TC1~TC13 回归验证

**必须全部 PASS**，确保普通模式 / 超快模式零影响。

### 5.2 综合与时序验证

- routed WNS ≥ 0
- routed WHS ≥ 0
- 资源增量 < 0.5%（新增 7 个寄存器 × 4 路 = 28 个寄存器）

---

## 6. 改动文件清单

| 文件 | 改动内容 | 行数估算 |
|---|---|---|
| `adcdata_acq.v` | 新增端口 + CDC + 3 处按模式选择 + State 2 分支 | ~40 行 |
| `adcdata_config.v` | 透传参数到 4 路 ADC | ~10 行 |
| `ETH_TOP.v` | 顶层接线 | ~2 行 |

---

## 7. 实施清单

实施前打印这张清单，逐项勾选：

**adcdata_acq.v 改动**：
- [ ] 模块端口增加 `laser_mode_en` 和 `acq_time`
- [ ] CDC 增加 `laser_mode_en_r0/r1/r2` 和 `acq_time_r0/r1/r2`
- [ ] `adc_sample_r0/r1/r2` **保持原样同步 `adc_sample`**（不 mux）
- [ ] `adc_valid_point` 增加激光模式分支，使用 `acq_time_r2`
- [ ] `adc_interval_reg` 增加激光模式分支，值为 `0`
- [ ] `adc_sample_reg` 增加激光模式分支，使用 `acq_time_r2`
- [ ] State 2 增加 `else if(laser_mode_en_r2 == 1)` 分支
- [ ] 激光模式分支跳过 dead time（不进 State 3）

**adcdata_config.v 改动**：
- [ ] 模块端口增加 `laser_mode_en` 和 `acq_time`
- [ ] 4 路 adcdata_acq 例化增加端口

**ETH_TOP.v 改动**：
- [ ] dacdata_config 例化增加 `acq_time` 接线

**验证**：
- [ ] TC1~TC13 回归全部 PASS
- [ ] TC14 激光模式采集点数验证 PASS
- [ ] 综合 WNS ≥ 0
- [ ] Implementation routed WNS ≥ 0 且 WHS ≥ 0

---

## 8. V2 相对于 V1 的修正

| 问题 | V1 方案（错误） | V2 方案（修正） |
|---|---|---|
| CDC 策略 | CDC 之前 mux | 所有参数先正常 CDC，使用时选择 |
| `adc_sample_r2` | 被 mux 替换为 `acq_time` | 保持原样同步 `adc_sample` |
| 超快模式影响 | ❌ 除法器会用错值 | ✅ 完全不影响 |
| 普通模式影响 | ✅ 不影响（但设计有风险） | ✅ 不影响（设计安全） |

---

**方案状态**：待审批  
**核心保证**：普通模式和超快模式的功能绝对不变

请审批后我开始实施。

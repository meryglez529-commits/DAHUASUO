# DL5_UNIT_004 兼容性检查报告

> **检查目标**：确保所有改动不影响普通模式和超快模式  
> **检查日期**：2026-06-04  
> **检查方法**：逐行分析方案中的改动点，对比原代码逻辑

---

## 检查清单

### ✅ 改动点 1：`adc_sample_src` mux（CDC 之前）

**方案中的代码**：
```verilog
// 激光模式下用 acq_time 替换 adc_sample
wire [31:0] adc_sample_src = laser_mode_en ? acq_time : adc_sample;

always @(posedge adc_dco) begin
    adc_sample_r0 <= adc_sample_src;  // ← 改这里，原来是 adc_sample
    adc_sample_r1 <= adc_sample_r0;
    adc_sample_r2 <= adc_sample_r1;
```

**原代码**（Line 78-88）：
```verilog
always @(posedge adc_dco) begin
    adc_tri_r0      <= adc_tri;
    // ...
    adc_sample_r0   <= adc_sample;  // ← 原代码
    adc_sample_r1   <= adc_sample_r0;
    adc_sample_r2   <= adc_sample_r1;
```

**兼容性分析**：
- ✅ **普通模式**：`laser_mode_en = 0` → `adc_sample_src = adc_sample` → 行为与原代码完全一致
- ✅ **超快模式**：`laser_mode_en = 0` → `adc_sample_src = adc_sample` → 行为与原代码完全一致
- ✅ **激光模式**：`laser_mode_en = 1` → `adc_sample_src = acq_time` → 新功能，不影响旧模式

**结论**：✅ 安全，不影响普通模式和超快模式

---

### ⚠️ 改动点 2：`adc_valid_point` 计算增加激光分支

**方案中的代码**：
```verilog
assign adc_valid_point = laser_mode_en_r2 ? adc_sample_r2  // 激光模式：单像素
                       : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                       : image_column_r2 * adc_sample_r2;
```

**原代码**（Line 107）：
```verilog
assign adc_valid_point = ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
                                            : image_column_r2 * adc_sample_r2;
```

**兼容性分析**：
- ❌ **潜在问题**：三目运算符优先级问题！

**展开原代码逻辑**：
```verilog
if (ultrafast_mode_r2 == 1)
    adc_valid_point = adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2;
else
    adc_valid_point = image_column_r2 * adc_sample_r2;
```

**展开方案代码逻辑**：
```verilog
if (laser_mode_en_r2 == 1)
    adc_valid_point = adc_sample_r2;
else if (ultrafast_mode_r2 == 1)
    adc_valid_point = adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2;
else
    adc_valid_point = image_column_r2 * adc_sample_r2;
```

**关键问题**：如果 `laser_mode_en_r2 = 1` 且 `ultrafast_mode_r2 = 1` 同时为真会怎样？

**检查系统约束**：
- 查看 `command_monitor_new.v` 寄存器定义：
  - `laser_mode_en` = 0x0205（独立寄存器）
  - `ultrafast_mode` = 0x0201 bit[0]（独立寄存器）
- **系统设计允许两者同时为 1 吗？**
  - 查看 UNIT_002/UNIT_003 文档：没有明确互斥约束
  - 上位机逻辑：需要确认 host-app 是否做了互斥检查

**风险评估**：
- 如果上位机错误地同时设置 `laser_mode_en = 1` 和 `ultrafast_mode = 1`
- 方案代码：激光模式优先 → `adc_valid_point = adc_sample_r2`（已被替换为 `acq_time`）
- 行为：超快模式被激光模式覆盖，不会执行超快模式逻辑

**修复建议**：
```verilog
// 修复版本：增加优先级注释 + 运行时互斥检查
assign adc_valid_point = laser_mode_en_r2 ? adc_sample_r2  // 优先级 1：激光模式
                       : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)  // 优先级 2：超快模式
                       : image_column_r2 * adc_sample_r2;  // 优先级 3：普通模式

// 约束：laser_mode_en 与 ultrafast_mode 不应同时为 1，由上位机保证
```

**结论**：⚠️ 需要明确模式互斥约束
- ✅ 如果上位机保证 `laser_mode_en` 和 `ultrafast_mode` 互斥 → 安全
- ❌ 如果两者可以同时为 1 → 需要增加 RTL 防呆或上位机检查

---

### ⚠️ 改动点 3：`adc_interval_reg` 计算增加激光分支

**方案中的代码**：
```verilog
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(laser_mode_en_r2)
        adc_interval_reg <= 32'd0;     // 激光模式无延迟
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;
    else
        adc_interval_reg <= adc_interval_r2;
```

**原代码**（Line 118-124）：
```verilog
always@(posedge adc_dco or negedge rstnr)
    if(!rstnr)
        adc_interval_reg <= 32'd19;
    else if(ultrafast_mode_r2)
        adc_interval_reg <= adc_acq_delay_r2;
    else
        adc_interval_reg <= adc_interval_r2;
```

**兼容性分析**：
- 同样的问题：如果 `laser_mode_en_r2` 和 `ultrafast_mode_r2` 同时为 1？
- 激光模式优先 → `adc_interval_reg = 0`
- 超快模式的 `adc_acq_delay_r2` 延迟被忽略

**结论**：⚠️ 同改动点 2，需要模式互斥约束

---

### ⚠️ 改动点 4：State 2 结束条件增加 `|| laser_mode_en_r2`

**方案中的代码**（Line 182）：
```verilog
else if(ultrafast_mode_r2 == 1 || laser_mode_en_r2 == 1) begin  // ← 增加 laser_mode_en_r2
    // 超快模式 / 激光模式：一个窗口结束后可能继续下一列
    adc_valid_point_cnt <= 0; 
    acq_en              <= 1'b0; 
    if(acq_dead_time_r2 == 32'd0)
        if(image_column_cnt == image_column_r2) begin 
            // 行计数递增
        end
        else
            state <= 4'd1;  // 继续等下一个触发
    else
        state <= 4'd3;  // 进入 dead time                     
end 
```

**原代码**（Line 182-197）：
```verilog
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
```

**兼容性分析**：
- ✅ **普通模式**：不进入这个分支，走 `else` 分支（Line 198-203）→ 完全不变
- ✅ **超快模式**：`ultrafast_mode_r2 == 1` → 进入这个分支 → 行为完全不变
- ✅ **激光模式**：`laser_mode_en_r2 == 1` → 进入这个分支 → 新功能

**关键检查**：激光模式是否需要 `acq_dead_time`？
- 查看方案文档：没有提到激光模式使用 `acq_dead_time`
- State 3 注释（Line 206）："dead time 只在超快模式使用"

**潜在问题**：
```verilog
if(acq_dead_time_r2 == 32'd0)
    // 分支 A：无 dead time
else
    state <= 4'd3;  // 分支 B：进入 dead time（State 3）
```

**问题**：如果激光模式下 `acq_dead_time_r2 ≠ 0` 会怎样？
- 激光模式会错误地进入 State 3（dead time 等待）
- 但激光模式不应该有 dead time 概念

**修复建议**：
```verilog
else if(ultrafast_mode_r2 == 1 || laser_mode_en_r2 == 1) begin
    adc_valid_point_cnt <= 0; 
    acq_en              <= 1'b0; 
    // 激光模式忽略 dead time，超快模式才需要
    if(acq_dead_time_r2 == 32'd0 || laser_mode_en_r2 == 1)
        if(image_column_cnt == image_column_r2) begin 
            state               <= 4'd0;
            image_column_cnt    <= 16'd0;
            line_count          <= line_count + 1'b1;
            line_count_en       <= 1'b1;
        end
        else
            state               <= 4'd1;
    else
        state               <= 4'd3;  // 只有超快模式才进这里                     
end 
```

**结论**：⚠️ 需要修复激光模式对 `acq_dead_time` 的处理

---

### ✅ 改动点 5：`adc_sample_reg` 除法器分母

**原代码**（Line 243）：
```verilog
assign adc_sample_reg = ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
                                           : adc_sample_r2;
```

**方案中的代码**（未明确提出修改）：
- `adc_sample_reg` 直接使用 `adc_sample_r2`
- 由于 `adc_sample_r2` 已被 mux 替换为 `adc_sample_src`（改动点 1）
- 激光模式下 `adc_sample_r2 = acq_time`

**兼容性分析**：
- ✅ **普通模式**：`adc_sample_r2 = adc_sample`（原值）→ 除法器分母不变
- ⚠️ **超快模式**：`adc_sample_r2 = adc_sample`（原值）→ 除法器仍然减去延时和死区 → 行为不变
- ✅ **激光模式**：`adc_sample_r2 = acq_time` → 除法器分母 = `acq_time`（正确）

**但是等等**！我发现一个严重问题：

**超快模式的 `adc_sample_reg` 计算**：
```verilog
assign adc_sample_reg = ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
                                           : adc_sample_r2;
```

**问题**：
- 超快模式需要用 **原始 `adc_sample`**（未 mux）计算分母
- 但方案中 `adc_sample_r2` 已经被 mux 替换了
- 如果激光模式 `adc_sample_r2 = acq_time`，超快模式的分母计算会用错值！

**修复方案**：需要保留原始 `adc_sample` 的 CDC 路径给 `adc_sample_reg` 使用

```verilog
// 方案 A：保留原始 adc_sample CDC（推荐）
reg [31:0]  adc_sample_raw_r0 = 50;  // 原始 adc_sample，不经 mux
reg [31:0]  adc_sample_raw_r1 = 50;
reg [31:0]  adc_sample_raw_r2 = 50;

always @(posedge adc_dco) begin
    // 给 adc_valid_point 用的（经过 mux）
    adc_sample_r0 <= adc_sample_src;
    adc_sample_r1 <= adc_sample_r0;
    adc_sample_r2 <= adc_sample_r1;
    
    // 给 adc_sample_reg 用的（原始值，不 mux）
    adc_sample_raw_r0 <= adc_sample;
    adc_sample_raw_r1 <= adc_sample_raw_r0;
    adc_sample_raw_r2 <= adc_sample_raw_r1;
end

// adc_sample_reg 用原始值
assign adc_sample_reg = ultrafast_mode_r2 ? (adc_sample_raw_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2) 
                                           : adc_sample_raw_r2;

// 激光模式需要增加分支
assign adc_sample_reg = laser_mode_en_r2 ? adc_sample_r2  // 激光模式用 acq_time
                      : ultrafast_mode_r2 ? (adc_sample_raw_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                      : adc_sample_raw_r2;
```

**结论**：❌ **严重问题**！方案中的 mux 会破坏超快模式的除法器分母计算

---

## 总结报告

### 🔴 发现的问题

| 问题 | 严重程度 | 影响 | 修复方案 |
|---|---|---|---|
| **问题 1**：`laser_mode_en` 与 `ultrafast_mode` 缺少互斥约束 | 🟡 中 | 如果上位机同时设置两者，行为未定义 | 增加文档说明 + 上位机检查 |
| **问题 2**：激光模式对 `acq_dead_time` 的处理不当 | 🟡 中 | 激光模式可能错误进入 State 3 | 修改 State 2 条件判断 |
| **问题 3**：`adc_sample_reg` 除法器分母被破坏 | 🔴 **严重** | **超快模式除法器会用错值** | **必须修复**：保留原始 `adc_sample` CDC 路径 |

### ✅ 安全的改动

| 改动点 | 普通模式 | 超快模式 | 激光模式 |
|---|---|---|---|
| `adc_sample_src` mux（CDC 前） | ✅ 不影响 | ✅ 不影响 | ✅ 新功能 |
| 新增 CDC 寄存器 | ✅ 不影响 | ✅ 不影响 | ✅ 新功能 |

---

## 修复后的完整方案

### 修复 1：保留原始 `adc_sample` CDC 路径

```verilog
// 新增：原始 adc_sample CDC（给除法器分母用）
reg [31:0]  adc_sample_raw_r0 = 50;
reg [31:0]  adc_sample_raw_r1 = 50;
reg [31:0]  adc_sample_raw_r2 = 50;

// 激光模式 mux 后的 CDC（给 adc_valid_point 用）
wire [31:0] adc_sample_src = laser_mode_en ? acq_time : adc_sample;

always @(posedge adc_dco) begin
    // ... 其他参数同步 ...
    
    // 给 adc_valid_point 用的（经过 mux）
    adc_sample_r0 <= adc_sample_src;
    adc_sample_r1 <= adc_sample_r0;
    adc_sample_r2 <= adc_sample_r1;
    
    // 给 adc_sample_reg 用的（原始值）
    adc_sample_raw_r0 <= adc_sample;
    adc_sample_raw_r1 <= adc_sample_raw_r0;
    adc_sample_raw_r2 <= adc_sample_raw_r1;
end

// adc_valid_point 使用 mux 后的值
assign adc_valid_point = laser_mode_en_r2 ? adc_sample_r2
                       : ultrafast_mode_r2 ? (adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                       : image_column_r2 * adc_sample_r2;

// adc_sample_reg 使用原始值（超快模式）+ mux 后的值（激光模式）
assign adc_sample_reg = laser_mode_en_r2 ? adc_sample_r2  // 激光模式用 acq_time
                      : ultrafast_mode_r2 ? (adc_sample_raw_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 24'd2)
                      : adc_sample_raw_r2;  // 普通模式用原始值
```

### 修复 2：激光模式忽略 `acq_dead_time`

```verilog
// State 2 采集完成后
else if(ultrafast_mode_r2 == 1 || laser_mode_en_r2 == 1) begin
    adc_valid_point_cnt <= 0; 
    acq_en              <= 1'b0; 
    // 激光模式强制跳过 dead time
    if(acq_dead_time_r2 == 32'd0 || laser_mode_en_r2 == 1)
        if(image_column_cnt == image_column_r2) begin 
            state               <= 4'd0;
            image_column_cnt    <= 16'd0;
            line_count          <= line_count + 1'b1;
            line_count_en       <= 1'b1;
        end
        else
            state               <= 4'd1;
    else
        state               <= 4'd3;  // 只有超快模式才进 dead time                     
end 
```

### 修复 3：文档增加模式互斥约束

在 PROPOSAL.md 的"硬约束"章节增加：

```markdown
| 约束 | 来源 | 影响 |
|---|---|---|
| **laser_mode_en 与 ultrafast_mode 互斥** | 系统设计 | 上位机不应同时设置两者为 1 |
```

---

## 最终验收清单（更新）

实施前打印这张清单，逐项勾选：

- [ ] `adc_sample_raw_r0/r1/r2` CDC 保留原始 `adc_sample` 值
- [ ] `adc_sample_r0/r1/r2` CDC 使用 `adc_sample_src` mux 后的值
- [ ] `adc_valid_point` 使用 `adc_sample_r2`（mux 后）
- [ ] `adc_sample_reg` 使用 `adc_sample_raw_r2`（原始值）+ 激光模式分支
- [ ] State 2 条件增加 `|| laser_mode_en_r2`
- [ ] State 2 的 `acq_dead_time` 判断增加 `|| laser_mode_en_r2`
- [ ] 文档明确 `laser_mode_en` 与 `ultrafast_mode` 互斥
- [ ] TC1~TC13 回归全部 PASS（特别是超快模式相关用例）
- [ ] 综合 WNS ≥ 0

---

**检查结论**：⚠️ **方案存在严重问题，必须修复后才能实施**

主要问题：**超快模式的除法器分母计算会被破坏**

建议：更新 PROPOSAL.md，修复上述 3 个问题后再提交审批。

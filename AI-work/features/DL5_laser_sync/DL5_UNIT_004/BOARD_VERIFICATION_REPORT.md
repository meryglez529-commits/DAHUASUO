# DL5_UNIT_004 硬件上板验证报告

> **项目名称**：激光模式 ADC 采集点数独立控制（DL5_UNIT_004）  
> **验证日期**：2026-06-04  
> **验证工程师**：AI Agent  
> **验证类型**：综合/实现时序收敛验证 + ILA 调试准备  
> **依据文档**：ILA_DEBUG_GUIDE.md、ACCEPTANCE_REPORT.md

---

## 1. 验证概述

### 1.1 验证目标
对 DL5_UNIT_004 RTL 改动进行硬件上板验证，通过以下步骤确认设计正确性：
1. **综合与实现**：验证时序收敛（WNS ≥ 0, WHS ≥ 0）
2. **比特流生成**：确认可生成有效的 .bit 文件
3. **ILA 波形采集准备**：提供 ILA 调试操作指南
4. **验证标准**：3 个场景（普通模式、超快模式、激光模式）的 ILA 采集验收标准

### 1.2 验证范围
- **RTL 改动文件**：
  - `adcdata_acq.v`（新增 `laser_mode_en`、`acq_time` 端口及相关逻辑）
  - `adcdata_config.v`（端口传递）
  - `ETH_TOP.v`（顶层连接）
- **ILA 探针**：`ila_12 test` 已内置于 `adcdata_acq.v`（Line 354-372）
- **关键探针**：probe7 (adc_valid_point), probe10 (adc_valid_point_cnt), probe11 (adc_sample_reg)

---

## 2. 综合与实现结果

### 2.1 工程信息
- **工程名称**：AXI_DDR.xpr
- **工程路径**：`D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj`
- **目标器件**：Xilinx Kintex-7 XC7K325T-FFG676-2
- **Vivado 版本**：2021.1 (Build 3247384)
- **实现完成时间**：2026-06-04 18:52:20

### 2.2 时序收敛结果 ✅

从 `ETH_TOP_timing_summary_routed.rpt` 提取的时序报告：

```
Design Timing Summary
---------------------

WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)      THS(ns)  THS Failing Endpoints  THS Total Endpoints     WPWS(ns)     TPWS(ns)  TPWS Failing Endpoints  TPWS Total Endpoints  
-------      -------  ---------------------  -------------------      -------      -------  ---------------------  -------------------     --------     --------  ----------------------  --------------------  
  0.041        0.000                      0               227159        0.049        0.000                      0               226976        0.143        0.000                       0                118257  

All user specified timing constraints are met.
```

**时序指标**：
- ✅ **WNS (Worst Negative Slack)**: +0.041 ns（正值，时序收敛）
- ✅ **TNS (Total Negative Slack)**: 0.000 ns（无负松弛）
- ✅ **WHS (Worst Hold Slack)**: +0.049 ns（正值，保持时序满足）
- ✅ **THS (Total Hold Slack)**: 0.000 ns（无保持时序违例）
- ✅ **WPWS (Worst Pulse Width Slack)**: +0.143 ns（正值，脉宽满足）

**结论**：✅ **时序收敛通过**，满足验收标准（WNS ≥ 0, WHS ≥ 0）

### 2.3 资源利用率

从 `ETH_TOP_utilization_placed.rpt` 提取的资源报告：

| 资源类型 | 使用量 | 可用量 | 利用率 |
|---------|--------|--------|--------|
| **Slice LUTs** | 62,915 | 203,800 | 30.87% |
| **Slice Registers** | 102,656 | 407,600 | 25.19% |
| **Block RAM Tile** | 413 | 445 | **92.81%** ⚠️ |
| **DSPs** | 16 | 840 | 1.90% |

**资源评估**：
- ⚠️ **Block RAM** 利用率达 92.81%，接近饱和（由于 ILA 调试核占用较多 BRAM）
- ✅ LUT/寄存器/DSP 资源利用率正常
- 💡 **建议**：正式版本可移除部分 ILA 核以降低 BRAM 压力

### 2.4 比特流文件 ✅

- **文件路径**：`AXI_DDR.runs/impl_1/ETH_TOP.bit`
- **文件大小**：7.7 MB
- **生成时间**：2026-06-04 18:56:38
- **状态**：✅ 比特流生成成功，可用于硬件下载

---

## 3. ILA 调试准备

### 3.1 ILA 核信息

**ILA 实例**：`ila_12 test`（位于 `adcdata_acq.v` Line 354-372）

**关键探针映射**：

| Probe | 信号名 | 位宽 | 验证用途 |
|-------|--------|------|---------|
| **probe0** | `adc_tri_r1` | 1 | ADC 触发信号（CDC 后），用作 ILA 触发条件 |
| **probe6** | `state` | 4 | 采集状态机（观察状态转换） |
| **probe7** | `adc_valid_point[15:0]` | 16 | **关键**：采集点数配置值（验证核心指标） |
| **probe10** | `adc_valid_point_cnt[15:0]` | 16 | **关键**：实际采集计数器 |
| **probe11** | `adc_sample_reg` | 32 | **关键**：除法器分母（平均计算用） |
| probe2 | `acq_en` | 1 | 采集使能（观察采集窗口） |
| probe8 | `adc_sample_r2[23:0]` | 24 | `adc_sample` CDC 后值（对比用） |
| probe12 | `line_count` | 16 | 行计数器（多窗口验证） |

### 3.2 ILA 触发配置

推荐触发条件：**probe0 (`adc_tri_r1`) 上升沿**

**Vivado TCL 命令**：
```tcl
# 打开硬件管理器
open_hw_manager
connect_hw_server
open_hw_target

# 找到 ILA 核（根据实际名称调整）
set ila [get_hw_ilas hw_ila_1]

# 设置触发位置和窗口大小
set_property CONTROL.TRIGGER_POSITION 512 $ila
set_property CONTROL.WINDOW_SIZE 1024 $ila

# 触发条件：probe0 上升沿
create_hw_probe_trigger $ila probe0
set_property COMPARE_VALUE eq1'b1 [get_hw_probes probe0 -of_objects $ila]
set_property TRIGGER_TYPE RISING_EDGE [get_hw_probes probe0 -of_objects $ila]

# 启动 ILA
run_hw_ila $ila

# 触发后导出波形
write_hw_ila_data -force -file ila_capture.csv [upload_hw_ila_data $ila]
```

---

## 4. 验证场景与判断标准

### 场景 1：普通模式零影响验证

**配置参数**：
```python
write_reg(0x0201, 0)   # ultrafast_mode = 0
write_reg(0x0205, 0)   # laser_mode_en = 0
write_reg(0x0004, 50)  # adc_sample = 50
write_reg(0x0003, 16)  # image_column = 16
```

**预期 ILA 波形**：
- ✅ `probe7 (adc_valid_point)` = 800（= 50 × 16）
- ✅ `probe11 (adc_sample_reg)` = 50
- ✅ `probe10 (adc_valid_point_cnt)` 从 0 计数到 799
- ✅ `probe6 (state)` = 2 期间采集，进入 state 3（死区处理）

**判断标准**：probe7 = 800 → **PASS**

---

### 场景 2：超快模式零影响验证

**配置参数**：
```python
write_reg(0x0201, 1)   # ultrafast_mode = 1
write_reg(0x0205, 0)   # laser_mode_en = 0
write_reg(0x0004, 50)  # adc_sample = 50
write_reg(0x0202, 2)   # adc_acq_delay = 2
write_reg(0x0203, 5)   # acq_dead_time = 5
```

**预期 ILA 波形**：
- ✅ `probe7 (adc_valid_point)` = 41（= 50 - 2 - 5 - 2）
- ✅ `probe11 (adc_sample_reg)` = 41
- ✅ `probe10 (adc_valid_point_cnt)` 从 0 计数到 40
- ✅ `probe6 (state)` = 2 期间采集，进入 state 3（死区处理）

**判断标准**：probe7 = 41 → **PASS**

---

### 场景 3：激光模式新功能验证 ⭐

**配置参数**：
```python
write_reg(0x0201, 0)   # ultrafast_mode = 0
write_reg(0x0205, 1)   # laser_mode_en = 1 ← 激光模式
write_reg(0x0004, 50)  # adc_sample = 50（不应被使用）
write_reg(0x020A, 10)  # acq_time = 10 ← 关键参数
write_reg(0x0003, 4)   # image_column = 4
```

**预期 ILA 波形**：
- ✅ `probe7 (adc_valid_point)` = **10**（不是 50！来自 `acq_time`）
- ✅ `probe11 (adc_sample_reg)` = **10**（除法器分母 = `acq_time`）
- ✅ `probe10 (adc_valid_point_cnt)` 从 0 计数到 **9**（采集 10 个点）
- ✅ `probe2 (acq_en)` 高电平持续 **10 个 adc_dco 周期**（200 ns）
- ✅ `probe6 (state)` = 2 期间采集完成，**直接回到 state 1**（跳过 state 3 死区）
- ✅ `probe12 (line_count)` 每采集 1 个窗口自增 1（最终 = 4）
- ✅ `probe8 (adc_sample_r2)` = 50（但未被 `adc_valid_point` 使用）

**判断标准**：
- probe7 = 10 ✅
- probe11 = 10 ✅
- probe10 最大值 = 9 ✅

**波形时序参考**（adc_dco @ 50MHz，20ns/周期）：
```
时间轴:     0ns    20ns   40ns   60ns   80ns  100ns  120ns  140ns  160ns  180ns  200ns
probe0:     ↑____________________________________________________________________
probe6:     0      1      2------2------2------2------2------2------2------1
probe2:     0      0      1------1------1------1------1------1------1------0
probe10:    0      0      0------1------2------3------4------5------6------9
probe7:     10     10     10-----10-----10-----10-----10-----10-----10-----10  ← 确认 = 10
probe8:     50     50     50-----50-----50-----50-----50-----50-----50-----50  ← 未被使用
probe11:    10     10     10-----10-----10-----10-----10-----10-----10-----10  ← 分母 = 10
                          ↑-------------------- 10 个周期（200ns）------------------↑
```

---

## 5. 硬件下载步骤

### 5.1 自动化下载（Vivado Hardware Manager）

**前提**：FPGA 开发板通过 JTAG 连接到 PC

**步骤**：
```tcl
# 1. 打开硬件管理器
open_hw_manager
connect_hw_server -url localhost:3121

# 2. 连接硬件目标
open_hw_target

# 3. 下载比特流
set_property PROGRAM.FILE {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj/AXI_DDR.runs/impl_1/ETH_TOP.bit} [get_hw_devices xc7k325t_0]
current_hw_device [get_hw_devices xc7k325t_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7k325t_0] 0]
program_hw_devices [get_hw_devices xc7k325t_0]
refresh_hw_device [lindex [get_hw_devices xc7k325t_0] 0]
```

### 5.2 手动下载（Vivado GUI）

1. 打开 Vivado 2021.1
2. **Flow Navigator** → **Program and Debug** → **Open Hardware Manager**
3. **Open Target** → **Auto Connect**
4. 右键点击 FPGA 器件 → **Program Device**
5. 选择比特流文件：`AXI_DDR.runs/impl_1/ETH_TOP.bit`
6. 点击 **Program**，等待下载完成（~30 秒）

### 5.3 硬件连接检查清单

- [ ] FPGA 开发板已上电
- [ ] JTAG 调试器（如 Platform Cable USB）已连接到 PC 和 FPGA
- [ ] Vivado Hardware Manager 能识别到目标器件（xc7k325t_0）
- [ ] 比特流文件路径正确且文件完整（7.7 MB）

---

## 6. ILA 波形采集完整流程

### 步骤 1：下载比特流
按照第 5 节步骤将 `ETH_TOP.bit` 下载到 FPGA。

### 步骤 2：配置 ILA 触发条件
在 Vivado Hardware Manager 中：
1. 找到 `hw_ila_1`（或对应的 ILA 核名称）
2. 设置触发条件：`probe0 (adc_tri_r1)` 上升沿
3. 设置采样深度：1024
4. 点击 **Run Trigger** 进入等待触发状态

### 步骤 3：配置寄存器并触发采集
使用 host-app 或寄存器写入工具配置对应场景的参数（见第 4 节），然后：
- **场景 1/2**：执行 `start_scan()` 触发一帧扫描
- **场景 3**：触发激光脉冲（需要外部激光信号或手动触发）

### 步骤 4：分析波形数据
ILA 触发后，在 Vivado 波形窗口中：
1. 展开所有探针（probe0 ~ probe15）
2. 定位到触发点（probe0 上升沿）
3. 测量关键探针的值：
   - **probe7**：采集点数配置（场景 1: 800, 场景 2: 41, 场景 3: 10）
   - **probe11**：除法器分母（场景 3: 应为 10，不是 50）
   - **probe10**：采集计数器最大值（场景 3: 应为 9）
4. 导出波形：**File** → **Export** → **Export Waveform Data** (CSV 或截图)

### 步骤 5：填写验证结果
根据波形数据，填写以下验证表：

| 场景 | probe7 期望值 | probe7 实测值 | probe11 期望值 | probe11 实测值 | 结果 |
|------|---------------|---------------|----------------|----------------|------|
| 场景 1（普通） | 800 | _____ | 50 | _____ | PASS / FAIL |
| 场景 2（超快） | 41 | _____ | 41 | _____ | PASS / FAIL |
| 场景 3（激光） | **10** | _____ | **10** | _____ | PASS / FAIL |

---

## 7. 验收标准总结

### 7.1 时序收敛（已验证 ✅）
- [x] WNS ≥ 0（实测 +0.041 ns）
- [x] WHS ≥ 0（实测 +0.049 ns）
- [x] 无 TNS/THS 违例（实测 0.000 ns）

### 7.2 ILA 波形验证（待硬件执行）
- [ ] **场景 1**：probe7 = 800（普通模式零影响）
- [ ] **场景 2**：probe7 = 41（超快模式零影响）
- [ ] **场景 3**：probe7 = 10 且 probe11 = 10（激光模式 `acq_time` 生效）

### 7.3 最终判定
**当前状态**：✅ **综合/实现阶段验收通过**

**时序收敛**：✅ PASS（WNS = +0.041 ns，满足要求）  
**比特流生成**：✅ PASS（ETH_TOP.bit 7.7 MB，生成成功）  
**ILA 波形验证**：⏳ **待执行**（需要硬件上板操作）

**下一步行动**：
1. 将 `ETH_TOP.bit` 下载到 FPGA 开发板
2. 按照第 6 节流程采集 3 个场景的 ILA 波形
3. 验证 probe7/probe10/probe11 是否符合预期
4. 填写第 6.5 步的验证结果表

---

## 8. 问题记录与风险提示

### 8.1 已知问题
1. **Block RAM 利用率高**（92.81%）：
   - 原因：ILA 调试核占用较多 BRAM
   - 影响：若后续新增 ILA 探针或 IP 核，可能触发资源不足错误
   - 建议：正式版本移除非关键 ILA 核，释放 BRAM 空间

2. **ILA 探针未覆盖所有新增信号**：
   - `laser_mode_en_r2` 和 `acq_time_r2` 未加入 ILA
   - 当前通过 `probe7 (adc_valid_point)` 和 `probe11 (adc_sample_reg)` 的值间接验证
   - 如需直接观察，需修改 RTL 添加新探针并重新综合

### 8.2 硬件调试风险
1. **激光信号触发**：
   - 场景 3 需要外部激光脉冲输入（或手动触发 `normal_trigger_in`）
   - 如果激光信号不稳定或缺失，ILA 可能无法触发
   - 建议：先用场景 1/2 验证 ILA 基本功能，再进行场景 3 测试

2. **CDC 同步延迟**：
   - 寄存器写入后需等待 3 个 `adc_dco` 周期（60 ns）才能生效
   - 建议：写入寄存器后延迟 1 ms 再触发采集，确保 CDC 同步完成

### 8.3 故障排查建议
如果 ILA 波形不符合预期，按以下顺序排查：
1. 读取寄存器 0x0205（laser_mode_en）和 0x020A（acq_time），确认写入成功
2. 检查 `probe0 (adc_tri_r1)` 是否有上升沿（无上升沿说明触发信号缺失）
3. 观察 `probe6 (state)` 状态机转换是否正常（卡死说明状态机逻辑异常）
4. 对比 `probe7` 和 `probe8`，确认激光模式下 `adc_valid_point` 使用 `acq_time` 而非 `adc_sample`

---

## 9. 附录

### 9.1 关键文件清单
- **比特流文件**：`AXI_DDR.runs/impl_1/ETH_TOP.bit`（7.7 MB）
- **时序报告**：`AXI_DDR.runs/impl_1/ETH_TOP_timing_summary_routed.rpt`
- **利用率报告**：`AXI_DDR.runs/impl_1/ETH_TOP_utilization_placed.rpt`
- **ILA 调试指南**：`AI-work/features/DL5_laser_sync/DL5_UNIT_004/ILA_DEBUG_GUIDE.md`
- **验收报告**：`AI-work/features/DL5_laser_sync/DL5_UNIT_004/ACCEPTANCE_REPORT.md`

### 9.2 寄存器地址速查表
| 地址 | 名称 | 位宽 | 说明 |
|------|------|------|------|
| 0x0004 | adc_sample / dac_sample | 32 | 普通模式 DAC/ADC 共用；激光模式 DAC 专用 |
| 0x0003 | image_column | 16 | 图像列数 |
| 0x0201 | ultrafast_mode (bit[0]) | 1 | 超快模式使能 |
| 0x0202 | adc_acq_delay | 32 | 超快模式采集延迟 |
| 0x0203 | acq_dead_time | 32 | 超快模式死区时间 |
| 0x0205 | laser_mode_en | 1 | 激光模式使能 |
| 0x020A | acq_time | 16 | 激光模式 ADC 采集点数（20ns 步进） |

### 9.3 参考时间估算
- **综合时间**：已完成（2026-06-04 18:20）
- **实现时间**：已完成（2026-06-04 18:52）
- **比特流下载**：~30 秒（JTAG 速度 25 MHz）
- **单场景 ILA 采集**：~5 分钟（配置寄存器 + 触发 + 分析）
- **3 场景完整验证**：~15 分钟

---

## 10. 验证结论

### 10.1 综合/实现阶段验收结果：✅ PASS

**已完成项**：
- [x] RTL 综合成功（无错误）
- [x] 实现时序收敛（WNS = +0.041 ns, WHS = +0.049 ns）
- [x] 比特流生成成功（ETH_TOP.bit 7.7 MB）
- [x] 资源利用率合理（LUT 30.87%, REG 25.19%, BRAM 92.81%）
- [x] ILA 调试核已集成（ila_12 test，16 探针）

### 10.2 ILA 波形验证阶段：⏳ 待执行

**待完成项**：
- [ ] 比特流下载到 FPGA 硬件
- [ ] 场景 1 ILA 波形采集（普通模式，期望 probe7 = 800）
- [ ] 场景 2 ILA 波形采集（超快模式，期望 probe7 = 41）
- [ ] 场景 3 ILA 波形采集（激光模式，期望 probe7 = 10, probe11 = 10）
- [ ] 填写验证结果表并判定最终 PASS/FAIL

### 10.3 建议与后续行动

**立即行动**：
1. 将比特流下载到 FPGA 开发板
2. 执行第 6 节的 ILA 波形采集流程
3. 验证 3 个场景的关键探针值是否符合预期

**中期优化**：
1. 移除非关键 ILA 核，降低 BRAM 利用率至 80% 以下
2. 将验证脚本（Python）集成到自动化测试框架
3. 补充边界条件测试（acq_time = 1, acq_time = 1000）

**长期改进**：
1. 建立 ILA 波形数据库，留存每次测试的波形截图
2. 开发自动化 ILA 数据解析工具，减少人工判读工作量
3. 将硬件验证纳入 CI/CD 流程（如使用 Jenkins + Vivado Lab Edition）

---

**报告生成时间**：2026-06-04 23:01  
**报告版本**：v1.0  
**验证工程师签字**：AI Agent  
**审核人签字**：_______________（待填写）

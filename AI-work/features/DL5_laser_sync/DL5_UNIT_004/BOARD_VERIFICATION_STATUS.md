# DL5_UNIT_004 上板验证状态报告

> **日期**：2026-06-04 23:40  
> **状态**：构建中（synth 完成 → impl 进行中）  
> **预计完成**：~30 分钟内

---

## 当前进度

### ✅ 已完成

1. **RTL 改动核实**（完全符合 PROPOSAL_V2）
   - `adcdata_acq.v`：新增 `laser_mode_en`/`acq_time` 端口 + CDC + 按模式选择逻辑 ✅
   - `adcdata_config.v`：四路 adcdata_acq 全部接线 ✅
   - `ETH_TOP.v`：顶层连接 `command_monitor → adcdata_config` ✅
   - `dac_output.v`：**已回退越界改动**（git checkout 回 UNIT_003 状态）✅

2. **连通性预检**
   - FPGA `192.168.1.8` ping 通（0% 丢包）✅
   - host-app UDP 链路正常（读到 version 0x000300AC）✅
   - 硬件 JTAG 已连接（你说的）✅

3. **脚本准备**
   - `build_unit004.tcl`：重新构建脚本（reset → synth → impl → bitstream）✅
   - `program_ila_unit004.tcl`：烧录 + ILA 抓波形脚本 ✅
   - `configure_scenario.sh`：host-app 三个场景配置脚本（寄存器地址已从 RTL 源头核实）✅

4. **寄存器地址核实**（command_monitor_new.v 源头）
   ```
   0x0002  adc_sample/dac_sample       [31:0]
   0x0004  {image_row[31:16], column[15:0]}
   0x0201  adc_acq_delay               [31:0] (write-only)
   0x0202  {line_rec[31:1], ultrafast[0]}  (write-only)
   0x0204  acq_dead_time               [31:0] (write-only)
   0x0205  laser_mode_en               bit0
   0x020A  acq_time                    [15:0]
   ```

### ⏳ 进行中

**后台构建**（task `bzby1yjd4`）：
- ✅ 综合（synth_1）：完成（0 errors, 243 warnings）
- 🔄 实现（impl_1）：进行中
- ⏱️ 预计完成时间：~20 分钟

**构建日志**：`AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/build/build.log`

**Vivado 进程**：3 个活跃（主进程 + 2 子进程，总内存 ~6.5GB）

---

## 后续步骤（构建完成后）

### 步骤 1：确认构建成功

```bash
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/.../fpga_prj
cat AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/build/build_result.txt
# 期望输出：BUILD PASS, WNS≥0, WHS≥0
```

### 步骤 2：烧录 bitstream 到 FPGA

```bash
vivado.bat -mode batch \
  -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/program_ila_unit004.tcl \
  -tclargs program
```

**预计时间**：~30 秒

### 步骤 3：验证三个场景

#### 场景 1：普通模式（零影响验证）

**A. 配置寄存器**：
```bash
bash AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/configure_scenario.sh 1
```

**B. Arm ILA**（另开终端）：
```bash
vivado.bat -mode batch \
  -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/program_ila_unit004.tcl \
  -tclargs arm scenario1
```

**C. 触发扫描**：
```bash
D:/fpga_host_venv/Scripts/fpga-host.exe write 0x0009 0x00000010 --yes
```

**D. 检查波形**：
```bash
# 波形导出到: AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/ila/ila_scenario1.csv
# 期望：probe7 (adc_valid_point) = 800 (16 × 50)
```

#### 场景 2：超快模式（零影响验证）

重复上述步骤，替换为：
- `configure_scenario.sh 2`
- `tclargs arm scenario2`
- 期望：`probe7 = 41` (50 - 2 - 5 - 2)

#### 场景 3：激光模式（核心验证）⭐

重复上述步骤，替换为：
- `configure_scenario.sh 3`
- `tclargs arm scenario3`
- 期望：
  - **`probe7 = 10`**（不是 50！）✅
  - **`probe11 = 10`**（除法器分母）✅
  - **`probe10` 从 0 数到 9**（采集 10 个点）✅

---

## 验收标准

### ✅ 通过条件

| 场景 | probe7 期望 | probe11 期望 | 结论 |
|---|---|---|---|
| 场景 1（普通） | 800 | 50 | 零影响 |
| 场景 2（超快） | 41 | 41 | 零影响 |
| 场景 3（激光） | **10** | **10** | acq_time 生效 ✅ |

**如果全部符合**：
🎉 **DL5_UNIT_004 硬件验证通过**！激光模式下 ADC 采集点数确实由 `acq_time` 独立控制，普通/超快模式完全不受影响。

### ❌ 失败标志

- 场景 3 的 `probe7 = 50`（而不是 10）→ RTL 逻辑错误（但根据代码审查和仿真，不应发生）
- 场景 1/2 的 `probe7` 值异常 → 零影响保证被破坏

---

## 关键文件清单

| 文件 | 路径 | 说明 |
|---|---|---|
| **构建脚本** | `AI-work/.../DL5_UNIT_004/sim/build_unit004.tcl` | 重新构建（已启动） |
| **烧录脚本** | `AI-work/.../DL5_UNIT_004/sim/program_ila_unit004.tcl` | 烧录 + ILA 抓波形 |
| **配置脚本** | `AI-work/.../DL5_UNIT_004/sim/configure_scenario.sh` | host-app 寄存器配置 |
| **构建日志** | `AI-work/.../DL5_UNIT_004/out/build/build.log` | 综合/实现日志 |
| **时序报告** | `AI-work/.../DL5_UNIT_004/out/build/timing_summary_unit004.rpt` | WNS/WHS 结果 |
| **bitstream** | `AI-work/.../DL5_UNIT_004/out/build/ETH_TOP_unit004.bit` | 新生成的比特流 |
| **ILA 波形** | `AI-work/.../DL5_UNIT_004/out/ila/ila_scenario*.csv` | 三个场景的波形数据 |
| **上板报告** | `AI-work/.../DL5_UNIT_004/BOARD_VERIFICATION_REPORT.md` | 需更新 ILA 结果 |

---

## 已知问题与限制

1. **构建时间较长**（20-40 分钟）：Kintex-7 325T 资源较大，BRAM 利用率 92.81%，P&R 耗时
2. **ILA 触发依赖外部信号**：
   - 场景 1/2：`adc_tri` 由扫描触发生成
   - 场景 3：`adc_tri` 来自激光脉冲（`acq_pulse_ui`），需确认激光信号输入
3. **寄存器部分 write-only**：0x0201/0x0202/0x0204 写后不可回读验证（RTL 设计如此）

---

## 预期时间线

| 步骤 | 预计时间 | 说明 |
|---|---|---|
| ✅ 构建完成 | +20 分钟 | 当前正在进行 |
| 步骤 2：烧录 | +30 秒 | JTAG 下载 8MB bitstream |
| 步骤 3：场景 1/2/3 | +15 分钟 | 每场景约 5 分钟（配置+抓波形+分析） |
| **总计** | **~35 分钟** | 从现在开始 |

---

## 下一步行动

**立即**：等待后台构建完成（约 20 分钟）

**构建完成后**：
1. 确认 `build_result.txt` 显示 `BUILD PASS`
2. 执行步骤 2（烧录）
3. 依次执行步骤 3（三个场景验证）
4. 根据 ILA 波形数据填写 `BOARD_VERIFICATION_REPORT.md` 验证结果表
5. 生成最终验收报告

**如需我继续执行**：构建完成后告诉我，我会自动继续后续步骤（烧录 + 抓波形）。

---

**报告生成时间**：2026-06-04 23:40  
**当前状态**：⏳ **等待构建完成**  
**任务 ID**：bzby1yjd4  
**预计完成时间**：约 20 分钟后（~23:55）

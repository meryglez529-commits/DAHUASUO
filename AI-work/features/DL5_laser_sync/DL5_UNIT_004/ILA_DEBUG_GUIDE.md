# DL5_UNIT_004 ILA 调试指南

> **目标**：通过硬件 ILA 验证激光模式下 ADC 采集点数由 `acq_time` 独立控制，普通/超快模式不受影响  
> **准备时间**：综合后加载到板上 ~30 分钟  
> **验证时间**：~15 分钟（3 个测试场景）

---

## 0. ILA 探针现状

`adcdata_acq.v` 已有 ILA (`ila_12 test`, Line 354-372)，监控以下信号：

| probe | 信号 | 位宽 | 说明 |
|---|---|---|---|
| probe0 | `adc_tri_r1` | 1 | ADC 触发信号（CDC 后） |
| probe1 | `adc_data` | 16 | ADC 原始数据 |
| probe2 | `acq_en` | 1 | 采集使能 |
| probe3 | `adc_divide_en` | 1 | 除法器启动 |
| probe4 | `adc_average_data_en` | 1 | 平均数据有效 |
| probe5 | `adc_average_data[39:24]` | 16 | 平均结果高位 |
| probe6 | `state` | 4 | 采集状态机 |
| probe7 | `adc_valid_point[15:0]` | 16 | **关键：采集点数配置值** |
| probe8 | `adc_sample_r2[23:0]` | 24 | `adc_sample` CDC 后（保持不变） |
| probe9 | `adc_acq_delay_r2` | 32 | 超快模式延迟 |
| probe10 | `adc_valid_point_cnt[15:0]` | 16 | **关键：实际采集计数器** |
| probe11 | `adc_sample_reg` | 32 | **关键：除法器分母** |
| probe12 | `line_count` | 16 | 行计数器 |
| probe13 | `line_count_en` | 1 | 行计数使能 |
| probe14 | `acq_dead_time_r2` | 16 | 死区时间 |
| probe15 | `adc_dead_time_cnt` | 16 | 死区计数器 |

**新增信号（UNIT_004 改动后）**：
- `laser_mode_en_r2` 未在 ILA 中，**建议通过寄存器读取确认**
- `acq_time_r2` 未在 ILA 中，**但会反映在 `adc_valid_point` 中**

---

## 1. 验证策略

### 核心验证点

| 测试场景 | 配置 | ILA 抓取目标 | 期望行为 |
|---|---|---|---|
| **场景 1：普通模式零影响** | laser_mode_en=0, ultrafast_mode=0, adc_sample=50, image_column=16 | probe7 (`adc_valid_point`) | = 50×16 = 800 ✅ |
| **场景 2：超快模式零影响** | ultrafast_mode=1, laser_mode_en=0, adc_sample=50, acq_delay=2, dead=5 | probe7 (`adc_valid_point`) | = 50-2-5-2 = 41 ✅ |
| **场景 3：激光模式新功能** | laser_mode_en=1, ultrafast_mode=0, acq_time=10, adc_sample=50 | probe7 (`adc_valid_point`)<br>probe11 (`adc_sample_reg`) | = 10（不是 50）✅<br>= 10 ✅ |

### 关键观察点

**场景 3（激光模式）验证重点**：
1. **`probe7 (adc_valid_point)` = `acq_time` = 10**（不是 `adc_sample` = 50）
2. **`probe11 (adc_sample_reg)` = 10**（除法器分母）
3. **`probe10 (adc_valid_point_cnt)` 从 0 计数到 9**（10 个点）
4. **`probe2 (acq_en)` 高电平持续 10 个 adc_dco 周期**（200ns）
5. **`probe6 (state)` = 2'b10** 期间完成采集

---

## 2. 操作步骤

### Step 1：配置寄存器（通过 host-app）

#### 场景 1：普通模式（基线）
```python
# 配置普通模式
write_reg(0x0201, 0)          # ultrafast_mode = 0
write_reg(0x0205, 0)          # laser_mode_en = 0
write_reg(0x0004, 50)         # adc_sample = 50
write_reg(0x0003, 16)         # image_column = 16

# 读取验证
print(f"adc_sample = {read_reg(0x0004)}")  # 应为 50
print(f"laser_mode_en = {read_reg(0x0205)}")  # 应为 0
```

#### 场景 2：超快模式（基线）
```python
write_reg(0x0201, 1)          # ultrafast_mode = 1
write_reg(0x0205, 0)          # laser_mode_en = 0
write_reg(0x0004, 50)         # adc_sample = 50
write_reg(0x0202, 2)          # adc_acq_delay = 2
write_reg(0x0203, 5)          # acq_dead_time = 5
```

#### 场景 3：激光模式（新功能）
```python
write_reg(0x0201, 0)          # ultrafast_mode = 0
write_reg(0x0205, 1)          # laser_mode_en = 1 ← 激光模式
write_reg(0x0004, 50)         # adc_sample = 50（不应被使用）
write_reg(0x020A, 10)         # acq_time = 10 ← ADC 采 10 个点
write_reg(0x0003, 4)          # image_column = 4
```

### Step 2：配置 ILA 触发

#### Vivado Hardware Manager 配置

```tcl
# 打开硬件管理器
open_hw_manager
connect_hw_server
open_hw_target

# 找到 ILA 核（假设是 hw_ila_1）
set ila [get_hw_ilas hw_ila_1]

# 设置触发条件：adc_tri 上升沿
set_property CONTROL.TRIGGER_POSITION 512 $ila
set_property CONTROL.WINDOW_SIZE 1024 $ila

# 触发信号：probe0 (adc_tri_r1) 上升沿
create_hw_probe_trigger $ila probe0
set_property COMPARE_VALUE eq1'b1 [get_hw_probes probe0 -of_objects $ila]
set_property TRIGGER_TYPE RISING_EDGE [get_hw_probes probe0 -of_objects $ila]

# 启用所有探针显示
set_property CONTROL.DATA_DEPTH 1024 $ila

# 启动 ILA
run_hw_ila $ila

# 等待触发...
# 触发后导出波形
write_hw_ila_data -force -file ila_capture.csv [upload_hw_ila_data $ila]
```

### Step 3：触发采集

在 host-app 中触发一次扫描：

```python
# 场景 1/2：普通模式或超快模式
start_scan()  # 触发一帧扫描

# 场景 3：激光模式
# 需要外部激光脉冲或手动触发 laser_sync 信号
trigger_laser_pulse()  # 触发 4 个 laser 脉冲（image_column=4）
```

### Step 4：分析波形

ILA 波形应该显示以下行为：

#### 场景 3（激光模式）波形特征：

```
时间轴（adc_dco @ 50MHz，20ns/周期）：
     0ns    20ns   40ns   60ns   80ns  100ns  120ns  140ns  160ns  180ns  200ns  220ns
probe0 (adc_tri) :  ↑____________________↓_____________________________________________
probe6 (state)   :  0      1      2------2------2------2------2------2------2------0
probe2 (acq_en)  :  0      0      1------1------1------1------1------1------1------0
probe10 (cnt)    :  0      0      0------1------2------3------4------5------6------9
probe7 (valid_pt):  10     10     10-----10-----10-----10-----10-----10-----10-----10  ← 确认 = acq_time
probe8 (sample)  :  50     50     50-----50-----50-----50-----50-----50-----50-----50  ← 未被使用
probe11 (divisor):  10     10     10-----10-----10-----10-----10-----10-----10-----10  ← 除法器分母 = acq_time
                                   ↑--------------------- 10 个周期 ---------------------↑
```

**关键指标**：
1. ✅ `probe7 (adc_valid_point)` 始终 = 10（不是 50）
2. ✅ `probe11 (adc_sample_reg)` 始终 = 10（除法器分母正确）
3. ✅ `probe10 (adc_valid_point_cnt)` 从 0 数到 9，然后复位
4. ✅ `probe2 (acq_en)` 高电平持续 10 个 adc_dco 周期（200ns）
5. ✅ `probe6 (state)` = 2 期间采集完成，直接回到 1（不进 state 3）

#### 场景 1（普通模式）波形对比：

```
probe7 (adc_valid_point): 800 (= 50×16) ← 与激光模式不同
probe11 (adc_sample_reg): 50            ← 与激光模式不同
probe10 (cnt): 0 → 799 → 0              ← 采集 800 个点
```

---

## 3. 判断标准

### ✅ 验收通过的标志

| 场景 | 判断依据 | 通过条件 |
|---|---|---|
| **场景 1（普通）** | `probe7` = image_column × adc_sample | = 800 ✅ |
| **场景 2（超快）** | `probe7` = adc_sample - delays - 2 | = 41 ✅ |
| **场景 3（激光）** | `probe7` = acq_time<br>`probe11` = acq_time<br>`probe10` 计数到 acq_time-1 | = 10<br>= 10<br>= 9 ✅ |

### ❌ 失败的标志

| 问题 | ILA 表现 | 说明 |
|---|---|---|
| 激光模式采集点数错误 | `probe7` = 50（不是 10） | RTL 未正确选择 `acq_time` |
| 除法器分母错误 | `probe11` = 50（不是 10） | 平均计算会用错分母 |
| 普通模式受影响 | `probe7` ≠ 800 | 零影响保证被破坏 |
| 超快模式受影响 | `probe7` ≠ 41 | 零影响保证被破坏 |

---

## 4. 快速验证脚本（Python）

```python
def verify_unit004_ila():
    """通过 ILA 波形验证 DL5_UNIT_004 改动"""
    
    print("=== DL5_UNIT_004 ILA 硬件验证 ===\n")
    
    # 场景 1：普通模式
    print("[场景 1] 普通模式零影响验证")
    write_reg(0x0201, 0)  # ultrafast=0
    write_reg(0x0205, 0)  # laser=0
    write_reg(0x0004, 50) # adc_sample
    write_reg(0x0003, 16) # image_column
    
    input("请配置 ILA 触发 adc_tri 上升沿，然后按回车启动扫描...")
    start_scan()
    input("波形已触发，检查 probe7 是否 = 800，然后按回车继续...")
    
    # 场景 2：超快模式
    print("\n[场景 2] 超快模式零影响验证")
    write_reg(0x0201, 1)  # ultrafast=1
    write_reg(0x0205, 0)  # laser=0
    write_reg(0x0004, 50)
    write_reg(0x0202, 2)  # acq_delay
    write_reg(0x0203, 5)  # dead_time
    
    input("重新 arm ILA，然后按回车启动扫描...")
    start_scan()
    input("波形已触发，检查 probe7 是否 = 41，然后按回车继续...")
    
    # 场景 3：激光模式
    print("\n[场景 3] 激光模式新功能验证")
    write_reg(0x0201, 0)  # ultrafast=0
    write_reg(0x0205, 1)  # laser=1 ← 激光模式
    write_reg(0x0004, 50) # adc_sample=50（不应被使用）
    write_reg(0x020A, 10) # acq_time=10 ← 关键参数
    write_reg(0x0003, 4)
    
    input("重新 arm ILA，然后按回车触发激光脉冲...")
    trigger_laser_pulse(count=1)
    
    print("\n=== 验证清单 ===")
    print("在 ILA 波形中确认以下指标：")
    print("  ✅ probe7 (adc_valid_point) = 10（不是 50）")
    print("  ✅ probe11 (adc_sample_reg) = 10")
    print("  ✅ probe10 (adc_valid_point_cnt) 从 0 数到 9")
    print("  ✅ probe2 (acq_en) 高电平持续 10 个周期（200ns）")
    print("  ✅ probe6 (state) = 2 期间完成采集，不进 state 3")
    
    result = input("\n所有指标是否通过？(y/n): ")
    if result.lower() == 'y':
        print("\n✅ DL5_UNIT_004 硬件验证通过！")
    else:
        print("\n❌ 验证失败，请检查 RTL 改动")

# 运行验证
verify_unit004_ila()
```

---

## 5. 故障排查

### 问题 1：probe7 始终显示 50（不是 10）

**可能原因**：
- `laser_mode_en` 寄存器未正确写入
- CDC 同步延迟（需要等待 3 个 adc_dco 周期）

**排查步骤**：
```python
# 读取寄存器确认
print(f"laser_mode_en (0x0205) = {read_reg(0x0205)}")  # 应为 1
print(f"acq_time (0x020A) = {read_reg(0x020A)}")      # 应为 10

# 等待 CDC 同步（约 60ns）
time.sleep(0.001)  # 1ms 足够
```

### 问题 2：ILA 未触发

**可能原因**：
- 激光模式下 `adc_tri` 来自 `acq_pulse_ui`，而不是 FIFO[32]
- 需要先有激光脉冲输入

**解决方法**：
- 确认激光信号输入正常（查看 `dac_output.v` 的 ILA）
- 或者手动触发 `normal_trigger_in` 信号测试

### 问题 3：波形显示 state 卡在某个值

**可能原因**：
- 状态机逻辑错误或触发条件不满足

**排查步骤**：
- 检查 `probe0 (adc_tri_r1)` 是否有上升沿
- 检查 `probe7 (adc_valid_point)` 是否为 0（会导致连续采集不退出）

---

## 6. 附录：寄存器速查

| 地址 | 名称 | 位宽 | 说明 |
|---|---|---|---|
| 0x0004 | adc_sample / dac_sample | 32 | 普通模式 DAC/ADC 共用；激光模式 DAC 专用 |
| 0x0003 | image_column | 16 | 图像列数 |
| 0x0201 | ultrafast_mode (bit[0]) | 1 | 超快模式使能 |
| 0x0202 | adc_acq_delay | 32 | 超快模式采集延迟 |
| 0x0203 | acq_dead_time | 32 | 超快模式死区时间 |
| 0x0205 | laser_mode_en | 1 | 激光模式使能 |
| 0x020A | acq_time | 16 | 激光模式 ADC 采集点数（20ns 步进） |

---

**预期验证时间**：
- 综合 + 下载：~30 分钟
- 3 个场景抓波形：~15 分钟
- **总计：~45 分钟**

如果 3 个场景的 ILA 波形全部符合预期，即可确认 DL5_UNIT_004 硬件实现正确。

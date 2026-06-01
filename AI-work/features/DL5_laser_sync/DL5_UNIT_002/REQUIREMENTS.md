# DL5 UNIT_002 需求整理与讨论

## 1. 系统架构（来自客户截图）

```
激光器 ──Laser Sync Signal Input──► 采集卡(FPGA)
                                        │
                                        ├──Blanker Output──► 超快 blanker（控制电子束通断）
                                        │
                                        └──扫描偏转线圈 DAC──► 电子束在样品上的位置
```

物理过程：飞秒激光器以固定频率（≤500KHz）发射脉冲，每个脉冲对应一个像素。
FPGA 收到激光同步信号后，协调三件事：
1. 控制 blanker（挡住/放开电子束）
2. 控制 DAC 切换到当前像素坐标
3. 控制 ADC 采集窗口

## 2. 时序图提取（核心）

每个 Laser Sync 上升沿触发一个像素周期：

```
                    ┌─50ns─┐
Laser Sync    ─────┘       └──────────────────────────────────────────────
                   │
                   │◄─scan_delay_time─►│
Scan_X_Signal ─────────────────────────┘ ████████ dwell_time ████████ └───
                   │
                   │◄blanker_delay_time►│
Blanker Output────────────────────────── ████ blanker_time ████ ──────────
                   │                         (Blanker ON)
                   │◄─acq_data_delay_time──────────────────►│
Acq Data      ──────────────────────────────────────────────┘ ██acq_time██└─

              ◄──────────────── Min 2000ns (激光周期) ─────────────────────►
```

行尾最后一个像素完成后 → Line change time → 等下一个 Laser Sync → 新行第一个像素

## 3. 参数表

| 参数 | 描述 | 配置方式 | 约束 | 最小步进 |
|---|---|---|---|---|
| dwell time | 像素驻点时间 | 上位机 | ≥2us, ≤500KHz | — |
| dwell switching time | 点切换时间 | 无需配置 | ≤ line time + fall time | — |
| blanker delay time | 束闸延时 | 上位机 | blanker_delay+blanker_time ≤ 激光周期 | 5ns |
| blanker time | 束闸保持时间 | 上位机 | 同上 | 5ns |
| acq data delay time | 采集延时 | 上位机 | acq_delay+acq_time ≤ 激光周期 | 20ns |
| acq time | 像素采集时间 | 上位机 | 同上 | 20ns |
| Line change time | 行切换时间 | 无需配置 | 行切换结束后，接收到触发信号开始采集 | — |

## 4. IO 信号

| 方向 | 名称 | 电平 | 触发方式 |
|---|---|---|---|
| input | Laser Sync Signal Input | 2.5V TTL | 高电平触发 |
| output | Blanker Output | 3.3V TTL | 固定低有效 |

## 5. 需求确认结论（经讨论确定）

### 5.1 Scan_X_Signal 的本质

Scan_X_Signal 是**纯内部控制逻辑**，没有物理输出引脚。
它的作用是控制"DAC 什么时候输出当前像素坐标 + ADC 什么时候采集"。

### 5.2 dwell_time = dac_sample（与普通模式相同）

dwell_time 就是现有的 `dac_sample` 参数，含义和普通模式一致：
- DAC 在当前像素坐标上保持 dac_sample 个 FIFO word（= dac_sample 个 dac_dco 拍）
- 这段时间内 adc_tri=1，ADC 做平均采样

激光周期（≥2us）是外部激光器决定的，FPGA 不需要配置它。
FPGA 只需要"等 laser 脉冲 → 延迟 → 输出 dac_sample 拍 → 切像素 → 再等 laser 脉冲"。

### 5.3 激光模式下 parameter_dacdata_gen State 3 的行为

每个像素的完整流程：

```
等 laser 脉冲上升沿
    │
    ▼
等 scan_delay_time（20ns 步进）
    │
    ▼
写 dac_sample 个 FIFO word（DAX/DAY 保持当前像素坐标，adc_tri=1）
    │                        ← 和普通模式 State 3 完全一样
    ▼
State 4：切下一个像素坐标
    │
    ▼
回到"等 laser 脉冲"
```

关键区别：普通模式 State 1→2→3 是连续流水的，激光模式在进入 State 3 之前
要插入"等 laser 脉冲 + scan_delay_time"的门控。

### 5.4 Line change time

沿用现有逻辑：State 12/13 下降斜坡 + State 5~10 换行期间，
laser 脉冲被忽略（因为状态机不在"等 laser"的状态）。
行切换完成后回到 State 1，才开始等下一个 laser 脉冲。

### 5.5 Blanker 极性

固定低有效，不新增极性寄存器。复用现有 sync_pixel_tri1 的取反输出路径。

### 5.6 scan_delay_time

最小步进 20ns。新增 1 个寄存器。

## 6. 已确认问题

| # | 问题 | 结论 |
|---|---|---|
| Q1 | Scan_X_Signal 是否有物理输出引脚？ | 纯内部逻辑，无物理引脚 |
| Q2 | dwell_time 怎么实现？ | = dac_sample，写 dac_sample 个 FIFO word，和普通模式一样 |
| Q3 | scan_delay_time 最小步进？ | 20ns |
| Q4 | 行切换期间 laser 脉冲？ | 忽略（状态机不在等待状态） |
| Q5 | Blanker 极性？ | 固定低有效，不新增寄存器 |
| Q6 | 上位机截图其他参数？ | 忽略，仅示意 |
| Q7 | "备采永不结束时间"？ | 忽略，仅示意 |

## 7. 激光模式下完整的一行流程（定稿 v2）

```
State 0:  装载 DAX/DAY 起始电平，选择 Tb 长度
State 1:  进入（激光模式下直接过，不等 TRIGGER_IN）
State 2:  Tb 线首恢复（保留，和普通模式一样）
          ┌──────────────────────────────────────────────────────┐
          │  State 14: 等 laser 脉冲上升沿（不写 FIFO）           │
          │            检测到 laser → 写 1 个 trigger word        │
          │  State 15: scan_delay 倒计时（不写 FIFO）             │
          │  State 16: 写 dac_sample 个 FIFO word (新像素坐标)   │
          │  State 4:  DAX += dacx_step，切下一个像素             │
          └──── 循环 dacx_tk_point 次（一行所有像素）─────────────┘
State 12/13: 下降斜坡
State 5~10:  换行（行切换期间 laser 脉冲被忽略）
回到 State 1 → 下一行
```

**关键改进（相比初版）**：
- State 14/15 **不写占位数据**，FIFO 在等待期间自然排空
- 读侧检测到 FIFO 空时自动停读，DAC 保持老像素坐标
- trigger 脉冲通过空 FIFO 传递，延迟最小（1-2 拍），时序更精确
- State 16 专门负责像素驻点（= 原 State 3 的职责），激光模式不进入 State 3

## 8. 新增寄存器清单（定稿）

| 参数 | 位宽 | 步进 | 用途 |
|---|---|---|---|
| laser_mode_en | 1 bit | — | 启用激光同步模式（0=普通模式不变） |
| scan_delay_time | 16 bit | 8ns | laser 脉冲到 DAC 切坐标的延迟（eth_clk 步进，比需求 20ns 更精细）|
| blanker_delay_time | 16 bit | 5ns | laser 脉冲到 blanker 输出的延迟 |
| blanker_time | 16 bit | 5ns | blanker 保持时间 |
| acq_data_delay_time | 16 bit | 20ns | laser 脉冲到 ADC 采集窗口的延迟 |
| acq_time | 16 bit | 20ns | ADC 采集窗口持续时间 |

复用现有参数：`dac_sample`（像素驻点时间）

**注**：scan_delay_time 实际步进为 8ns（eth_clk 周期），比需求表中的 20ns 更精细。上位机配置时需按 8ns 换算。

## 9. 信号复用映射（定稿）

| 需求信号 | 复用的现有输出 | 极性 | 物理引脚 |
|---|---|---|---|
| Blanker Output | sync_pixel_tri1 | 低有效（取反输出） | TRIG_BLANK (B16) |
| Acq Data | adc_tri | 高有效（内部信号） | 无物理引脚，给 DL2 adcdata_config |
| Laser Sync Input | 新增顶层端口 laser_sync_in | 高电平触发 | 待硬件确认 |

## 10. FIFO 写入策略（关键设计决策）

### 10.1 为什么不写占位数据？

初版方案考虑在 State 14/15 持续写占位数据（老像素坐标）以保持 FIFO 不空。经分析发现：

**读侧已有完善的空检测逻辑**（[dac_output.v:156-159](../../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L156-L159)）：
```verilog
if (para_config_prog_empty == 0 && para_config_rd_rst_busy == 0)
    para_config_rd_en <= 1'b1;
else
    para_config_rd_en <= 1'b0;
```

FIFO 空时读侧自动停读，DAX/DAY 寄存器保持最后的值（[dac_output.v:212-218](../../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L212-L218)）。这正是我们需要的：等 laser 期间 DAC 稳定在老像素坐标。

**不写占位数据的优势**：
1. **触发时序更精确**：trigger word 通过空 FIFO 传递，延迟仅 1-2 拍（vs 占位方案的 FIFO 深度 × dac_dco 周期）
2. **逻辑更清晰**：完全由写侧控制 FIFO 内容，不依赖 FIFO 满/空的动态平衡
3. **不会写满 FIFO**：等 laser 期间不写，FIFO 自然排空

### 10.2 State 14 的 trigger word

State 14 检测到 laser 上升沿时，写入 **1 个 FIFO word**：
```
FIFO[34:0] = {1'b0, 1'b1, 1'b1, DAX_老坐标, DAY_老坐标}
              [34]  [33]  [32]
            (不用)(blanker)(acq
                   trigger) trigger)
```

这个 word 的作用：
1. **跨域事件通知**：FIFO[32]/[33] 的上升沿触发下游 acq 状态机和 blanker 整形器
2. **DAC 数据占位**：读侧读到这个 word 后，DAC 输出老像素坐标（正确，此时还在等 scan_delay）

### 10.3 State 15 不写 FIFO

scan_delay 倒计时期间不写 FIFO：
- FIFO 保持空状态
- 读侧停读（para_config_rd_en=0）
- DAC 保持老像素坐标（寄存器保持）✅

### 10.4 State 16 写 dac_sample 个 word

每个 word 的格式：
```
FIFO[34:0] = {1'b0, 1'b0, 1'b0, DAX_新坐标, DAY_新坐标}
              [34]  [33]  [32]
```

**关键：FIFO[32]/[33] 必须写 0**，原因：
- 读侧 acq/blanker 靠**上升沿**触发（`para_config_dout[32] && ~adc_tri_d`）
- 如果 State 16 写 1，读侧看到的序列是 `1(trigger), 1, 1, 1(dwell)...`，下一个 trigger 来时检测不到 0→1 ❌
- 写 0 后序列是 `1(trigger), 0, 0, 0(dwell)..., 1(next trigger)` ✅ 每次都能检测到上升沿

激光模式下 FIFO[32] 的角色是**事件脉冲**（只在 trigger 那拍为 1），不是电平信号（普通模式下 adc_tri=1 持续整个 dwell）。

### 10.5 读侧不需要改动

- `scan_state` 是独立信号，不依赖 FIFO 数据
- FIFO 空时读侧自动停读，DAC/adc_tri 保持安全状态
- 现有逻辑天然支持 FIFO 间歇性为空的场景

## 11. 状态

- 需求定稿日期：2026-05-28
- 方案优化日期：2026-05-28（v2：不写占位数据，State 14→15→16→4）
- 下一步：架构设计（基于 v2 方案）

# DL5 飞秒激光同步采集模式 As-Built

> 本文件只记录当前 RTL 中已经实现并验证过的事实。开发过程和 AI 工作痕迹见 `AI-work/features/DL5_laser_sync/DL5_UNIT_001/`。

> 2026-05-27 需求复核提示：用户审查后指出 UNIT_001 的需求方向存在偏差。因此本文当前只描述“现有 RTL/历史实现事实”，不能作为最终需求验收文档。第二轮需求和后续实现从 `AI-work/features/DL5_laser_sync/DL5_UNIT_002/WORK.md` 开始；等 UNIT_002 验收后再回写最终 As-Built。

## 1. 当前状态

| 项 | 状态 |
|---|---|
| RTL 实现 | 已完成第一轮 |
| 单元仿真 | PASS，TC1-TC8 全部通过；2026-05-27 已用 `DL5_UNIT_001/sim/run_batch.tcl` 复跑 |
| RTL elaboration | PASS，0 ERROR / 0 CRITICAL WARNING |
| synth_1 | PASS，0 ERROR / 0 CRITICAL WARNING |
| 上板验证 | 未完成 |
| `laser_sync_in` XDC | 未完成，等待硬件确认引脚 |

证据入口：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/WORK.md
AI-work/features/DL5_laser_sync/DL5_UNIT_001/RTL_REVIEW.md
AI-work/features/DL5_laser_sync/DL5_UNIT_001/SIM_REPLAY.md
```

## 2. 功能事实

DL5 是一条新增数据通路：外部飞秒激光器给 FPGA 一个同步脉冲，FPGA 根据寄存器参数在 `ui_clk` 域生成 blanker、acq 和事件 busy 信号，并在一个激光周期结束时推进 DAC 扫描到下一个像素。

旧模式保留：

- `laser_mode_en=0`：走原 DAC 扫描/ADC 触发逻辑。
- `laser_mode_en=1`：走 DL5 激光同步逻辑。

## 3. 新增寄存器

寄存器在 `command_monitor_new.v` 中实现：

| 地址 | 名称 | 单位 | 当前事实 |
|---|---|---|---|
| `0x0205` | `laser_mode_en` | bit[0] | 1=启用 DL5 |
| `0x0206` | `blanker_delay_time` | 5ns | 激光上升沿后 blanker 延时 |
| `0x0207` | `blanker_time` | 5ns | blanker 窗口宽度 |
| `0x0208` | `acq_data_delay_time` | 20ns | acq 延时，内部乘 4 转 5ns |
| `0x0209` | `acq_time` | 20ns | acq 窗口宽度，内部乘 4 转 5ns |
| `0x020A` | `laser_period` | 5ns | 一个激光周期长度，500kHz 对应 400 |

reset 默认值：

- `laser_mode_en = 0`
- `blanker_delay_time = 0`
- `blanker_time = 0`
- `acq_data_delay_time = 0`
- `acq_time = 0`
- `laser_period = 400`

## 4. 核心控制模块

模块：

```text
AXI_DDR.srcs/sources_1/new/laser_sync_blanker_ctrl.v
```

已实现行为：

- `laser_sync_in` 在模块内做 3 级 FF 同步。
- 只在 `laser_mode_en & scan_state` 为 1 时响应激光上升沿。
- 状态机为 `IDLE -> BUSY -> DONE -> IDLE`。
- BUSY 期间：
  - `blanker_pulse` 在 `[blanker_delay_time, blanker_delay_time + blanker_time)` 为 1。
  - `laser_acq_pulse` 在 `[acq_data_delay_time*4, acq_data_delay_time*4 + acq_time*4)` 为 1。
  - `laser_event_busy` 全程为 1。
- `t_cnt == laser_period - 1` 后进入 DONE，打一拍 `pixel_done_pulse_ui`。

## 5. 接入方式

### 5.1 `parameter_dacdata_gen.v`

laser 模式下，State 3 不再用 `dac_sample_cnt` 决定像素停留时间，而是：

1. 首次进入 State 3 时写 1 个 FIFO word，让 DAC 输出当前像素电平。
2. 设置 `laser_pixel_written=1`。
3. 停止写 FIFO，等待 `pixel_done_pulse`。
4. `pixel_done_pulse` 到来后进入 State 4。

### 5.2 `dac_output.v`

laser 模式下三路输出切换：

| 输出 | 旧模式 | laser 模式 |
|---|---|---|
| `adc_tri` | FIFO[32] | `laser_acq_pulse` |
| `sync_pixel_tri1` | `sync_pixel_tri1_reg` 经取反 | `blanker_pulse` 经同一取反路径 |
| `sync_pixel_tri2` | `sync_pixel_tri2_reg` | `laser_event_busy` |

注意：`sync_pixel_tri1` 物理输出保持低有效。

### 5.3 `dacdata_config.v`

负责：

- `eth_clk -> ui_clk` 参数双 FF 同步。
- 例化 `laser_sync_blanker_ctrl`。
- `pixel_done_pulse_ui -> eth_clk` toggle 同步。
- 把 DL5 输出接到 `dac_output`。

### 5.4 `ETH_TOP.v`

新增顶层输入：

```verilog
input laser_sync_in
```

目前只加了端口和内部接线，还没有 XDC 约束。

## 6. 验证事实

### 6.1 单元仿真

入口：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/SIM_REPLAY.md
```

结果文件：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/result.txt
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/vivado_run_batch.log
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
```

已通过用例：

| 用例 | 结论 |
|---|---|
| TC1 mode_en=0 | PASS |
| TC2 单个正常事件 | PASS |
| TC3 连续 3 发脉冲 | PASS |
| TC4 blanker_delay=0 | PASS |
| TC5 BUSY 中第二个脉冲忽略 | PASS |
| TC6 blanker_time=0 | PASS |
| TC7 acq_time=0 | PASS |
| TC8 scan_state=0 门控 | PASS |

### 6.2 RTL elaboration

已通过：

- 0 ERROR
- 0 CRITICAL WARNING
- 顶层 port 列表包含 `laser_sync_in`

### 6.3 synth_1

已通过：

- `synth_design Complete`
- `BUILD PASS`
- 0 ERROR
- 0 CRITICAL WARNING

综合后资源：

| 资源 | 使用率 |
|---|---|
| Slice LUTs | 31.94% |
| Slice Registers | 27.19% |
| Block RAM Tile | 89.89% |
| DSP | 1.90% |
| Bonded IOB | 70.50% |

## 7. 仍不是事实的内容

这些内容不能当作已经完成：

- `laser_sync_in` 引脚号。
- `laser_sync_in` 的最终 IOSTANDARD。
- 真实硬件上 2.5V TTL 激光同步脉冲是否满足该 bank 的输入要求。
- `sync_pixel_tri2 = laser_event_busy` 是否就是外设最终需要的语义。
- 上板后 blanker/acq/sync2 的真实示波器波形。

## 8. 后续建议

下一轮 DL5 工作建议新建：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_002/
```

可能内容：

- 确认并补写 `laser_sync_in` XDC。
- 做上板 ILA/示波器验证。
- 如有必要，补完整链路集成 testbench。
- 根据外设反馈决定是否修改 `sync_pixel_tri2` 语义。

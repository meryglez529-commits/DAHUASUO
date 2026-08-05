# DL5_UNIT_006：板级 ILA 定位结果（2026-08-05）

## 结论摘要

本次使用同一份诊断 bit/LTX 完成了写侧整行、DAC 读侧/相机同步、采集时序三组 ILA 抓取。

1. 外部激光输入正常：相邻上升沿为 250 个 `eth_clk` 采样，即约 2 us；在行内，每个沿均被 State 14 接收。
2. 在重新下发 16x16 测试配置后，`x_index` 从 0 到 15 连续推进，State 16 恰好执行 16 次；本次没有 FPGA 写侧丢失像素。
3. 首次 16x16 冒烟配置 `dac_sample=4` 时，末点输出 4 个 20 ns word，即 80 ns；它不是“少写 sample”。随后将 `0x0002` 安全改为 `50` 后重抓：`x_index=0..15` 的每次 State 16 都完整运行 50 拍，DAC 侧末点 `0xE664` 连续保持 50 个 DAC 时钟（1.000 us）才进入回扫，已实测闭环上位机的 1 us 驻点合同。
4. `dac_sample` 就是上位机的 DAC 驻点 word 数。历史设计记录给出写侧 125 MHz、读侧 50 MHz；每个像素完整写入 `dac_sample` 后的净积压约为 `0.6 × dac_sample` word，排空时间为 `dac_sample × 12 ns`。对 `dac_sample=50` 为约 600 ns，结合当前 800 ns 扫描延时与 2 us laser 周期，仍有约 200 ns 余量。因此，写满 1 us 的 sample 不会导致下一像素因 FIFO 排空而产生高延时。
5. 回扫至 `0x1999` 后下一 X 增量在约 6.74 us 后出现；该间隔包含线首恢复、scan delay、等待下一次可接受 laser 及 FIFO 输出，不能仅凭该测量判定 5 us 的恢复参数失效。
6. `camera_line_sync` 在两次 DAC ILA 的 81.92 us 窗口内始终为高，即使 FIFO bit33 行尾标记已两次出现；低有效相机行同步当前不符合需求。根因已定位为激光模式 FIFO 行首标记 bit34 与实际写使能错开一拍，致使 `camera_line_active` 从未置位；尚未改 RTL。

## 配置核对

第一次立即快照的实时寄存器与测试预期不符：

| 寄存器 | 当时读回 | 16x16 测试值 |
|---|---:|---:|
| `0x0002` (`dac_sample`) | 50 | 4 |
| `0x0004` (`rows, cols`) | `0x04140698` | `0x00100010` |
| `0x0006` (`X points, recovery`) | `0x0698012C` | `0x00100005` |
| `0x000F` (X fall) | 300 us | 1 us |
| `0x0206` (scan delay) | 10 (80 ns) | 100 (800 ns) |

这解释了首次 ILA 中 `x_index=76..92`、没有行尾以及此前示波器“点数不对”的现象。随后按停扫 -> 关激光模式 -> 写配置 -> 读回 -> 开扫的顺序重新下发，并确认 `0x0009=0x00003211`。

## 最终触发抓取证据

文件均在 `out/ila/`：

- `eth_full_line_TRIG_20260805_135750.csv`
- `dac_tail_camera_TRIG_20260805_135750.csv`
- `acq_timing_TRIG_20260805_135750.csv`
- `capture_event_16x16_20260805_135747.log`
- `eth_full_line_TRIG_20260805_144245.csv`
- `dac_tail_camera_TRIG_20260805_144245.csv`
- `acq_timing_TRIG_20260805_144245.csv`
- `dwell50_camera_20260805_144242.log`

### 写侧整行

- 行首触发位于样本 0，`x_index=0`。
- State 15 在每个激光沿后保持 100 个 8 ns 采样，State 16 从 `+0.808 us` 开始；配置的 800 ns 扫描延时生效。
- `x_index=0..15` 连续，16 次 State 16，每次写 4 个 word；没有 `prog_full` 停顿。
- 在 `+30.848 us` 进入 State 12；随后 State 12 共 50 次、State 13 共 100 次，完成 1 us 回扫的 50 个节拍。
- 第二次抓取前仅将 `0x0002` 改为 50 并读回确认；`x_index=0..15` 的每一段 State 16 均为 50 个 eth_clk 周期，未出现 `prog_full` 停顿。

### DAC 行尾和恢复

DAC ILA 以 bit33 行尾标记触发（位置 3072）。相对触发时刻，倒数第二个有效点 `0xD8BD` 在两个连续行中均保持 100 个 DAC 时钟（2 us）；最后有效点 `0xE664` 从 `-0.020 us` 保持至 `+0.040 us`，只有 4 个 DAC 时钟（80 ns）。`+0.060 us` 即开始回扫，至 `+1.240 us` 到达 `0x1999`。其后 FIFO 为空/间歇读，直到 `+7.980 us` 才出现下一有效 X 点 `0x2740`。

“回扫末端到下一 X 增量”约为 6.74 us，不应与寄存器定义的 5 us 恢复值直接一一比较：它还包含后续 scan delay、等待下一次可接受 laser，以及异步 FIFO 读侧时刻。该现象暂不作为恢复计数错误的证据。

末点只有 80 ns 的直接原因不是少写 FIFO word：写侧 ILA 已证明 `x_index=15` 同样完整写入 4 个 `dac_sample` word，而本次诊断配置的 `dac_sample` 本身就是 4。行内点转 State 14 等待下一 laser，故 FIFO 排空后仍保持该 DAX 值；末点则直接转 State 12，将回扫 word 紧随其后写入 FIFO。要验证上位机的 1 us 驻点要求，应在相同 16x16 几何参数下把 `0x0002` 设为 50 后复测：末点应保持 50 个 DAC 时钟（1 us），随后才回扫。只有当产品规格额外要求“末点也必须保持到下一 laser、即与行内表观 2 us 相同”时，才需要另加末点等待状态；这不是当前 80 ns 抓取能够证明的 RTL 缺陷。

该复测已完成：在 `dac_tail_camera_TRIG_20260805_144245.csv` 中，末点 `0xE664` 出现在 `1225..1274` 和 `3025..3074`，每段均为 50 个 20 ns DAC 时钟（1.000 us）；之后才开始单调回扫。因此末点驻点问题由正确的 `dac_sample=50` 配置解决，无需修改扫描 RTL。

### 激光到 DAX 实际输出延时的可观测性

本次 ETH ILA 只能量到 `laser_sync_in` 上升沿至 State 16 **开始写 FIFO** 为 `0.808 us`，这证明 `scan_delay=100`（800 ns）已生效；它不是 laser 到 DAC 引脚更新的完整延时。此前示波器的 laser→DAX 实测约 1.2 us，符合“800 ns 扫描延时加固定 FIFO/DAC 链路延时”的量级，但本次 ILA 尚未独立得出该完整值。DAC ILA 虽记录了 DAX，但以 FIFO bit33 行尾触发，且未采集与激光沿同一时基的事件信号。三组 ILA 没有公共时间戳，故不能由本次 CSV 严格得出当前配置的 laser→DAX 引脚延时。

历史记录中的约 256/274 ns 对应另一套 `scan_delay` 配置，不能套用到当前 800 ns 配置。要得到当前值，应使用示波器同时测 `TRIGGER_IN` 与 DAX 模拟输出，或在下一次诊断 bit 中于同一个 `dac_dco` ILA 采集同步后的 laser 事件、FIFO 读出和 DAX；后者需要重新编译。

### 采集时序

采集 ILA 在样本 512 触发。`laser_pulse_ui` 后，延时状态为 4 个 `ui_clk`（20 ns），采集高电平状态也为 4 个 `ui_clk`（20 ns）。`0x0209=1`、`0x020A=1` 的实际行为正确。

### 相机同步

两次 DAC ILA 中 `camera_line_sync` 的 4096 个 50 MHz 样本均为高；第二次的 FIFO bit33 行尾标记位于样本 1272、3072。根因可由 ILA 与 RTL 时序共同确定：`parameter_dacdata_gen` 以 `current_state==16 && dac_sample_cnt==0` 组合生成 bit34 行首标记，但 `para_config_wr_en` 是进入 State 16 后才寄存器置 1。实际 ILA 显示 x=0 时样本 101 为 `State16/cnt=0/wr_en=0`，样本 102 已为 `State16/cnt=1/wr_en=1`；故第一笔真正 FIFO 写入未携带 bit34。DAC 域只以 bit34 置位 `camera_line_active`，而 bit33 只请求结束，导致 `camera_line_sync=~camera_line_active` 始终为高。该结论排除了板外 TRIGGER_H 接线问题。

此外，当前 bit33 出现在末点仍剩 2 个 DAC 时钟时（第二条线 marker=3072、末点 `0xE664` 至 3074 才结束）。因此修复时应把 bit34/bit33 与**实际 FIFO 写入 word**对齐：bit34 标在第一有效 word，bit33 标在最后有效 word；不能只把 bit34 延后一拍，否则会留下行尾提前释放问题。下一次诊断 bit 还应同时采集 `laser_mode_en_dac`、FIFO[34] 与 `camera_line_active`，作为修复验收探针。

## 未修改项

本次只改动诊断脚本与板卡寄存器测试配置；未改动扫描状态机、FIFO 格式、寄存器映射、XDC 或业务 RTL。

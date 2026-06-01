# DL5_UNIT_001 单元仿真期望

Testbench:

```text
AXI_DDR.srcs/sim_1/new/tb_laser_sync_blanker_ctrl.v
```

DUT:

```text
AXI_DDR.srcs/sources_1/new/laser_sync_blanker_ctrl.v
```

时钟：

```text
ui_clk = 200 MHz, 5 ns
```

## 通过条件

```text
==== tb_laser_sync_blanker_ctrl done, errors=0 ====
PASS
```

## 用例

| 用例 | 配置 | 期望计数 |
|---|---|---|
| TC1 | `mode_en=0`, `scan_state=1` | `blanker_cnt=0`, `acq_cnt=0`, `busy_cnt=0`, `pixel_done_cnt=0` |
| TC2 | `mode_en=1`, `laser_period=400`, `bd=20`, `bt=40`, `acq_d=10`, `acq_t=20` | `blanker_cnt=40`, `acq_cnt=80`, `busy_cnt=400`, `pixel_done_cnt=1` |
| TC3 | TC2 配置，连续 3 发激光脉冲 | `blanker_cnt=120`, `acq_cnt=240`, `busy_cnt=1200`, `pixel_done_cnt=3` |
| TC4 | `blanker_delay_time=0` | `blanker_cnt=40`, `acq_cnt=80`, `busy_cnt=400`, `pixel_done_cnt=1` |
| TC5 | BUSY 中插入第二个激光脉冲 | 第二个脉冲忽略，计数仍等于 1 个事件 |
| TC6 | `blanker_time=0` | `blanker_cnt=0`, `acq_cnt=80`, `busy_cnt=400`, `pixel_done_cnt=1` |
| TC7 | `acq_time=0` | `blanker_cnt=40`, `acq_cnt=0`, `busy_cnt=400`, `pixel_done_cnt=1` |
| TC8 | `mode_en=1`, `scan_state=0` | 全部输出为 0，`pixel_done_cnt=0` |

## 时间换算

| 参数 | 单位 | 示例 |
|---|---|---|
| `blanker_delay_time` | 5ns | 20 = 100ns |
| `blanker_time` | 5ns | 40 = 200ns |
| `acq_data_delay_time` | 20ns，内部乘 4 | 10 = 200ns |
| `acq_time` | 20ns，内部乘 4 | 20 = 400ns |
| `laser_period` | 5ns | 400 = 2us = 500kHz |

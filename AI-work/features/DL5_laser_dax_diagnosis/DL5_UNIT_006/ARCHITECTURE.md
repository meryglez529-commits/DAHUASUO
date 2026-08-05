# DL5_UNIT_006：诊断 ILA 架构

## 双时钟观察面

| ILA | 时钟 | 深度 | 观察问题 |
|---|---:|---:|---|
| `ila_dl5_eth / dl5_eth_debug` | `eth_clk` 125 MHz | 4096（32.768 us） | 一整行的激光脉冲接收、状态、像素序号、写 FIFO 与恢复计数。 |
| `ila_2 / dac_ila` | `dac_dco` 50 MHz | 4096（81.92 us） | FIFO 读出后真正送至 DAX/DAY 的码值、FIFO 空/读使能和行尾标记。 |
| `ila_1 / dl5_acq_timing_test` | `ui_clk` 200 MHz | 1024（5.12 us） | 一次激光脉冲的采集延时、采集时间、状态和计数；足以覆盖 20 ns/20 ns 测试窗口。 |

## eth_clk ILA 编码

`probe1[31:0]` 从高到低：

`{state[4:0], x_index[15:0], dac_sample_cnt[4:0], prog_full, wr_rst_busy, wr_en, laser_rise, laser_mode, scan_state}`

其它 probe：

- `probe0`：原始 `laser_sync_in`；
- `probe2`：`{laser_mode, scan_state, laser_rise, laser_toggle}`；
- `probe3`：`line_start_accept`，即 `State14 && x_index==0 && laser_rise`，作为完整行触发；
- `probe4`：待写 FIFO 的 `{DAX_DATA,DAY_DATA}`；
- `probe5`：`dacx_tb_point_cnt[15:0]`；
- `probe6`：`tail_entry`（State12），用于独立抓线尾/恢复。

## DAC ILA 编码

保留 DAX/DAY 输出；单比特 probe 为实际低有效 `camera_line_sync`、FIFO `prog_empty`、读使能、读使能延迟和 FIFO bit33 行尾标记。用 bit33 触发可在最后有效像素处开始记录后续回扫、恢复、相机同步释放与下一行。

## 旧功能保持

所有新增/替换仅连接 ILA 输入。状态机、FIFO 宽度、FIFO 读写使能、DAC 输出、寄存器映射和顶层引脚均不改变。独立 ETH ILA 避免把两个 UI ILA 一并扩深，保持调试 BRAM 在可接受范围。

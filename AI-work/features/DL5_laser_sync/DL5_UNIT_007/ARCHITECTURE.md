# DL5_UNIT_007：架构

## 时序链路

```text
State 13 最后一个回扫 word（eth 写侧）
  -> FIFO[32]=tail_end 标记
  -> FIFO 读侧按 dac_dco 输出该 word
  -> DAX/DAY 更新的同一 dac_dco 边沿翻转 tail_done_toggle
  -> 3 FF 同步到 eth_clk
  -> State 17 等到新 toggle
  -> State 18 按 T * 125 个 eth_clk 周期恢复
  -> State 14 才允许接受下一次 laser
```

## 状态机

- State 2：激光模式只写两个起始锚点，不再把其 ETH 计数误作为物理恢复时间。
- State 17：仅在有物理回扫的行间，等待 DAC 读侧确认最后一个回扫 word 已实际输出。
- State 18：从确认同步到 ETH 后开始恢复计时；期间不写 FIFO、不接受 laser。
- State 14：维持原有的 laser 门控职责。

## CDC

| 信号 | 源 | 目的 | 方法 |
|---|---|---|---|
| `laser_tail_done_toggle_dac` | `dac_dco` | `eth_clk` | 3 FF 同步并比较 toggle |
| FIFO[32] tail marker | `eth_clk` | `dac_dco` | 现有异步 FIFO 数据位 |

## 兼容性

- `laser_mode_en=0`：FIFO[32] 继续等于 `adc_tri`；State 17/18 不可达；所有原逻辑保持。
- `ultrafast_mode=1 && laser_mode_en=0`：同上，超快恢复仍使用既有 `ultrafast_line_rec` 和原 State 2。
- 激光 ADC、blanker、相机行同步分别保持既有独立路径；FIFO[32] 仅在读侧生成尾部确认，不驱动 ADC 或相机。

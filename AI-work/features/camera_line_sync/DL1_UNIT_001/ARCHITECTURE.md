# DL1_UNIT_001 架构 - 相机行同步

## 选定方案

行同步必须在 `dac_output` 的 `dac_dco` 域产生。原因是 `eth_clk` 侧的生成器可能因异步 FIFO 积压而领先实际 DAC 输出，不能直接作为相机时序。

```text
普通 / 超快：
State 3 FIFO[32]=adc_tri --> dac_output --> camera_line_active --> 取反 --> TRIGGER_H

激光：
State 16 首 word FIFO[34]=line_start --> dac_output 锁存 --> camera_line_active
State 16 末 word FIFO[33]=line_end   --> 下一 dac_dco 拍清锁存 --> TRIGGER_H
```

FIFO 仍为 35 bit，仅在激光模式复用位语义：

| FIFO 位 | 普通 / 超快 | 激光模式的本功能语义 |
|---|---|---|
| `[34]` | 原 sync2 来源 | `camera_line_start` |
| `[33]` | 原 sync1 来源 | `camera_line_end` |
| `[32]` | `adc_tri`，即有效像素区 | 保持为 0；激光 ADC 仍走独立 `acq_pulse_ui` |
| `[31:0]` | DAC X/Y 数据 | 不变 |

## 分模式时序

### 普通与超快

State 3 会为每个像素发出连续的 `dac_sample` 个 word。State 4 不写 FIFO，因此相邻像素在 DAC 侧的 `adc_tri=1` word 连续；其后的 Tb/回扫/帧等待 word 都为 `adc_tri=0`。故可直接以 DAC 域已拆包的 `adc_tri` 表示有效行。

### 激光

State 14 等待 laser 边沿；State 16 输出一个像素；State 4 决定等待下一像素或进入行尾。两个 laser 之间 FIFO 可能没有读操作，因此须用锁存器保持行有效状态。

State 16 仅生成如下标记：

```verilog
laser_line_start = (dacx_tk_point_cnt == 0) && (dac_sample_cnt == 0);
laser_line_end   = (dacx_tk_point_cnt == dacx_tk_point - 1)
                && (dac_sample_cnt == dac_sample - 1);
```

`dac_output` 在观察到 `laser_line_end` 的下一 `dac_dco` 拍才清除锁存，保证最后一个 DAC word 完整处于低有效窗口内。

## RTL 变更地图

| 文件 | 变更 |
|---|---|
| `parameter_dacdata_gen.v` | 在激光模式生成 `[34]/[33]` 的行首/行尾标记；非激光模式保持原 sync 位语义。 |
| `dac_output.v` | 增加 DAC 域行有效锁存与输出；用 `!laser_mode_en_dac` 屏蔽激光模式的旧 sync1/sync2 拆包入口。 |
| `dacdata_config.v` | 将 `camera_line_sync` 从 `dac_output` 透传到包装模块端口。 |
| `ETH_TOP.v` | 接入该输出，并替换固定为 0 的 `TRIGGER_H`。 |

不改 XDC、IP、FIFO 位宽或上位机寄存器。

## 时钟与 CDC

| 信号 | 源时钟 | 目的时钟 | 方法 | 风险 |
|---|---|---|---|---|
| FIFO `[34]/[33]` 标志 | `eth_clk` | `dac_dco` | 现有异步 FIFO，随对应 DAC word 传输 | 低 |
| `adc_tri` 行有效信息 | `dac_dco` | `dac_dco` | 现有拆包寄存器 | 低 |
| `laser_mode_en_dac` | `eth_clk` | `dac_dco` | `dac_output` 中已有同步链 | 低 |
| `camera_line_sync` | `dac_dco` | F15 | 直接寄存器输出 | 低 |

## 旧行为保持

- `laser_mode_en=0` 时，FIFO `[34:33]` 与既有 sync1/2 的语义完全一致。
- `TRIGGER_OUT` 保持连接既有 `sync_pixel_tri2`。
- `TRIG_BLANK` 保持 blanker/sync1 输出。
- 除新 `TRIGGER_H` 信号外，DAC X/Y 与 `adc_tri` 行为必须逐拍不变。

## 验证策略

1. 用 FIFO/IP stub 对 `dac_output` 做聚焦仿真。
2. 普通模式：一行连续 `adc_tri=1` 产生一段低 `TRIGGER_H`，前后 0 word 不被包含。
3. 超快模式：验证同样行窗口且 sync1/2 原行为保留。
4. 激光模式：多个间隔的 State-16 类数据只产生一段连续低窗口；行尾标记仅在末像素后释放。
5. 回归：激光标记不得触发旧 sync 整形器。
6. 仿真通过后再进行综合，并准备 ILA/示波器观察 `camera_line_sync`、`camera_line_active`、FIFO 读使能/数据、`adc_tri` 与激光标记。

# Host App 参数单位审计

日期：2026-06-11

范围：`command_monitor_new.v` 寄存器写表、`parameter_dacdata_gen.v`、`dacdata_config.v`、`dac_output.v`、`adcdata_acq.v`，以及 `AI-work/host-app` 当前 GUI/CLI/参数模型。

## 结论

上位机不应把所有时间参数统一当成 ns。当前 RTL 的寄存器值主要是“硬件步进值/计数值”，只有少数字段是上位机按 us 写入后由 FPGA 内部乘 50。

本次 host-app 修改后的原则：

- GUI/CLI 显示并接收 RTL 原始单位：cycles、steps、sample points、FIFO words、us。
- 不做隐式 ns 换算，避免用户填 `100` 以为是 100ns，硬件却按 100 个 tick 执行。
- 如果未来要加“按 ns 输入”的友好层，必须新增独立字段，并在写寄存器前显式换算和取整。

## 单位对照表

| 地址 | 参数 | 上位机输入单位 | RTL 实际解释 | 证据/备注 |
|---|---|---|---|---|
| `0x0000` | `clk_sel` | boolean | `0` 自由运行，`1` 每行等 `TRIGGER_IN` | `command_monitor_new.v` 写 bit0 |
| `0x0001` | `adc_len_single`, `adc_channel` | 点数 / 通道数 | ADC 上传长度和通道选择 | 不是时间 |
| `0x0002` | `adc_sample`, `dac_sample` | sample points / FIFO words | ADC 平均点数，同时是 DAC 每像素保持的 FIFO word 数 | `parameter_dacdata_gen.v` State 3 用 `dac_sample_cnt` |
| `0x0003` | ADC/DAC gain | 2-bit code | 板级继电器/增益编码 | 不是时间；默认 ADC=2、DAC=3 |
| `0x0004` | `image_row`, `image_column` | 行/列计数 | 图像空间维度，触发 Y 步进重算 | 不是时间 |
| `0x0005` | DAC X start/end | 16-bit DAC code | X 扫描起止码值 | 不是时间 |
| `0x0006[31:16]` | `dacx_tk_point` | pixels per line | X 方向点数，用作 X 步进除数 | 必须非 0 |
| `0x0006[15:0]` | `dacx_recovery_time` | us | FPGA 内部 `x50` 转成 DAC/FIFO word 数 | `parameter_dacdata_gen.v` 中 `<<5 + <<4 + <<1` |
| `0x0007` | DAC Y start/end | 16-bit DAC code | Y 扫描起止码值，触发 Y 步进重算 | 不是时间 |
| `0x0008` | `frame_waiting_time` | FIFO words | 帧间等待输出 word 数，约 20ns/word（DAC DCO 50MHz） | 不乘 50 |
| `0x0009[31:8]` | `adc_interval` | ADC DCO cycles | 普通模式触发到采集等待计数，约 20ns/step（ADC DCO 50MHz） | 不是 ns 值 |
| `0x0009[7:4]` | `scan_mode` | 4-bit mode code | 扫描模式编码 | 不是时间 |
| `0x0009[3:0]` | `scan_state` | 4-bit state code | 启停状态 | 不是时间 |
| `0x000F` | `dax_fall_time` | us | `dacdata_config.v` 内部 `x50` 后作为 X 回扫 FIFO word 数 | 上位机填 us，硬件转换 |
| `0x0013` | `row_repeat` | repeat count | 同一行重复扫描/平均次数 | 必须 >= 1 |
| `0x0014` | `row_m`, `row_n` | row counts | 交错扫描分组参数 | `row_n` 必须 >= 1 |
| `0x0200` | `sync1_pixel_tri_wigth` | 20ns steps | `dac_output.v` 内部 `<<2` 转为 `ui_clk` 5ns 拍数 | sync1 输出为低有效 |
| `0x0205` | `sync2_pixel_tri_wigth` | 20ns steps | 当前 `command_monitor_new.v` 写表中 sync2 宽度；`dac_output.v` 内部 `<<2` | 已补 RTL 读回，host-app 可 checked write |
| `0x0201` | `adc_acq_delay` | ADC DCO cycles | 超快模式采集延时；约 20ns/step（ADC DCO 50MHz） | 参与 `adc_sample - delay - dead - 2` |
| `0x0202[31:1]` | `ultrafast_line_rec` | us | FPGA 内部 `x50` 转成 line recovery FIFO word 数 | bit0 是 ultrafast enable |
| `0x0202[0]` | `ultrafast_mode` | boolean | 超快模式使能 | 已补读回 |
| `0x0203[31:16]` | `sync_sig_delay1` | `ui_clk` cycles | sync1 延时，5ns/step（200MHz ui_clk） | 不乘 4 |
| `0x0203[15:0]` | `sync_sig_delay2` | `ui_clk` cycles | sync2 延时，5ns/step（200MHz ui_clk） | 不乘 4 |
| `0x0204` | `acq_dead_time` | ADC DCO cycles | 超快模式采集死区；约 20ns/step | 参与 ADC 分母计算 |
| `0x020B` | `laser_mode_en` | boolean | 当前 `command_monitor_new.v` 写表中的 DL5 激光模式使能 | 已补读回，host-app checked write |
| `0x0206` | `scan_delay_time` | `eth_clk` cycles | DL5 收到 laser 后等待，8ns/step（125MHz eth_clk） | 不是 ns 值 |
| `0x0207` | `blanker_delay_time` | `ui_clk` cycles | DL5 blanker 延时，5ns/step | 直接用于 sync1 mux |
| `0x0208` | `blanker_time` | `ui_clk` cycles | DL5 blanker 宽度，5ns/step | 直接用于 sync1 mux |
| `0x0209` | `acq_data_delay_time` | 20ns steps | `dac_output.v` 内部 `<<2` 转为 ui_clk 拍数 | laser acq pulse 延时 |
| `0x020A` | `acq_time` | ADC samples / 20ns steps | DAC 触发路径按 20ns step 生成脉宽；ADC 采集路径把它当激光模式采样点数 | laser enable 时应 >= 2 |

## 容易误用的字段

| 字段 | 易错理解 | 正确处理 |
|---|---|---|
| `scan_delay_time` | 直接填 ns | 填 `eth_clk` 拍数；100 表示约 800ns |
| `blanker_delay_time` / `blanker_time` | 直接填 ns | 填 `ui_clk` 拍数；20 表示约 100ns |
| `acq_data_delay_time` | 直接填 ns | 填 20ns steps；30 表示约 600ns |
| `acq_time` | 只是一段 ns 时间 | 同时是 ADC sample count；60 表示 60 点采集，若 50MHz 约 1200ns |
| `adc_acq_delay` / `acq_dead_time` | 任意延时 ns | ADC DCO cycles，并且必须满足 `adc_sample > adc_acq_delay + acq_dead_time + 2` |
| `sync*_pixel_tri_wigth` | ui_clk 5ns 拍 | 上位机填 20ns steps，FPGA 内部 `<<2` |
| `dacx_recovery_time` / `dax_fall_time` | 已经是硬件拍数 | 上位机填 us，FPGA 内部乘 50 |
| `frame_waiting_time` | us | FIFO words，不乘 50 |

## 本次 host-app 对应修改

- `command_monitor_new.v`：补齐 `0x0200~0x0205` 和 `0x020B` 读回。
- `register_map.py`：`0x0205=sync2_pixel_tri_width`，`0x020B=laser_mode_en`，两者都按可读写处理。
- `ScanConfig`：补齐 gain、frame waiting、row repeat、row_m/row_n、可选 `clk_sel`，并保持原始单位写寄存器。
- `UltrafastModeConfig`：新增 `sync2_width`，并校验 ADC 超快采集分母不会下溢。
- `Dl5Config`：laser enable 改到 `0x020B`；laser enable 时 `acq_time >= 2`。
- GUI/CLI：标签和 help 文案都标注 raw unit 和 step resolution，不再只写 “Delay/Time”。

# DL1_UNIT_002：RTL 变更审查（实施前）

| 文件 | 改动原因 | 拟改内容 | 必须审查的风险 | 当前状态 |
|---|---|---|---|---|
| `parameter_dacdata_gen.v` | 激光 FIFO 行首/行尾 marker 与实际写 word 错位 | 去除 laser 专用组合 bit33/34 旁路；在 State16 用既有 `sync_pixel_tri2/1` 寄存首末标记并直接打包 | 非阻塞赋值流水级理解错误、`dac_sample=1` 同时首尾、普通/超快意外改变 | 待实施 |
| `dac_output.v` | 一次重新实现时需要完整观察修复效果 | 仅把现有 16-bit ILA probe2 改接为 marker/active/mode 调试总线 | 不得改 `camera_line_active/end_pending` 功能逻辑，不得改 FIFO 读时序 | 待实施 |
| `tb_dl1_unit_002_marker_alignment.v` | 需直接验证写侧真实 word，而非仅向 DAC TB 人工塞 word | 新增真实生成器/写入记录和 DAC 域回归 | 必须同时验证首、尾、激光间隙和三种 `dac_sample` 边界 | 待新增 |

## 功能不变量

1. FIFO 格式仍为 `{sync2, sync1, adc_tri, DAX, DAY}`，宽度 35 bit 不变。
2. 激光模式 FIFO[32] 仍为 0；ADC 触发仍走既有独立路径。
3. 普通和超快模式仍由原来的 `sync_pixel_tri2/1`、`adc_tri` 产生 FIFO 字段；这次只取消了激光模式对 bit33/34 的组合旁路。
4. `dac_output` 的相机输出仍为 `camera_line_sync = ~camera_line_active`，TRIGGER_H 引脚不变。
5. 不触及 State14，故 blanker、激光输入同步和 ADC 采集状态机不应受到影响。

## 需在代码审查中逐项确认

- State16 所有非激光路径原有对 `sync_pixel_tri1/2` 的清零与赋值仍完整保留。
- `dacx_tk_point - 1`、`dac_sample - 1` 的位宽及合法零值约束不因修复改变。
- 同时置位 start/end 的单样本 word 在 DAC 域仍先拉低、后一拍释放。
- ILA 改线不引入新的 IP/XCI 变更；若 Vivado 自动要求 IP 升级，停止并单独报告。

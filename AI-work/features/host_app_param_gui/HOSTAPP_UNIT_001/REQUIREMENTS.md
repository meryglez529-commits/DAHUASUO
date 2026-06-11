# Host App 参数覆盖与 GUI 重设计需求

## 目标

以当前 `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` 写寄存器表为标准，修正 host-app 地址定义、参数模型、CLI 和 GUI。用户在上位机设置参数时必须能看清单位：哪些是 ns 对应的硬件步进，哪些是 ADC/DAC sample count，哪些是 FPGA 内部再换算的 us。

## 用户确认

| 决策 | 结论 |
|---|---|
| 地址标准 | 以当前 `command_monitor_new.v` 为准 |
| DL5 laser enable | `0x020B = laser_mode_en` |
| sync2 width | `0x0205 = sync2_pixel_tri_width` |
| 扩展寄存器读回 | RTL 已补 `0x0200~0x0205` 和 `0x020B` 读回，host-app 使用 checked write |
| GUI 方向 | 参数分类展示，减少 raw register 依赖 |
| 单位策略 | GUI/CLI 接收 RTL 原始单位，并在标签/help 中标明 step resolution |

## 范围

| 类别 | 本单元处理 |
|---|---|
| host-app 地址表 | 对齐 `0x0205=sync2_pixel_tri_width`、`0x020B=laser_mode_en` |
| host-app 写入计划 | normal/ultrafast/laser 按新地址生成 |
| 参数模型 | 补齐 gain、frame waiting、row repeat、row_m/row_n、可选 `clk_sel` |
| 单位标注 | 区分 `ui_clk` 5ns、`eth_clk` 8ns、ADC/DAC 20ns/sample、FIFO words、us x50 |
| GUI | 分为基础扫描、DAC 几何、增益/帧/行、模式扩展 |
| 测试 | 更新/新增单测，验证地址、写入计划、单位相关 raw value 不被隐式换算 |

## 不在本单元处理

- 不修改 RTL。
- 不跑 Vivado 综合/实现/bitstream。
- 不做真实板卡写入验证。
- 不实现 DL2 真实数据接收。
- 不把 ns 输入自动换算成寄存器值；如需此能力，应另建显式转换层。

## 验收标准

- `fpga-host mode laser apply --mock --dry-run --json` 中 laser enable 使用 `0x020B` 并执行 checked write。
- `0x0205` 在 host-app 中表示 `sync2_pixel_tri_width`，不再作为 laser enable。
- GUI 可配置更多 `command_monitor_new.v` 参数，并且标签明确单位。
- CLI help 明确 `scan-delay`、`blanker-*`、`acq-*`、`adc-*` 的硬件步进。
- 单元测试和 `compileall` 通过。

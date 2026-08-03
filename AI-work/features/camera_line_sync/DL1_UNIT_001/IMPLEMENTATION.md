# DL1_UNIT_001 实施记录

## 当前结论 / Status

工作包规划完成；尚未开始 RTL、仿真、综合或上板验证。

## 已批准范围

- 在现有 `TRIGGER_H` / F15 上输出低有效相机行同步。
- 覆盖普通、超快和激光模式。
- 每次 `row_repeat` 的实际 X 扫描独立形成一行窗口。
- 保持 FIFO 为 35 bit，不修改 FIFO IP。

## 实施顺序 / Planned Order

1. 固化当前 RTL 证据窗口，并建立针对 `dac_output` 的聚焦 testbench/FIFO stub。
2. 在 `parameter_dacdata_gen.v` 实现激光模式行首/行尾标记复用。
3. 在 `dac_output.v` 实现 DAC 域锁存和旧 sync 隔离。
4. 通过 `dacdata_config.v`、`ETH_TOP.v` 将 `camera_line_sync` 接到 `TRIGGER_H`。
5. 运行聚焦仿真与回归/elaboration。
6. 仿真通过后再跑综合，记录 WNS/WHS 与资源变化。
7. 准备 ILA/示波器检查；下载 bitstream 和真实测量由用户执行。

## 计划改动文件

| 文件 | 状态 |
|---|---|
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | 未修改 |
| `AXI_DDR.srcs/sources_1/new/dac_output.v` | 未修改 |
| `AXI_DDR.srcs/sources_1/new/dacdata_config.v` | 未修改 |
| `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | 未修改 |
| `AI-work/features/camera_line_sync/DL1_UNIT_001/sim/*` | 仅有仿真规划文件 |

## 约束与排除项

- 不修改 `fpga_pin.xdc`；`TRIGGER_H` 已具有 F15/LVCMOS33 约束。
- 不修改 `fifo_generator_4.xci` 或 FIFO 宽度。
- 在 testbench、脚本和 unit 产物边界就绪前，不运行 Vivado/xsim。

## 验证与证据位置

- 仿真：`out/sim/`
- 回归：`out/regression/`
- 综合：`out/synth/`
- 实现/bitstream：`out/impl/`、`out/bitstream/`
- ILA/示波器记录：`out/ila/`、`out/hw_debug/`

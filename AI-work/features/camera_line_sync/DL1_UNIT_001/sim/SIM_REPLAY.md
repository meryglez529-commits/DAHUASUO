# DL1_UNIT_001 仿真复现

## 当前状态

尚不可运行。本单元将遵循 `AI-work/guide/VIVADO_SIM_SOP.md`，并在合适处复用 DL5_UNIT_005 已验证的 Tcl 托管 xsim 流程。

## 计划 DUT 与 testbench

- 主 DUT：`AXI_DDR.srcs/sources_1/new/dac_output.v`
- 支撑逻辑：提供按 `dac_dco` 顺序输出 35-bit word 的 FIFO/IP stub。
- testbench：`sim/tb_dl1_unit_001_camera_line_sync.v`（运行前创建）。

## 必测用例

| TC | 场景 | 通过标准 |
|---|---|---|
| TC1 | 普通模式一行 | `TRIGGER_H` 从第一个至最后一个 `adc_tri=1` word 期间为低。 |
| TC2 | 超快模式一行 | 行窗口规则相同，且 sync1/sync2 仍保持可观察的原行为。 |
| TC3 | 激光模式间隙 | 行首标记拉低后，无 FIFO 读操作的间隙不得将输出释放。 |
| TC4 | 激光模式行尾 | 行尾标记后一个 DAC 时钟才释放输出。 |
| TC5 | 回归 | 激光标记不得激活旧 sync 整形器。 |

## 批处理命令

testbench 与脚本创建完成后，从工程根目录执行：

```powershell
& 'D:\Xilinx\Vivado\2021.1\bin\vivado.bat' -mode batch -source AI-work/features/camera_line_sync/DL1_UNIT_001/sim/run_manual.tcl
```

日志、WDB 与结果标记统一写入 `out/sim/`。

## Vivado GUI 复现

在 Vivado 打开工程后，于 Tcl Console 执行：

```tcl
source AI-work/features/camera_line_sync/DL1_UNIT_001/sim/run_gui.tcl
```

`run_gui.tcl` 将与 testbench 一并创建；在该文件存在前不启动 GUI 仿真。

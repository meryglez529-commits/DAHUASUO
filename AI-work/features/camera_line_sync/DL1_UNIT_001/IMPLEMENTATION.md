# DL1_UNIT_001 实施记录

## 当前结论 / Status

RTL、聚焦仿真和全工程 RTL elaboration 已通过。独立综合已完成逻辑构建但时序未收敛，因此尚未进行 implementation、bitstream 或上板验证。

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
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | 已实现激光模式 FIFO `[34]/[33]` 行首/行尾标记 |
| `AXI_DDR.srcs/sources_1/new/dac_output.v` | 已实现 DAC 域行有效锁存、末 word 后一拍释放，以及激光模式旧 sync 隔离 |
| `AXI_DDR.srcs/sources_1/new/dacdata_config.v` | 已透传 `camera_line_sync` |
| `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | 已将 `TRIGGER_H` 从常量改接 `camera_line_sync` |
| `AI-work/features/camera_line_sync/DL1_UNIT_001/sim/*` | 已加入 FIFO/ILA stub、聚焦 testbench、batch 与 GUI 复现脚本 |

## 约束与排除项

- 不修改 `fpga_pin.xdc`；`TRIGGER_H` 已具有 F15/LVCMOS33 约束。
- 不修改 `fifo_generator_4.xci` 或 FIFO 宽度。
- 在 testbench、脚本和 unit 产物边界就绪前，不运行 Vivado/xsim。

## 本次 RTL 实现（2026-08-04）

- 普通与超快模式：`dac_output` 在 `dac_dco` 域用拆包后的 FIFO `[32]` 直接驱动内部 `camera_line_active`；因此相机窗口与真正的 DAC word 同拍对齐。
- 激光模式：`parameter_dacdata_gen` 仅在 State 16 的首个/最后一个 word 将 FIFO `[34]/[33]` 置位。读侧收到 `[34]` 后置位行有效，收到 `[33]` 后置位 `camera_line_end_pending`，下一 `dac_dco` 拍才释放行有效。
- `camera_line_sync = ~camera_line_active`，通过 `dacdata_config` 传到顶层的 F15 / `TRIGGER_H`。没有修改 XDC、FIFO IP、FIFO 宽度或寄存器映射。
- 聚焦仿真复用 `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl` 的 Vivado Tcl 托管 xsim 方式；本 unit 的日志、WDB 与结果均写入 `out/sim/`。

## 仿真执行记录

| 轮次 | 结果 | 说明 |
|---|---|---|
| 1 | 未开始编译 | Vivado 2021.1 从 `bin/unwrapped/win64.o` 启动，旧模板按相对路径查找 `glbl.v` 失败；已改为本机已确认存在的 `D:/Xilinx/Vivado/2021.1/data/verilog/src/glbl.v`，随后重跑。 |
| 2 | PASS | `run_manual.tcl` 完成 xvlog、xelab 与 Tcl 托管 xsim；测试台在 1431 ns 打印 `PASS`，结果为 `out/sim/result.txt`。 |

## Route result (2026-08-04)

- With explicit user authorization, refreshed project-managed `synth_1` and `impl_1` and ran only through `route_design`; `write_bitstream` was not run.
- Fresh `synth_1` completed in 1m47 with 0 ERROR / 0 CRITICAL WARNING. `impl_1` status: `route_design Complete!`.
- Final timing: WNS = **+0.119 ns**, TNS = 0, WHS = **+0.053 ns**, THS = 0, WPWS = +0.143 ns. Setup, hold, and pulse-width timing are all closed.
- Placed resources: Slice LUT = 62,620 (30.73%), Slice Register = 101,736 (24.96%), BRAM Tile = 404.5 (90.90%), DSP = 16 (1.90%). This feature does not change FIFO width or FIFO IP.
- `report_drc` has no Error; it retains 198 project warnings (including 2 `RPBF-3` IO-port buffering warnings). `report_methodology` retains 36 project Critical Warnings (TIMING-6/7 clock relations) and 556 warnings. These were not introduced by this feature; clock/XDC work is out of this authorized scope.
- Evidence: `out/impl/run_status.txt`, `out/impl/ETH_TOP_timing_summary_routed.rpt`, `out/impl/ETH_TOP_utilization_placed.rpt`, `out/impl/ETH_TOP_drc_routed.rpt`, `out/impl/ETH_TOP_methodology_drc_routed.rpt`, `out/impl/runme.log`, `out/impl/vivado_route_20260804.log`, and `out/impl/vivado_route_20260804.backup.log`. Root Vivado logs were archived to `out/impl/`.
- Hardware acceptance still requires explicit bitstream authorization and board-level oscilloscope/ILA checking.

## Bitstream result (2026-08-04)

- User authorized bitstream generation from the timing-closed routed implementation. `write_bitstream` completed successfully with 0 ERROR / 0 CRITICAL WARNING; no Hardware Manager, JTAG, or board action was performed.
- Deliverables: `out/bitstream/ETH_TOP.bit` (7,966,258 bytes), `out/bitstream/ETH_TOP.bin` (7,966,140 bytes), and `out/bitstream/ETH_TOP.ltx` (969,735 bytes).
- Reproducible command: `vivado.bat -mode batch -source AI-work/features/camera_line_sync/DL1_UNIT_001/impl/run_bitstream.tcl`.
- Evidence: `out/bitstream/run_status.txt`, `out/bitstream/runme.log`, `out/bitstream/vivado.log`, `out/bitstream/launcher_stdout.log`, and `out/bitstream/ETH_TOP_drc_routed.rpt`. The generated bitstream carries the already-recorded routed timing result (WNS +0.119 ns, WHS +0.053 ns).
- Board programming and the active-low camera line-sync electrical/waveform acceptance remain user-executed hardware validation steps.

## RTL elaboration

- 命令：`vivado.bat -mode batch -source synth/run_rtl_elaboration.tcl`。
- 结果：PASS。`out/synth/rtl_elaboration_properties.rpt` 显示顶层为 `ETH_TOP`、器件为 `xc7k325tffg676-2`。
- Vivado 启动时曾自动格式化 `AXI_DDR.xpr`；该工具副作用已恢复，不作为本单元改动。

## 综合策略

- 项目既有 `synth_1` 处于 2026-06-22 的已完成状态，`launch_runs synth_1` 会直接复用旧结果，不能证明本次 RTL。
- `AXI_DDR.runs/**` 是项目规则中的只读 Vivado 生成目录，因此不执行 `reset_run`。
- 改用 `synth/run_unit_synth.tcl` 的独立 `synth_design`；只向 `out/synth/` 写入 DCP、资源和时序报告。结果待运行。

## 独立综合结果（未通过时序门）

- 命令：`vivado.bat -mode batch -source synth/run_unit_synth.tcl`。
- 逻辑构建：`synth_design` 成功，日志为 `out/synth/vivado.log`，其中为 `0 ERROR / 0 CRITICAL WARNING`。
- 时序：`out/synth/timing_summary_synth.rpt` 为 WNS = -0.309 ns、WHS = -1.254 ns，未达到项目规则的 WNS/WHS >= 0 ns，不进入 implementation 或 bitstream。
- 最差 setup 路径是既有 `U6/N1/step_count_reg[15] -> day_level_reg[63]`，并非新增的相机同步寄存器。最差 hold 同样位于既有全工程路径；本次没有修改这些模块。
- 资源报告为 LUT 33.01%、Reg 28.00%、BRAM 90.90%、DSP 1.90%、IOB 70.25%。该结果不能与 2026-06-22 的 `synth_1` 直接比较：旧 run 使用已完成的 OOC/IP 结果，而独立 `synth_design` 会重新展开其实现。
- 结论：本次独立综合证明当前 RTL 可综合且端口贯通，但不能作为时序签核或资源增量证据。若需要完成闭环，必须由用户明确允许刷新受规则保护的 `AXI_DDR.runs/synth_1`，或提供可复用的、已签核的完整综合基线。

## Implementation 执行（2026-08-04）

- 用户已明确授权刷新 `AXI_DDR.runs/synth_1` 与 `impl_1`，以使用当前相机同步 RTL 完成 route_design；不执行 write_bitstream。
- 脚本：`impl/run_impl.tcl`。它在 project-managed run 完成后，将综合/实现日志、时序、资源、DRC、methodology 和 route status 报告复制到 `out/impl/`。
- 首轮：当前综合已在 1 分 47 秒完成（0 ERROR / 0 CRITICAL WARNING），首次 route 在 Phase 2.4 被中断，未形成可用结果。
- 续跑：使用 `impl/run_impl_only.tcl` 复用这次最新 `synth_1`，重置并重跑 `impl_1` 至 route_design；结果待回填。

## 产物边界

- Vivado 在工程根目录生成的 `vivado*.log/.jou` 已移动到 `out/synth/`。
- 已运行 `scan-artifact-spill.py`，以 `out/.artifact_start` 为边界，结果为 PASS：无运行产物遗留在单元外。

## 关键证据索引

- 仿真 PASS：`out/sim/result.txt`、`out/sim/xvlog.log`、`out/sim/xelab.log`、`out/sim/xsim.log`、`out/sim/vivado_dl1_unit001_r2.log`。
- RTL elaboration：`out/synth/rtl_elaboration_properties.rpt`。
- 独立综合：`out/synth/vivado.log`、`out/synth/utilization_synth.rpt`、`out/synth/timing_summary_synth.rpt`、`out/synth/ETH_TOP_unit001_synth.dcp`。

## 验证与证据位置

- 仿真：`out/sim/`
- 回归：`out/regression/`
- 综合：`out/synth/`
- 实现/bitstream：`out/impl/`、`out/bitstream/`
- ILA/示波器记录：`out/ila/`、`out/hw_debug/`

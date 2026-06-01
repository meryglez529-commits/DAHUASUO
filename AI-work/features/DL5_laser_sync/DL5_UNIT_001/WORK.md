# DL5_UNIT_001 工作记录

> 本文件是 DL5 第一次完整开发单元的主入口：需求、计划、AI 实际工作、验证结果和遗留问题都从这里看。

> 2026-05-27 需求复核结论：本包保留为 DL5 第一版实现的历史记录。用户审查 RTL 后指出需求方向存在偏差，后续真实需求、第二轮方案和新的 RTL 修改不再继续改写本包，而从 `../DL5_UNIT_002/WORK.md` 开始。本包中的 PASS 只说明 UNIT_001 自身测试通过，不代表它是最终需求方案。

## 1. 当前结论

DL5 飞秒激光同步采集模式已经完成第一轮 RTL 实现，并完成以下验证：

| 项 | 结果 | 证据 |
|---|---|---|
| 单元仿真 | PASS，8/8 用例通过 | `out/sim/result.txt`、完整 transcript 见 `out/sim/vivado_run_batch.log` |
| RTL elaboration | PASS，0 ERROR / 0 CRITICAL WARNING | `out/sim/dl5_elab.log` |
| synth_1 综合 | PASS，0 ERROR / 0 CRITICAL WARNING | `out/synth/run_synth.log` |
| 资源报告 | 已生成 | `out/synth/utilization_synth.rpt` |

注意：本轮没有完成上板验证；`laser_sync_in` 的实际引脚号和 XDC 约束仍待硬件确认。

## 2. 本工作包范围

本工作包只记录 DL5 第一次开发：

- 新增第五条数据通路：外部飞秒激光作为时间基准，FPGA 在 `ui_clk` 域响应激光脉冲。
- 保留旧 DAC 扫描模式，通过 `laser_mode_en` 寄存器切换。
- 新增 `laser_sync_blanker_ctrl` 控制模块。
- 改动 DL1/DL2 相关接线，使 laser 模式下 blanker/acq/sync2 信号由 DL5 控制。
- 建立用户可复现的 Vivado 仿真入口。

后续如果 DL5 继续加功能，不继续改写本工作包的历史过程；应新建 `DL5_UNIT_002/`。

## 3. 需求快照

DL5 的核心需求：

| 需求 | 当前实现 |
|---|---|
| 激光器作主时钟源 | 外部 `laser_sync_in` 脉冲进入 FPGA，模块内做 3 级 FF 同步和上升沿检测 |
| 1 个激光周期对应 1 个像素 | `laser_period` 到期后产生 `pixel_done_pulse_ui`，跨到 `eth_clk` 后推进 `parameter_dacdata_gen` |
| blanker 与 acq 并行计时 | 二者都从同一个激光上升沿开始独立窗口比较 |
| blanker 输出复用旧 `sync_pixel_tri1` | 内部 `blanker_pulse` 高有效，最终经 `dac_output` 原有取反路径输出低有效 |
| acq 触发复用内部 `adc_tri` | laser 模式下 `laser_acq_pulse` 覆盖旧 FIFO[32] |
| sync2 输出激光事件状态 | laser 模式下 `sync_pixel_tri2` 输出 `laser_event_busy` |
| 旧模式保持不变 | `laser_mode_en=0` 时仍走原 FIFO/State 3 逻辑 |

## 4. 关键决策

| 决策 | 当前状态 |
|---|---|
| 200 MHz 时钟源 | 使用 `ui_clk`，不新增 `clk200m` 接线 |
| blanker 极性 | 物理输出保持低有效，复用现有 `sync_pixel_tri1` 取反路径 |
| acq 延时寄存器 | 新建 `acq_data_delay_time`，不复用 0x0201 `adc_acq_delay` |
| 参数防呆 | `blanker_end <= laser_period`、`acq_end <= laser_period` 由上位机保证，FPGA 不夹紧 |
| mode 切换 | 要求 `laser_mode_en` 只在 `scan_state=0` 时切换 |
| scan_state 门控 | `laser_sync_blanker_ctrl` 内部用 `laser_mode_en & scan_state` 激活状态机 |

## 5. AI 已完成的工作

| 步骤 | 状态 | 说明 |
|---|---|---|
| 需求/方案 v1-v3 整理 | 完成 | 原始设计记录归档在 `evidence/DL5_LASER_SYNC_MODE_DESIGN_v3_original.md` |
| 新控制模块 | 完成 | `laser_sync_blanker_ctrl.v` |
| 单元 testbench | 完成 | `tb_laser_sync_blanker_ctrl.v`，覆盖 TC1-TC8 |
| `parameter_dacdata_gen.v` 修改 | 完成 | State 3 增加 laser one-shot 分支 |
| `dac_output.v` 修改 | 完成 | `adc_tri/sync1/sync2` 三处 mux |
| `dacdata_config.v` 修改 | 完成 | 例化 DL5 控制器并完成 CDC |
| `command_monitor_new.v` 修改 | 完成 | 新增 0x0205-0x020A 寄存器 |
| `ETH_TOP.v` 修改 | 完成 | 新增 `laser_sync_in` 顶层端口和参数接线 |
| 单元仿真 | 完成 | `PASS` |
| RTL elaboration | 完成 | `PASS` |
| synth_1 | 完成 | `BUILD PASS` |
| 上板验证 | 未完成 | 等用户接硬件和确认引脚 |

## 6. 用户从哪里开始看

| 你要做什么 | 入口 |
|---|---|
| 看 AI 本轮到底改了哪些 RTL | `RTL_REVIEW.md` |
| 在 Vivado 里复现仿真和打开波形 | `SIM_REPLAY.md` |
| 看稳定后的 DL5 事实，不看开发过程 | `../../../guide/data-paths/DL5_LASER_SYNC_AS_BUILT.md` |
| 看旧设计草稿全文 | `evidence/DL5_LASER_SYNC_MODE_DESIGN_v3_original.md` |
| 看单元仿真结论 | `out/sim/result.txt`、`out/sim/xsim.log` |
| 看单元仿真完整输出 | `out/sim/vivado_run_batch.log` |
| 看综合日志 | `out/synth/run_synth.log` |

## 7. 未完成项

| 项 | 状态 | 影响 |
|---|---|---|
| `laser_sync_in` 引脚号 | 待硬件确认 | 目前顶层已有端口，但 XDC 未约束 |
| `laser_sync_in` IOSTANDARD | 待硬件确认 | 设计按 2.5V TTL 输入预期，需确认 FPGA bank 支持 |
| 上板验证 | 待用户执行 | 需要真实激光脉冲和外设验证 |
| `sync_pixel_tri2 = laser_event_busy` 是否符合外设真实需要 | 待实际接外设确认 | 如外设需要 acq 脉冲，后续建 `DL5_UNIT_002` 修改 |
| 集成仿真 | 本轮未跑 | 当前用单元仿真 + RTL elaboration + synth 覆盖；若用户希望看完整链路波形，后续补一个集成 testbench |

## 8. 本次补救说明

2026-05-27 对 DL5 进行文档补救：

- 把散落的 DL5 设计、RTL 审查、仿真复现、综合证据收拢到本工作包。
- 实际验证 `sim/run_batch.tcl` 可以通过 Vivado 2021.1 调用 XSim 跑通，并重新生成 `out/sim/waveform.wdb`。
- 不修改 RTL 功能。
- 不修改 `fpga-project-reader` skill 本体。
- 旧 `DL5_LASER_SYNC_MODE_DESIGN.md` 改为归档入口，避免继续被误认为当前进度文档。

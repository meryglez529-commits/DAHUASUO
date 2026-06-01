# DL5_UNIT_001 Vivado 仿真复现说明

> 本文件给用户使用。目标是让你能在 Vivado 里复现 AI 的仿真、打开波形、知道该看哪些信号。

> 2026-05-27 需求复核结论：本仿真只证明 UNIT_001 第一版实现自身通过，不代表它满足后续重新对齐的真实需求。UNIT_002 的仿真入口将在 `../DL5_UNIT_002/SIM_REPLAY.md` 中重新定义。

## 1. 已有结果

AI 已经跑过一次 DL5 单元仿真，并在 2026-05-27 用本工作包里的 `sim/run_batch.tcl` 复跑通过。

快速结论在：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/xsim.log
```

完整 Vivado transcript 在：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/vivado_run_batch.log
```

关键结论：

| 项 | 结果 |
|---|---|
| 仿真器 | Vivado XSim v2021.1 |
| testbench | `AXI_DDR.srcs/sim_1/new/tb_laser_sync_blanker_ctrl.v` |
| DUT | `AXI_DDR.srcs/sources_1/new/laser_sync_blanker_ctrl.v` |
| 用例 | TC1-TC8 |
| 结果 | `PASS`，`errors=0` |

已有波形数据库：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
```

## 2. `.wdb` 和 `.wcfg` 是什么

| 文件 | 作用 | 怎么用 |
|---|---|---|
| `.wdb` | xsim 波形数据库，里面是仿真时刻和信号值 | 用 Vivado 打开 |
| `.wcfg` | Vivado 波形窗口布局，记录哪些信号放进波形窗口、显示顺序和进制 | 打开 `.wdb` 后加载 |

简单理解：`.wdb` 是数据，`.wcfg` 是看数据的视图。

## 3. 在 Vivado GUI Tcl Console 里直接打开已有波形

先在 Vivado GUI 打开本工程，然后在 Tcl Console 粘贴：

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj
open_wave_database AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
open_wave_config AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/waves.wcfg
```

如果你不想记两条命令，可以只粘贴：

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj
source AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/run_gui.tcl
```

`run_gui.tcl` 会打开已有 `.wdb`，加载 `waves.wcfg`，并尝试补充关键波形信号。

## 4. 重新跑一次单元仿真

在 PowerShell 里粘贴：

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj
& "D:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch -source AI-work\features\DL5_laser_sync\DL5_UNIT_001\sim\run_batch.tcl -log AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\sim\vivado_run_batch.log -journal AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\sim\vivado_run_batch.jou
```

跑完后看：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/xsim.log
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/result.txt
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/vivado_run_batch.log
```

通过条件：

- `result.txt` 里是 `PASS`
- `xsim.log` 里出现 `result=PASS` 和 `errors=0`
- `vivado_run_batch.log` 里 TC1-TC8 都是 `ok`，并出现 `PASS`

说明：脚本会临时把 Vivado 工程的 `target_simulator` 设置为 `XSim`，并临时把 `sim_1` top 切到 DL5 testbench；结束前会恢复原来的仿真配置，不保存这些临时设置。这个工程在 `update_compile_order` 会花大约 1 分钟，看到这里等待是正常的。

## 5. 重新跑 RTL elaboration

这个不是波形仿真，而是检查顶层接线、端口、位宽、模块缺失等问题。PowerShell 粘贴：

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj
& "D:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch -source AI-work\scripts\dl5_elab.tcl -tclargs AXI_DDR.xpr -log AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\sim\dl5_elab_replay.log -journal AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\sim\dl5_elab_replay.jou
```

通过条件：

- `INFO: ERROR count = 0`
- `INFO: CRITICAL WARNING count = 0`
- `INFO: RTL elaboration PASS`
- 顶层 port 列表里能看到 `laser_sync_in`

## 6. 重新跑 synth_1

PowerShell 粘贴：

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj
& "D:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch -source AI-work\scripts\run_synth.tcl -tclargs AXI_DDR.xpr synth 4 -log AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\synth\run_synth_replay.log -journal AI-work\features\DL5_laser_sync\DL5_UNIT_001\out\synth\run_synth_replay.jou
```

通过条件：

- `INFO  : synth_1 status: synth_design Complete!`
- `INFO  : BUILD PASS`
- 综合日志中没有 ERROR / CRITICAL WARNING

## 7. 仿真用例说明

| 用例 | 验证点 | 预期 |
|---|---|---|
| TC1 | `laser_mode_en=0` | 激光脉冲不触发任何输出 |
| TC2 | 单个正常激光事件 | blanker=40 拍，acq=80 拍，busy=400 拍，done=1 |
| TC3 | 连续 3 个激光脉冲 | 3 个完整事件 |
| TC4 | `blanker_delay=0` | blanker 立即进入窗口，总宽度仍为 40 拍 |
| TC5 | BUSY 中来第二个激光脉冲 | 第二个脉冲被忽略 |
| TC6 | `blanker_time=0` | blanker 全程为 0，其它路径正常 |
| TC7 | `acq_time=0` | acq 全程为 0，其它路径正常 |
| TC8 | `scan_state=0` | 状态机完全不响应 |

## 8. 看波形时重点看什么

建议优先看这些信号：

| 信号 | 你要确认什么 |
|---|---|
| `laser_sync_in` | testbench 发出的 50ns 高电平脉冲 |
| `dut.laser_pulse_edge` | 异步输入同步后只形成 1 拍上升沿 |
| `dut.current_state` | IDLE -> BUSY -> DONE -> IDLE |
| `dut.t_cnt` | BUSY 期间从 0 递增到 `laser_period - 1` |
| `blanker_pulse` | 在 blanker 窗口内为 1 |
| `laser_acq_pulse` | 在 acq 窗口内为 1 |
| `laser_event_busy` | BUSY 全程为 1 |
| `pixel_done_pulse_ui` | DONE 状态只打一拍 |

## 9. 本轮仿真的边界

这次可复现的是 `laser_sync_blanker_ctrl` 单元仿真。它验证 DL5 的核心时序控制器。

本轮没有提供完整链路集成波形，例如：

- PC 写 0x0205-0x020A 寄存器。
- `parameter_dacdata_gen` 进入 State 3。
- `dac_output` 末级输出到 `adc_tri/sync_pixel_tri1/sync_pixel_tri2`。

这些接线已经通过 RTL elaboration 和 synth_1 验证没有端口/位宽/模块缺失问题；如果后续你希望看完整链路时序，应新建 `DL5_UNIT_002` 或在本功能验收前补一个集成 testbench。

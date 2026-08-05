# DL5_UNIT_007：仿真复现

## Vivado GUI

在 Vivado GUI 的 Tcl Console 执行：`source AI-work/features/DL5_laser_sync/DL5_UNIT_007/sim/run_gui.tcl`。该命令只在单元目录的 `out/sim/gui_work/` 编译并打开 XSim，不改工程、不写 bitstream。

# DL5_UNIT_007：仿真复现

## 依据

- 项目 SOP：`AI-work/guide/VIVADO_SIM_SOP.md`
- 复用模板：`AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl`
- 本单元采用独立的 FIFO/ILA/除法器行为模型，直接编译 `parameter_dacdata_gen.v` 和 `dac_output.v`；不依赖项目生成物。

## 运行

```powershell
New-Item -ItemType Directory -Force AI-work/features/DL5_laser_sync/DL5_UNIT_007/out/sim
& "D:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch `
  -source AI-work/features/DL5_laser_sync/DL5_UNIT_007/sim/run_batch.tcl `
  -log AI-work/features/DL5_laser_sync/DL5_UNIT_007/out/sim/vivado_unit007.log `
  -journal AI-work/features/DL5_laser_sync/DL5_UNIT_007/out/sim/vivado_unit007.jou
```

## 用例与通过条件

- TC1：普通模式运行 100 个 ETH 周期，FIFO[32] 等于 `adc_tri`，State 17/18 不可达。
- TC2：超快模式同上。
- TC3：激光模式完成两像素和一段回扫后，记录 DAC completion toggle；恢复期间发出的 laser 不得改变 `laser_toggle`；State 14 时间减 completion 时间不得小于 `dacx_recovery_time`。

通过条件为 testbench 打印并写入 `PASS`。

## 结果

- 日期：2026-08-05
- `TC1/TC2/TC3`：PASS
- 关键测量：`tail_done=3.890 us`，`State14=4.932 us`，间隔 `1.042 us`，配置值 `1.000 us`。
- 证据：`out/sim/xsim.log`、`out/sim/dl5_unit007_tb_result.txt`、`out/sim/result.txt`。

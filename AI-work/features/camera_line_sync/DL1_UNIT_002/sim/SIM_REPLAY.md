# DL1_UNIT_002：仿真复现记录（已通过）

## 必须遵循的项目 SOP

项目级仿真规程：`AI-work/guide/VIVADO_SIM_SOP.md`。

本工程不能直接使用独立 `xsim`，也不应使用 batch `launch_simulation`；必须沿用 Vivado Tcl 主进程托管的 `exec xvlog` / `exec xelab` / 内置 `xsim` 流程。

## 已选用的近邻模板

- 逻辑模板：`../DL1_UNIT_001/sim/tb_dl1_unit_001_camera_line_sync.v`
- Tcl 模板：`../DL1_UNIT_001/sim/run_manual.tcl`
- 项目已验证 batch 参考：`../../DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl`

本单元已复制/适配为 `tb_dl1_unit_002_marker_alignment.v`、`dl1_unit_002_stubs.v`、
`run_manual.tcl` 和 `run_gui.tcl`。所有日志、WDB 和 `result.txt` 只写入 `out/sim/`。

最终运行于 2026-08-05 PASS，仿真结束于 3630 ns。证据：`out/sim/result.txt`、
`out/sim/xvlog.log`、`out/sim/xelab.log`、`out/sim/xsim.log` 与
`out/sim/vivado_retry6_fifo_latency.log`。早期失败日志保留在同一目录；根因是 testbench
时钟连接和 FIFO stub 时序，不是修复 RTL，见 `../IMPLEMENTATION.md`。

## 计划 TC

| TC | 输入 | 检查 |
|---|---|---|
| TC1 | 激光、3 X、`dac_sample=50` | 首个 `para_config_wr_en` word 的 bit34=1；最终 word 的 bit33=1；二者唯一，DAC 域低窗口为 150 word。 |
| TC2 | 激光、3 X、`dac_sample=4` | marker 仍随首末实际 word，对历史短驻留设置不产生提前释放，DAC 域低窗口为 12 word。 |
| TC3 | 激光、单 X、`dac_sample=1` | 同一 word 的 bit34/bit33 同为 1；相机恰好覆盖该一个 word。 |
| TC4 | 激光、两个像素间插入无 FIFO 读空隙 | `camera_line_sync` 维持低，不能被空隙释放。 |
| TC5 | 普通模式、16 个有效 `adc_tri` word | 相机低窗口仍与 FIFO[32] 精确一致。 |
| TC6 | 超快模式 | TC5 行为不变，legacy sync1/sync2 仍可见。 |

## PASS 定义

testbench 需记录错误计数、输出 `PASS`/`FAIL`，并对每个实际写入 word 断言 marker、DAX/DAY、写使能在同一流水级。批处理脚本须检查编译、展开、运行日志和 `result.txt`，不允许仅凭 Vivado 进程返回码判定成功。

实际 PASS 条件：顶层只输出 `PASS: DL1_UNIT_002 marker alignment and normal/ultrafast regression`，
且所有 case 的 `errors` 求和为 0；任意 `FAIL:` 或超时均使脚本以非零退出。

## Batch 复现命令

从工程根目录执行：

```powershell
& 'D:/Xilinx/Vivado/2021.1/bin/vivado.bat' -mode batch `
  -log AI-work/features/camera_line_sync/DL1_UNIT_002/out/sim/vivado.log `
  -journal AI-work/features/camera_line_sync/DL1_UNIT_002/out/sim/vivado.jou `
  -source AI-work/features/camera_line_sync/DL1_UNIT_002/sim/run_manual.tcl
```

## 计划 GUI 复现命令

实现脚本后，在已打开工程的 Vivado Tcl Console 执行：

```tcl
source AI-work/features/camera_line_sync/DL1_UNIT_002/sim/run_gui.tcl
```

该命令用于在已打开工程中复现已通过的 batch 仿真。

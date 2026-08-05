# DL1_UNIT_002：仿真复现计划（尚未执行）

## 必须遵循的项目 SOP

项目级仿真规程：`AI-work/guide/VIVADO_SIM_SOP.md`。

本工程不能直接使用独立 `xsim`，也不应使用 batch `launch_simulation`；必须沿用 Vivado Tcl 主进程托管的 `exec xvlog` / `exec xelab` / 内置 `xsim` 流程。

## 已选用的近邻模板

- 逻辑模板：`../DL1_UNIT_001/sim/tb_dl1_unit_001_camera_line_sync.v`
- Tcl 模板：`../DL1_UNIT_001/sim/run_manual.tcl`
- 项目已验证 batch 参考：`../../DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl`

实施时复制为本单元的 `tb_dl1_unit_002_marker_alignment.v`、stub 和 `run_manual.tcl`，所有日志、WDB 和 `result.txt` 只写入 `out/sim/`。当前没有 testbench、没有仿真结果，不能将本文件解释为仿真通过。

## 计划 TC

| TC | 输入 | 检查 |
|---|---|---|
| TC1 | 激光、16 X、`dac_sample=50` | 首个 `para_config_wr_en` word 的 bit34=1；最终 word 的 bit33=1；二者唯一。 |
| TC2 | 激光、16 X、`dac_sample=4` | marker 仍随首末实际 word，对历史短驻留设置不产生提前释放。 |
| TC3 | 激光、单 X、`dac_sample=1` | 同一 word 的 bit34/bit33 同为 1；相机恰好覆盖该 word。 |
| TC4 | 激光、两个像素间插入无 FIFO 读空隙 | `camera_line_sync` 维持低，不能被空隙释放。 |
| TC5 | 普通模式、16 个有效 `adc_tri` word | 相机低窗口仍与 FIFO[32] 精确一致。 |
| TC6 | 超快模式 | TC5 行为不变，legacy sync1/sync2 仍可见。 |

## PASS 定义

testbench 需记录错误计数、输出 `PASS`/`FAIL`，并对每个实际写入 word 断言 marker、DAX/DAY、写使能在同一流水级。批处理脚本须检查编译、展开、运行日志和 `result.txt`，不允许仅凭 Vivado 进程返回码判定成功。

## 计划 GUI 复现命令

实现脚本后，在已打开工程的 Vivado Tcl Console 执行：

```tcl
source AI-work/features/camera_line_sync/DL1_UNIT_002/sim/run_gui.tcl
```

该命令当前是待实施入口，不代表脚本或仿真已经存在/通过。

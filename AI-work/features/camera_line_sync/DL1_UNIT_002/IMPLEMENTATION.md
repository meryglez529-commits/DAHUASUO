# DL1_UNIT_002：实施记录

## 当前状态：方案已评审，等待实施授权

截至 2026-08-05，本单元只建立了修复方案和验证门槛，**没有修改 RTL、IP、XDC、寄存器映射、上位机、bitstream 或板卡配置**。

已确认的根因及波形证据来自 `DL5_UNIT_006`；普通模式的相机同步对照通过，因此本次不把问题归因于 TRIGGER_H 接线或相机物理接口。

## 拟定实施顺序

1. 复制并扩展 `DL1_UNIT_001` 的受控 DAC 域 testbench；新增真实 `parameter_dacdata_gen` 写侧 marker 对齐检查。
2. 在 `parameter_dacdata_gen.v` 实施 `sync_pixel_tri2/1` 与 DAX/DAY/`wr_en` 同级寄存器打包的最小改动；不改 FIFO 宽度和 State14。
3. 运行新旧相机用例、普通/超快回归和激光边界用例，存档至 `out/sim/`。
4. 仅为了确认修复效果，重接 `dac_output.v` 中既有 `ila_2/probe2` 的调试输入；不改 ILA XCI 的端口宽度或深度。
5. 顺序执行 `synth_1`、`impl_1`、`write_bitstream`，分别归档报告、日志、bit/ltx。
6. 用户下载匹配 bit/ltx 后，用 unit-local ILA 脚本抓取激光整线；最后以 TRIGGER_H + AOUT1 示波器复核。

## 拟修改文件清单

| 文件 | 状态 | 目的 |
|---|---|---|
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | 待改 | 让激光 FIFO[34]/[33] 与实际写入 DAX/DAY word 对齐。 |
| `AXI_DDR.srcs/sources_1/new/dac_output.v` | 仅调试待改 | 打包既有 DAC 域观测量至不变宽度的 `ila_2/probe2`；不改相机功能状态机。 |
| `sim/tb_dl1_unit_002_marker_alignment.v` | 待新增 | 写侧真实 word 对齐及 DAC 域窗口回归。 |
| `sim/dl1_unit_002_stubs.v`、`sim/run_manual.tcl`、`sim/run_gui.tcl` | 待新增 | 遵循项目仿真 SOP 的可复现脚本。 |
| `ila/capture_laser_camera_alignment.tcl` | 待新增 | 修复镜像的 unit-local ILA 导出。 |

明确不改：FIFO `.xci`、ILA `.xci` 端口配置、XDC、顶层 IO、主机寄存器和 State14。

## 实施前阻断条件

- 未先通过仿真，禁止运行综合/实现。
- 实现有负时序、DRC ERROR 或 CRITICAL WARNING，禁止生成交付 bitstream。
- 上板只看到相机低电平而没有验证 bit34/bit33 与 DAX 的相对位置，禁止宣称问题已修复。

## 已有参考与证据

- 根因与上板证据：`../../DL5_laser_dax_diagnosis/DL5_UNIT_006/BOARD_VERIFICATION.md`
- 初版相机功能仿真：`../DL1_UNIT_001/sim/SIM_REPLAY.md`
- 项目仿真 SOP：`../../../guide/VIVADO_SIM_SOP.md`
- 已验证回退镜像：见 `ARCHITECTURE.md` 第 8 节。

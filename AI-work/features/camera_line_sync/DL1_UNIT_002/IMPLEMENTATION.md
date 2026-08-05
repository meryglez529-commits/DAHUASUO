# DL1_UNIT_002：实施记录

## 当前状态：RTL、仿真、实现和激光板级 ILA 通过

截至 2026-08-05，已按批准方案修改 `parameter_dacdata_gen.v`：激光 FIFO[34]/[33] 不再由
State16 计数器组合旁路，而是由 `sync_pixel_tri2/1` 与 DAX/DAY/`para_config_wr_en` 同拍
寄存、再打包写入 FIFO。未修改 IP、XDC、寄存器映射、上位机或板卡配置。

已新增 unit-local 仿真源：`sim/tb_dl1_unit_002_marker_alignment.v`、
`sim/dl1_unit_002_stubs.v`、`sim/run_manual.tcl` 和 `sim/run_gui.tcl`。2026-08-05 的最终
Vivado batch 仿真 PASS，仿真时间 3630 ns；证据为 `out/sim/result.txt`、`xvlog.log`、
`xelab.log`、`xsim.log` 与 `vivado_retry6_fifo_latency.log`。

仿真通过后，已在 `dac_output.v` 只重接现有 `ila_2/probe2[15:0]`：
`{12'd0, laser_mode_en_dac, camera_line_active, FIFO[34], FIFO[33]}`。没有改 ILA XCI 的
宽度、深度或配置，也没有改相机状态机功能逻辑。新建 `impl/build_camera_marker_fix_bitstream.tcl`
会先检查现有 ILA IP 参数，再拒绝任何自动 XCI 修改；`ila/capture_laser_camera_alignment.tcl`
供用户下载匹配 bit/LTX 并启动激光模式后使用。实现于 2026-08-05 完成：`write_bitstream`
成功，正式时序为 WNS=+0.202 ns、WHS=+0.048 ns，所有用户时序约束满足；实现阶段无 ERROR
或 CRITICAL WARNING。交付文件为 `out/bitstream/ETH_TOP_camera_marker_fix.bit` 与其匹配的
`ETH_TOP_camera_marker_fix.ltx`。资源中 Block RAM Tile 为 414.5/445（93.15%）；DRC 有 198 条
既有 Warning、无 Error，未因本次 FIFO marker 对齐修复新增 IP 或约束变更。

已确认的根因及波形证据来自 `DL5_UNIT_006`；普通模式的相机同步对照通过，因此本次不把问题归因于 TRIGGER_H 接线或相机物理接口。

## 拟定实施顺序

1. 已完成：新增真实 `parameter_dacdata_gen` 写侧 marker 对齐检查，并复用 `dac_output` 的 DAC 域状态机。
2. 已完成：在 `parameter_dacdata_gen.v` 实施 `sync_pixel_tri2/1` 与 DAX/DAY/`wr_en` 同级寄存器打包的最小改动；未改 FIFO 宽度和 State14。
3. 已完成：激光 `dac_sample=1/4/50`、普通和超快回归 PASS，证据存档至 `out/sim/`。
4. 已完成：重接 `dac_output.v` 中既有 `ila_2/probe2` 的调试输入；未改 ILA XCI。
5. 已完成：按 `impl/build_camera_marker_fix_bitstream.tcl` 执行 `synth_1`、`impl_1`、`write_bitstream`，并归档报告、日志、匹配 bit/ltx；正式 WNS=+0.202 ns、WHS=+0.048 ns。
6. 用户下载匹配 bit/ltx 后，用 unit-local ILA 脚本抓取激光整线；最后以 TRIGGER_H + AOUT1 示波器复核。

## 拟修改文件清单

| 文件 | 状态 | 目的 |
|---|---|---|
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | 已改，仿真/实现通过 | 让激光 FIFO[34]/[33] 与实际写入 DAX/DAY word 对齐。 |
| `AXI_DDR.srcs/sources_1/new/dac_output.v` | 已改，仿真/实现通过，仅 ILA 连接 | 不变宽度 probe2 打包 marker/active/mode；相机状态机、FIFO 读时序不改。 |
| `sim/tb_dl1_unit_002_marker_alignment.v` | 已新增，PASS | 三种激光驻留、真实写侧 word 对齐及 DAC 域窗口回归。 |
| `sim/dl1_unit_002_stubs.v`、`sim/run_manual.tcl`、`sim/run_gui.tcl` | 已新增，PASS | 遵循项目仿真 SOP 的可复现脚本。 |
| `impl/build_camera_marker_fix_bitstream.tcl` | 已新增，已通过 | 检查既有 ILA IP 形状后重新实现，不自动修改 XCI；已生成匹配 bit/ltx。 |
| `ila/capture_laser_camera_alignment.tcl` | 已新增，待上板 | 抓 ETH、DAC marker/camera 和采集 ILA。 |

## 仿真问题与处置

首次仿真平台把 `parameter_dacdata_gen` 的历史命名端口 `ui_clk` 错接到 200 MHz UI 时钟；
真实工程由 `dacdata_config` 将它接到 125 MHz `eth_clk`。该错误会使 testbench 在错误时钟域
抽样 `para_config_wr_en`，表现为漏看首 marker。第二个临时 FIFO stub 又误用了首字直通模型，
与 `dac_output` 的 `rd_en/rd_en_r` 寄存器输出时序不匹配。两项均为仿真平台问题，不是 RTL
功能失败；已改为真实时钟连接与读时钟寄存器输出 FIFO 模型，最终 PASS。

## 实现证据（2026-08-05）

- 执行脚本：`impl/build_camera_marker_fix_bitstream.tcl`；最终状态：`IMPL_STATUS=write_bitstream Complete!`。
- 正式报告：`out/impl/timing_summary.rpt` 显示 WNS=+0.202 ns、WHS=+0.048 ns、TNS/THS=0，且“所有用户时序约束满足”。
- 资源报告：`out/impl/utilization.rpt`，Block RAM Tile 414.5/445（93.15%）。
- DRC 报告：`out/impl/drc.rpt`，198 条 Warning、0 Error；实现/bitgen 日志均为 0 Critical Warning、0 Error。Warning 覆盖工程既有的门控时钟、RAM 异步控制、IO 缓冲等规则，未更改其相关 RTL/IP/XDC。
- 交付与调试描述：`out/bitstream/ETH_TOP_camera_marker_fix.bit`（8,164,678 bytes）和匹配 `ETH_TOP_camera_marker_fix.ltx`（965,790 bytes）。板级 ILA 必须加载这对文件，禁止混用旧 `.ltx`。

明确不改：FIFO `.xci`、ILA `.xci` 端口配置、XDC、顶层 IO、主机寄存器和 State14。

## 板级 ILA 证据（2026-08-05）

- 使用匹配的 `ETH_TOP_camera_marker_fix.bit/.ltx`，由工程上位机下发并读回确认：16×16、`dac_sample=50`、行首恢复 5 µs、扫描延时 800 ns；DL5 原始计数为扫描延时/束闸延时/束闸宽度/采集延时/采集宽度=`100/20/80/30/60`。
- `eth_full_line` 捕获到 16 个完整的 State16 写侧点（X=0…15），每点 50 个 `eth_clk` 周期，`prog_full=0`；相邻激光上升沿相隔 250 个 `eth_clk` 周期，即 2 µs。
- `dac_camera_alignment` 捕获到首 marker（FIFO[34]）与首有效 DAX=`0x1999` 同一读 word，末 marker（FIFO[33]）与末有效 DAX=`0xE664` 同一读 word。相机低电平覆盖至末点后，回扫首码 `0xE260` 装载时恢复高电平；详细逐样本记录见 `BOARD_VERIFICATION.md`。
- `acq_timing` 捕获到每次激光边沿后 120 个 `ui_clk` 周期（600 ns）延迟、240 个 `ui_clk` 周期（1.2 µs）采集高窗，与 `0x0209=30`、`0x020A=60` 一致。

## 实施前阻断条件

- 未先通过仿真，禁止运行综合/实现。
- 实现有负时序、DRC ERROR 或 CRITICAL WARNING，禁止生成交付 bitstream（本次已通过）。
- 板级 ILA 已验证 bit34/bit33 与 DAX 的相对位置；后续示波器测试仍用于确认 TRIGGER_H 的实际电平和接口连接。

## 已有参考与证据

- 根因与上板证据：`../../DL5_laser_dax_diagnosis/DL5_UNIT_006/BOARD_VERIFICATION.md`
- 初版相机功能仿真：`../DL1_UNIT_001/sim/SIM_REPLAY.md`
- 项目仿真 SOP：`../../../guide/VIVADO_SIM_SOP.md`
- 已验证回退镜像：见 `ARCHITECTURE.md` 第 8 节。

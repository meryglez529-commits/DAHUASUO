# 2026-08-05 live diagnostic build status

- The current diagnostic probe set includes: ETH-side accepted-trigger/state/FIFO
  flow/recovery counter; DAC-side DAX/DAY, FIFO-empty/read, line-end marker, and
  actual active-low `camera_line_sync`; the pre-existing UI ILA retains acquisition
  delay/time configuration, state, and both counters.
- The earlier post-route result (WNS=+0.043 ns, WHS=+0.049 ns) is superseded before
  delivery because it did not directly record `camera_line_sync`. `ila_2/probe0`
  now observes it in the DAC clock domain, replacing previously validated blanker.
- This is debug-only; no business logic, register mapping, FIFO format/depth, or IO
  constraint changes. The resource-optimized final implementation qualified.

# DL5_UNIT_006：实施记录

## 当前状态

已完成资源优化诊断 ILA bitstream 及板级抓取：WNS=+0.105 ns、WHS=+0.051 ns、BRAM=414.5/445（93.15%，相对 404.5 基线增加约 2.5%），DRC 0 error/0 critical warning。最终 16x16 条件触发证据已导出至 `out/ila/`。先以 `dac_sample=4` 解释了 80 ns 末点，随后仅改 `0x0002=50` 重抓，确认 16 个点均完整驻留 1.000 us，FIFO 没有高延时积压；未改扫描 RTL。相机同步仍未拉低，已定位为激光行首 FIFO bit34 与实际写使能错开一拍，详见 `BOARD_VERIFICATION.md`；修复待单独 RTL 变更闭环。

## 实施顺序

1. 将现有 `ila_1`/`ila_2` 的采样深度设为 4096；
2. 重编码两处现有 ILA 输入，仅接入诊断信号；
3. 运行 `synth_1 -> impl_1 -> write_bitstream`，检查时序、DRC 和资源变化；
4. 用户下载 `ETH_TOP_dl5_dax_diag.bit` 与配套 LTX；
5. 通过受控脚本抓完整行、线尾 DAX 输出和恢复；导出 CSV/VCD 并给出三个问题的根因结论。

## 复用路径

- 项目 SOP：`AI-work/guide/VIVADO_SIM_SOP.md`；
- ILA 启动器：`AI-work/scripts/run_vivado_ila_guarded.ps1`；
- 历史 eth ILA 抓取：`AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_dax_anomaly_eth.tcl`；
- 本单元产物根：`AI-work/features/DL5_laser_dax_diagnosis/DL5_UNIT_006/out/`。

## 风险

- ILA 深度增加会增加 BRAM 使用量并可能影响布线时序；以本次实现报告为准。
- 诊断 bitstream 只用于定位。未完成 ILA 结论前不改动业务功能。

## 最终构建证据（2026-08-05）

- 高 BRAM 版：`out/impl/build_diagnostic_bitstream_final.log`；虽经后优化通过时序，但 BRAM=429.5/445，不交付。
- 最终资源优化版：`out/impl/build_diagnostic_bitstream_resource_optimized.log`；WNS=+0.105 ns、WHS=+0.051 ns、BRAM=414.5/445。
- 时序/DRC：`out/impl/timing_summary.rpt`、`out/impl/drc.rpt`。
- 早期调试脚本失败记录：`out/impl/build_diagnostic_bitstream_retry4.log`（bitgen 已完成，但旧脚本未重新打开 routed checkpoint 即生成报告）；已由当前脚本修复。
- 可下载匹配对：`out/bitstream/ETH_TOP_dl5_dax_diag.bit`、`out/bitstream/ETH_TOP_dl5_dax_diag.ltx`。
- 上板抓取：`ila/capture_full_line_and_tail.tcl`，必须通过 `AI-work/scripts/run_vivado_ila_guarded.ps1` 运行；采集 ILA 的深度为 1024，触发位置为 512。
- 2026-08-05 板级结论与逐样本证据：`BOARD_VERIFICATION.md`；首次条件抓取 CSV 时间戳为 `20260805_135750`，`dac_sample=50` 复测时间戳为 `20260805_144245`。

## 产物边界

- 项目托管的 OOC/综合/实现运行会在只读的 `AXI_DDR.runs/` 产生 `.jou`，其可审查副本与最终报告已存入本单元 `out/impl/`。
- 项目根目录的 `vivado.log`、`vivado_pid18956.str` 被用户已打开的 Vivado GUI（PID 18956）锁定，无法安全移动；未关闭 GUI，未删除文件。本单元不依赖它们作为验证证据。
- 最终 spill 扫描同时列出用户 GUI 管理的 `.Xil/Vivado-18956-*/hw_ila_data_*` 与 `AXI_DDR.hw/hw_1/wave/` 历史工作目录；它们未被移动或删除。受控批处理启动器每次均报告 `NEW_DROOT_SPILL_COUNT=0`，本次 CSV/VCD/批处理日志均在本单元 `out/ila/`。
- 本次 `dac_sample=50` 重抓后，以更新过的 `.artifact_start` 运行严格 spill 扫描；唯一命中是用户已打开 Vivado GUI 更新的项目根 `vivado_pid18956.str`。该锁定 GUI 文件不属于本次脚本，未移动或删除；受控启动器的 `dwell50_camera_20260805_144242.spill_manifest.txt` 仍为 `NEW_DROOT_SPILL_COUNT=0`。

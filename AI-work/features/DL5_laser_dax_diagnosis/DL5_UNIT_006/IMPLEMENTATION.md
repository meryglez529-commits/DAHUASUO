# 2026-08-05 live diagnostic build status

- The current diagnostic probe set includes: ETH-side accepted-trigger/state/FIFO
  flow/recovery counter; DAC-side DAX/DAY, FIFO-empty/read, line-end marker, and
  actual active-low `camera_line_sync`; the pre-existing UI ILA retains acquisition
  delay/time configuration, state, and both counters.
- The earlier post-route result (WNS=+0.043 ns, WHS=+0.049 ns) is superseded before
  delivery because it did not directly record `camera_line_sync`. `ila_2/probe0`
  now observes it in the DAC clock domain, replacing previously validated blanker.
- This is debug-only; no business logic, register mapping, FIFO format/depth, or IO
  constraint changes. The final full implementation and post-route repair qualified.

# DL5_UNIT_006：实施记录

## 当前状态

已完成诊断 ILA bitstream：最终后优化 WNS=+0.189 ns、WHS=+0.053 ns，DRC 0 error/0 critical warning。`out/bitstream/` 中的 bit/LTX 已包含完整行诊断、采集时序和实际低有效相机行同步；等待用户下载后上板抓取。

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

- 初始全量实现：`out/impl/build_diagnostic_bitstream_final.log`；bitgen 成功但 WNS=-0.152 ns，未交付。
- 最终后优化：`out/impl/post_route_timing_repair_final.log`，`POST_ROUTE_WNS=0.189`、`POST_ROUTE_WHS=0.053`。
- 时序/DRC：`out/impl/post_route_repair_timing_summary.rpt`、`out/impl/post_route_repair_drc.rpt`。
- 可下载匹配对：`out/bitstream/ETH_TOP_dl5_dax_diag.bit`、`out/bitstream/ETH_TOP_dl5_dax_diag.ltx`。
- 上板抓取：`ila/capture_full_line_and_tail.tcl`，必须通过 `AI-work/scripts/run_vivado_ila_guarded.ps1` 运行。

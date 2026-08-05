# DL5_UNIT_006：仿真复现说明

本单元只增加/重分配 ILA 观测逻辑：不改变状态机、FIFO 格式、DAC/ADC 业务数据、寄存器映射或 IO 约束，因此不新增行为级仿真用例。

## Testbench / 仿真 top

无。本单元无功能 RTL 变更，不创建 testbench 或仿真 top；业务行为回归由后续修复单元负责。

## GUI 与 batch/manual 复现

- Vivado GUI：无需启动行为仿真；可在 Tcl Console 打开最终 LTX 检查 ILA probe 名称。
- batch/manual：未创建 `run_manual.tcl` 或 `run_batch.tcl`，因为不存在可执行的功能仿真场景。
- 上板 batch：使用 `AI-work/scripts/run_vivado_ila_guarded.ps1` 调用 `../ila/capture_full_line_and_tail.tcl`。

## 通过标准

本单元的 PASS 标准为：实现报告 WNS/WHS 非负、DRC 无 ERROR/CRITICAL WARNING，且最终 LTX 同时含完整行、DAX/相机和采集计数探针；不是 xsim PASS。

已完成的替代验证：

- RTL 审查：`../RTL_REVIEW.md`，确认所有新增信号仅进入 ILA probe；
- 实现验证：`../out/impl/build_diagnostic_bitstream_resource_optimized.log`；
- 时序/资源/DRC：`../out/impl/timing_summary.rpt`、`../out/impl/utilization.rpt`、`../out/impl/drc.rpt`；
- 上板复现入口：`../ila/capture_full_line_and_tail.tcl`，使用项目受控启动器执行。

后续若修复“恢复时间、少台阶、末尾尖峰”中的业务 RTL，再从项目 SOP
`AI-work/guide/VIVADO_SIM_SOP.md` 和最近的 `DL5_UNIT_005` 仿真/ILA脚本建立有 PASS/FAIL 的功能用例。

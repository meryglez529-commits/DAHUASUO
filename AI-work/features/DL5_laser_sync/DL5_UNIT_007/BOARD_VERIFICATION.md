# DL5_UNIT_007：上板验证计划

## 2026-08-05 实测结果：通过

已使用本单元的 qualified `.bit/.ltx`、工程 host-app 和受控 ILA 脚本完成激光模式验证。配置为 16×16、`dac_sample=50`、行首恢复 5 us、X 回扫 1 us、扫描延时 800 ns、采集延时/时间均为 20 ns。

- 物理尾点确认：DAC ILA 在 FIFO[32] 尾点 marker 上触发；`laser_tail_done_toggle_dac` 随该最终回扫字的 DAC 时钟边沿翻转。ILA 的寄存器采样显示为相邻一条记录，是同一时钟边沿的非阻塞更新可见性。
- 恢复下限：ETH ILA 中 `tail_done_sync` 于样本 218 改变，样本 219 进入 State 18；下一次 `dl5_dbg_line_start_accept` 在样本 844，间隔恰为 `(844-219)×8 ns = 5.000 us`。期间到达的两次 laser 输入（样本 343、593）都在 State 18，未被接收。
- 相机同步：`camera_line_sync` 已在激光模式低有效；完整行窗口为 DAC ILA 样本 1474..3023，共 1550 个 20 ns DAC 时钟，即 31.000 us，符合 16 个、2 us 间隔的激光像素行覆盖要求。
- 采集：UI ILA 中 delay 和 high 两段计数均为 0..3，各为 4 个 5 ns 时钟，实测均为 20 ns。

原始证据：`out/ila/eth_recovery_TRIG_20260805_184848.csv`、`out/ila/dac_tail_camera_TRIG_20260805_184848.csv`、`out/ila/acq_timing_TRIG_20260805_184848.csv`；受控启动记录 `out/hw_debug/dl5_recovery_ack_20260805_184845.log`，且 spill manifest 为 `NEW_DROOT_SPILL_COUNT=0`。

产物边界说明：全局 spill 扫描仍列出项目根的 `vivado.jou`、`vivado.log`、`vivado_pid18956.str` 以及 `AXI_DDR.runs/*/vivado.jou`；它们属于已打开的 Vivado GUI/项目托管运行，未被本次受控 ILA 启动器创建或改动，故未移动或删除。

## 已具备的交付物

- 下载文件：`out/bitstream/ETH_TOP_dl5_recovery_ack_qualified.bit`
- 必须配对的探针文件：`out/bitstream/ETH_TOP_dl5_recovery_ack_qualified.ltx`
- 该版本已完成实现后修复并满足时序：WNS `+0.093 ns`、WHS `+0.048 ns`、TNS/THS 均为 `0`。

请只下载上述带 `qualified` 后缀的 `.bit`；同目录不带该后缀的文件来自首次负裕量实现，不用于上板。

## 建议的激光测试配置

沿用已验证的便于观察配置：`16 x 16`、`dac_sample=50`（每个像素 1 us）、X 回扫 `1 us`、行首恢复 `5 us`、`scan_delay_time=100`（800 ns）。激光周期应大于单像素 DAC 保持和采集窗口，并保持输入电平、端接与既有测试一致。

## ILA 执行

在下载并用上位机启动激光模式后，从工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File AI-work/scripts/run_vivado_ila_guarded.ps1 `
  -Tcl AI-work/features/DL5_laser_sync/DL5_UNIT_007/ila/capture_recovery_ack.tcl `
  -OutDir AI-work/features/DL5_laser_sync/DL5_UNIT_007/out/hw_debug `
  -RunName dl5_recovery_ack -TclArgs event
```

脚本一次性抓取三个既有 ILA，不会配置或下载 FPGA：

| 数据 | 触发点 | 核查内容 |
|---|---|---|
| ETH ILA | `dl5_dbg_tail_done_sync=1` | DAC 尾点确认到达 ETH 后，State 18 的恢复计数完成前不能进入 State 14 接受下一次激光。|
| DAC ILA | `para_config_dout_2[32]=1` | FIFO[32] 的单拍尾点 marker 与 `laser_tail_done_toggle_dac`、DAX/DAY 最后一个回扫字同拍；`camera_line_sync` 在激光行首到行尾保持低有效。|
| UI/ADC ILA | `laser_pulse_ui_1=1` | 采集延时与采集时间维持原有配置，不受本修复影响。|

## 判定标准

1. `laser_tail_done_toggle_dac` 的翻转必须与最终回扫 DAC 字更新同一 `dac_dco` 边沿发生。
2. ETH 域的 `dl5_dbg_tail_done_sync` 变化后，到下一次 `dl5_dbg_line_start_accept` 之间应不小于配置的恢复时间；5 us 配置允许 CDC 带来的额外延迟，不允许提前。
3. 普通、超快模式下 FIFO[32] 仍等于 `adc_tri`，不会进入 State 17/18；激光模式下仅最终回扫字临时占用 FIFO[32]，ADC 触发仍来自独立链路。
4. 本次未修改相机行同步的 marker 对齐逻辑；若激光模式相机信号仍异常，应作为独立问题继续处理，不将其误判为本次恢复修复失败。

当前状态：等待上板结果，尚未宣称硬件验证通过。

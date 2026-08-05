# DL5_UNIT_007：上板验证计划

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

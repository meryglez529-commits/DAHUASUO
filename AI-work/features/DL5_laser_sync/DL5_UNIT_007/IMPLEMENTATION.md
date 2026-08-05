# DL5_UNIT_007：实施记录

## Current status

Completed and ready for board validation. The laser-only physical-flyback acknowledgement was implemented, behavioral regression passed, and the final repaired routed design meets timing. Normal and ultrafast paths were not altered.

## 执行顺序

1. 修改 `parameter_dacdata_gen.v`、`dac_output.v`、`dacdata_config.v`，不改 FIFO IP、寄存器映射、XDC 或顶层 IO。
2. 执行 `sim/run_batch.tcl`，得到 `out/sim/result.txt=PASS`。
3. 执行完整实现；首次路由 WNS 为负，不交付。
4. 仅从首次 routed checkpoint 执行一次物理优化和重布线，生成合格 `.bit/.ltx`。
5. 下载合格文件后，使用 `ila/capture_recovery_ack.tcl` 做板级验收。

## 已完成的实现证据

- 仿真：`out/sim/vivado_unit007.log`、`out/sim/xvlog.log`、`out/sim/xelab.log`、`out/sim/xsim.log`、`out/sim/result.txt`。
- 实现：`out/impl/vivado_impl.log`、`out/impl/vivado_post_route_repair.log`、`out/impl/post_route_repair_timing_summary.rpt`。
- 合格交付：`out/bitstream/ETH_TOP_dl5_recovery_ack_qualified.bit` 与同名 `.ltx`。

## 当前状态

进行中：RTL 已完成，独立双时钟回归仿真 PASS；实现/bitstream 尚未启动。

## 计划改动

| 文件 | 改动 |
|---|---|
| `parameter_dacdata_gen.v` | 产生激光末回扫 FIFO[32] 标记；同步 DAC 确认；新增 State 17/18。 |
| `dac_output.v` | 在末回扫 word 实际更新 DAX/DAY 的 DAC 时钟沿翻转确认 toggle；复用既有 ILA 位宽观察。 |
| `dacdata_config.v` | 连接 DAC→ETH 确认 toggle；在既有 ETH ILA 打包观察确认与恢复状态。 |
| `tb_dl5_unit_007.v` | 回归普通、超快和激光物理回扫后恢复时序。 |

## 已完成 RTL

- `parameter_dacdata_gen.v`
  - 激光最后一个 State 13 回扫 word 在 FIFO[32] 写入单拍 marker。
  - 以 3 FF 将 DAC 读侧 completion toggle 同步回 ETH。
  - State 2 仅写两个起始锚点；有回扫时转 State 17 等确认，随后 State 18 按 `dacx_recovery_time * 125` 个 ETH 周期计时，才进入 State 14。
  - 普通/超快分支未修改，FIFO[32] 仍来自 `adc_tri`。
- `dac_output.v`：marker word 在实际更新 DAX/DAY 的 DAC 边沿翻转 completion toggle；已有 DAC ILA 位宽内打包 marker 和 toggle。
- `dacdata_config.v`：连接 completion toggle，并用既有 ETH ILA 的 4-bit probe 观察同步值和已消费值。

## 仿真结果

- 运行：`sim/run_batch.tcl`
- 结果：PASS
- 证据：`out/sim/result.txt`、`out/sim/xsim.log`
- TC1：普通模式 FIFO[32] 保持 `adc_tri`，不进入 State 17/18。
- TC2：超快模式同样保持原路径。
- TC3：配置 1 us 恢复和 4 个回扫 word 时，DAC completion 为 3.890 us，State 14 为 4.932 us；实际间隔 1.042 us。恢复期间注入的 laser 未改变 `laser_toggle`。

## 运行环境

- SOP：`AI-work/guide/VIVADO_SIM_SOP.md`
- 仿真模板：`AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_batch.tcl`
- 本单元输出根：`AI-work/features/DL5_laser_sync/DL5_UNIT_007/out/`

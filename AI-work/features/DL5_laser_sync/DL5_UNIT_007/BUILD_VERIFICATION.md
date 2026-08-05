# DL5_UNIT_007：构建与验证记录

## 仿真

`sim/run_batch.tcl` 已通过。行为级双时钟回归覆盖普通、超快与激光三种模式：

- 普通模式：FIFO[32] 仍等于 `adc_tri`，不进入 State 17/18。
- 超快模式：同样保持原路径。
- 激光模式：尾点 DAC 实际输出确认时间为 `3.890 us`，下一次可接受激光的 State 14 时间为 `4.932 us`；二者相隔 `1.042 us`，不小于配置的 `1.000 us`。等待期间注入的激光不会改变 `laser_toggle`。

证据：`out/sim/result.txt`、`out/sim/xsim.log`、`out/sim/dl5_unit007_tb_result.txt`。

## 实现与 bitstream

首次项目实现的 WNS 为 `-0.031 ns`，因此其输出明确废弃，不用于下载。随后从该 routed checkpoint 仅执行一次 `phys_opt_design -directive Explore` 与 `route_design -directive Explore`：没有修改 RTL、IP、XDC、约束或工程运行配置。

最终结果：

| 项目 | 结果 |
|---|---:|
| WNS | `+0.093 ns` |
| WHS | `+0.048 ns` |
| TNS / THS | `0 / 0` |
| bitgen | 成功，`0 error / 0 critical warning` |

证据：`out/impl/post_route_repair_timing_summary.rpt`、`out/impl/post_route_repair_drc.rpt`、`out/impl/vivado_post_route_repair.log`。

可上板文件仅为：

```text
out/bitstream/ETH_TOP_dl5_recovery_ack_qualified.bit
out/bitstream/ETH_TOP_dl5_recovery_ack_qualified.ltx
```

上板、示波器和 ILA 尚未执行，不能替代硬件验收。

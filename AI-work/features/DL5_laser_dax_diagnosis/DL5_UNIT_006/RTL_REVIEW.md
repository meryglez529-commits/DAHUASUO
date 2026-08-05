# DL5_UNIT_006：RTL / IP 审查

| 文件 | 改动 | 功能风险 | 审查结论 |
|---|---|---|---|
| `parameter_dacdata_gen.v` | 导出恢复计数的只读调试端口。 | 无状态、赋值或数据通路改动。 | 仅观测。 |
| `dacdata_config.v` | 重编码 7 个 ETH 调试 probe，并改接独立 `ila_dl5_eth`。 | ILA 输入扇出可能影响实现时序；不驱动业务逻辑。 | 仅观测。 |
| `dac_output.v` | 接入原来未使用的 `ila_2` 标量 probe。 | 仅观测 DAC 读侧。 | 仅观测。 |
| `ila_1.xci` | 保持深度 1024。 | 采集 ILA 仍可记录一次激光采集窗口。 | 仅观测。 |
| `ila_2.xci` | 深度 2048 -> 4096。 | 增加 DAC ILA 调试 BRAM。 | 需检查实现资源/时序。 |
| `ila_dl5_eth.xci` | 新增独立 4096 深度 ETH ILA。 | 用独立核换回两个 UI ILA 的 BRAM，保留完整行抓取。 | 仅观测。 |

没有修改 XDC、寄存器映射、FIFO 配置、状态机转移、DAC 数据格式或输出引脚。

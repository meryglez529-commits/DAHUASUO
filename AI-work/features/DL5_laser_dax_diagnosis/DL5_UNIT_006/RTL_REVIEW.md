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

## 2026-08-05：相机行同步的已确认 RTL 缺陷（未修）

| 文件 | 证据 | 缺陷 | 影响 | 修复约束 |
|---|---|---|---|---|
| `parameter_dacdata_gen.v` | `laser_line_start` 以 `State16 && dac_sample_cnt==0` 组合生成 FIFO[34]；板级 ILA 在 x=0 显示 `cnt=0/wr_en=0` 后才变为 `cnt=1/wr_en=1` | FIFO 行首标记早于实际第一笔写入一拍，bit34 未随有效像素 word 写入 | DAC 域的 `camera_line_active` 仅由 bit34 置位，故低有效 `camera_line_sync` 全程保持高 | bit34 必须标在第一笔实际 FIFO word，bit33 必须标在最后一笔实际 FIFO word；标记须与寄存器化 `wr_en` 和 DAX/DAY 一起对齐 |
| `dac_output.v` | `camera_line_active` 仅在 `para_config_dout[34]` 时置 1，bit33 仅置 `camera_line_end_pending` | 当前 bit33 在末点仍余 2 个 DAC 时钟时出现；若只补 bit34，行同步将提前释放 | 相机同步不能覆盖完整有效像素区 | 保留现有 DAC 域的“一拍后释放”机制，但把 bit33 移至末个有效 word；下一诊断 bit 同时探测 FIFO[34]、`laser_mode_en_dac`、`camera_line_active` |

该结论来自 `out/ila/eth_full_line_TRIG_20260805_144245.csv` 和 `out/ila/dac_tail_camera_TRIG_20260805_144245.csv`，不是外部接线推测。未修改 RTL、FIFO 格式或相机输出引脚。

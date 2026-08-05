# DL5_UNIT_007：RTL 审查

| 文件 | 审查结论 | 风险与控制 |
|---|---|---|
| `parameter_dacdata_gen.v` | FIFO[32] 仅在 `laser_mode_en=1` 时改为末回扫 marker；State 17/18 只从激光 State 2 可达。 | completion 是异步事件，采用三拍 toggle 同步；等待期间激光由状态机天然忽略。 |
| `dac_output.v` | marker 与 `para_config_rd_en_r` 同拍时翻转 toggle，因此确认对应 DAX/DAY 寄存器更新边沿。 | 不改 FIFO/IP；普通和超快的 marker 条件恒为假。 |
| `dacdata_config.v` | 只增加内部连线并复用现有 ILA probe 宽度。 | 不改顶层 IO、寄存器映射或 XDC。 |

已完成针对回扫确认、恢复下限、激光门控以及普通/超快兼容性的仿真审查；仍需实现时序和板级 ILA 验证。

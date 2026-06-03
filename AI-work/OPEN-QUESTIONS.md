# Open Questions

四个 mode 共享的待解决问题。每条都标注来源 mode、提出时间、当前状态。

| 编号 | 提出时间 | 来源 mode | 问题 | 状态 | 解决依据 |
|---|---|---|---|---|---|
| Q1 | 2026-05-22 | cowork-setup | AD9258 实际采样率？（DL2 推测 ~50 MSPS） | open | |
| Q2 | 2026-05-22 | cowork-setup | DDR3 颗粒型号？（型号 / 速率 / 位宽） | open | |
| Q3 | 2026-05-22 | cowork-setup | SGMII Ethernet PHY 芯片型号？ | open | |
| Q4 | 2026-05-22 | cowork-setup | QSPI Flash 容量与型号？ | open | |
| Q5 | 2026-05-22 | cowork-setup | FRAM 容量与型号？ | open | |
| Q6 | 2026-05-22 | cowork-setup | 偏置 DAC 型号？（offset_cfg / offset_dac_cfg 控制的器件） | open | |
| Q7 | 2026-05-22 | cowork-setup | OV5640 摄像头在本工程是辅助/调试还是主功能？ | open | |
| Q8 | 2026-05-22 | cowork-setup | `eth_clk` 实际频率（从 TEMAC 用户时钟输出，DL1/PROJECT_GUIDE 推测 125 MHz） | open | |
| Q9 | 2026-05-22 | cowork-setup | SGMII_TEMAC / SGMII_PHY 的 license 状态（Step 6 跑 check_env.tcl 时验证） | resolved | `AI-work/sim_out/check_env.log` 14:59 跑 PASS：SGMII_TEMAC (tri_mode_ethernet_mac:9.0) OK；SGMII_PHY (gig_ethernet_pcs_pma:16.2) OK |
| Q10 | 2026-05-22 | cowork-setup | DAC 焦点细节：当前现象、期望、复现条件 | open | 等用户补充 FOCUS.md |
| Q11 | 2026-05-22 | cowork-setup | `AXI_DDR.srcs/parameter_dacdata_gen_old.v` 是手动备份还是无用文件？要不要清理 / 加 .gitignore？ | open | |
| Q12 | 2026-05-22 | DL5-design | sync_pixel_tri2 在新模式具体输出什么？当前定为 `laser_event_busy`（BUSY 期间为高）。如果外设其实需要 acq 起止脉冲，再改 mux | open | 等用户实际接外设确认 |
| Q13 | 2026-05-22 | DL5-design | `blanker_end ≤ laser_period` 和 `acq_end ≤ laser_period` 是否要 FPGA 防呆？目前不做 | resolved | v3 拍板：上位机保证，FPGA 不做 |
| Q14 | 2026-05-22 | DL5-design | dac_output.v 在 State 3 只写 1 个 FIFO word 时是否能保持 DAC 电平？ | resolved | 读 dac_output.v:212-217 确认：`para_config_rd_en=0` 时 DAX/DAY 自保持。新模式用 `laser_pixel_written` one-shot 标志写 1 word 后停 wr_en 即可 |
| Q15 | 2026-05-22 | DL5-v3 | DL5 用 ui_clk 还是 clk200m？ | resolved | v3 拍板：`ui_clk`（dacdata_config 现有端口，零成本） |
| Q16 | 2026-05-22 | DL5-v3 | blanker 输出极性 | resolved | v3 拍板：与现有 sync_pixel_tri1 一致 = 物理引脚低有效，mux 复用现有 ~ 取反路径 |
| Q17 | 2026-05-22 | DL5-v3 | DL5 `acq_data_delay_time` 是否复用 0x0201 `adc_acq_delay`？ | resolved | v3 拍板：功能不同（一个在 ui_clk 域控制 adc_tri 产生延时，一个在 adc_dco 域控制 ADC 内部死区），新建独立寄存器 0x0208 |
| Q18 | 2026-05-22 | DL5-v3 | `command_monitor_new.v` 已有 0x0200 case 重复 bug（sync2_pixel_tri_wigth 不可达），DL5 实现时顺手修不修？ | open | 先不动，避免 DL5 改动面太广；后续单独提 PR |
| Q19 | 2026-05-27 | DL5_UNIT_001 | `laser_sync_in` 的实际 FPGA 引脚号、bank 电压和 XDC IOSTANDARD 怎么定？ | resolved | 2026-06-02 决定复用 `TRIGGER_IN`/D15/LVCMOS33：普通/超快模式保持 TRIGGER_IN，激光模式下同一物理输入作为 laser_sync_in |
| Q20 | 2026-06-03 | DL5-board-debug | host-app 跑普通模式时 DAC 无波形（即便 bitstream/RTL 正常）。为何？ | resolved | host-app `ScanConfig.to_registers()` 漏写 `0x0005/0x0006/0x0007/0x000F`，导致写 `0x0006` 触发的 `dacx_step` 除法器从不重算，DAX 恒 0x8000。已修 `scan.py`+`modes.py` 补全几何寄存器（固定内置默认值），21 单测过，上板验证 DAC 出波形。详见 `host-app/HOST_APP_L0_L9_READINESS.md` 与 `DL5_UNIT_003/BOARD_DEBUG_GUIDE.md ★ 实录` |
| Q21 | 2026-06-03 | DL5-board-debug | 激光模式 blanker 无输出，D15 连接器有 500kHz 信号但 FPGA 内部 `laser_sync_in` 恒 0。RTL/约束/板级哪一层？ | resolved | 顶层 `ila_5` 直抓 `TRIGGER_IN_IBUF`（IBUF 输出）实测 8192 采样全 0，同时内部注入对照脉冲正常 → 铁证锁定 D15 球脚之前板级物理层（约束/bank 供电均已排除）。用户修复硬件后复测 `TRIGGER_IN_IBUF` = 500kHz/20%/2µs，端到端 blanker 输出正常 |

## 处理约定

- 任何 mode 在读取过程中遇到无法立即确认的事实，写一条带 `> ⚠️ 待确认` 的内容时，**必须**同时在这里追加一行。
- 状态从 open → resolved 时，留下解决依据（commit hash / 用户口头确认 / 仿真证据）。
- 长期 open 的问题（超过一周）在每周协作开始时复盘一次，决定继续追还是关掉。

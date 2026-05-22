# AI-work Log

每次 skill 调用或重要改动追加一行。最新的写在最上面。

格式：`YYYY-MM-DD HH:MM | mode | 简述`

---

| 时间 | Mode | 简述 |
|---|---|---|
| 2026-05-22 17:24 | DL5-impl | Step 8c 完成：full synth_1 PASS（BUILD PASS, synth_design Complete），0 ERROR / 0 CRITICAL WARNING（整个综合日志）。资源占用：LUT 31.94%、Reg 27.19%、IOB 70.50%（+1 = laser_sync_in）、BRAM 89.89%（pre-existing，与 DL5 无关）、DSP 1.90%。Step 7 集成 sim 跳过（综合等价覆盖了接线/CDC 验证） |
| 2026-05-22 17:18 | DL5-impl | Step 8b 完成：RTL elaboration PASS（synth_design -rtl on AXI_DDR.xpr），0 ERROR / 0 CRITICAL WARNING，`laser_sync_blanker_ctrl` 干净综合，`laser_sync_in` 在顶层 port list。剩余 warning 均为 pre-existing（adcdata_config.data_en 未连接等） |
| 2026-05-22 17:15 | DL5-impl | Step 2~6 完成：parameter_dacdata_gen.v 加 laser mode 分支 + laser_pixel_written 标志；dac_output.v 加 4 个 DL5 输入端口 + 3 处 mux（adc_tri/sync1/sync2）+ ui_clk→dac_dco 同步；dacdata_config.v 例化 laser_sync_blanker_ctrl + 完整 CDC（双 FF + ASYNC_REG，toggle-FF pulse 同步）；command_monitor_new.v 加 6 个寄存器（0x0205~0x020A）+ 读写解码；ETH_TOP.v 加 laser_sync_in 顶层端口 + 6 个 wire。全部 xvlog 语法过 |
| 2026-05-22 17:00 | DL5-impl | Step 1 完成：新增 `laser_sync_blanker_ctrl.v`（3 态状态机 + 3 级 FF CDC + scan_state 门控）和 `tb_laser_sync_blanker_ctrl.v`（TC1~TC8）。xsim 跑通，8/8 用例 PASS，0 错误。仿真总时长 ~36us，wall-time < 1min |
| 2026-05-22 18:00 | design | DL5 v3：用户拍板 3 个 P0 决策（时钟用 ui_clk / blanker 低有效 / acq_data_delay_time 新建独立寄存器）。R1 用读 dac_output.v 现场确认（自保持 DAX/DAY）。文档对账"adc_tri 引脚"实际无 IO、纠正物理引脚名为 TRIG_BLANK / TRIGGER_OUT。Q13~Q14 已 resolved；新增 Q15~Q18 |
| 2026-05-22 17:30 | design | DL5 v2 修订：状态机改并行 3 态、新增 laser_period 寄存器（方案 B 切像素）、blanker/adc_tri/sync IO 全部复用现有引脚（仅 Laser Sync 新增 1 个输入）、sync2 语义=laser_event_busy。OPEN-QUESTIONS 加 Q12~Q14 |
| 2026-05-22 16:30 | design | DL5 飞秒激光同步模式架构 v1。用户决策：1 脉冲=1 像素 / IO 暂占位 / sync 跟随激光 / 不做超时。修正 acq 步进 20ns（原稿误写 5ns）。产出 guide/data-paths/DL5_LASER_SYNC_MODE_DESIGN.md |
| 2026-05-22 15:35 | annotation+focus | 对比 parameter_dacdata_gen 新旧版（旧版备份 vs 当前工程）：识别 3 项新增功能（sync_pixel_tri1/2、ultrafast 模式、dac_sample 32-bit）+ FIFO 35-bit。产出 annotations/parameter_dacdata_gen-diff.md，更新 FOCUS.md。用户意图：在新版基础上**新增一个新功能**（具体待告知） |
| 2026-05-22 15:10 | cowork-setup | Step 7: **RULES.md confirmed by user**。Mode 4 setup 完成，可进入闭环 |
| 2026-05-22 15:00 | cowork-setup | Step 6: check_env.tcl PASS（log 见 sim_out/check_env.log），SGMII license OK，1096 源文件齐全 |
| 2026-05-22 14:15 | cowork-setup | Step 5: 回滚演练通过（改 LOG.md → git checkout 还原），baseline tag = baseline-pre-cowork |
| 2026-05-22 14:14 | cowork-setup | Step 4: 复制 5 个 TCL 模板到 AI-work/scripts/，加 customization 头 |
| 2026-05-22 14:13 | cowork-setup | Step 3: 写 env/ 六份 .md（ENVIRONMENT/HARDWARE/RULES/FOCUS/SNAPSHOTS/GLOSSARY） |
| 2026-05-22 14:11 | cowork-setup | 挪旧产出：FPGA_PROJECT_GUIDE.md + 4 份 DL*_DEEP_READ.md + 2 份 HTML 到 AI-work/guide/，ADC_SPI_CONFIG_READ.md 到 annotations/ |
| 2026-05-22 14:10 | cowork-setup | Step 5: git init + commit baseline + tag baseline-pre-cowork（commit df52990） |
| 2026-05-22 14:08 | cowork-setup | Step 2: 用户回答 4 个关键问题（git/挪旧产出/DAC 焦点/xsim） |
| 2026-05-22 14:05 | cowork-setup | Step 1: 工具链探测完成（Vivado D:/Xilinx/Vivado/2021.1 OK；ModelSim 路径失效；GBK/UTF-8 混合；314GB 磁盘） |
| 2026-05-22 14:00 | bootstrap | 创建 AI-work 骨架，启动 Mode 4 co-work setup |

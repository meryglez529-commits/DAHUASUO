# AI-work Log

每次 skill 调用或重要改动追加一行。最新的写在最上面。

格式：`YYYY-MM-DD HH:MM | mode | 简述`

---

| 时间 | Mode | 简述 |
|---|---|---|
| 2026-06-03 19:30 | DL5-UNIT003-board-debug-closed | **DL5 上板调试闭环**：blanker 无输出 → 逐层定位出两个独立问题并全部解决。(1) **host-app 漏写扫描几何寄存器**：`ScanConfig.to_registers()` 只写 `0x0001/0x0002/0x0004/0x0009`，从不写 `0x0005/0x0006/0x0007/0x000F`，导致 `0x0006` 不写 → `dacx_step` 除法器(`dacx_step_flag`)从不触发 → DAX 恒 0x8000、普通模式 DAC 也无波形。修 `scan.py`+`modes.py`(补全几何寄存器，固定内置默认值)，21 单测过。(2) **D15/laser_sync_in 硬件输入问题**：ILA 直抓 `TRIGGER_IN_IBUF` 实测恒 0(对照内部注入脉冲 33 个完美上升沿)，铁证锁定板级物理层；用户修复硬件后复测 `TRIGGER_IN_IBUF` = 500kHz/20%/2µs，与信号源吻合。mux 改回真实 `TRIGGER_IN` 端到端验证：示波器 TRIG_BLANK 有输出，ILA 实测 laser_sync_in 20% 占空比、laser_toggle 翻转、状态机 14→15→16→4 循环、blanker 整形器输出正常。延迟指标上板实测与仿真吻合(blanker 脉宽 500ns、laser→DAX ~256ns vs 仿真 274ns、跨行 20ns vs 仿真 48ns、FIFO 水位 80% 在地板)。清理全部调试代码(顶层注入+ila_top_trig+dl5_dac_diag)，重出正式 bitstream |
| 2026-06-03 09:51 | DL5-UNIT003-board-bringup | bitstream 烧录后开始实板 L0-L5 联调：`192.168.1.8` ping/UDP version 通，版本 `0x000300AC`；先 `stop` 得到 `0x0009=0x00001310`，随后写入激光模式并启动，参数读回为 `0x0205=1, 0x0206=10, 0x0207=100, 0x0208=100, 0x0209=30, 0x020A=25`，扫描状态 `0x0009=0x00000011`；等待示波器确认 D15、TRIG_BLANK、TRIGGER_OUT |
| 2026-06-02 17:20 | host-app-L0-L9-readiness | 检查 `AI-work/host-app` 对 DL5_UNIT_003 L0-L9 上板验证的支持度：21 项 unittest 通过，CLI dry-run 确认普通/激光模式写入计划正确；新增 `HOST_APP_L0_L9_READINESS.md`；同步修正 `BOARD_DEBUG_GUIDE.md` 中版本寄存器和 DL5 地址旧表（laser_mode_en 为 0x0205，version 为 0x000A） |
| 2026-06-02 17:11 | DL5-UNIT003-docs | 更新 `BOARD_DEBUG_GUIDE.md`：明确当前状态为 route_design 已通过、下一步直接 write_bitstream；修正原文中把 `run_implementation.tcl` 当作 bit 生成脚本的问题；新增 `run_bitstream.tcl` 用于生成并归档 `ETH_TOP_unit003.bit` |
| 2026-06-02 17:03 | DL5-UNIT003-impl | 新增并运行 `run_implementation.tcl`，`impl_1` 跑到 `route_design Complete!`（12 分钟）；routed timing 通过：WNS=0.091 ns、TNS=0、WHS=0.052 ns、THS=0，0 setup/hold failing endpoint；bus skew 全部正 slack；`laser_sync_in` NSTD/UCIO DRC 未复现，下一步可 write_bitstream |
| 2026-06-02 16:26 | DL5-UNIT003-synth | 复用 `TRIGGER_IN`/D15 后重跑完整 synthesis：`synth_design` 完成，0 ERROR / 0 CRITICAL WARNING；旧 `laser_sync_in` NSTD/UCIO DRC 已消除；synthesis WNS 仍为 -0.622 ns，最差 setup 路径为 `U6/N1/step_count_reg[15]` → `U6/N1/day_level_reg[63]`，记录为 implementation 前的时序风险 |
| 2026-06-02 15:45 | DL5-UNIT003-pin-reuse | 按用户确认复用 `TRIGGER_IN`/D15/LVCMOS33：普通/超快模式保留原 TRIGGER_IN 行触发语义，激光模式下同一物理输入作为 `laser_sync_in`；移除顶层独立 laser_sync_in 物理端口，Q19 resolved |
| 2026-06-01 10:47 | host-app-gui-safety | 落地 UI 第一性原则中的 P0/P1：模式工作台新增参数 dirty 状态、失败态 start 防护、REAL 模式 apply/start 确认、`0x0009` scan 状态读回、GUI 操作等价 CLI 日志、写入计划地址展开开关；连接栏新增网络诊断；验证 21 项 unittest、compileall、CLI mode dry-run、GUI 行为小测试通过 |
| 2026-06-01 10:35 | host-app-ui-principles | 参考 ISA-101、FDA human factors、LabOne、Windows design basics、Qt HMI 资料，从第一性原理重新梳理上位机 UI；新增 `HOST_APP_UI_FIRST_PRINCIPLES.md`，明确 UI 是仪器控制台而非寄存器编辑器，并定义状态、模式、日志、防错、DL2/3 扩展和验收标准 |
| 2026-06-01 10:01 | host-app-gui-v2 | 按用户确认实施 GUI V2：新增模式工作台和顶部连接栏，主流程改为普通扫描/超快扫描/激光同步三种模式；raw register console 移到高级调试；补齐 V2 实现记录，验证 21 项 unittest、compileall、CLI mode dry-run、GUI instantiate 均通过 |
| 2026-06-01 09:48 | host-app-ux-plan | 根据用户试用 GUI 反馈，新建 `HOST_APP_GUI_UX_V2_PLAN.md`：将 V2 GUI 定位为以人为本的三模式工作台（普通/超快/激光），主流程隐藏寄存器地址，寄存器控制台降级为高级调试；补充三种模式的参数、写入流程、防呆规则和 V2-P0~P7 改造计划 |
| 2026-06-01 09:40 | host-app-env | 检查并安装上位机 Python 环境：系统 Python 3.12.10/64bit 可用；因工程路径过长导致本地 `.venv` 安装 PySide6-Essentials 触发 long path，改用短路径 `D:\fpga_host_venv`；已安装 editable `fpga-host 0.1.0`、PySide6_Essentials 6.11.1；CLI、GUI import、UDP 32000 bind、17 项 unittest 均通过；新增 `HOST_APP_ENVIRONMENT.md` 实板测试命令 |
| 2026-06-01 09:10 | host-app-implementation | 实现 `AI-work/host-app` 第一版 P0-P6：Python package 骨架、DL4 protocol/register map/register client、real UDP + mock transport、scan/DL5 device API、CLI、PySide6/PyQt GUI 面板、DL2 data-plane stub/mock、configs 和 unittest；17 项单测通过，CLI mock 验证通过；当前环境缺少 Qt binding，GUI 未启动实测，真实 FPGA UDP 未接板实测 |
| 2026-05-31 14:16 | host-app-architecture | 新建 `AI-work/host-app/HOST_APP_ARCHITECTURE.md`：固化 PySide6/PyQt 上位机的分层架构、目录骨架、core/GUI/CLI/mock 边界、DL4 协议模块、DL2 数据平面预留、测试策略和开发阶段；在选型文档中补充架构文档链接 |
| 2026-05-30 17:21 | host-app-planning | 固化上位机第一版技术栈决策：Python Qt 路线（PySide6 优先、PyQt 备选）、原生 CLI、mock 模式、第一阶段不打包 exe；补充 DL2 快速接入的 control/data 分层和后台 worker/帧模型预留要求 |
| 2026-05-30 17:19 | host-app-planning | 根据用户倾向更新上位机选型文档：记录 Qt 路线，并区分 C++ Qt 与 PySide6/PyQt 两个分支；新增 mock 模式说明、模拟范围和工程价值 |
| 2026-05-30 17:18 | host-app-planning | 根据用户补充的 AI 协作需求，更新上位机选型文档：第一版明确为 GUI + 原生 CLI + 共享核心库，并记录 CLI 命令草案、JSON/dry-run/mock 等要求及 CLI-Anything 后续定位 |
| 2026-05-30 17:02 | host-app-planning | 新建 `AI-work/host-app/HOST_APP_DISCUSSION_AND_TECH_SELECTION.md`，记录上位机第一版范围、DL4 协议约束、技术选型候选方案、推荐路线和待用户决策问题 |
| 2026-05-30 16:49 | DL4-doc-update | 补充 `DL4_REG_CONTROL_DEEP_READ.md` 的上位机开发协议说明：网络端点/端口绑定、payload 编解码、读写确认策略、寄存器模型、普通扫描和 DL5 配置流程；同步更新 0x0205~0x020A 读写表 |
| 2026-05-30 16:45 | DL4-protocol-read | 阅读 DL4 寄存器控制链路和以太网协议栈源码，确认 UDP 32000 双向寄存器协议、payload 格式、读回格式、端口过滤和上位机绑定要求；未修改 RTL |
| 2026-05-30 16:39 | context-read | 阅读 AI-work 工作区，补充当前项目理解；重点核对 FPGA_PROJECT_GUIDE、env、DL1~DL5 文档与 UNIT_002 仿真记录，未修改 RTL |
| 2026-05-27 18:35 | DL5-UNIT002-plan | 补充 `DL5_UNIT_002/WORK.md` 实现方案草案：推荐复用 `0x020A` 为 `scan_delay_time`，由 `laser_sync_in` 触发 scan/blanker/acq 三窗口，`Scan_X_Signal` 仅作内部脉冲，`parameter_dacdata_gen` 由 scan_x 触发写 `dac_sample` 长度 FIFO burst；未修改 RTL |
| 2026-05-27 18:20 | DL5-UNIT002-requirements | 根据 PDF 截图和用户纠偏更新 `DL5_UNIT_002/WORK.md`：确认 dwell time 来自 `dac_sample`，每个 `laser_sync_in` 边沿后经 `scan delay` 产生 `Scan_X_Signal` 控制 DAC 坐标赋值，同时产生 blanker/acq 三窗口；未修改 RTL |
| 2026-05-27 18:03 | DL5-UNIT002-docs | 用户确认 UNIT_001 需求方向偏差；整理 UNIT_001 为历史实现包，并新建 `features/DL5_laser_sync/DL5_UNIT_002/` 作为第二轮需求对齐入口，当前未修改 RTL |
| 2026-05-27 14:40 | DL5-sim-replay | 验证 `features/DL5_laser_sync/DL5_UNIT_001/sim/run_batch.tcl`：脚本临时切 `target_simulator=XSim`，Vivado 2021.1 复跑 TC1-TC8 PASS，重新生成 `out/sim/result.txt`、`xsim.log`、`vivado_run_batch.log`、`waveform.wdb` |
| 2026-05-27 14:22 | DL5-doc-recovery | 按 `skill-improvements/fpga-project-reader-doc-management.md` 第 10 节补救 DL5：新建 `features/DL5_laser_sync/DL5_UNIT_001/`，整理 `WORK.md`、`RTL_REVIEW.md`、`SIM_REPLAY.md`、仿真/综合证据、Vivado replay Tcl，并把旧 `DL5_LASER_SYNC_MODE_DESIGN.md` 改为归档入口 |
| 2026-05-27 09:39 | env-maintenance | 通过真实 `winget.exe` 安装并验证 Python 3.12.10；`python`/`py`/`pip`/`winget` 在模拟新终端 PATH 下均可按命令名找到；回填 `ENVIRONMENT.md` |
| 2026-05-27 09:19 | env-maintenance | 更新 `ENVIRONMENT.md` / `SNAPSHOTS.md` 中的工程根路径为当前 `D:/SGSC_SEM_dahuasuo_325T_V3_172/.../fpga_prj`；当时 PATH 里的 Python/winget 均表现为 WindowsApps 占位入口，后续改用 App Installer 包内真实 `winget.exe` 处理 |
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

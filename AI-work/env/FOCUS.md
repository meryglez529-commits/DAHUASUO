# Focus

> 当前调试/改动的焦点。聚焦项目里**正在动**的部分，不是整体功能列表。
> 焦点变了就改这份文件，不要堆历史。历史挪到 LOG.md。

## 当前调试焦点

**功能描述**：DAC 波形输出（DL1 数据通路）

**涉及模块/通路**：
- `AXI_DDR.srcs/sources_1/new/dacdata_config.v` —— DL1 顶层包装
- `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` —— 14 态状态机，生成 35-bit 参数流（IDE 选中的 `ultrafast_line_rec`:63 与"超快扫描模式"相关）
- `AXI_DDR.srcs/sources_1/new/dac_output.v` —— `dac_dco` 域输出，含异步 FIFO 与 sync 延迟状态机
- `AXI_DDR.srcs/sources_1/new/dacdata_config.v` 下游：`fifo_generator_4`（eth_clk → dac_dco CDC）
- 参考阅读：[AI-work/guide/data-paths/DL1_DAC_SCAN_DEEP_READ.md](../guide/data-paths/DL1_DAC_SCAN_DEEP_READ.md)

**核心架构**：
1. PC 通过以太网写寄存器，配置扫描参数（扫描尺寸、像素步长、ultrafast 行恢复时间等）
2. `eth_clk` 域：`parameter_dacdata_gen` 14 态状态机**预计算整帧波形**，每拍输出 35-bit `{sync2,sync1,adc_tri,DAX[15:0],DAY[15:0]}`
3. 异步 FIFO（`fifo_generator_4`）跨 `eth_clk → dac_dco`
4. `dac_dco` 域：`dac_output` 逐拍读 FIFO，拆包发出 DAX/DAY/adc_tri 与 sync 信号

**关键时钟域**：
- `eth_clk` 125 MHz `⚠️ 待确认`（参数计算 + FIFO 写）
- `dac_dco` 50 MHz（DAC 输出）
- `ui_clk` 200 MHz（sync 延迟状态机）

**当前现象**：在现有版本基础上**新增 DL5 飞秒激光同步采集模式**。

**新功能需求**：来自客户大化所的飞秒激光器联用方案，详见 [AXI_DDR.srcs/大化所新方案设计.md](../../AXI_DDR.srcs/大化所新方案设计.md)。
核心：FPGA 从 master 变 slave，由外部 Laser Sync 脉冲触发"blanker → adc_tri"两段时序事件，每个激光脉冲对应一个像素。

**架构设计 v3**：[AI-work/guide/data-paths/DL5_LASER_SYNC_MODE_DESIGN.md](../guide/data-paths/DL5_LASER_SYNC_MODE_DESIGN.md)
- 新增 `laser_sync_blanker_ctrl.v` 独立模块（**ui_clk** 域，200MHz，来自 MIG），3 态并行状态机
- 6 个新寄存器（地址 0x0205~0x020A）：laser_mode_en / blanker_delay_time / blanker_time / acq_data_delay_time（与 0x0201 adc_acq_delay 不同）/ acq_time / laser_period
- IO 复用：blanker → sync_pixel_tri1 → 物理引脚 `TRIG_BLANK`(B16, 低有效)；acq 触发→内部 adc_tri wire（**无 IO**）→ DL2 adcdata_config；laser_event_busy → sync_pixel_tri2 → 物理引脚 `TRIGGER_OUT`(G16, 高有效)；仅 Laser Sync 是新增 1 个输入
- 切像素策略（方案 B）：t_cnt = laser_period 时切，每像素时长精确等于激光周期
- State 3 新模式：one-shot 写 1 个 FIFO word（`laser_pixel_written` 标志），然后停 wr_en 等 pixel_done_pulse（R1 已确认 dac_output 自保持 DAX/DAY）
- blanker 极性 = 低有效（与现有 sync_pixel_tri1 一致，复用 dac_output 末级 ~ 取反路径）
- scan_state 门控：`laser_sync_blanker_ctrl` 内部用 `mode_en & scan_state` 激活，scan_state=0 强制 IDLE
- 用户已批准 v3 三决策（2026-05-22），等进入 plan mode 落 RTL
- 旧模式（laser_mode_en=0）完全不变

**版本上下文**（2026-05-22 对比完成）：
- 新版（当前工程在用）相对旧版（`AXI_DDR.srcs/parameter_dacdata_gen_old.v`）已经新增了 3 项功能：
  1. **双路同步脉冲 sync_pixel_tri1/2**：像素采样窗口前 N 拍的同步标记，宽度由 `sync1/2_pixel_tri_wigth` 独立配置
  2. **ultrafast 扫描模式**：`ultrafast_mode=1` 时改用 `ultrafast_line_rec*50` 作为线首 Tb 长度
  3. **dac_sample 位宽扩展**：24-bit → 32-bit，允许超长像素停留
- FIFO word 已经从 33-bit 扩到 35-bit（`[34]=sync2, [33]=sync1, [32]=adc_tri, [31:16]=DAX, [15:0]=DAY`）
- 预留端口 `line_count/line_count_en` 占位，由 `adcdata_acq` 驱动
- 详细对比见 [annotations/parameter_dacdata_gen-diff.md](../annotations/parameter_dacdata_gen-diff.md)

**新增功能前必查的联动清单**（来自 diff 文档第 6 节）：
- [ ] `sources_1/ip/fifo_generator_4/fifo_generator_4.xci` 是否已是 35-bit
- [ ] `sources_1/new/dac_output.v` 是否已拆 `[34]/[33]` 给 sync 输出
- [ ] `constrs_1/new/fpga_pin.xdc` 是否有 sync 输出引脚约束
- [ ] `sources_1/new/dacdata_config.v` 和 `ETH_TOP.v` 顶层例化是否传齐 sync*_pixel_tri_wigth、ultrafast_mode、ultrafast_line_rec
- [ ] `command_monitor_new.v` 的寄存器映射是否覆盖这 4 个新参数

**用户已经尝试过** `> ⚠️ 待用户补充`：
- 

**已知未修 bug**（避免 AI 触发）`> ⚠️ 待用户补充`：
- 

**期望产出**：
- [ ] 仿真层验证通过（`fram_test.v` 或 DL1 专用 testbench，待补）
- [ ] 综合时序收敛（WNS ≥ 0）
- [ ] 上板验证（用户执行）

**截止时间**（可选）：未指定

---

## 工作约束（与 RULES.md 配合）

- 改 RTL 前先看相关 `*_cfg.v`、`adcdata_acq.v` 之类的 CDC 邻居，确保改动不破坏跨域握手。
- 用户在 IDE 选中 `ultrafast_line_rec` 端口，提示 ultrafast 扫描模式是当前热点之一。
- 仿真先用 xsim，testbench 走 `AXI_DDR.srcs/sim_1/` 或 `AI-work/sim/`。

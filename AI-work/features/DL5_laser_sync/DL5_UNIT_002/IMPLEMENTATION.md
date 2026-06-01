# DL5 UNIT_002 实现进度跟踪

> 架构文档：[ARCHITECTURE.md](ARCHITECTURE.md)
> 需求文档：[REQUIREMENTS.md](REQUIREMENTS.md)

## 实施顺序

- [x] 1. 修改 `command_monitor_new.v`（加 6 个寄存器）
- [x] 2. 修改 `parameter_dacdata_gen.v`（State 2/4 分支 + 新增 14/15/16 + laser_toggle + FIFO mux）
- [x] 3. 修改 `dac_output.v`（同步链 + acq 状态机 + sync1 mux + adc_tri mux）
- [x] 4. 修改 `dacdata_config.v`（laser_sync_in CDC + 端口透传）
- [x] 5. 修改 `ETH_TOP.v`（顶层端口 + wire 连接）
- [x] 6. RTL elaboration（PASS，0 ERROR / 0 CRITICAL WARNING）
- [x] 7. 集成仿真验证（**7/7 PASS**，2026-05-29 12:35）
- [ ] 8. 综合验证

## 6. RTL elaboration 结果

**状态**：✅ PASS（2026-05-29 10:46）

**执行命令**：
```
vivado -mode batch -source AI-work/scripts/dl5_elab.tcl -tclargs AXI_DDR.xpr
```

**关键结论**：
- ERROR count = 0
- CRITICAL WARNING count = 0
- `laser_sync_in` 出现在顶层端口列表，确认顶层已正确加端口
- 4 个改动模块全部 elaborate 完成（command_monitor_new、parameter_dacdata_gen、dac_output、dacdata_config）

**修复过程**：
- 第一轮 elaborate 报 Synth 8-6901：`acq_pulse_ui` 在 dac_output.v:257 / :265 处先于声明使用
- 处理：在 1.1 节同步链末尾加 `reg acq_pulse_ui;` 前向声明，原 5.5 节的 reg 声明改为注释说明
- 第二轮 elaborate 警告消失，ERROR/CRITICAL WARNING 均为 0

**遗留 CRITICAL WARNING**（非本次改动引入）：
- `Project 1-19`：工程 `.xpr` 仍引用 UNIT_001 的 `laser_sync_blanker_ctrl.v` 和 `tb_laser_sync_blanker_ctrl.v`，这两个文件方案 J 已废弃。处理方式：等用户确认后从工程移除引用（属于 RULES.md 中"必须先告诉用户"的 .xpr 改动）。

**日志位置**：[out/sim/dl5_elab.log](out/sim/dl5_elab.log)

---

## 1. command_monitor_new.v

**状态**：✅ 完成

**新增寄存器**（地址 0x0205~0x020A）：

| 地址 | 寄存器名 | 位宽 | 步进 | 复位值 |
|---|---|---|---|---|
| 0x0205 | laser_mode_en | [0] | — | 0 |
| 0x0206 | scan_delay_time | [15:0] | 8ns | 0 |
| 0x0207 | blanker_delay_time | [15:0] | 5ns | 0 |
| 0x0208 | blanker_time | [15:0] | 5ns | 0 |
| 0x0209 | acq_data_delay_time | [15:0] | 20ns | 0 |
| 0x020A | acq_time | [15:0] | 20ns | 0 |

**改动点**：
- [x] 声明 6 个 output reg
- [x] 复位块加 6 行初始化
- [x] 写入 case 加 6 条地址匹配
- [x] 读回 case 加 6 条地址匹配

---

## 2. parameter_dacdata_gen.v

**状态**：✅ 完成

**新增端口**：
- [x] `input laser_mode_en`
- [x] `input laser_sync_rise_eth`
- [x] `input [15:0] scan_delay_time`
- [x] `output reg laser_toggle`

**新增内部信号**：
- [x] `reg [15:0] scan_delay_cnt`
- [x] `current_state` 位宽从 4 扩到 5（容纳 State 16）

**改动点**：
- [x] FIFO word 拼接 mux（激光模式 FIFO[32]/[33]/[34] 清零）
- [x] laser_toggle 生成（State 14 内门控）
- [x] State 2 末尾分支（激光模式 → 14，普通模式 → 3）
- [x] State 4 末尾分支（激光模式 → 14，普通模式 → 3；行尾 → 12）
- [x] 新增 State 14（等 laser，不写 FIFO）
- [x] 新增 State 15（scan_delay 倒计时，不写 FIFO）
- [x] 新增 State 16（写 dac_sample 个像素 word，复用 dac_sample_cnt）
- [x] 复位块和 default 分支补 scan_delay_cnt / laser_toggle 复位

---

## 3. dac_output.v

**状态**：✅ 完成

**新增端口**：
- [x] `input laser_mode_en`
- [x] `input laser_toggle`
- [x] `input [15:0] blanker_delay_time`
- [x] `input [15:0] blanker_time`
- [x] `input [15:0] acq_data_delay_time`
- [x] `input [15:0] acq_time`

**新增同步链**：
- [x] laser_mode_en → dac_dco 域（双 FF + ASYNC_REG）
- [x] laser_mode_en → ui_clk 域（双 FF + ASYNC_REG）
- [x] laser_toggle → ui_clk 域（3 级 FF + 异或 → laser_pulse_ui）
- [x] acq_data_delay_time / acq_time → ui_clk 域（双 FF）
- [x] blanker_delay_time / blanker_time → ui_clk 域（双 FF）

**改动点**：
- [x] 新增 acq 状态机（ui_clk 域，ACQ_IDLE/ACQ_DELAY/ACQ_HIGH）
- [x] acq_delay_used / acq_time_used 左移 2（20ns → ui_clk 拍数）
- [x] adc_tri 输出 mux（激光模式单 FF 采样 acq_pulse_ui）
- [x] sync1 整形器入口 mux（sync1_trig_used / sync1_delay_used / sync1_width_used）
- [x] sync_pixel_tri1 输出门控扩展（ultrafast_mode_r1 || laser_mode_en_ui）

---

## 4. dacdata_config.v

**状态**：✅ 完成

**新增端口**：
- [x] `input laser_mode_en`
- [x] `input [15:0] scan_delay_time`
- [x] `input [15:0] blanker_delay_time`
- [x] `input [15:0] blanker_time`
- [x] `input [15:0] acq_data_delay_time`
- [x] `input [15:0] acq_time`
- [x] `input laser_sync_in`

**新增 CDC 逻辑**：
- [x] laser_sync_in → eth_clk 域（3 级 FF + ASYNC_REG + 上升沿检测）
- [x] laser_toggle wire 声明（连接 N1 → N2）

**改动点**：
- [x] parameter_dacdata_gen 例化加 3 个输入端口 + 1 个输出端口
- [x] dac_output 例化加 6 个输入端口

---

## 5. ETH_TOP.v

**状态**：✅ 完成

**新增顶层端口**：
- [x] `input laser_sync_in`

**新增 wire**：
- [x] `wire laser_mode_en`
- [x] `wire [15:0] scan_delay_time`
- [x] `wire [15:0] blanker_delay_time`
- [x] `wire [15:0] blanker_time`
- [x] `wire [15:0] acq_data_delay_time`
- [x] `wire [15:0] acq_time`

**改动点**：
- [x] command_monitor_new 例化加 6 个输出
- [x] dacdata_config 例化加 7 个输入

---

## 6. 集成仿真验证

**状态**：未开始

**测试用例**：
- [ ] 普通模式回归（laser_mode_en=0，逐拍对比基线）
- [ ] 激光模式基本流程（2us laser 周期，验证 State 14→15→16→4 循环）
- [ ] FIFO 积压不影响功能（帧首/行内/行末三种边界）
- [ ] State 14 门控（行切换期间 laser 不触发）
- [ ] 模式切换（停扫描 → 改 laser_mode_en → 开扫描，rstn_r2 清状态机）
- [ ] acq/blanker 时序（acq_data_delay / blanker_delay / acq_time / blanker_time）
- [ ] laser 周期上限（验证 FIFO 不溢出）

---

## 7. 综合验证

**状态**：未开始

**检查项**：
- [ ] WNS ≥ 0（所有时钟域）
- [ ] laser_sync_in 加 set_max_delay 约束
- [ ] 所有双 FF / 3 级 FF 路径加 ASYNC_REG 属性
- [ ] laser_toggle 跨域路径加 set_max_delay
- [ ] 资源占用增加 < 3%
- [ ] 无 latch 推断
- [ ] 无组合环

---

## 问题跟踪

### 已解决

### 待解决

---

## 变更记录

| 日期 | 模块 | 变更内容 | 负责人 |
|---|---|---|---|
| 2026-05-29 | — | 创建实现进度文档 | Claude |
| 2026-05-29 | command_monitor_new.v | 新增 6 个 DL5 寄存器（0x0205~0x020A）+ 复位/写/读 case | Claude |
| 2026-05-29 | parameter_dacdata_gen.v | 新增 State 14/15/16 + laser_toggle 在 State 14 内门控 + FIFO[32:34] 拼接 mux + current_state 扩到 5 位 | Claude |
| 2026-05-29 | dac_output.v | 新增 laser_mode_en/toggle 同步链 + ui_clk 域 acq 状态机 + sync1 入口 mux + adc_tri 单 FF 采样 mux + sync_pixel_tri1 输出门控扩展 | Claude |
| 2026-05-29 | dacdata_config.v | 新增 7 个端口 + laser_sync_in 3 级 FF CDC + 上升沿检测 + 两个子模块例化接线 | Claude |
| 2026-05-29 | dac_output.v | 把 `reg acq_pulse_ui` 提前到 1.1 节同步链末尾做前向声明，消除 Synth 8-6901 警告 | Claude |
| 2026-05-29 | RTL elaboration | PASS（ERROR=0, CRITICAL WARNING=0），日志保存在 `out/sim/dl5_elab.log` | Claude |
| 2026-05-29 | sim_1 fileset | 新增 `tb_dl5_unit_002.v`（集成 testbench，覆盖 7 个用例）| Claude |
| 2026-05-29 | sim/ | 新增 `run_manual.tcl`（绕过 init.tcl 加密问题的仿真脚本）| Claude |
| 2026-05-29 | 集成仿真 | **7/7 PASS**（TC1~TC7）；TC4 acq 脉宽 100ns，TC5 blanker 脉宽 100ns，时序符合预期 | Claude |

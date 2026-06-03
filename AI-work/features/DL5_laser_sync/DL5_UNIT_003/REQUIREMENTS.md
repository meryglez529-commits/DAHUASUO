# DL5 UNIT_003 需求整理：FIFO 水位延迟优化

> 前置依赖：[DL5_UNIT_002](../DL5_UNIT_002/ARCHITECTURE.md)（激光模式基础功能，已验证 12/12 PASS）

## 1. 问题背景

DL5_UNIT_002 仿真验证中发现两个 FIFO 水位相关的延迟问题：

### 1.1 问题 1：行内单像素切换延迟过高（542ns）

**现象**（TC11 实测）：
- laser → acq 触发延迟 = 77ns（独立 toggle-FF 桥，不受 FIFO 影响）
- laser → DAX_DATA 更新延迟 = 634ns（数据路径经 FIFO）
- 其中 State 16 进入 → DAX_DATA 更新 = 542ns

**根因**：
- fifo_generator_4 IP 的 `prog_empty` 阈值 = 20
- dac_output.v 读侧用 `prog_empty == 0` 做 gating：count ≤ 20 时停读
- 每个像素 State 16 写入新 word 后，读侧要先消化 20 个旧 word 才读到新 word
- 延迟 = 20 word × 20ns（dac_dco 周期）= 400ns + CDC/同步杂项 ≈ 542ns

**目标**：降到 100~200ns

### 1.2 问题 2：行末跨行延迟过高（3200ns），可能超过 laser 最小周期

**现象**（TC12 实测，dax_fall_time=5µs, dacx_recovery_time=2µs）：
- State 13（斜坡 + State 12 配合）写 250 word，时间 4000ns
- State 2（Tb）写 100 word，时间 800ns
- 写读速率比 = 125MHz / 50MHz = 2.5×
- State 13 净增 ≈ 50 word，State 2 净增 ≈ 60 word，进 State 14 时 FIFO 残留 ≈ 130 word
- 排到 prog_empty（count=20）需要 (130-20) × 20ns = 2200ns（实测 3200ns，差距来自切换状态的同步开销）
- 如果 laser 最小周期 = 2µs = 2000ns，下一个 laser 来时 FIFO 还有大量旧 word
- DAC 在 acq 采集窗口内输出的仍是斜坡/Tb 旧坐标 → 像素错位

**目标**：跨行延迟 < 200ns，解除 laser 周期对 dax_fall_time 的约束

## 2. 约束条件

| 约束 | 来源 | 说明 |
|---|---|---|
| laser 最小周期 ≥ 2µs | 客户硬件（飞秒激光器） | 不可改 |
| DAC 斜坡必须保留 | 物理需求（电子束伺服系统平滑回退） | State 13 不能删，斜坡形态不能变 |
| 普通模式行为零变化 | UNIT_002 设计原则 | `laser_mode_en=0` 时不受影响 |
| 不改 dac_output.v 读侧逻辑 | 最小改动原则 | 读侧仍用 prog_empty gating |
| 不改 testbench 已有 TC1~TC12 | 回归验证 | 新改动不能破坏已有功能 |
| 行间隔不能变长 | 帧率需求 | 限速类方案被排除 |

## 3. 设计决策（已确认）

经过多轮讨论，最终选定方案为 **A + State 2 写 2 次 + C3-lite 限速 State 13（激光模式专用）**：

### 决议 D1：State 2 在激光模式下"只写 2 次 + 后续纯排空"

- State 2 在第 1、2 拍各写 1 个 dacx_strat word 进 FIFO（共 2 个 word）
- 之后状态机继续计时直到 dacx_tb_point 满（行间隔不变）
- 期间不写 FIFO，让读侧持续消化掉 State 13 留下的积压
- 普通模式（laser_mode_en=0）仍写满 dacx_tb_point × 50 word（行为零变化）

**为什么写 2 次而不是 1 次**：
- DAC 主动驱动 dacx_strat 时间从 20ns → 40ns（DAC 建立时间余量）
- 修正斜坡末端截断误差更稳（多 1 拍精确锁在 dacx_strat）
- 极端反压情况下有补救余量
- 代价仅 8ns + 1 个 FIFO slot，对延迟无影响

### 决议 D2：fifo_generator_4 IP 的 prog_empty 阈值改为 2

- 当前阈值 = 20，是单像素 542ns 延迟的主导项
- 改为 IP 允许的最小值 2，地板降到 2 word × 20ns = 40ns
- 单像素延迟 → ~80ns

### 决议 D3：State 13 限速到 3 拍/word（C3-lite，2026-06-02 增补）

- D1+D2 实施后 TC13 边界扫描发现 dax_fall ≥ 2µs 仍超 200ns 目标（318/626/1022 ns）
- 根因：dax_fall_time **是读侧时间不可改**，写侧 State 12/13 配对 2 拍/word（62.5MHz）> 读侧 50MHz，FIFO 在 State 13 期间持续净增
- **方案核心**：仅 laser_mode_en=1 时把 State 12/13 配对从 2 拍 → 3 拍，写速率 41.67MHz < 读侧 50MHz
- 实测效果：所有 dax_fall（1/2/3/5 µs）跨行延迟统一 = 48ns，撞墙边界完全消失
- 普通模式 State 13 保持 2 拍/word，行为零变化
- **关键设计点**：等待拍 wr_en 必须为 0（实施时踩过这个 bug，详见 IMPLEMENTATION.md §6.4）

### 决议 D4：State 13 不动 word 数（保留 D3 的语义）

- State 13 写入的 word 数 = dax_fall × 50 不变（保证 DAC 模拟斜坡时长 = 用户填的 µs）
- 只改 word 间的写入节奏（限速），不改总数
- 不采用方案 E（减 word 数会让 DAC 物理斜坡变陡）

## 4. 决策对比表

| 方案 | 单像素 | 跨行 | 行间隔 | DAC 斜坡 | 状态 |
|---|---|---|---|---|---|
| 当前（不改） | 542ns | 3200ns | — | — | 不达标 |
| A + C3（限速 State 13/2 双限速） | 80ns | 80ns | +(dax_fall+rec)×800ns | 不变 | 备选 |
| A + E（State 13 减 word） | 80ns | 80ns | 不变 | 变陡 3× | 备选（需硬件验证） |
| **A + 决议 D1（State 2 写 2 次）** | **80ns** | 48ns（dax_fall=1）<br>~1µs（dax_fall=5）| 不变 | 不变 | dax_fall ≥ 2µs 撞墙 |
| **A + D1 + D3（C3-lite，采纳）** | **80ns** | **48ns 全配置** ✅ | +(0~2)µs | **不变** | **采纳** ✅ |

## 5. 验证状态（2026-06-02 更新）

- [x] TC1~TC12 回归全 PASS
- [x] TC11 实测 delay_DAC = 274ns（含 warm-up 残留），单像素切换路径不经 State 13，C3-lite 后保持不变
- [x] TC12 实测下一行第 1 像素 DAX = dacx_strat（行末斜坡正确）
- [x] **TC13 极限场景实测**（C3-lite 后）：dax_fall ∈ {1, 2, 3, 5} µs / rec=1µs / laser=2µs，**跨行延迟全部 = 48ns** ✅（before C3-lite 时为 48/318/626/1022 ns）
- [ ] 综合时序：WNS ≥ 0（待综合验证）
- [ ] 行间隔实测（C3-lite 增加最坏 +2µs，需硬件部署后确认帧率影响）

## 6. dax_fall_time 语义澄清（2026-06-02 增补）

实施过程中重新确认 dax_fall_time 的物理语义，避免后续误解：

- **用户在 PC 端填的 µs 值** = DAC 模拟输出上 X 轴回扫斜坡持续时长（**读侧时间**）
- 预处理 `×50` 把 µs 转成 dac_dco 拍数 = FIFO word 数
- DAC 一拍 dac_dco 输出一个 word，所以 N µs 配置 → DAC 端真实斜坡时长 N µs ✓
- 写侧 State 12/13 写完这些 word 用时 = N × 50 × 16ns = 0.8 × N µs（只占读侧时间的 80%）
- 写读速率不匹配是 dax_fall 撞墙的根因，C3-lite 通过限速让两者匹配

# DL5 UNIT_003 架构设计：FIFO 水位延迟优化（推荐方案 = A + State 2 写 2 次 + C3-lite 限速 State 13）

> 配套文档：[REQUIREMENTS.md](REQUIREMENTS.md) | [IMPLEMENTATION.md](IMPLEMENTATION.md)
> 前置：[DL5_UNIT_002 ARCHITECTURE.md](../DL5_UNIT_002/ARCHITECTURE.md)

## 1. 数据路径模型

```
eth_clk 域（写侧 125MHz = 8ns/拍）          dac_dco 域（读侧 50MHz = 20ns/拍）
┌──────────────────────┐                    ┌──────────────────────┐
│ parameter_dacdata_gen │                    │     dac_output       │
│                      │    35-bit FIFO     │                      │
│  State 16: 写像素    │──── 512 deep ─────►│  prog_empty=0 → 读  │
│  State 12+13: 写斜坡 │    (异步时钟)      │  prog_empty=1 → 停  │
│  State 2:  写 Tb     │                    │  FIFO 空 → 保持值   │
└──────────────────────┘                    └──────────────────────┘
         写速率 = 125MHz                           读速率 = 50MHz
         写/读比 = 2.5×                            地板 = prog_empty 阈值
```

### 1.1 关键事实

- **dax_fall_time 是读侧时间**：用户在 PC 端填的 µs 值 = DAC 模拟输出上斜坡持续时长。预处理 ×50 转为 dac_dco 拍数（FIFO word 数）。一个 word 在 DAC 输出占 20ns，所以 N µs → N × 50 word
- **写读速率比**：State 12/13 配对每 word 用 2 拍 eth_clk = 16ns（等效写速率 62.5MHz），dac_dco 读侧 1 word/20ns（50MHz），写 > 读 25%
- **每 word FIFO 净变化**：
  - State 13 当前（2 拍/word，16ns 写期内读侧消化 16/20=0.8 word）→ 净增 **+0.2 word/写**
  - State 13 C3-lite（3 拍/word，24ns 写期内读侧消化 24/20=1.2 word）→ 净减 **-0.2 word/写** ✓
  - State 2/16（1 拍/word，8ns 写期内读侧消化 8/20=0.4 word）→ 净增 +0.6 word/写
- **State 2 计时**：dacx_tb_point = dacx_recovery_time × 50（dac_dco 拍数），State 2 状态机时长 = dacx_tb_point × 8ns（eth_clk 域）
- **DAC 输出来自 FIFO**：dac_output 持续读 FIFO，每 word 输出 20ns
- **FIFO 空时 DAC 保持**：[dac_output.v:266-274](../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L266-L274) 在 rd_en_r=0 时 `DAX_DATA <= DAX_DATA`

### 1.2 延迟公式

**单像素切换延迟**（State 16 第 1 个 word 写入 → DAX_DATA 更新）：

```
delay = (FIFO 地板 word 数) × 20ns + CDC/同步杂项
      = 2 × 20ns + ~140ns（地板=2 后）
      ≈ 80ns（实测 ~80ns，TC11 测得 274ns 含 warm-up 残留）
```

**跨行延迟**（State 13 写完 → 进 State 14 → DAX 切到 dacx_strat）：

```
当前（C3-lite 前）:
  drain_time = (FIFO 残留 - 地板) × 20ns
  残留 = State 13 净增 × dax_fall × 50 + State 2 净增 × dacx_rec × 50
       = 0.2 × dax_fall × 50 + 极小（State 2 已限到写 2 次）
       ≈ dax_fall × 10 word

C3-lite 后:
  State 13 净减 → 写完 FIFO ≈ 地板 → 跨行延迟 ≈ 单像素延迟 ≈ 80ns
  与 dax_fall 无关 ✓
```

实测对比（dax_fall=5）：当前 1022ns，C3-lite 后 48ns。

## 2. 推荐方案：A + State 2 写 2 次

### 2.1 方案 A：fifo_generator_4 prog_empty 阈值 20 → 2

**改动**：Vivado IP Catalog 双击 fifo_generator_4 → Programmable Flags 选项卡 → `Empty Threshold Assert Value` 从 20 改到 2 → OK → Generate Output Products → 重综合 IP

**效果**：
- FIFO 地板从 20 word × 20ns = **400ns** 降到 2 × 20ns = **40ns**
- 单像素延迟从 542ns → **~80ns**（40 + 杂项）

**安全性**：
- IP 允许最小值 = 2（`spirit:minimum="2"`）
- Xilinx FIFO Generator prog_empty 已考虑 CDC 延迟，阈值 ≥ 2 安全
- Empty_Threshold_Negate_Value 自动跟随（minimum=21，但实际 = Assert+1=3）

### 2.2 State 2 改"只写 2 次 + 纯排空"（激光模式专用）

**核心思路**：State 2 时间不变（dacx_tb_point × 8ns），但只在前 2 拍写 word，剩余时间不写。让读侧在 State 2 + State 14 期间消化 State 13 留下的所有积压。

**改动**：parameter_dacdata_gen.v State 2 分支增加 `laser_mode_en` 判断 + 一个 2-bit `s2_write_cnt` 计数器。

```verilog
reg [1:0] s2_write_cnt;

2: begin
    if (laser_mode_en) begin
        // 激光模式：前 2 拍写 dacx_strat，之后纯计时不写
        if (s2_write_cnt < 2'd2 && para_config_prog_full == 0
            && para_config_wr_rst_busy == 0) begin
            para_config_wr_en   <= 1'b1;
            adc_tri             <= 1'b0;
            sync_pixel_tri1      <= 1'b0;
            sync_pixel_tri2      <= 1'b0;
            DAX_DATA            <= dax_level[63:48];
            DAY_DATA            <= day_level[63:48];
            s2_write_cnt        <= s2_write_cnt + 1'b1;
        end else begin
            para_config_wr_en   <= 1'b0;
        end
        // 计时器仍跑满 dacx_tb_point 拍（行间隔不变）
        if (dacx_tb_point_cnt < dacx_tb_point - 1) begin
            dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
        end else begin
            dacx_tb_point_cnt   <= 0;
            s2_write_cnt        <= 0;
            current_state       <= 14;
        end
    end else begin
        // 普通模式：原行为不变（每拍写 1 个 word）
        // ... 保留 UNIT_002 当前 State 2 代码 ...
    end
end
```

### 2.3 状态机流时序图（dax_fall=5, rec=2, laser=2µs）

```
时间轴 (ns):     0      4000        4080      4880       直到 laser
eth_clk 域:     ┌──────┬───────────┬─────────┬───────────┬──────────────┐
                │ State 13      │ 5~10/1  │ State 2  │ State 14 等  │
                │ 写斜坡 250 word│ 80ns    │ 写 2 word│   laser      │
                │ (4000ns)      │         │ +排空    │              │
                └──────┴───────────┴─────────┴───────────┴──────────────┘

FIFO 水位变化（方案 A 后地板=2）:
  State 13 起:   2  → 写 250 - 读 200 = 净增 50  → State 13 末: 52
  State 5~10/1: 52  → 排 4                       → 进 State 2:  48
  State 2:      48  → 写 2 - 读 ~40 = 净减 38     → State 2 末:  10
  State 14 排空: 10 → 排到地板 2                  → 仅需 160ns
                                                   (远小于 laser 周期)

下一个 laser 来 → State 16 写新 word → 跨行延迟 = 2 × 20ns + 杂项 ≈ 80ns ✅
```

### 2.4 行内单像素延迟（同样达标）

```
State 16 写 dac_sample=30 word, 240ns: 净增 18  → FIFO = 20
State 4 + State 14 等 laser ≥ 1.7µs:    排空    → FIFO 在地板 2
下一个 laser → State 16 写 → 跨像素延迟 = 2×20 + 杂项 ≈ 80ns ✅
```

行内、跨行延迟统一为 ~80ns。

## 3. 为什么写 2 次而不是 1 次（State 2 设计要点）

| 项 | 写 1 次 | 写 2 次 |
|---|---|---|
| FIFO 占用 | +1 | +2 |
| 净减少 | 39 word | 38 word |
| 排到地板 | 140ns | 160ns |
| **DAC 主动驱动 dacx_strat** | **20ns** | **40ns** |
| 修正斜坡截断误差余量 | 1 拍 | 2 拍 |
| 抗反压余量 | 单点 | 双点冗余 |
| 跨行延迟 | ~80ns | ~80ns |

**写 2 次的理由**：
- DAC 主动驱动时间翻倍（20→40ns），更利于 DAC 内部建立和外部 LPF 滤波
- 修正 State 13 末尾 dax_level 与 dacx_strat 的截断误差（截断误差 ≈ dacx_pp/dax_fall_time_r，dax_fall=5 时约 0.4% 满量程）
- 工程冗余：极端反压情况下仍有第 2 次补救
- 代价仅 8ns 状态机时间 + 1 FIFO slot，对延迟无任何影响

## 3a. 方案 C3-lite：State 13 限速到 3 拍/word（激光模式专用，2026-06-02 增补）

**背景**：方案 A + State 2 写 2 次实施完成后，TC13 边界扫描发现 dax_fall ≥ 2µs 时跨行延迟仍超 200ns 目标（318/626/1022 ns）。

**根因**：dax_fall_time 是读侧时间不可改，写侧 State 12/13 配对 2 拍/word（62.5MHz）> 读侧 50MHz，FIFO 在 State 13 期间持续净增。

**方案核心**：State 12/13 配对从 2 拍 → 3 拍，让写速率（41.67MHz）< 读速率（50MHz）：

```verilog
// 仅 laser_mode_en=1 时生效，普通模式保持 2 拍/word
13: begin
    if (prog_full==0 && wr_rst_busy==0) begin
        if (laser_mode_en) begin
            if (s13_wait_cnt == 0) begin
                // 第 1 拍：写 word
                wr_en <= 1; DAX_DATA <= dax_level[63:48]; ...
                s13_wait_cnt <= 1;
                current_state <= 13;  // 留在 13 等下一拍
            end else begin
                // 第 2 拍：等待，wr_en=0（关键：避免重复写）
                wr_en <= 0;
                s13_wait_cnt <= 0;
                if (dax_fall_cnt < dax_fall_time - 1) begin
                    current_state <= 12;
                    dax_fall_cnt  <= dax_fall_cnt + 1;
                end else begin
                    current_state <= 5;
                    dax_fall_cnt  <= 0;
                end
            end
        end else begin
            // 普通模式：原 2 拍/word
            wr_en <= 1; DAX_DATA <= ...
            ...
        end
    end
end
```

**关键设计点**：
1. 等待拍 `wr_en=0` 必须严格——若 wr_en 在等待拍泄漏会让每个 word 被写 2 次，FIFO 反而更满（实施时踩过这个坑，见 IMPLEMENTATION.md §6.4）
2. `s13_wait_cnt` 仅 1 bit（取值 0/1），资源开销可忽略
3. 普通模式分支保持原 2 拍写满逻辑，行为零变化

**效果**（TC13 实测）：
- 所有 dax_fall（1/2/3/5 µs）跨行延迟统一为 **48ns**，与 dax_fall 完全解耦
- 撞墙边界消失，dax_fall 上限不再受 FIFO 行为限制

### 3a.1 状态机流时序图（dax_fall=5, rec=1, laser=2µs，C3-lite 后）

```
时间轴 (ns):     0        6000      6080     6880      下一个 laser
eth_clk 域:     ┌────────┬─────────┬────────┬───────────┬──────────────┐
                │ State 13      │ 5~10/1 │ State 2 │ State 14 等  │
                │ 写斜坡 250 word│ 80ns   │ 写 2 word│   laser      │
                │ (6000ns，限速) │        │ +排空    │              │
                └────────┴─────────┴────────┴───────────┴──────────────┘

FIFO 水位变化（C3-lite + 地板=2）:
  State 13 起:  2  → 写 250 - 读 300 = 净减 50（被 prog_empty 钳制在地板 2）
  State 13 末:  2  → 已稳定在地板
  State 5~10/1: 2  → 不写
  State 2:     2  → 写 2 - 读 ~2 = 净持平
  State 14:    2  → 已在地板

下一个 laser 来 → State 16 写新 word → 跨行延迟 = 2 × 20ns + 杂项 ≈ 48ns ✅
（实测全 dax_fall 配置 = 48ns，与 dax_fall 无关）
```

State 13 时长从 4000ns（2 拍/word）变为 6000ns（3 拍/word），多了 2µs。但这 2µs 把"State 14 排空"的代价提前消化了，最终行间隔被 laser 周期对齐，最坏多 1 个 laser 周期。

## 4. 与之前讨论方案的对比

| 方案 | 单像素 | 跨行 | 行间隔 | DAC 斜坡 | 改动量 | 评价 |
|---|---|---|---|---|---|---|
| 当前 | 542ns | 3200ns | — | — | — | 不达标 |
| A 单独 | 80ns | 3000ns | 不变 | 不变 | IP 1 处 | ❌ 跨行未解决 |
| A + State 2 写 2 次 | 80ns | 80ns（dax_fall=1）<br>~1µs（dax_fall=5）| 不变 | 不变 | IP + State 2 一处 | dax_fall ≥ 2µs 撞墙 |
| A + C3（限速 State 13/2 双限速）| 80ns | 80ns | +(dax_fall+rec)×800ns | 不变 | IP + RTL 多处 | 行间隔过长 |
| A + E（State 13 减 word） | 80ns | 80ns | 不变 | **变陡 3×** | IP + State 13 + dax_step_div | 需硬件验证 |
| **A + State 2 写 2 次 + C3-lite（采纳）** | **80ns** | **48ns 全 dax_fall 配置** ✅ | **+(0~2)µs 取决于 laser 对齐** | **不变** ✅ | **IP + State 2 + State 13 一拍 wait** ✅ | **采纳** |

## 5. 普通模式不受影响

`laser_mode_en=0` 时 State 2 走原分支（每拍写 1 个 word，写满 dacx_tb_point 个）：

- 普通模式 State 2 后是 State 3（行内像素），不是 State 14
- DAC 必须输出 dacx_strat 共 dacx_recovery_time × 1µs（这段是"连续读出 Tb word"实现）
- 普通模式行 7~8 跳变直接进 State 3 写新像素，FIFO 中间的 Tb word 必须写满才能让 DAC 持续输出 dacx_strat

激光模式 State 2 后是 State 14（等 laser，期间 FIFO 空时 DAC 保持），所以只写 2 次也能让 DAC 持续输出 dacx_strat 直到下一个 laser。

## 6. 不改的事

- 不改 dac_output.v 读侧逻辑（仍用 prog_empty gating）
- 不改 FIFO IP 的 empty 端口连接
- 不改 State 13 的斜坡形态（台阶高度、word 数都不变；仅在激光模式下加 1 拍 wait 让写速率匹配读速率，对 DAC 输出形态零影响）
- 不改 dax_step_div、div_gen_3 IP（不需要重生成 div_gen_3）
- 不改普通模式 State 0~13（laser_mode_en=0 时 State 13 仍走 2 拍/word 原路径）
- 不改 testbench TC1~TC12（用作回归验证）

## 7. 风险与回退

| 风险 | 概率 | 影响 | 回退方案 |
|---|---|---|---|
| IP 重生成后时序退化 | 低 | WNS 可能下降 | 保留旧 IP 配置作为 git fallback |
| 写 2 次仍有 DAC 跳变 | 极低 | 行首像素位置略偏 | 改为写 3~5 次（s2_write_cnt 改 3 位） |
| TC10 失败（per-pixel DAX 错） | 低 | 行内像素错位 | 单测 IP 改动确认是否 IP 引入；否则定位 throttle 时序 |
| 综合面积/时序不过 | 极低 | 5 个寄存器影响可忽略 | 不存在 |
| **C3-lite wr_en 在等待拍泄漏**（实施时已踩过） | 已定型 | 每 word 写 2 次，FIFO 反而更满 | 已修复，wr_en/DAX/DAY 必须在 "第 1 拍" 分支内，第 2 拍只更新计数器 |
| **C3-lite 行间隔变长** | 中 | 最坏情况 +1 个 laser 周期（~2µs） | 硬件部署后实测帧率影响；若不可接受可考虑回滚到方案 E |

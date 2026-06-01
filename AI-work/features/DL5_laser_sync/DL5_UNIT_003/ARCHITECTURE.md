# DL5 UNIT_003 架构设计：FIFO 水位延迟优化（推荐方案 = A + State 2 写 2 次）

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

- **写读比 = 2.5×**：每个 burst 写完后 FIFO 净增 ≈ 0.6 × W（W = 写入 word 数）
- **State 12+13 配对**：每个斜坡 word 用 2 拍（State 12 减 dax_level、State 13 写 FIFO）
- **State 2 计时**：dacx_tb_point = dacx_recovery_time × 50（dac_dco 拍数），State 2 状态机时长 = dacx_tb_point × 8ns（eth_clk 域）
- **DAC 输出来自 FIFO**：dac_output 持续读 FIFO，每 word 输出 20ns。State 2/13/16 写入的 word 都会被 DAC 真实播放
- **FIFO 空时 DAC 保持**：[dac_output.v:266-274](../../../AXI_DDR.srcs/sources_1/new/dac_output.v#L266-L274) 在 rd_en_r=0 时 `DAX_DATA <= DAX_DATA`，DAC 输出保持不变

### 1.2 延迟公式

**单像素切换延迟**（State 16 第 1 个 word 写入 → DAX_DATA 更新）：

```
delay = (FIFO 地板 word 数) × 20ns + CDC/同步杂项
      = 20 × 20ns + ~140ns
      = 542ns（实测）
```

**跨行延迟**（State 13 写完 → 进 State 14 → FIFO 排到地板）：

```
drain_time = (FIFO 残留 - 地板) × 20ns
残留 = State 13 净增 + State 2 净增
     = dax_fall × 50 × 0.6 + dacx_rec × 50 × 0.6（典型）
```

dax_fall=5, rec=2 时残留 ≈ 130 word，drain ≈ 2200ns（实测 3200ns）。

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

## 3. 为什么写 2 次而不是 1 次

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

## 4. 与之前讨论方案的对比

| 方案 | 单像素 | 跨行 | 行间隔 | DAC 斜坡 | 改动量 | 评价 |
|---|---|---|---|---|---|---|
| 当前 | 542ns | 3200ns | — | — | — | 不达标 |
| A 单独 | 80ns | 3000ns | 不变 | 不变 | IP 1 处 | ❌ 跨行未解决 |
| A + C3（限速 State 13/2） | 80ns | 80ns | **+(dax_fall+rec)×800ns** | 不变 | IP + RTL 多处 | 行间隔变长 |
| A + E（State 13 减 word） | 80ns | 80ns | 不变 | **变陡 3×** | IP + State 13 + dax_step_div | 需硬件验证 |
| **A + State 2 写 2 次（推荐）** | **80ns** | **80ns** | **不变** ✅ | **不变** ✅ | **IP + State 2 一处** ✅ | **采纳** |

## 5. 普通模式不受影响

`laser_mode_en=0` 时 State 2 走原分支（每拍写 1 个 word，写满 dacx_tb_point 个）：

- 普通模式 State 2 后是 State 3（行内像素），不是 State 14
- DAC 必须输出 dacx_strat 共 dacx_recovery_time × 1µs（这段是"连续读出 Tb word"实现）
- 普通模式行 7~8 跳变直接进 State 3 写新像素，FIFO 中间的 Tb word 必须写满才能让 DAC 持续输出 dacx_strat

激光模式 State 2 后是 State 14（等 laser，期间 FIFO 空时 DAC 保持），所以只写 2 次也能让 DAC 持续输出 dacx_strat 直到下一个 laser。

## 6. 不改的事

- 不改 dac_output.v 读侧逻辑（仍用 prog_empty gating）
- 不改 FIFO IP 的 empty 端口连接
- 不改 State 13 / State 12（斜坡形态、台阶高度、时间都不变）
- 不改 dax_step_div、div_gen_3 IP（不需要重生成 div_gen_3）
- 不改普通模式 State 0~13（laser_mode_en=0 时行为零变化）
- 不改 testbench TC1~TC12（用作回归验证）

## 7. 风险与回退

| 风险 | 概率 | 影响 | 回退方案 |
|---|---|---|---|
| IP 重生成后时序退化 | 低 | WNS 可能下降 | 保留旧 IP 配置作为 git fallback |
| 写 2 次仍有 DAC 跳变 | 极低 | 行首像素位置略偏 | 改为写 3~5 次（s2_write_cnt 改 3 位） |
| TC10 失败（per-pixel DAX 错） | 低 | 行内像素错位 | 单测 IP 改动确认是否 IP 引入；否则定位 throttle 时序 |
| 综合面积/时序不过 | 极低 | 4 寄存器影响可忽略 | 不存在 |

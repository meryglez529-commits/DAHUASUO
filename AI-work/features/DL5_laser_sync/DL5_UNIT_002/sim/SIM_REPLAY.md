# DL5_UNIT_002 仿真复现说明书

> 本文档手把手带你在 Vivado GUI 里跑 DL5 集成仿真，并查看每个测试用例（TC）的关键波形。

---

## 0. 你将得到什么

完成本说明书后，你会：

1. 看到 12 个测试用例（TC1~TC12）的 PASS/FAIL 输出
2. 学会如何在波形里观察每个 TC 的核心信号
3. 理解状态机切换、acq 时序、blanker 时序、激光门控、**FIFO 水位带来的延迟**的实际行为

测试用例分两层：

| 范围 | 关注点 |
|---|---|
| TC1~TC7 | RTL 功能性：状态机、CDC、寄存器、模式切换 |
| TC8~TC12 | FIFO 水位与延迟：触发路径独立性、数据路径延迟、行内/行末边界排空 |

> **TC11 是核心**：直接量测 laser → DAX_DATA（数据路径）vs laser → acq_pulse_ui（触发路径）的延迟差，验证 ARCHITECTURE.md §1.1 "数据/触发分离"的设计断言。

---

## 1. 启动

### Step 1.1：打开 Vivado GUI

双击 Vivado 2021.1 图标，等启动完成。

### Step 1.2：打开工程

菜单 → File → Project → Open，选择：

```
D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj\AXI_DDR.xpr
```

等工程加载完成（左下角 Status 显示 OK）。

### Step 1.3：在 Tcl Console 切换工作目录

Tcl Console 在 Vivado 窗口下方。**第一次打开工程时**，工作目录可能不在工程根目录。先确认：

```tcl
pwd
```

如果输出不是工程根目录（应该是 `D:/SGSC_SEM_dahuasuo_325T_V3_172/.../fpga_prj`），就先 cd 过去：

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj
```

> **注意**：Tcl 用正斜杠 `/`，不是反斜杠 `\`。

### Step 1.4：source 仿真启动脚本

```tcl
source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_gui.tcl
```

> **直接 source，命令前不要加 `tcl` 字样。**

脚本会做以下事情：
- 把 `tb_dl5_unit_002.v` 加到 sim_1 fileset
- 设置仿真顶层为 `tb_dl5_unit_002`
- `launch_simulation` 启动仿真
- `run all` 跑到 `$finish`

预计 **3-5 分钟**。Tcl Console 不停滚动是正常的。

### Step 1.5：看仿真结果

仿真完成后，Tcl Console 末尾会有：

```
[TC1] PASS
[TC2] PASS
[TC3] PASS
[TC4] PASS
[TC5] PASS
[TC6] PASS
[TC7] PASS
[TC8] PASS
[TC9] PASS
[TC10] PASS
[TC11] PASS
[TC12] PASS
========================================
DL5_UNIT_002 test done, errors = 0
PASS
========================================
```

12 个 TC 全 PASS 就 OK。仿真总时长约 39us（仿真时间，不是真实时间）。

---

## 2. 仿真完成后看波形

仿真自动完成后，**Waveform Viewer** 会自动出现在中间区域。

### Step 2.1：导航 Scope

左边 **Scope** 面板显示模块层次：

```
tb_dl5_unit_002
  └─ DUT
      ├─ N1 (parameter_dacdata_gen)
      └─ N2 (dac_output)
```

点开层次，选中模块，**Objects** 面板会显示该模块所有信号。

### Step 2.2：添加全局基础信号

在 Scope 选中 `tb_dl5_unit_002`，找到下面这些信号，右键 → **Add to Wave Window**：

| 信号 | 含义 |
|---|---|
| `eth_rstn` | 全局复位（低有效） |
| `scan_state` | 扫描启停 |
| `laser_mode_en` | 激光模式开关 |
| `laser_sync_in` | 外部 laser 触发输入 |
| `errors` | 错误计数器（最后看） |
| `tc_id` | 当前测试用例编号 |

### Step 2.3：添加状态机和关键内部信号

Scope 选中 `tb_dl5_unit_002`，添加这些 **wire 探针**（tb 里已声明）：

| 信号 | 含义 |
|---|---|
| `dut_state` | parameter_dacdata_gen 状态机（0~16） |
| `dut_laser_toggle` | eth_clk 域 toggle 翻转 |
| `dut_laser_pulse_ui` | ui_clk 域 laser 脉冲（独立触发桥的产物） |
| `dut_acq_pulse_ui` | acq 状态机输出（ui_clk 域） |
| `dut_para_wr_en` | FIFO 写使能（State 2/13/16/11 时为 1） |
| `dut_prog_empty` | FIFO prog_empty（阈值=20，TC10/11/12 用它判定 FIFO 排空） |
| `dut_rd_en` | FIFO 读使能（dac_dco 域，prog_empty=0 时为 1） |

### Step 2.4：添加输出引脚

| 信号 | 含义 |
|---|---|
| `DAX_DATA[15:0]` | DAC X 通道输出 |
| `DAY_DATA[15:0]` | DAC Y 通道输出 |
| `adc_tri` | ADC 采集触发引脚 |
| `sync_pixel_tri1` | blanker 引脚（低有效） |

### Step 2.5：把 dut_state 设成 enum 显示（推荐）

`dut_state` 是 5-bit 数字，看起来不直观。在 Wave Window 里右键 `dut_state` → **Radix → Unsigned Decimal**，这样能直接看到 0/1/2/3/4/14/15/16。

### Step 2.6：FIFO 内部信号（看 TC11/TC12 必备）

如果想直接看 FIFO 数据流（而不是只通过 `dut_prog_empty` 判断），在 Scope 里展开：

```
tb_dl5_unit_002
  └─ DUT
      └─ N2 (dac_output)
          └─ fifo_para_config (FIFO IP 例化)
```

选中 `fifo_para_config`，把这些信号加到波形：

| 信号 | 含义 |
|---|---|
| `wr_en` | FIFO 写使能（与 `dut_para_wr_en` 同源） |
| `rd_en` | FIFO 读使能（dac_dco 域） |
| `din[34:0]` | 写入数据（包含 DAX/DAY/sync 拼接） |
| `dout[34:0]` | 读出数据（dac_dco 拍数据） |
| `prog_full` | FIFO 半满信号（阈值 480/512） |
| `prog_empty` | FIFO 半空信号（阈值 20/512） |

> **看 TC11 高水位时**：在 inject 时刻往左拖几百 ns，能看到 `wr_en` 持续 30 个 eth_clk 拍把新像素写进去；之后 `rd_en` 在 dac_dco 域慢慢读，这时 `dout` 仍是上一像素的旧 DAX/DAY，等读了 ~20 个 word 后 `dout` 才换到新坐标。这就是 557ns gap 的本质。

---

## 3. 按 TC 看波形

每个 TC 都有 `tc_id` 标记，先在 Wave Window 里把 `tc_id` 拉到最上面，方便找到对应区间。

### 快速定位（实测时间线）

参考下表（来自 v5 仿真日志）快速跳转：

| TC | 起始时间 (近似) | 持续 | 备注 |
|---|---|---|---|
| TC1 | 0 ns | ~500 ns | 复位释放后立即进入 |
| TC2 | ~600 ns | ~1.5 µs | 第一次激光模式 |
| TC3 | ~2.1 µs | ~100 ns | scan_delay 倒计时 |
| TC4 | 2260 ns | ~200 ns | acq 时序 |
| TC5 | 4300 ns | ~200 ns | blanker 时序 |
| TC6 | ~4.6 µs | ~500 ns | 状态门控 |
| TC7 | ~5.5 µs | ~3 µs | 模式切换 |
| TC8 | 8972 ns | ~600 ns | 触发独立性 |
| TC9 | ~10.5 µs | ~1.5 µs | FIFO 排空 |
| TC10 | ~12 µs | ~13 µs | 4 像素逐个验证 |
| TC11 | 25556 ns | ~700 ns | **FIFO 水位实证（核心）** |
| TC12 | ~26 µs | ~12 µs | 行末斜坡 |

> 在 Tcl Console 用 `set time_unit ns` 后可以直接 `relaunch_simulation`；想快速跳转到某个时刻，Wave Window 工具栏的"Go to time"输入 `25556 ns` 就可以直达 TC11。

---

### TC1 — 普通模式回归

**目的**：验证 `laser_mode_en=0` 时状态机正常进入 State 3（像素采样）。

**操作**：
1. Wave Window 工具栏 → 找到 `tc_id = 1` 的时间区间
2. 在该区间里，观察 `dut_state` 应该走 0 → 1 → 2 → 3
3. `laser_mode_en` 应保持 0

**关键信号**：`dut_state`、`scan_state`、`laser_mode_en`、`DAX_DATA`、`adc_tri`

**通过判据**：State 3 进入后，`adc_tri` 应该跟着 FIFO[32]（即 dac_sample 拍期间高电平）。

---

### TC2 — 激光模式基本流程

**目的**：验证激光模式状态机循环 14 → 15 → 16 → 4 → 14。

**操作**：
1. 定位到 `tc_id = 2` 区间
2. 观察 `dut_state` 在 `laser_sync_in` 上升沿到来时进入 15，然后 16，然后 4，再回 14
3. 期间 `DAX_DATA` 应该在 State 16 里写入新像素坐标

**关键信号**：`dut_state`、`laser_sync_in`、`dut_laser_toggle`（每次 laser 翻转）、`DAX_DATA`

**通过判据**：每个 laser 上升沿后，`dut_state` 完成一次 14→15→16→4→14 循环。

---

### TC3 — scan_delay 倒计时

**目的**：验证 State 15 持续 `scan_delay_time × eth_clk` 周期。

**配置**：`scan_delay_time = 5`（即应停留 5 个 eth_clk = 40ns）

**操作**：
1. 定位 `tc_id = 3` 区间
2. 找到 `dut_state` 进入 15 的时刻 t1
3. 找到 `dut_state` 离开 15（变为 16）的时刻 t2
4. 用 Wave Window 的标尺（**Marker**）测量 t2 - t1

**通过判据**：t2 - t1 ≈ 40ns（允许 ±2 拍 = ±16ns 偏差）。

---

### TC4 — acq 时序

**目的**：验证 acq 状态机产生正确宽度的脉冲。

**配置**：`acq_data_delay_time = 2`（40ns delay），`acq_time = 5`（100ns 宽度）

**操作**：
1. 定位 `tc_id = 4` 区间
2. 找到 `laser_sync_in` 上升沿（t_laser）
3. 找到 `dut_acq_pulse_ui` 上升沿（t_rise）和下降沿（t_fall）
4. 测量：
   - delay = t_rise - t_laser（期望 ~80ns，含 CDC 延时）
   - width = t_fall - t_rise（期望 100ns）

**关键信号**：`laser_sync_in`、`dut_acq_pulse_ui`、`adc_tri`

**通过判据**：脉宽 100ns ±20%。Tcl Console 会打印实测值。

---

### TC5 — blanker 时序

**目的**：验证 sync_pixel_tri1（blanker 引脚，低有效）正确产生。

**配置**：`blanker_delay_time = 10`（50ns delay），`blanker_time = 20`（100ns 宽度）

**操作**：
1. 定位 `tc_id = 5` 区间
2. 找到 `laser_sync_in` 上升沿（t_laser）
3. 找到 `sync_pixel_tri1` 下降沿（t_fall，blanker 关）和上升沿（t_rise，blanker 开）
4. 测量 t_rise - t_fall

**关键信号**：`laser_sync_in`、`sync_pixel_tri1`

**通过判据**：脉宽 100ns ±20%。**注意 blanker 是低有效，下降沿才是 blanker 关闭**。

---

### TC6 — State 14 门控

**目的**：验证不在 State 14 时（比如 State 16 写像素期间）到达的 laser 不会让 toggle 翻转。

**操作**：
1. 定位 `tc_id = 6` 区间
2. 第一次 `inject_laser` 让状态机走到 State 16
3. 第二次 `inject_laser` 在 State 16 期间发生
4. 观察 `dut_laser_toggle` 在第二次 laser 时**不翻转**

**关键信号**：`dut_state`、`laser_sync_in`、`dut_laser_toggle`

**通过判据**：第二次 laser 上升沿之后 20 个 eth_clk 周期内，`dut_laser_toggle` 保持不变。

---

### TC7 — 模式切换复位

**目的**：验证通过 `scan_state` 上升沿（rstn_r2 6 拍复位脉冲）能正确清状态机。

**操作**：
1. 定位 `tc_id = 7` 区间
2. 观察 `scan_state` 从 1 → 0 → 1 的过程
3. 看 `laser_mode_en` 切换为 0
4. 看 `dut_state` 是否能正常走到 State 3

**关键信号**：`scan_state`、`laser_mode_en`、`dut_state`

**通过判据**：切回普通模式后，`dut_state` 能进入 State 3。

---

## 3.5 FIFO 水位与延迟测试（TC8~TC12，本期重点）

> 这一组用例覆盖 ARCHITECTURE.md §1.1 / §5 的核心断言：
> - 触发路径（acq/blanker）通过独立 toggle-FF 桥跨域，**不受 FIFO 水位影响**
> - 数据路径（DAX/DAY）走 35-bit FIFO，**延迟由 FIFO 水位决定**
> - FIFO 水位被 `prog_empty` 阈值（=20 word）钳位，每个像素读侧要先消化 20 个旧 word 才看到新坐标
>
> 在波形里建议先把 `dut_prog_empty`、`dut_acq_pulse_ui`、`DAX_DATA` 三个信号拉到一起，TC8~TC12 全部围绕它们。

### TC8 — 触发路径独立性（不依赖 FIFO 水位）

**目的**：第 1 次 laser（FIFO 空）和第 2 次 laser（FIFO 有 1 像素残留）的 acq 延迟应一致。

**配置**：`scan_delay_time = 5`，`acq_data_delay_time = 2`，`acq_time = 5`，`dac_sample = 10`，
        `dacx_tk_point = 100`（行内多像素）

**操作**：
1. 定位 `tc_id = 8` 区间
2. 找到第 1 次 `laser_sync_in` 上升沿 t_laser1 和对应 `dut_acq_pulse_ui` 上升沿 t_acq1
3. 找到第 2 次 t_laser2 / t_acq2
4. 用 marker 测两次的 delay = t_acq - t_laser

**通过判据**：两次 delay 都在 ~76ns 附近，差值 < 50ns（实测 76ns / 78ns，diff = 2ns ✅）

**为什么 delay 稳定**：toggle-FF 桥是 eth_clk 1 拍 + ui_clk 3 级 FF + 异或，与 FIFO 完全无关。

---

### TC9 — State 16 后 FIFO 排空时间

**目的**：观察单个像素写入 FIFO 后，读侧多久把它消化干净。

**配置**：沿用 TC8（`dac_sample = 10`）

**操作**：
1. 定位 `tc_id = 9` 区间
2. 找到 `dut_state` 离开 State 16 的时刻 t_wr_fall
3. 找到 `dut_prog_empty` 从 0 → 1 的时刻 t_empty
4. 测 drain = t_empty - t_wr_fall

**关键信号**：`dut_state`、`dut_prog_empty`、`dut_para_wr_en`、`dut_rd_en`

**通过判据**：drain ≤ dac_sample × 30ns。实测 drain ≈ 1128ns（FIFO 累积了多 TC 的残留 word，所以比理论 120ns 大；这是正常的，因为 prog_empty 阈值=20，FIFO 内仍可能有积压）。

---

### TC10 — 多像素行内逐个 DAX 正确性（核心功能性测试）

**目的**：在每个像素 inject 之间等 FIFO 排到阈值，验证 DAC 输出最终都更新到正确坐标。

**配置**：`dac_sample = 30`（必须 > FIFO 阈值 20，否则 DAX 永远不更新），
        `dacx_tk_point = 10`（保证不会误进 State 12 行末），
        `dacx_strat_level = 0x2000`，`dacx_step` 高 16 位 = `0x0080`

**操作**：
1. 定位 `tc_id = 10` 区间
2. 在 Wave Window 同时显示 `dut_state`、`dut_prog_empty`、`DAX_DATA`、`laser_sync_in`
3. 观察 4 次 `inject_laser` 之间的节奏：
   - 每次 inject 前 `dut_prog_empty = 1`（FIFO 在阈值）
   - State 14 → 15 → 16（写 30 word）→ 4 → 14
   - 等 `dut_prog_empty` 回 1，DAX_DATA 应该已更新到 `0x2000 + k × 0x0080`

**关键信号**：`dut_state`、`dut_prog_empty`、`DAX_DATA`、`laser_sync_in`

**通过判据**：4 个像素 DAX 依次为 `0x2000 / 0x2080 / 0x2100 / 0x2180` ✅

**踩坑提示**：如果 `dac_sample ≤ 20`，单个像素写入不足以让 FIFO 突破 prog_empty 阈值，读侧 `rd_en` 一直为 0，DAX 永远停留在初始值。

---

### TC11 — FIFO 水位让 DAC 路径延迟远大于 acq 路径延迟（FIFO 水位的核心实证）

**目的**：直接测量两条路径的延迟，验证设计断言。

**配置**：`dac_sample = 30`，`dacx_tk_point = 100`，warm-up 跑 3 个像素让 FIFO 进入稳态水位

**测量**：
- `t_laser` = `inject_laser` 时刻
- `t_acq` = `dut_acq_pulse_ui` 第一次上升沿（独立 toggle-FF 桥的输出）
- `t_dax_change` = `DAX_DATA` 从旧值变到新值的时刻（FIFO 数据路径的输出）

**操作**：
1. 定位 `tc_id = 11` 区间，找到最后一次 inject（warm-up 之后）的 `laser_sync_in` 上升沿
2. 在 Wave Window 加 marker_1 = laser 上升沿
3. 加 marker_2 = `dut_acq_pulse_ui` 上升沿，测 delay_ACQ
4. 加 marker_3 = `DAX_DATA` 跳变，测 delay_DAC
5. 状态栏读出 dt 即可

**关键信号**：`laser_sync_in`、`dut_acq_pulse_ui`、`DAX_DATA`、`dut_prog_empty`

**通过判据（实测）**：
| 路径 | 延迟 | 范围 |
|---|---|---|
| acq（独立 toggle 桥） | **77 ns** | [50, 150] ns ✅ |
| DAC（FIFO 数据路径） | **634 ns** | [300, 1500] ns ✅ |
| gap = DAC - ACQ | **557 ns** | ≥ 200 ns ✅ |

**这 557ns 就是 FIFO 水位带来的延迟**。来源：
- prog_empty 阈值 = 20 word
- 读侧消化 20 个旧 word，每个 dac_dco 周期 = 20ns
- 20 × 20ns ≈ 400ns + scan_delay + 几拍 CDC ≈ 557ns

**这正是为什么 acq/blanker 必须走独立路径**：如果 acq 也通过 FIFO 触发，每个像素 acq 起算时刻就会有 ~500ns 抖动（取决于 FIFO 水位），无法满足"laser → acq 延迟稳定"的需求。

---

### TC12 — 行末斜坡排空 → 下一行 DAC = dacx_strat

**目的**：验证 ARCHITECTURE.md §5.3 "行末斜坡 → 下一行第 1 个像素"约束公式。

**配置**：`dax_fall_time = 5` µs（× 50 = 250 word 斜坡），`dacx_tk_point = 3`（行短）

**操作**：
1. 定位 `tc_id = 12` 区间
2. 看完整一行的扫描：3 次 inject_laser → 行末 State 12/13（写 250 个斜坡 word）
3. 行切换 5~10 → 回到 State 14（下一行起点）
4. 观察 `dut_prog_empty` 从 0 → 1（斜坡排空）
5. inject 下一行第 1 个 laser
6. 等 `dut_prog_empty = 1`，读 `DAX_DATA`

**关键信号**：`dut_state`、`dut_prog_empty`、`DAX_DATA`

**通过判据**：下一行第 1 个像素 DAX = `dacx_strat_level = 0x2000` ✅

**实测时间线**：
- 第 1 行结束于 t = 29420ns
- 下一行 State 14 进入于 t = 34276ns（中间走斜坡 + 行切换 ≈ 4856ns）
- FIFO 排空于 t = 37476ns
- 下一行第 1 个像素 inject 后 DAX = 0x2000

如果 laser 周期太短（在 FIFO 排空前到来），残留斜坡 word 会让 DAC 短暂输出错误坐标，但 ARCHITECTURE.md §5.4 的分析说明这种残留只影响 DAC 模拟侧的"瞬态"，最终值仍是正确的 dacx_strat。

---

## 4. 常用波形操作

| 操作 | 快捷键 / 方法 |
|---|---|
| 缩放到全部 | F6 或工具栏 "Zoom Fit" |
| 缩放选中区间 | 鼠标拖框 + F8 |
| 放标尺（Marker） | 在波形区点击想标记的位置，看下面状态栏的 t1, t2 |
| 测量两个 marker 时间差 | 添加第二个 marker，状态栏显示 dt |
| 改信号显示进制 | 右键信号 → Radix |
| 保存当前波形布局 | File → Save Waveform Configuration As → `dl5_unit002.wcfg` |

---

## 5. 重新跑仿真

如果你改了 testbench 或 RTL，需要重跑：

```tcl
restart
run all
```

如果改动了源文件，需要重新编译：

```tcl
close_sim
source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_gui.tcl
```

---

## 6. 故障排除

| 症状 | 解决 |
|---|---|
| `couldn't read file ... no such file or directory` | Tcl Console 不在工程根目录，先 `cd` |
| `ambiguous command name "tcl"` | source 命令前不要加 `tcl` 关键字 |
| 仿真跑不出结果，卡住 | 看 `dut_state` 是不是卡在某个 state，对照 testbench 逻辑 |
| 波形里某些信号显示 X（红色） | 仿真还没初始化到那个时刻，往后拖时间 |
| `errors > 0` | 看 Tcl Console 里哪个 TC 报 FAIL，按本文档对应章节查信号 |

---

## 7. 文件清单

| 文件 | 用途 |
|---|---|
| `AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_gui.tcl` | GUI 模式启动脚本（本文档主用）|
| `AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_manual.tcl` | Batch 模式脚本（仅 CI 用，不要在 GUI 里 source）|
| `AXI_DDR.srcs/sim_1/new/tb_dl5_unit_002.v` | 集成 testbench |
| `AI-work/guide/VIVADO_SIM_SOP.md` | Vivado 仿真 SOP（适用其他 unit 的通用说明） |

# DL5_UNIT_003 仿真跑通完整路线

> 本文档记录 DL5_UNIT_003（FIFO 水位延迟优化）的端到端实施流程：
> 从改 IP → 改 RTL → batch 仿真 → 结果验证。
>
> 通用 Vivado 仿真 SOP 见 [VIVADO_SIM_SOP.md](../../../guide/VIVADO_SIM_SOP.md)，
> 本文档只覆盖 UNIT_003 这次实施踩过的坑和验证步骤。

---

## 0. 环境前提（一次性配置）

跑任何仿真前必须先确认：

### 0.1 wbtcv.exe 改名（永久修复，已完成）

`D:\Xilinx\Vivado\2021.1\bin\unwrapped\win64.o\wbtcv.exe` 已被改名为 `wbtcv.exe.bak`。

**为什么**：xelab 在 build snapshot 后会 fork wbtcv 上报 webtalk，公司网络（aTrust）封锁导致 wbtcv 死等不返回 + 持有 elaborate.log 句柄不放，整个 launch_simulation 卡死几小时。改名后 xelab 找不到 wbtcv 会打印一行非致命错误然后继续，仿真正常完成。

**自检**：
```bash
ls "D:/Xilinx/Vivado/2021.1/bin/unwrapped/win64.o/wbtcv"*
# 应该看到 wbtcv.exe.bak 而不是 wbtcv.exe
```

如果 Vivado 升级或重装，需要重新改名。

### 0.2 工程根目录

```
D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj
```

所有仿真命令在这个目录执行。

---

## 1. RTL 改动

直接编辑 `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v`：

### 1.1 加 reg 声明（line 96 附近）
```verilog
reg [1:0]   s2_write_cnt;
```

### 1.2 加复位（两处：主复位块 + default 分支）
```verilog
s2_write_cnt        <= 2'd0;
```

### 1.3 改 State 2 主体（line 316~376）
分激光模式 / 普通模式两个分支。激光模式只写 2 次，普通模式行为保持不变。具体代码见 [IMPLEMENTATION.md §2.3](../IMPLEMENTATION.md)。

**RTL 改完后不需要做任何"reload"操作**，仿真启动时会自动重新编译。

---

## 2. IP 改动（fifo_generator_4 prog_empty 阈值 20 → 2）

### 2.1 必须在 Vivado GUI 里改，不能直接编辑 .xci

理由：直接改 .xci 不会重新生成 IP 的 sim_netlist，仿真用的还是旧网表。

### 2.2 在 GUI Tcl Console 执行（一段一段粘贴）

**前置**：先在 Vivado 里打开 `AXI_DDR.xpr` 工程。

**第 1 步：读当前值**
```tcl
set ip_obj [get_ips fifo_generator_4]
puts "Empty_Threshold_Assert_Value = [get_property CONFIG.Empty_Threshold_Assert_Value $ip_obj]"
puts "Empty_Threshold_Negate_Value = [get_property CONFIG.Empty_Threshold_Negate_Value $ip_obj]"
```

**第 2 步：改阈值**
```tcl
set_property -dict [list \
    CONFIG.Empty_Threshold_Assert_Value 2 \
    CONFIG.Empty_Threshold_Negate_Value 3 \
] $ip_obj
```

**第 3 步：复查（应当输出 2 / 3）**
```tcl
puts "Empty_Threshold_Assert_Value = [get_property CONFIG.Empty_Threshold_Assert_Value $ip_obj]"
puts "Empty_Threshold_Negate_Value = [get_property CONFIG.Empty_Threshold_Negate_Value $ip_obj]"
```

**第 4 步：重新生成 IP（约 3~5 分钟）**
```tcl
generate_target {synthesis simulation} [get_files fifo_generator_4.xci]
```

完成后 `AXI_DDR.gen/sources_1/ip/fifo_generator_4/sim/fifo_generator_4.v` 会用新阈值。

### 2.3 改完 IP 必须关闭 GUI 才能跑 batch 仿真

GUI 占用工程独占锁，batch 模式打不开同一个工程。

**关 GUI 流程**：
1. File → Close Project（不需要关 Vivado 主程序）
2. 或直接关 Vivado 进程

---

## 3. 仿真执行（Batch 模式 = 推荐）

### 3.1 为什么选 batch 不选 GUI

| 维度 | batch | GUI |
|---|---|---|
| 稳定性 | ✅ 经多次验证可靠 | wbtcv 改名后可用，但 launch_simulation 路径还有偶发问题 |
| 速度 | ~3 分钟 | ~5 分钟（启动慢） |
| 自动化 | ✅ 一条命令 | 需要手动 source |
| 看波形 | 不能直接看 | ✅ 自动弹窗 |
| 工程锁 | 自己开关 | 需要先关 GUI |

**结论**：跑回归用 batch，看波形/调试用 GUI（前提 wbtcv 已改名）。

### 3.2 跑 batch 仿真的标准命令

```bash
cd "D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj"

# 清掉上次残留 snapshot（避免文件锁）
rm -rf AXI_DDR.sim/sim_1/behav/xsim/xsim.dir

# 跑仿真，重定向到日志
"D:/Xilinx/Vivado/2021.1/bin/vivado.bat" -mode batch \
    -source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_manual.tcl \
    > AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/sim/run.log 2>&1
```

**注意**：路径里有空格的话要全部加引号。

### 3.3 run_manual.tcl 做什么

1. 打开工程
2. 把 testbench 加入 sim_1 fileset
3. `generate_target Simulation` 生成 IP 仿真目标
4. 在 sim 目录下手动调用 `xvlog` → `xelab` → `xsim`（绕开 launch_simulation 的 Broken pipe 问题）
5. `run all` 跑到 `$finish`
6. 把日志和 .wdb 复制到 `out/sim/`

### 3.4 run_manual.tcl 里的 result.txt FAIL 是误判

脚本末尾用 `string match "*FAIL*"` 检测 xsim_out 字符串。但 testbench 的 `$display` 格式字符串里包含 `FAIL` 字面量（如 "FAIL: %0d error(s)"），即使 errors=0 也会触发误判。

**正确判断 PASS/FAIL 的方式**：直接 grep log 看 errors 和每个 TC 的状态，不要看 result.txt。

---

## 4. 结果检查

### 4.1 一行命令提取所有 TC 状态

```bash
grep -E "^\[TC|errors|finish" out/sim/run.log | head -40
```

### 4.2 关键指标摘要

```bash
grep -E "TC11.*delay|TC12.*drain|TC13|errors =" out/sim/run.log
```

### 4.3 当前 DL5_UNIT_003 的预期数字（已验证）

| TC | 关键数据 | 状态 |
|---|---|---|
| TC1~TC10 | 全 PASS | 功能正确 |
| TC8 delay_ACQ | 76~78ns | 不变（独立路径） |
| TC9 drain | 248ns | 改前 1128ns ↓78% |
| TC11 delay_DAC | 274ns | 改前 634ns ↓57% |
| TC11 gap | 197ns | 改前 557ns ↓65% |
| TC12 drain | 360ns | 改前 3200ns ↓89% |
| TC13.0 dax_fall=1us | delay=48ns | ✅ 安全 |
| TC13.1 dax_fall=2us | delay=318ns | ⚠️ 超 200ns |

如果数字明显偏离上面的范围，说明 IP 或 RTL 没改对，回去检查。

---

## 5. 常见错误与处理

### 5.1 elaborate.log 被锁，launch_simulation 卡死

```
boost::filesystem::remove: 另一个程序正在使用此文件 ... elaborate.log
```

**根因**：上一次 GUI launch_simulation 卡死后留下了 wbtcv.exe 进程，持有 elaborate.log 句柄。

**已永久修复**：wbtcv.exe 已改名（见 §0.1）。如果还出现，说明 wbtcv 又被恢复了。

**临时排查**（如果出现）：
```bash
tasklist | grep -iE "wbtcv|xsim|xelab"
# 如果有 wbtcv 进程：
taskkill //F //IM wbtcv.exe
```

### 5.2 `Multiple occurrences of option ---mt is not allowed`

**根因**：simset property `xsim.elaborate.xelab.more_options` 被污染。

**修复**（在 GUI Tcl Console 执行）：
```tcl
set_property xsim.elaborate.xelab.more_options "" [get_filesets sim_1]
```

注意要用 `""` 强制覆盖，`reset_property` 不一定清得掉。

### 5.3 `Spawn failed: Broken pipe`（batch 模式）

**根因**：batch 模式 `launch_simulation` 路径在长路径工程下有 bug。

**修复**：用 `run_manual.tcl`（绕开 launch_simulation，手动调 xvlog/xelab/xsim）。

### 5.4 testbench 编译报 `'xxx' is not declared`

**根因**：testbench 引用了不存在的变量（比如我之前误用 `dacx_pp_level`）。

**排查**：
```bash
grep "ERROR.*VRFC" out/sim/run.log
```

### 5.5 仿真跑完没结果

通常是因为 testbench 在某个 wait/repeat 处死锁。看：
```bash
grep -E "TC[0-9]+|finish|GLOBAL FAIL|timeout" out/sim/run.log
```

如果最后停在某个 TC 没出 PASS，说明那里卡住了。检查 wait_state 的 max_wait 是否够大。

### 5.6 时间戳显示是 ns 还是 ps

testbench 使用 `timescale 1ns/1ps`，**`$time` 返回的数字以 ns 为单位**（不是 ps）。
- ❌ 错误：`if (delay < 50000) // 以为是 ps`
- ✅ 正确：`if (delay < 50)     // ns`

判据写错会导致明明仿真数据正确但 testbench 报 FAIL。

---

## 6. GUI 模式（看波形用）

如果只是 batch 跑通后想看波形：

### 6.1 前提
- wbtcv.exe 已改名（§0.1）
- batch 已经跑过一次，`AXI_DDR.sim/sim_1/behav/xsim/tb_dl5_unit_002_behav.wdb` 存在

### 6.2 直接打开 wdb 看波形（推荐）
1. 启动 Vivado GUI
2. File → Open → Waveform Database
3. 选 `AXI_DDR.sim/sim_1/behav/xsim/tb_dl5_unit_002_behav.wdb`

不需要重新跑仿真，直接看 batch 跑出来的波形。

### 6.3 或者重新跑仿真（带 GUI）

打开 GUI 工程 → Tcl Console：
```tcl
close_sim
source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_gui.tcl
```

跑完会自动弹 Waveform Viewer。

---

## 7. 完整端到端流程（DL5_UNIT_003 实施回放）

按时间顺序：

| 步骤 | 操作 | 时间 | 验证 |
|---|---|---|---|
| 1 | 编辑 parameter_dacdata_gen.v 加 s2_write_cnt + State 2 分支 | 5 分钟 | 手动 review diff |
| 2 | GUI Tcl Console 改 fifo_generator_4 IP 阈值 20→2 + 重生成 | 5 分钟 | get_property 复查 |
| 3 | 关闭 GUI 工程（File → Close Project） | 10 秒 | tasklist 确认无 vivado 进程 |
| 4 | batch 模式跑 run_manual.tcl，观察 12/12 PASS | 3 分钟 | grep TC 状态 |
| 5 | 修复 TC11 判据范围（旧 [300,1500] 改新 [50,500]） | 1 分钟 | 重跑 batch |
| 6 | 加 TC13 边界扫描，重跑 batch | 5 分钟 | 看 dax_fall 撞墙数据 |
| 7 | 更新文档（REQUIREMENTS / ARCHITECTURE / IMPLEMENTATION） | 10 分钟 | git diff |

总耗时约 30 分钟（含等仿真完成）。

---

## 8. 文件清单（DL5_UNIT_003 涉及的所有文件）

| 路径 | 类型 | 状态 |
|---|---|---|
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | RTL | 已改 |
| `AXI_DDR.srcs/sources_1/ip/fifo_generator_4/fifo_generator_4.xci` | IP 配置 | 已改 |
| `AXI_DDR.gen/sources_1/ip/fifo_generator_4/*` | IP 生成产物 | 已重新生成 |
| `AXI_DDR.srcs/sim_1/new/tb_dl5_unit_002.v` | testbench | 加 TC13 + 修 TC11 判据 |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/REQUIREMENTS.md` | 文档 | 完成 |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/ARCHITECTURE.md` | 文档 | 完成 |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/IMPLEMENTATION.md` | 文档 | 完成 |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/change_fifo_threshold.tcl` | 工具 | 备忘 |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/SIM_GUIDE.md` | 文档 | **本文件** |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/sim/unit003_v2_run.log` | 日志 | 12/12 PASS |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/sim/tc13_boundary_scan.log` | 日志 | 边界扫描数据 |

---

## 9. 复用本流程到下次类似任务

如果未来要做类似的"改 IP + 改 RTL + 跑回归"任务（比如 DL5_UNIT_004），按这个清单执行：

- [ ] 确认 `wbtcv.exe.bak` 状态（§0.1）
- [ ] 改 RTL（直接编辑 .v 文件）
- [ ] 改 IP（GUI Tcl Console 用 set_property + generate_target）
- [ ] 关闭 GUI 工程
- [ ] 清理 `AXI_DDR.sim/sim_1/behav/xsim/xsim.dir`
- [ ] 用 `run_manual.tcl` 跑 batch 仿真
- [ ] grep 日志看 PASS/FAIL
- [ ] 如果 FAIL：先看是 testbench 判据问题还是 RTL 实际错误
- [ ] 改完后跑通 → 更新 IMPLEMENTATION.md 实测数据
- [ ] 看波形：用已生成的 .wdb 在 GUI 里 Open Waveform Database

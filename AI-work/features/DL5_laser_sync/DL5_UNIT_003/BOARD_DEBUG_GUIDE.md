# DL5_UNIT_003 上板调试指南

> 配套文档：[REQUIREMENTS.md](REQUIREMENTS.md) | [ARCHITECTURE.md](ARCHITECTURE.md) | [IMPLEMENTATION.md](IMPLEMENTATION.md)
>
> 本文档整理 DL5_UNIT_003（FIFO 水位延迟优化）硬件部署和上板调试的完整路线。

---

## ★ 上板调试实录与结论（2026-06-03，已闭环）

**最终状态**：DL5 激光同步功能在真实硬件上完整验证通过。普通模式 DAC 扫描正常，
激光模式由真实 D15 laser 驱动，TRIG_BLANK / TRIGGER_OUT 有输出，所有延迟指标与仿真吻合。

调试过程定位到**两个独立问题**，对后续上板有重要参考价值：

### 问题 A：host-app 漏写 DAC 扫描几何寄存器（普通模式 DAC 也无输出）

- **现象**：blanker 无输出，深挖发现普通模式 DAC 也无波形。
- **对照实验**：能工作的旧上位机 + 同一 bitstream → DAC 有波形；host-app + 同一 bitstream → 无波形。锁定问题在 host-app。
- **根因**：`AI-work/host-app` 的 `ScanConfig.to_registers()` 只写 `0x0001/0x0002/0x0004/0x0009`，
  **从不写 `0x0005`(dacx 范围)/`0x0006`(dacx 点数)/`0x0007`(dacy 范围)/`0x000F`(回扫时间)**。
  关键：FPGA 只在**写 `0x0006`** 时脉冲 `dacx_step_flag` 触发除法器重算 `dacx_step`
  （见 `command_monitor_new.v` 0x0006 分支 + `dax_step_module`）。host-app 不写 0x0006 →
  `dacx_step` 保持复位值 → DAX 恒 0x8000 → 示波器一条直线。旧上位机因为写了完整几何而正常。
- **修复**：`scan.py` 给 `ScanConfig` 加 X/Y 几何字段（固定内置默认值，取自已验证可出波形的板上配置），
  `to_registers()` 产出 `0x0005/0x0006/0x0007/0x000F`，`0x0009` 仍在末尾。`normal/ultrafast/laser`
  三模式共用 `_scan_items()` 一并修复。21 单测全过。
- **教训**：host-app 的 mode 计划必须覆盖"重新上电后 DAC 扫描所需的全部参数"，
  尤其任何"写入即触发硬件重算"的寄存器（`0x0006`→dacx_step、`0x0004`/`0x0007`→dacy_step）必须显式写。

### 问题 B：D15/laser_sync_in 外部输入无信号（板级硬件）

- **现象**：问题 A 修复后普通模式 DAC 正常，但激光模式 blanker 仍无输出；示波器在 D15 连接器看到 500kHz/20%/3.3V，但 ILA 显示 FPGA 内部 `laser_sync_in` 恒 0、状态机卡在 State 14。
- **逐层隔离**：
  1. RTL 内部注入 500kHz 脉冲（dacdata_config 或顶层 mux）→ 同步器/State14/laser_toggle/CDC/blanker/acq/DAX 全部正常。
  2. 约束验证（`ETH_TOP_io_placed.rpt`）：D15→bank15(HR)/INPUT/LVCMOS33/Pull=NONE，IBUF 正确。
  3. VCCO 排除：同 bank 15 的 `pll_ld`/`pll_sdo`/`dac_sdo`/`UART_RX` 等 INPUT 都正常工作 → bank 供电 + IBUF 机制正常。
  4. **铁证测试**：顶层加 `ila_5 ila_top_trig` **直抓 `TRIGGER_IN_IBUF`**（IBUF 输出，FPGA 能观测的最前端）。
     实测：内部注入对照脉冲 33 个完美上升沿，但 `TRIGGER_IN_IBUF` 8192 采样**全 0**。
     → laser 信号根本没进到 FPGA，问题在 D15 球脚之前的板级物理层。
- **修复**：用户修复板级硬件后，复测 `TRIGGER_IN_IBUF` = 500kHz/20% 占空比/2µs 周期，与信号源精确吻合。
- **教训**：示波器高阻探头在连接器看到 3.3V，不代表信号能驱动 FPGA 输入；
  排查"引脚无信号"时，ILA 直抓 IBUF 输出是区分"RTL/约束问题"vs"板级问题"的决定性手段。

### 上板实测延迟指标 vs 仿真（全部吻合）

| 指标 | 仿真（IMPL §4~6） | 上板实测 |
|---|---|---|
| acq 脉宽 | acq_time×20ns=500ns | 500ns ✅ |
| blanker 脉宽 | blanker_time×5ns=500ns | 500ns ✅ |
| laser→DAX（TC11） | 274ns | ~256ns ✅ |
| 跨行延迟（TC13, dax_fall=5µs） | 48ns | 20ns ✅ |
| FIFO 水位地板 | 阈值=2 | 79.9% 时间 prog_empty=1 ✅ |

> 详细波形分析见 [IMPLEMENTATION.md §7b](IMPLEMENTATION.md)。原始 ILA 数据在 `out/hw_debug/`。

---

## 0. 前置条件检查清单

上板前必须确认以下项目：

- [x] RTL 改动完成：parameter_dacdata_gen.v（State 2 + State 13 C3-lite）
- [x] IP 改动完成：fifo_generator_4 阈值 20→2 并重新生成
- [x] 仿真验证通过：TC1~TC13 全 PASS（见 [IMPLEMENTATION.md §4~§6](IMPLEMENTATION.md)）
- [x] **实现后时序通过**：synthesis WNS = -0.622 ns，routed WNS = 0.091 ns / WHS = 0.052 ns（见 §1）
- [ ] **时序约束完整**：eth_clk / ui_clk / dac_dco / adc_dco 的 CDC 路径都有约束
- [x] **laser_sync_in 引脚约束**：复用 `TRIGGER_IN` / D15 / LVCMOS33（见 §2）
- [x] **bit 文件生成**：2026-06-03 多轮生成验证通过；正式版（清理调试 ILA 后）见 §★ 实录
- [x] **上位机 DL5 模式就绪**：host-app CLI/GUI 支持激光模式配置；2026-06-03 修复扫描几何寄存器漏写 bug（见 §★ 实录 问题 A）
- [x] **上板功能验证（L0~L8）**：2026-06-03 真实 D15 laser 驱动下全部通过（见 §★ 实录）

---

## 1. 综合 / Implementation 时序状态（2026-06-02 复测完成）

**综合运行**：2026-06-02 16:22:32 ~ 16:26:28
```bash
vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_synthesis.tcl
```

**Implementation 运行**：2026-06-02 16:50:47 ~ 17:03:15
```bash
vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_implementation.tcl
```

**报告位置**：
- 综合：`AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/synth/`
- 实现：`AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/impl/`

**当前结论**：
- `synth_design` 完成，0 ERROR / 0 CRITICAL WARNING。
- synthesis timing 中 WNS = -0.622 ns，TNS = -0.622 ns，1 个 setup failing endpoint；这是布局布线前估算。
- `impl_1` 已跑到 `route_design Complete!`，0 ERROR / 0 CRITICAL WARNING。
- routed timing 通过：WNS = 0.091 ns，TNS = 0.000 ns，0 setup failing endpoint；WHS = 0.052 ns，THS = 0.000 ns，0 hold failing endpoint。
- synthesis 阶段最差路径 `U6/N1/step_count_reg[15]/C` → `U6/N1/day_level_reg[63]/D` 已被 implementation 收敛；可继续生成 bitstream。
- DRC 未再命中 `laser_sync_in` / `NSTD-1` / `UCIO-1`；D15 / `TRIGGER_IN` 复用已消除旧引脚约束问题。
- routed DRC 仍有 pre-existing warning（RAMB async control、DSP pipelining、`adc*_sdio` IO buffer），与本次 `laser_sync_in` 复用无直接关系。
- bus skew routed report 全部有正 slack。

**验收标准**：
- routed WNS (Worst Negative Slack) ≥ 0（所有时钟域）
- routed WHS (Worst Hold Slack) ≥ 0
- 资源增量 < 0.1%（新增仅 3 个寄存器：s2_write_cnt 2-bit + s13_wait_cnt 1-bit）
- 0 CRITICAL WARNING（或与 DL5 无关的 pre-existing warning）

**基线数据**（5/22 DL5_UNIT_001，见 LOG.md）：
- LUT 31.94%，Reg 27.19%，IOB 70.50%，BRAM 89.89%，DSP 1.90%

**如果综合失败**：
1. 检查 `AXI_DDR.runs/synth_1/runme.log`，定位 ERROR 行
2. 常见问题：
   - CDC 路径 timing violation → 增加 false_path / set_max_delay 约束
   - fifo_generator_4 IP 未重新生成 → 手动在 GUI 重新 generate_target Synthesis
   - parameter_dacdata_gen.v 语法错误 → xvlog 阶段就会报错

---

## 2. laser_sync_in 引脚约束（已复用 TRIGGER_IN）

**当前状态**：[OPEN-QUESTIONS.md Q19](../../../OPEN-QUESTIONS.md) 已关闭。

复用现有 `TRIGGER_IN` 物理输入：

```tcl
set_property PACKAGE_PIN D15 [get_ports TRIGGER_IN]
set_property IOSTANDARD LVCMOS33 [get_ports TRIGGER_IN]
```

模式语义：
- 普通模式 / 超快模式：D15 仍作为 `TRIGGER_IN`，用于外部行触发。
- 激光模式：D15 进入 `laser_sync_in` CDC 链路，作为外部 laser sync 输入；普通行触发在 RTL 内屏蔽。

硬件接线要求：激光器 sync 输出接 D15 对应的板级接口，电平需与 `LVCMOS33` / bank VCCO 匹配。

---

## 3. 生成 bit 文件（当前下一步）

当前状态：`impl_1` 已经到 `route_design Complete!`，routed timing 通过。除非 RTL / XDC / IP 又发生改动，否则不需要重新从综合开始；下一步直接从现有 `impl_1` 继续执行 `write_bitstream`。

### 3.1 batch 模式（推荐）

先创建输出目录，避免 Vivado 启动时打不开 `-log/-journal` 路径：

```powershell
New-Item -ItemType Directory -Force `
  AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/bitstream
```

然后执行：

```powershell
& 'D:\Xilinx\Vivado\2021.1\bin\vivado.bat' -mode batch `
  -log AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/bitstream/run_bitstream.log `
  -journal AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/bitstream/run_bitstream.jou `
  -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_bitstream.tcl
```

脚本会检查 `impl_1` 状态，继续跑到 `write_bitstream`，并把生成的 bit 复制一份到 UNIT_003 输出目录。

### 3.2 GUI 模式

1. 打开 Vivado GUI：`File → Open Project → AXI_DDR.xpr`
2. 确认 `impl_1` 已是 `route_design Complete!`
3. Flow Navigator → `Generate Bitstream`
4. 生成后检查 `AXI_DDR.runs/impl_1/runme.log`，确认没有 ERROR

### 3.3 bit 文件位置

Vivado 原始输出：

```text
AXI_DDR.runs/impl_1/ETH_TOP.bit
```

UNIT_003 归档副本：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/bitstream/ETH_TOP_unit003.bit
```

### 3.4 bitstream 验收标准

- `impl_1 STATUS` 变为 `write_bitstream Complete!`
- `AXI_DDR.runs/impl_1/ETH_TOP.bit` 存在
- `out/bitstream/ETH_TOP_unit003.bit` 存在
- `run_bitstream.log` 中无 ERROR

---

## 4. 烧录 bit 文件到 FPGA

### 4.1 工具准备

- Vivado Hardware Manager（推荐，Vivado 自带）
- 或 iMPACT（老版本）
- JTAG 下载器：Xilinx Platform Cable USB II 或兼容型号

### 4.2 烧录步骤（Vivado Hardware Manager）

1. 连接 JTAG 下载器到 PC 和 FPGA 板
2. 打开 Vivado GUI → `Flow Navigator → Program and Debug → Open Hardware Manager`
3. `Open Target → Auto Connect`
4. 右键 FPGA 设备（如 `xc7k325t_0`）→ `Program Device`
5. 选择 `AXI_DDR.runs/impl_1/ETH_TOP.bit`
6. 点击 `Program`

烧录成功后 FPGA 立即开始运行新固件。

### 4.3 验证烧录成功

- **DONE LED** 亮（FPGA 配置完成）
- **以太网 PHY LINK LED** 亮（网络正常）
- 上位机能 ping 通 FPGA IP（如 `192.168.1.10`）

---

## 5. 上板调试策略

### 5.1 分阶段验证

| 阶段 | 测试内容 | 成功标准 | 失败时定位 |
|---|---|---|---|
| **L0 基本连通** | ping FPGA IP | 能 ping 通 | 检查网线、PHY、FPGA 供电 |
| **L1 寄存器读写** | 上位机读 `0x000A`（版本号） | 返回预期值 | 检查 UDP 端口、command_monitor_new.v |
| **L2 普通模式不受影响** | 跑普通扫描（`laser_mode_en=0`），采集一帧 | ADC 数据正常，DAC 扫描正常 | RTL 改动破坏了普通模式分支（回滚 parameter_dacdata_gen.v） |
| **L3 激光模式基础** | 写 `0x0205=1`（激光模式使能），读回确认 | 读回 `0x0205=1` | 寄存器写逻辑问题 |
| **L4 激光输入信号** | 用信号发生器输入 2µs 周期方波到 `laser_sync_in` | ILA 抓到 `laser_sync_in` 翻转 | 引脚约束错误 / 信号未接入 |
| **L5 blanker/acq 输出** | 触发激光输入，示波器看 `TRIG_BLANK`（blanker）和 `TRIGGER_OUT`（acq） | 延迟符合 `0x0207`（blanker_delay）和 `0x0209`（acq_delay），脉宽符合 `0x0208` / `0x020A` | CDC 路径问题 / 状态机卡死 |
| **L6 DAC 坐标切换** | 配置 DL5 参数，触发激光，示波器看 DAC_X 输出 | 激光后 ~80ns 切到新坐标 | FIFO 路径问题 / State 16 未触发 |
| **L7 行末跨行延迟** | 跑完一行，立刻触发下一个激光 | DAC_X 延迟 < 200ns（实测应 ~48ns） | State 13 限速未生效 / FIFO 积压 |
| **L8 参数边界** | 先只跑 dax_fall=1µs；需要边界时再扫 {1, 2} µs | 全部跨行延迟 < 200ns | C3-lite 未生效 |
| **L9 小帧采集** | 先跑 16×16 激光同步扫描，确认后再放大 | 图像无撕裂、坐标对齐 | 系统级时序问题 |

### 5.2 关键寄存器操作（上位机 CLI 命令示例）

假设上位机 CLI 已实现（见 [HOST_APP_ARCHITECTURE.md](../../../host-app/HOST_APP_ARCHITECTURE.md)）：

> 推荐先用小参数冒烟：`rows=16`、`cols=16`、`adc/dac_sample=4`。
> `0x0006=0x00100005` 表示 `dacx_tk_point/tb=16`、`dacx_recovery_time=5`；
> `0x000F=1` 表示 `dax_fall_time=1µs`。
> 激光模式小参数：`scan_delay=2`(16ns)、`blanker_delay=10`(50ns)、`blanker_time=20`(100ns)、`acq_delay=5`(100ns)、`acq_time=5`(100ns)。
> 注意：当前 CLI 的 `mode ... apply` 会用默认值写一次 `0x0006/0x000F`，所以下面示例采用“apply 不启动 → 覆盖小 tb/fall → start”的顺序。

```powershell
# L1: 读版本号
fpga-host version --json
fpga-host read 0x000A --json

# L2: 普通扫描（不开激光模式，小参数）
fpga-host mode normal apply --rows 16 --cols 16 --adc-sample 4 --dac-sample 4 --adc-channel 4 --scan-mode 1 --yes --json
fpga-host write-checked 0x0006 0x00100005 --yes --json
fpga-host write-checked 0x000F 1 --yes --json
fpga-host start --scan-mode 1 --yes --json

# L3: 使能激光模式
fpga-host write-checked 0x0205 1 --yes --json
fpga-host read 0x0205 --json  # 应返回 1

# L4~L8: 配置 DL5 小参数
fpga-host mode laser apply `
  --rows 16 --cols 16 --adc-sample 4 --dac-sample 4 --adc-channel 4 --scan-mode 1 `
  --laser-mode 1 --scan-delay 2 --blanker-delay 10 --blanker-time 20 --acq-delay 5 --acq-time 5 `
  --yes --json
fpga-host write-checked 0x0006 0x00100005 --yes --json
fpga-host write-checked 0x000F 1 --yes --json
fpga-host start --scan-mode 1 --yes --json

# L8: dax_fall 边界扫描（寄存器 0x000F，单位按 RTL 为 µs，内部 ×50）
fpga-host write-checked 0x000F 1 --yes --json
fpga-host write-checked 0x000F 2 --yes --json

# L9: 小帧激光同步扫描
fpga-host mode laser apply --rows 16 --cols 16 --adc-sample 4 --dac-sample 4 --adc-channel 4 --scan-mode 1 --laser-mode 1 --scan-delay 2 --blanker-delay 10 --blanker-time 20 --acq-delay 5 --acq-time 5 --yes --json
fpga-host write-checked 0x0006 0x00100005 --yes --json
fpga-host write-checked 0x000F 1 --yes --json
fpga-host start --scan-mode 1 --yes --json
```

> 注意：当前 host-app 已支持 DL4 控制面和 mock frame；真实 DL2 ADC 帧接收/保存尚未接入，因此 L9 的“保存 ADC 数据”需要后续补真实数据面，或临时使用现有板卡采集工具。

### 5.3 调试工具

**ILA（集成逻辑分析仪）**：
- 工程里已有 `ila_1`、`ila_2` 等 13 个 ILA IP
- 如果需要抓 `laser_sync_in` / `blanker_start` / FIFO 水位，需在 RTL 里添加 ILA probe 并重新综合

**推荐探测点**（如果 ILA 容量够）：
```verilog
// dacdata_config.v 或顶层
ila_laser_debug (
    .clk(ui_clk),
    .probe0(laser_sync_in),          // [0]
    .probe1(blanker_start),          // [1]
    .probe2(acq_start),              // [2]
    .probe3(current_state),          // [6:3] parameter_dacdata_gen state
    .probe4(para_config_wr_en),      // [7] FIFO 写使能
    .probe5(para_config_prog_empty), // [8] FIFO 地板标志
    .probe6(DAX_DATA),               // [24:9] DAC X 坐标
    .probe7(s2_write_cnt),           // [26:25] State 2 写计数
    .probe8(s13_wait_cnt)            // [27] State 13 等待计数
);
```

**示波器**：
- 必须测的信号：`laser_sync_in`（输入，2µs 周期）、`TRIG_BLANK`（输出，blanker）、`TRIGGER_OUT`（输出，acq）
- 可选：`DAC_X_OUT`（模拟输出，需高速示波器 + 探头带宽 ≥ 50MHz）

---

## 6. 常见问题与排查

### 6.1 综合后 WNS < 0（implementation 可收敛）

**现象**：2026-06-02 综合后 `timing_summary.rpt` 显示 WNS = -0.622 ns，但 implementation routed timing 收敛到 WNS = 0.091 ns。

**根因**：
- 综合阶段的最差路径不是 CDC 约束问题，而是 `clkout0` 域内的 `U6/N1` 组合链路较长。
- 具体路径为 `step_count_reg[15]` → `day_level_reg[63]`，对应 `parameter_dacdata_gen.v` 中 `step_count*dacy_step` / `day_level` 计算链路。
- 报告显示 2 个 DSP48E1、8 个 CARRY4、16 级逻辑，data path delay = 8.436 ns，超过 8.000 ns requirement。
- 该路径在 place/route 后通过物理布局和布线优化收敛，最终 routed timing 为正。

**处理建议**：
如果 routed timing 仍为负，再处理 `parameter_dacdata_gen.v` 的乘加链路，推荐把 `step_count*dacy_step` 相关计算拆成流水/预计算，避免在单个 `clkout0` 周期内完成 DSP 级联 + 宽加法。当前 routed timing 已通过，暂不需要为这条路径改 RTL。

### 6.2 上板后 ping 不通

**排查**：
1. 检查网线（换一根试试）
2. 检查 PC 和 FPGA 是否在同一子网（如 PC=192.168.1.100，FPGA=192.168.1.10）
3. 检查 FPGA 供电（+3.3V / +1.0V 核心电压）
4. 重新烧录 bit 文件

### 6.3 寄存器读写失败（返回全 0 或超时）

**排查**：
1. 上位机 UDP 端口是否正确（32000）
2. FPGA 端口是否被占用（`command_monitor_new.v` 监听 32000）
3. 用 Wireshark 抓包，看 UDP payload 是否正确
4. 检查 `ETH_TOP.v` 里 `command_monitor_new` 例化的端口连接

### 6.4 激光输入无响应（blanker/acq 不触发）

**排查**：
1. 示波器确认 `laser_sync_in` 引脚有信号（2µs 周期，3.3V 高电平）
2. 检查 `fpga_pin.xdc` 引脚约束是否正确
3. ILA 抓 `laser_sync_in` 和 `blanker_start`，看是否进入 `laser_sync_blanker_ctrl` 状态机
4. 检查 `0x0205` 是否写 1（激光模式使能）

### 6.5 DAC 坐标切换延迟 > 200ns

**排查**：
1. 仿真验证 TC11/TC13 是否 PASS（如果仿真 PASS 但实测不 PASS，可能是时序违例）
2. ILA 抓 FIFO 水位（`para_config_data_count`），看是否在地板 2 附近
3. 检查 `fifo_generator_4` IP 的 `prog_empty` 阈值是否真的是 2（读 `AXI_DDR.srcs/sources_1/ip/fifo_generator_4/fifo_generator_4.xci`）
4. 如果阈值正确但延迟仍高，可能是 dac_output.v 读侧逻辑有 bug（与 UNIT_002 diff 对比）

### 6.6 行末跨行延迟仍 > 200ns（dax_fall ≥ 2µs 时）

**排查**：
1. 确认 C3-lite 代码是否生效：检查 `parameter_dacdata_gen.v` State 13 是否有 `s13_wait_cnt` 分支
2. ILA 抓 State 13 的 `para_config_wr_en` 和 `s13_wait_cnt`，看是否真的 3 拍/word（1 拍写，1 拍等待）
3. 如果 `wr_en` 在等待拍泄漏（= 每 word 写 2 次），回去检查 RTL 改动（见 [IMPLEMENTATION.md §6.4](IMPLEMENTATION.md#L304)）

### 6.7 普通模式扫描异常（DL5 改动破坏了原功能）

**现象**：`laser_mode_en=0` 时 DAC 不扫描 / ADC 数据错乱

**根因**：State 2 / State 13 的 `else` 分支（普通模式）被误改

**修复**：
对比 UNIT_002 和 UNIT_003 的 `parameter_dacdata_gen.v`，确认普通模式分支完全一致。

---

## 7. 上板调试检查清单

上板前打印这张清单，逐项勾选：

- [x] Implementation routed WNS ≥ 0（0.091 ns）
- [x] Implementation routed WHS ≥ 0（0.052 ns）
- [ ] bit 文件生成成功
- [x] laser_sync_in 复用 TRIGGER_IN/D15/LVCMOS33，无新增临时占位引脚
- [ ] JTAG 下载器连接正常
- [ ] FPGA 板供电正常（LED 亮）
- [ ] 网线连接 FPGA 和 PC
- [ ] PC 网卡配置为静态 IP（与 FPGA 同一子网）
- [ ] 上位机 CLI/GUI 已安装并能启动
- [ ] 信号发生器准备好（输出 2µs 周期方波，3.3V）
- [ ] 示波器准备好（≥ 4 通道，带宽 ≥ 100MHz）
- [ ] 备份当前 bit 文件（上板前保存一份 `ETH_TOP_unit003.bit`）

上板后按 §5.1 分阶段验证表逐级推进，每个阶段通过后再进下一个。

---

## 8. 下一步（当前执行路线）

当前工程已经完成 RTL 修改、仿真、综合和 routed implementation。下一步不要先改乘法路径，先按下面顺序推进：

1. **P0：生成 bitstream**
   - 执行 §3.1 的 `run_bitstream.tcl`
   - 通过后勾选 §0 / §7 的 “bit 文件生成成功”
   - 把 `ETH_TOP_unit003.bit` 作为本轮上板固件归档
2. **P1：烧录 FPGA 并做基础连通性**
   - 用 Vivado Hardware Manager 烧录 §3.3 的 bit 文件
   - 完成 §5.1 的 L0~L3：DONE LED、ping、寄存器读写、`laser_mode_en=1` 读回
3. **P2：验证 D15 / TRIGGER_IN 复用**
   - 普通模式 / 超快模式先确认原 `TRIGGER_IN` 行触发不受影响
   - 激光模式下把 laser sync 接到 D15，确认 `TRIG_BLANK` 和 `TRIGGER_OUT` 有响应
4. **P3：验证 DL5 关键指标**
   - 按 §5.1 L4~L8 看 `blanker/acq` 延迟、DAC_X 切换延迟、行末跟行延迟
   - 重点确认 DAC_X 切换是否满足 < 200ns
5. **P4：先跑小帧**
   - 先跑 16×16 激光同步扫描，不直接上 512×512
   - 小帧稳定后再逐级放大到 32×32、64×64 或实际目标尺寸
   - 保存 ADC 数据，检查图像是否有撕裂、错行、坐标跳变

如果上板后发现新问题，再按以下优先级处理：

1. **功能阻塞**：激光输入无响应 / DAC 不切换 / 采集数据全 0  
   先回滚到 UNIT_002 或 baseline 验证硬件链路，再仿真复现问题，修 RTL，重新跑 TC1~TC13。
2. **性能不达标**：延迟 > 200ns / 行间隔过长影响帧率  
   分析 ILA 波形定位瓶颈，再考虑 State 13 减 word 数或其他优化。
3. **边界情况异常**：小参数矩阵下（dax_fall=1~2µs / 16×16~64×64）异常
   补充 TC14 矩阵扫描，并在上位机增加参数校验。
4. **工程优化**：Q18（0x0200 case 重复 bug）、Q11（清理 .gitignore）等。

---

## 9. 联系方式与协作

- **硬件问题**（引脚定义、信号电平、JTAG）：找硬件工程师
- **RTL 问题**（状态机、FIFO、时序）：本文档 + IMPLEMENTATION.md
- **上位机问题**（网络、寄存器协议）：见 [HOST_APP_ARCHITECTURE.md](../../../host-app/HOST_APP_ARCHITECTURE.md)

上板调试过程中的实测数据、波形截图、ILA 抓取结果，请追加到本文档末尾或新建 `BOARD_DEBUG_LOG.md`。

---

## 附录 A：寄存器地址速查表（DL5 相关）

| 地址 | 名称 | 读/写 | 复位值 | 说明 |
|---|---|---|---|---|
| `0x0006` | `dacx_tk_point/dacx_recovery_time` | R/W | 1 | 高 16bit=`dacx_tk_point`，低 16bit=`dacx_recovery_time` |
| `0x0009` | `scan_control` | R/W | — | `{adc_interval, scan_mode, scan_state}`，低 4bit 为 start/stop 状态 |
| `0x000A` | `version_number` | R | — | 版本号 |
| `0x000F` | `dax_fall_time` | R/W | 20 | X 轴回扫斜坡时间；RTL 内部按 µs ×50 转 FIFO word |
| `0x0205` | `laser_mode_en` | R/W | 0 | 1=激光同步模式，0=普通模式 |
| `0x0206` | `scan_delay_time` | R/W | 0 | laser 后到 DAC 坐标写入的延迟，单位 8ns |
| `0x0207` | `blanker_delay_time` | R/W | 0 | blanker 延迟，单位 5ns |
| `0x0208` | `blanker_time` | R/W | 0 | blanker 脉冲宽度，单位 5ns |
| `0x0209` | `acq_data_delay_time` | R/W | 0 | acq 触发延迟，单位 20ns |
| `0x020A` | `acq_time` | R/W | 0 | acq 脉冲宽度，单位 20ns |

**单位换算**：
- `scan_delay_time`：寄存器值 × 8ns。
- `blanker_delay_time` / `blanker_time`：寄存器值 × 5ns。
- `acq_data_delay_time` / `acq_time`：寄存器值 × 20ns。
- `dax_fall_time`：上位机写 µs 值，RTL 内部 ×50 转成 20ns FIFO word 数。
- 当前没有独立 `laser_period` 寄存器；激光周期由接到 D15 / `TRIGGER_IN` 的外部 laser sync 输入决定。

---

## 附录 B：参考波形（仿真 TC11 期望）

```
时间轴 (ns):    0          76         274                 2000
                ┌──────────┬──────────┬───────────────────┬────────
laser_sync_in:  ──┐        │          │                   │
                  └────────┘          │                   │
                  (50ns 高脉冲)       │                   │
                                      │                   │
acq_start:      ────────────┐         │                   │
                            └─────────┘                   │
                            (76ns 延迟，500ns 宽)          │
                                      │                   │
DAX_DATA:       [dacx_strat]──────────┴───[dac_sample]────┘
                                      (274ns 延迟)
                                      
说明：
- laser → acq：76ns（独立 CDC 路径，不经 FIFO）
- laser → DAX 更新：274ns（含 warm-up 残留，单次切换路径 ~80ns）
- DAX 保持 dac_sample 直到 State 4 / State 14
```

---

**文档版本**：v1.0  
**创建日期**：2026-06-02  
**维护**：与 IMPLEMENTATION.md 同步更新

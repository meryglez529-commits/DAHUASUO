# Host App 对 DL5_UNIT_003 L0-L9 上板验证的支持度

> 结论：host-app 的 DL4 控制面可以支撑 L1-L8 的寄存器配置、读回和启动/停止；L0 需要系统 ping 配合；L4-L8 的最终判据需要 ILA/示波器；L9 的真实 ADC 帧接收/保存还未接入，目前只有 mock frame。

## 2026-06-03 重要修复：普通模式 DAC 无输出（host-app 漏写扫描几何）

**现象**：上板后激光模式 blanker 无输出；进一步排查发现普通模式 DAC 也没有波形。

**对照实验**：
- 能工作的旧上位机 + DL5 固件 → 普通模式 DAC 有波形。
- host-app（本工程）+ 同一 DL5 固件 → DAC 无波形（恒为 0x8000 中点）。
- 故障域锁定在 host-app，RTL/bitstream 均正常。

**根因**：`ScanConfig.to_registers()` 只写 `0x0001/0x0002/0x0004/0x0009`，从不写 DAC 扫描几何寄存器 `0x0005`（dacx 范围）、`0x0006`（dacx 点数/恢复）、`0x0007`（dacy 范围）、`0x000F`（回扫时间）。其中 **写 `0x0006` 是 FPGA 触发 `dacx_step` 除法器（`dacx_step_flag`）重算 X 步进的唯一时机**（见 `command_monitor_new.v` 的 `0x0006` 分支与 `dax_step_module`）。FPGA 重新配置后若 host-app 不写 `0x0006`，`dacx_step` 保持复位/未计算值，状态机虽在 State 3↔4 正常循环，但 `dax_level += dacx_step(=0)`，导致 `DAX_DATA` 恒为 0x8000，示波器一条直线。旧上位机因为写了完整几何而正常。

**修复**：给 `ScanConfig` 增加 X/Y 几何字段（固定内置默认值，取自已验证可出波形的板上配置：dacx 0x1999~0xE665、dacy 0x3BBB~0xC443、recovery=50、fall=20、tk_point 默认跟随 cols），`to_registers()` 现产出 `0x0005/0x0006/0x0007/0x000F`，`0x0009` 仍保持在列表末尾。`normal/ultrafast/laser` 三个模式共用 `_scan_items()`，一并修复。21 个单测全部通过；硬件端到端 `mode normal apply` 全部寄存器写入 OK 并启动扫描。

**经验**：host-app 的 mode 计划必须覆盖"重新上电后 DAC 扫描所需的全部参数"，不能依赖板上残留值；尤其是任何"写入即触发硬件重算"的寄存器（如 `0x0006` → `dacx_step`、`0x0004`/`0x0007` → `dacy_step`）必须显式写入。


## 已验证的本地证据

- `D:\fpga_host_venv\Scripts\python.exe -m unittest discover -s tests`：21 tests PASS。
- `mode normal apply --mock --dry-run --json`：可生成普通模式写入计划，关闭 `0x020B` 激光模式，并支持读回确认。
- `mode laser apply --mock --dry-run --json`：可生成激光模式写入计划，按 `0x0206~0x020A` 写时序，最后写 `0x020B=1`，并支持读回确认。
- `dump --range dl5 --mock --json`：DL5 读回范围为 `0x0206~0x020B`。
- `data mock-frame --mock --json`：只生成 mock DL2 帧，不是真实板卡 ADC 数据。

## 上板实测状态（2026-06-03，修复扫描几何 bug 后）

- **L0~L3 历史上板通过**：ping/version 通，寄存器读写正常，普通模式 DAC 出波形；当时激光模式证据基于旧 `0x0205=laser_mode_en` 读回。当前 host-app 已按现行 RTL 写表迁移到 `0x020B=laser_mode_en`，该点如需闭环需重新上板确认。
- **L4~L7 上板通过**：真实 D15 laser（500kHz/20%）驱动下，ILA 实测 `laser_sync_in` 翻转、`laser_toggle` 翻转、状态机 14→15→16→4 循环；示波器 TRIG_BLANK 有输出；延迟指标与仿真吻合（见 `DL5_UNIT_003/IMPLEMENTATION.md §7b`）。
- **L8 上板通过**：dax_fall=5µs（最坏 case）跨行延迟实测 20ns。
- **L9 待补**：真实 DL2 ADC 帧接收/保存仍未实现。

## 支持度表

| 阶段 | host-app 支持度 | 可用能力 | 缺口 / 现场配合 |
|---|---|---|---|
| L0 基本连通 | 部分支持 | GUI 连接栏可做 UDP 版本读取和 `0x0009` 网络诊断；CLI 可 `version` | ICMP ping 用系统命令 `Test-Connection` / `ping` |
| L1 寄存器读写 | 支持 | `version` 读 `0x000A`；`read` / `write` / `write-checked`；GUI raw register console | 注意版本寄存器是 `0x000A`，不是 `0x0000` |
| L2 普通模式不受影响 | ✅ 上板通过 | `mode normal apply --start-after` 关闭激光/超快并启动普通扫描；**已补全扫描几何寄存器 `0x0005/0x0006/0x0007/0x000F`**，DAC 出波形 | “采集一帧 ADC 数据正常”需要真实 DL2 数据面或外部采集工具 |
| L3 激光模式基础 | ⚠️ 需按新地址复测 | 当前 host-app 使用 `0x020B` checked write；旧 `0x0205` 读回证据不再代表当前协议 | RTL 已补 `0x020B` 读回，仍需上板复测 |
| L4 激光输入信号 | ✅ 上板通过 | host-app 配激光模式并启动；真实 D15 laser 经 ILA 确认 `laser_sync_in` 翻转 | `laser_sync_in` 翻转最终判据靠 ILA/示波器 |
| L5 blanker/acq 输出 | ✅ 上板通过 | host-app 配 `0x0207/0x0208/0x0209/0x020A`；示波器实测 TRIG_BLANK 输出、blanker 脉宽 500ns | 延迟/脉宽精测用示波器/ILA |
| L6 DAC 坐标切换 | ✅ 上板通过 | host-app 配 DL5 并启动；ILA 实测 laser→DAX ~256ns（仿真 274ns） | — |
| L7 行末跨行延迟 | ✅ 上板通过 | ILA 实测 dax_fall=5µs 跨行延迟 20ns（仿真 48ns） | — |
| L8 参数边界 | 部分支持 | 可用 raw register 写 `0x000F` 扫描 dax_fall；DL5 参数可 CLI/GUI 配置 | 目前没有自动 sweep + 记录脚本 |
| L9 完整帧采集 | 不完整 | 可配置 512×512 并启动激光同步扫描；有 `data mock-frame` | 真实 DL2 ADC 帧接收、解析和保存尚未实现 |

## 现场推荐命令

```powershell
# L0: 系统连通性
Test-Connection 192.168.1.8 -Count 4

# L1: UDP 控制面版本读取
fpga-host version --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --json
fpga-host read 0x000A --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --json

# L2: 普通扫描模式
fpga-host mode normal apply `
  --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 `
  --rows 128 --cols 128 --adc-sample 20 --dac-sample 20 --adc-channel 4 --scan-mode 1 `
  --yes --start-after --json

# L3-L7: 激光同步模式
fpga-host mode laser apply `
  --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 `
  --rows 512 --cols 512 --adc-sample 20 --dac-sample 20 --adc-channel 4 --scan-mode 1 `
  --laser-mode 1 --scan-delay 10 --blanker-delay 100 --blanker-time 100 --acq-delay 30 --acq-time 25 `
  --yes --start-after --json

# L8: dax_fall 边界，单位按 RTL 为 µs
fpga-host write-checked 0x000F 1 --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --yes --json
fpga-host write-checked 0x000F 2 --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --yes --json
fpga-host write-checked 0x000F 3 --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --yes --json
fpga-host write-checked 0x000F 5 --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --yes --json

# 停止扫描
fpga-host stop --host-ip 0.0.0.0 --fpga-ip 192.168.1.8 --yes --json
```

## 建议补齐项

1. 新增真实 DL2 数据接收/保存命令，例如 `fpga-host data capture --rows 512 --cols 512 --output frame.bin`。
2. 新增 L8 自动 sweep 脚本：循环写 `0x000F` 和 DL5 参数，记录每组示波器/ILA 测量结果。
3. GUI 的高级 raw register console 当前没有 REAL 操作确认，现场建议优先用模式工作台或 CLI `--yes` 路径。

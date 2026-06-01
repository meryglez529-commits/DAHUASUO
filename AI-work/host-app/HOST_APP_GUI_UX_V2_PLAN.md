# 上位机 GUI V2 以人为本改版方案

> 日期：2026-06-01
> 背景：用户试用第一版 GUI 后反馈，当前界面更像寄存器调试工具，不像面向使用者的上位机。
> 结论：V2 GUI 应以“普通 / 超快 / 激光”三种工作模式为主入口，寄存器地址输入只保留在高级调试区。

## 1. 问题判断

当前 GUI 的问题不是功能缺失，而是信息架构站错了视角。

第一版 GUI 的视角：

```text
连接
寄存器控制台
扫描参数
DL5 参数
日志
```

这对调试 FPGA/协议的人有用，但对真正操作上位机的人不够友好。用户关心的是“我要用哪种扫描方式、图像多大、采样多久、什么时候开始”，而不是“我要写哪个地址”。

V2 GUI 的视角应改成：

```text
选择工作模式
配置本模式需要的参数
检查安全条件
应用参数
开始/停止扫描
观察状态与结果
```

## 2. V2 设计原则

| 原则 | 说明 |
|---|---|
| 模式优先 | 主界面首先让用户选择普通、超快、激光三种模式 |
| 参数语义优先 | 用“图像行数、列数、采样点、激光延时”这种语言，不让用户输入寄存器地址 |
| 安全流程优先 | 改模式/关键参数时默认先 stop，再 apply，再 readback/标记风险，再允许 start |
| 状态可见 | 当前 real/mock、连接状态、FPGA version、scan running/stopped 要一直可见 |
| 高级功能隐藏 | 原始寄存器控制台保留，但放到“高级调试”，默认不作为主入口 |
| AI/CLI 不受影响 | GUI 改成人用，CLI 继续保留工程/AI 调试能力；二者仍共用 core |

## 3. 主界面结构

建议 V2 使用“工作台式”布局，而不是纯 tab 调试页。

```text
┌─────────────────────────────────────────────────────────────────┐
│ 顶部状态栏：连接模式 | FPGA IP | 本机 IP | version | scan 状态       │
├───────────────┬─────────────────────────────────┬───────────────┤
│ 模式选择       │ 当前模式参数区                    │ 运行与状态      │
│ ○ 普通扫描     │                                 │ Apply 参数      │
│ ○ 超快扫描     │                                 │ Start Scan      │
│ ○ 激光同步     │                                 │ Stop Scan       │
│               │                                 │ Readback/检查   │
├───────────────┴─────────────────────────────────┴───────────────┤
│ 底部日志：操作记录 / 写入计划摘要 / 错误 / timeout / readback      │
└─────────────────────────────────────────────────────────────────┘
```

主界面只暴露三类按钮：

| 按钮 | 意义 |
|---|---|
| `应用参数` | 把当前模式参数转换成寄存器写入计划并执行 |
| `开始扫描` | 启动当前模式扫描 |
| `停止扫描` | 停止扫描，任何时候可点 |

寄存器地址不在主界面出现。需要时提供“显示写入计划”按钮，只展示“将写入哪些底层寄存器”，不要求用户手填。

## 4. 三种模式定义

### 4.1 普通扫描

用户心智模型：按常规扫描路径输出 DAC 坐标并触发 ADC 采集。

普通模式应显示：

| UI 参数 | 底层含义 |
|---|---|
| 图像行数 | `image_row`，写入 `0x0004[31:16]` |
| 图像列数 | `image_column`，写入 `0x0004[15:0]` |
| 每点采样/停留点数 | `adc_sample` / `dac_sample`，当前硬件由 `0x0002` 同时设置 |
| ADC 通道 | `adc_channel`，写入 `0x0001[3:0]` |
| ADC 间隔 | `adc_interval`，写入 `0x0009[31:8]` |
| 扫描模式 | `scan_mode`，写入 `0x0009[7:4]`，默认保持已知可用值 |
| X/Y 起止电平 | `0x0005`、`0x0007`，可先放在“高级参数”折叠区 |

普通模式应用流程：

```text
Stop Scan
laser_mode_en = 0
ultrafast_mode = 0
写普通扫描参数
读回可读寄存器
等待用户 Start Scan
```

界面文案建议：

```text
普通扫描
适合常规 SEM 扫描和基础联调。该模式关闭超快和激光同步扩展。
```

### 4.2 超快扫描

用户心智模型：仍由 FPGA 自己推进扫描，但启用 ultrafast 分支，适合更快的扫描/采集路径。

超快模式应显示：

| UI 参数 | 底层含义 |
|---|---|
| 图像行数/列数 | 同普通模式 |
| 每点采样/停留点数 | 同普通模式 |
| ADC 通道 | 同普通模式 |
| ADC 间隔 | 同普通模式 |
| 超快模式开关 | `0x0202[0] = ultrafast_mode` |
| 超快行记录/行参数 | `0x0202[31:1] = ultrafast_line_rec` 的写入值来源 |
| 采集延时 | `0x0201 = adc_acq_delay`，当前不可读回 |
| 采集死区 | `0x0204 = acq_dead_time`，当前不可读回 |
| sync/触发延时 | `0x0203` 等扩展参数，可放高级折叠区 |

超快模式应用流程：

```text
Stop Scan
laser_mode_en = 0
写普通扫描基础参数
写 ultrafast 扩展参数
写 0x0202 打开 ultrafast_mode
对可读寄存器读回
对 0x0200~0x0204 标记“已发送，硬件不可读回确认”
等待用户 Start Scan
```

重要 UI 提醒：

```text
超快扩展寄存器 0x0200~0x0204 当前硬件不可读回，软件只能确认 UDP 已发送，不能确认硬件影子寄存器值。
```

界面文案建议：

```text
超快扫描
适合 ultrafast 分支联调。部分扩展参数当前不可读回，应用后请结合 ILA/采集结果确认。
```

### 4.3 激光同步扫描

用户心智模型：外部 laser_sync_in 决定像素推进，GUI 配置 laser 后 DAC/blanker/acq 的相对时序。

激光模式应显示：

| UI 参数 | 底层含义 |
|---|---|
| 图像行数/列数 | 同普通模式 |
| 每点采样/停留点数 | 同普通模式，仍影响每个像素写 FIFO 的长度/采样窗口配合 |
| ADC 通道 | 同普通模式 |
| Laser 模式 | `0x0205[0] = laser_mode_en` |
| Scan Delay | `0x0206 = scan_delay_time` |
| Blanker Delay | `0x0207 = blanker_delay_time` |
| Blanker Time | `0x0208 = blanker_time` |
| Acq Delay | `0x0209 = acq_data_delay_time` |
| Acq Time | `0x020A = acq_time` |

激光模式应用流程：

```text
Stop Scan
写 0x0205 = 0，先关闭 laser mode
写普通扫描基础参数
写 0x0206~0x020A 激光时序参数
写 0x0205 = 1，打开 laser mode
读回 0x0205~0x020A
等待用户 Start Scan
```

需要前端防呆：

| 防呆项 | 建议 |
|---|---|
| 模式切换 | 必须先 stop，不能 running 时切普通/超快/激光 |
| laser mode 打开顺序 | 必须先写时序参数，再打开 `0x0205` |
| 参数单位 | UI 显示“步进值”和“估算时间”两列，避免用户只看到裸数字 |
| acq/blanker 宽度 | 允许输入 0，但提示 0 表示关闭该窗口 |
| readback | `0x0205~0x020A` 必须全部读回一致，否则应用失败 |

界面文案建议：

```text
激光同步
适合外部 laser_sync_in 驱动像素推进。应用参数时会自动停止扫描、关闭 laser mode、写入时序、再打开 laser mode。
```

## 5. 顶部状态栏

顶部状态栏要一直可见，不随模式切换消失。

| 状态 | 显示 |
|---|---|
| 连接模式 | `MOCK` / `REAL`，real 模式用醒目颜色 |
| 本机 IP | 例如 `192.168.1.10:32000` |
| FPGA IP | 默认 `192.168.1.8:32000` |
| FPGA version | 读 `0x000A`，期望 `0x000300AC` |
| scan 状态 | 读/缓存 `0x0009[3:0]`，显示 stopped/running |
| 当前工作模式 | 普通 / 超快 / 激光 |

建议连接区只保留：

```text
Mock/Real 切换
本机 IP
FPGA IP
连接/读版本号
```

端口默认固定 32000，放到高级设置。因为普通用户不应该频繁改端口。

## 6. 参数组织方式

每个模式页都分成三层参数：

| 层级 | 显示方式 | 内容 |
|---|---|---|
| 常用参数 | 默认展开 | 图像尺寸、采样点、通道、模式核心时序 |
| 高级参数 | 折叠面板 | X/Y 起止电平、sync、dead time、行重复等 |
| 写入计划 | 默认隐藏，可展开 | 地址和值，只供调试/确认 |

这样既对人友好，也没有丢掉工程可追溯性。

## 7. 寄存器控制台的位置

寄存器控制台不应该消失，但不能再作为主界面。

建议放在：

```text
工具 -> 高级调试 -> 寄存器控制台
```

或者主界面底部的：

```text
Advanced / Debug
```

并加明确提示：

```text
该页面用于工程调试。普通使用请回到“普通 / 超快 / 激光”模式页。
```

寄存器控制台保留这些功能：

| 功能 | 说明 |
|---|---|
| raw read/write | AI/工程师调试 |
| write_checked | 验证某个地址读回 |
| dump basic/dl5 | 快速诊断 |
| copy CLI command | 把当前操作转成 CLI，方便 AI/脚本复现 |

## 8. GUI 和 CLI 的关系

GUI 面向人，CLI 面向 AI/脚本，但两者不应分裂。

V2 后 core 应增加三种模式配置对象：

```text
NormalModeConfig
UltrafastModeConfig
LaserModeConfig
```

GUI 调：

```text
device.apply_mode_config(config)
```

CLI 也可以对应扩展：

```text
fpga-host mode normal apply ...
fpga-host mode ultrafast apply ...
fpga-host mode laser apply ...
```

现有 CLI 命令可以保留兼容：

```text
fpga-host scan apply ...
fpga-host dl5 apply ...
fpga-host write/read ...
```

## 9. V2 代码改造计划

建议按这个顺序改，避免一下子重写全部 GUI。

| 阶段 | 内容 | 验收 |
|---|---|---|
| V2-P0 | 增加 `core/control/modes.py`，定义普通/超快/激光三个模式配置和写入计划 | 三种模式 dry-run 能生成正确计划 |
| V2-P1 | 改 GUI 主窗口布局：顶部状态栏 + 左侧模式选择 + 中间参数页 + 右侧运行控制 | GUI 默认不再显示寄存器地址 |
| V2-P2 | 实现普通模式页 | mock 下可 Apply/Start/Stop |
| V2-P3 | 实现超快模式页 | 可写 `0x0201~0x0204`，并显示不可读回风险 |
| V2-P4 | 实现激光模式页 | 自动 stop -> close laser -> write params -> enable laser -> readback |
| V2-P5 | 移动寄存器控制台到高级调试 | 主流程不需要手填地址 |
| V2-P6 | CLI 补 `mode normal/ultrafast/laser` | GUI/CLI 写入计划一致 |
| V2-P7 | 实板验证 | 三种模式分别能读版本、应用参数、start/stop |

## 10. 需要确认的问题

| 问题 | 当前建议 |
|---|---|
| 普通模式 `scan_mode` 默认值 | 先用当前硬件默认/已知可用值 `1`，实板验证后固化 |
| 超快模式用户需要哪些参数 | 先暴露 `ultrafast_line_rec`、`adc_acq_delay`、`acq_dead_time`，其它放高级 |
| 超快寄存器不可读回 | UI 明确提示“已发送但不可硬件读回确认” |
| 激光参数单位 | UI 同时显示寄存器步进值和换算后的时间；具体换算以 DL5 最新实现为准 |
| 是否保留 raw register tab | 保留，但放高级调试，不作为主流程 |

## 11. 推荐下一步

先不要急着继续在现有 GUI 上加按钮。下一步应先改 core，把“三种工作模式”的写入计划做出来并测试通过，然后 GUI 只是选择模式和填写参数。

推荐立即做：

```text
1. 新增 core/control/modes.py
2. 新增 tests/test_mode_plans.py
3. CLI 增加 mode ... --dry-run --json
4. GUI 再按模式重排
```

这样不会把“以人为本”的 GUI 又写回“寄存器表单”的老路。

## 12. 实现记录（2026-06-01 10:01）

本轮已按 V2 方案完成第一版可运行改造：

| 阶段 | 状态 | 说明 |
|---|---|---|
| V2-P0 | 已实现 | `core/control/modes.py` 已定义普通、超快、激光三种模式配置和写入计划 |
| V2-P1 | 已实现 | 主窗口改为顶部连接栏 + 模式控制页 + 高级调试页 + 底部日志 |
| V2-P2 | 已实现 | 普通扫描页可配置扫描参数、预览计划、应用参数、start/stop |
| V2-P3 | 已实现 | 超快扫描页暴露行记录、采集延时、采集死区、sync 参数，并标记不可读回项 |
| V2-P4 | 已实现 | 激光同步页按 stop -> close laser -> write timing -> enable laser 的计划执行 |
| V2-P5 | 已实现 | raw register console 已移到“高级调试”，默认主流程不要求用户输入寄存器地址 |
| V2-P6 | 已实现 | CLI 已补 `mode normal/ultrafast/laser apply`，与 GUI 共用 core 模式配置 |
| V2-P7 | 待实板验证 | 需要 FPGA 板连接后验证 version、三种模式 apply、start/stop |

验证命令：

```powershell
D:\fpga_host_venv\Scripts\python.exe -m unittest discover -s tests
D:\fpga_host_venv\Scripts\python.exe -m compileall -q src tests
D:\fpga_host_venv\Scripts\fpga-host.exe mode normal apply --mock --dry-run --json
D:\fpga_host_venv\Scripts\python.exe -c "from PySide6.QtWidgets import QApplication; from fpga_host.gui.main_window import MainWindow; app=QApplication([]); w=MainWindow(); print('GUI instantiate OK', w.windowTitle())"
```

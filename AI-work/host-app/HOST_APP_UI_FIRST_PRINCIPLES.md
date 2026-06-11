# 上位机 UI 第一性原理设计稿

> 日期：2026-06-01
> 目标：从“控制真实 FPGA/SEM 扫描系统”的本质出发，定义后续 GUI 的设计原则、信息架构和验收标准。
> 结论：这个上位机不是寄存器编辑器，也不是好看的普通桌面软件；它首先是一个仪器控制台。

## 1. 参考资料给我们的启发

本轮参考了工业 HMI、科学仪器软件、Windows 桌面应用和 Qt 工业界面的公开资料。它们的共同点不是某一种视觉风格，而是都在解决同一个问题：人在复杂机器前，如何少犯错、快判断、可追溯地完成任务。

| 来源 | 可借鉴点 | 对本项目的含义 |
|---|---|---|
| ISA-101 HMI 标准系列 | HMI 要提高安全、质量、生产率、可靠性；强调人本设计、显示结构、交互、培训、生命周期 | UI 要围绕操作者任务组织，不围绕 RTL 寄存器表组织 |
| FDA human factors guidance | 人因工程的目标是减少使用错误和伤害风险，并面向真实用户、用途、环境验证 | start/stop、模式切换、laser enable 这类动作要有防误操作设计 |
| Zurich Instruments LabOne | 科学仪器 UI 使用侧边工具/设置、主工作区、状态栏、告警和 command log，同时支持 API 控制 | GUI 给人操作，CLI/API 给 AI 和脚本操作，但二者必须共享同一套动作模型 |
| Microsoft Windows design basics | 桌面 UI 应清晰组织导航、命令和内容，用标准控件降低学习成本 | PySide6 Widgets 不需要炫技，应使用熟悉控件、清晰分组和稳定布局 |
| Qt 工业 HMI 建议 | 工业 HMI 要组件化、可扩展、长期可维护 | DL2/3 后续接入时，不能推翻当前 GUI；每个数据链路应作为可插拔模块扩展 |

参考链接：

- ISA-101 Series of Standards: https://www.isa.org/standards-and-publications/isa-standards/isa-101-standards
- FDA Applying Human Factors and Usability Engineering to Medical Devices: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/applying-human-factors-and-usability-engineering-medical-devices
- Zurich Instruments LabOne UI Overview: https://docs.zhinst.com/uhf_user_manual/functional_description/labone_overview.html
- Microsoft Windows App Design Basics: https://learn.microsoft.com/en-us/windows/apps/design/basics/
- Qt industrial HMI best practices: https://www.qt.io/software-insights/built-to-last-five-best-practices-for-building-reliable-industrial-hmis

## 2. 第一性原理

### 2.1 UI 的本质：把人的意图安全地翻译成硬件状态

用户真正想表达的是：

```text
我要普通扫描
我要超快扫描
我要激光同步扫描
我要图像大小是多少
我要采样窗口是多少
我要现在开始/停止
```

用户不应该直接表达：

```text
我要写 0x0009
我要写 0x0205
我要写 0x0202[0]
```

因此 UI 的第一层必须是“意图层”，不是“寄存器层”。寄存器层仍然存在，但属于高级调试和 AI/工程复现。

### 2.2 硬件状态不是天然可见的，UI 必须把不可见状态显性化

FPGA 内部状态、UDP 是否发送成功、write-only 寄存器是否真的生效，这些都不是人眼可见的。UI 必须把它们分成三类显示：

| 状态类型 | UI 表达 |
|---|---|
| 可读回确认 | 显示 verified/readback OK |
| 只可发送不可读回 | 显示 sent only / hardware readback unavailable |
| 未知或失败 | 显示 unknown/failed，并给下一步建议 |

这件事比颜色和布局更重要。一个漂亮但让人误以为“写入成功=硬件生效”的界面，是危险界面。

### 2.3 控制动作必须可逆，Stop 永远比 Start 更重要

这是仪器控制台，不是表单软件。任何时候都应该能看到并点击：

```text
停止扫描
断开/切回 mock
查看最后一次写入计划
回到已知安全模式
```

Start 可以需要前置条件，Stop 不应该需要复杂条件。

### 2.4 参数应该按物理语义组织，而不是按寄存器地址组织

普通用户的参数分组应是：

| 分组 | 例子 |
|---|---|
| 图像 | 行数、列数 |
| 采样 | 每点采样、ADC 通道、ADC 间隔 |
| 模式 | 普通、超快、激光 |
| 时序 | scan delay、blanker delay/time、acq delay/time |
| 高级 | sync width、dead time、行记录等 |

寄存器地址只应该出现在：

```text
高级调试
写入计划详情
日志/command log
CLI dry-run JSON
```

### 2.5 GUI 和 CLI 是同一个控制模型的两张皮

这个项目特别的一点是：人用 GUI，AI 用 CLI。二者不能各自实现一套逻辑。

正确结构：

```text
GUI mode button
CLI mode command
        ↓
ModeConfig
        ↓
ModeApplyPlan
        ↓
FpgaDevice
        ↓
DL4 transport
```

验收标准：GUI 里的一次“应用激光模式”，应能导出等价 CLI 命令；CLI 的 dry-run JSON，应能解释 GUI 的写入计划。

### 2.6 UI 不应隐藏复杂性，而应分层安放复杂性

复杂性不会消失。我们要避免两种错误：

1. 把复杂性全摊在首页，用户被寄存器和底层字段淹没。
2. 把复杂性全藏起来，出了问题无法调试。

正确做法是三层：

| 层级 | 面向谁 | 内容 |
|---|---|---|
| 操作层 | 日常使用者 | 模式、关键参数、start/stop、状态 |
| 工程层 | 调试者/用户进阶 | 写入计划、readback、时序高级参数 |
| 原始层 | AI/工程师 | raw register、dump、CLI 命令、日志 |

## 3. 推荐主界面结构

### 3.1 常驻顶部状态条

顶部不是装饰，而是“我现在连着什么、机器处于什么状态”的安全锚点。

建议字段：

| 字段 | 必要性 |
|---|---|
| MOCK/REAL | 必须醒目，避免误把真实硬件当 mock |
| FPGA IP / 本机 IP / 端口 | 必须常驻，便于实板排障 |
| FPGA version | 必须可一键读取 |
| 当前模式 | 必须显示普通/超快/激光 |
| Scan 状态 | stopped/running/unknown |
| 最后一次动作 | applied/start/stop/read failed 等 |

### 3.2 左侧模式导航

只放三种主模式：

```text
普通扫描
超快扫描
激光同步
```

DL2/3 后续接入后，不应和这三种控制模式混在同一级。建议后续增加顶部或左侧二级区域：

```text
控制
数据
维护
```

第一阶段先不要过度复杂化。

### 3.3 中间参数区

参数区按“常用 -> 高级 -> 写入计划”组织。

默认展开：

```text
图像行数
图像列数
每点采样
ADC 通道
ADC 间隔
当前模式核心参数
```

默认收起或弱化：

```text
sync width
sync delay
dead time
raw register address
```

### 3.4 右侧动作区

右侧只做动作，不堆参数。

建议顺序固定：

```text
预览写入计划
应用参数
开始扫描
停止扫描
```

其中“停止扫描”永远可见，视觉权重不能低。

### 3.5 底部日志与 command log

日志不是开发者自嗨，它是实板调试生命线。每次动作都应记录：

```text
时间
连接模式
模式
用户动作
寄存器写入计划摘要
readback 结果
错误原因
等价 CLI 命令
```

这能让用户、AI、后续测试报告在同一条证据链上说话。

## 4. 三种模式的 UI 定义

### 4.1 普通扫描

目标：稳定、默认、安全。

默认流程：

```text
Stop scan
Disable laser
Disable ultrafast
Apply scan params
Wait for user Start
```

UI 重点：

- 不出现 raw address。
- 显示“普通模式会关闭超快和激光扩展”。
- 应用后显示 readback OK 或失败地址。

### 4.2 超快扫描

目标：明确这是一个“寄存器写入可读回，但波形效果仍需外部观测”的工程模式。

默认流程：

```text
Stop scan
Disable laser
Apply scan params
Write ultrafast params
Enable ultrafast
Wait for user Start
```

UI 重点：

- 超快扩展参数单独成组。
- `0x0200~0x0205` 对应的项显示 write_checked 结果。
- 不用吓人，但要诚实标注不确定性。

### 4.3 激光同步

目标：保护启用顺序，减少误开 laser mode。

默认流程：

```text
Stop scan
Disable ultrafast
Apply scan params
Close laser mode
Write DL5 timing
Enable laser mode
Wait for user Start
```

UI 重点：

- laser enable 不应是散落的小 checkbox，而应是模式流程的一部分。
- 时序参数要成组显示。
- 后续可以增加简单时序图，但第一版先不要手画复杂图，避免和真实硬件不一致。

## 5. 防错规则

| 场景 | UI 应做什么 |
|---|---|
| real 模式下点击应用 | 顶部 REAL 醒目；关键动作写日志 |
| 从一种模式切到另一种模式 | 默认先 stop，再应用新模式 |
| 写入不可读回寄存器 | 标注 sent only，不显示 verified |
| 参数越界 | 控件层限制范围，core 再校验 |
| start 前未应用参数 | 显示“当前参数未应用”，建议先预览/应用 |
| UDP timeout | 不吞错误，显示本机 IP/端口和 FPGA IP/端口 |
| readback mismatch | 停在失败状态，不继续 start |

## 6. 视觉原则

本项目应走“安静、清楚、工程化”的视觉方向。

建议：

- 背景浅灰或白色，主要区域清晰分组。
- 颜色只用于状态：正常、警告、错误、real 模式。
- 不用大面积渐变、装饰卡片、夸张标题。
- 按钮文字短，动作固定位置。
- 数值输入框宽度稳定，不因内容跳动。
- 中文标签优先，必要时保留英文术语，如 `Scan Delay`、`Acq Time`。

## 7. 后续 DL2/3 扩展方式

DL2 接入后，主界面不应变成“大杂烩”。建议扩展为：

```text
控制页：普通/超快/激光，参数和 start/stop
数据页：帧接收、图像预览、丢包、保存
调试页：寄存器、dump、command log、网络诊断
维护页：DL3 remote update、版本、配置导入导出
```

DL2 的图像显示不应挤进控制参数区。控制和数据要互相可见，但不要混排。

## 8. 当前 GUI 的差距

现有 V2 已经走对方向，但还只是骨架。下一版建议补：

| 优先级 | 改进 |
|---|---|
| P0 | 参数 dirty 状态：改了参数但未应用时，start 前提醒 |
| P0 | 失败态：readback mismatch/timeout 后禁用 start，直到重新 apply 或 stop |
| P0 | 日志增加等价 CLI 命令 |
| P1 | 写入计划中增加寄存器地址的可展开详情，默认不展示地址 |
| P1 | 顶部 scan 状态从 `0x0009` 读回，而不是只用 GUI 内部缓存 |
| P1 | real 模式下增加“一键读版本 + 网络诊断” |
| P2 | 激光模式增加简洁时序预览图 |
| P2 | 配置 profile 保存/加载，记录常用参数组 |

## 9. UI 验收标准

一个新用户不懂寄存器，也应该能完成：

1. 打开软件后知道当前是 mock 还是 real。
2. 选择普通/超快/激光三种模式之一。
3. 填图像和采样参数。
4. 点“预览写入计划”知道软件准备做什么。
5. 点“应用参数”后知道哪些项已读回确认、哪些项仅发送。
6. 点“开始扫描”和“停止扫描”。
7. 出错时知道是网络、参数、readback，还是硬件不可读回限制。
8. 能把一次 GUI 操作交给 AI，用 CLI 复现。

如果做不到这 8 条，UI 就还没有真正“以人为本”。

## 10. 本轮落地记录（2026-06-01 10:47）

已将 P0/P1 中最影响实板安全和可复现性的部分先落到 GUI：

| 项目 | 状态 | 说明 |
|---|---|---|
| 参数 dirty 状态 | 已实现 | 参数、模式、ADC 通道、laser enable 改动后，参数状态变为“未应用” |
| Start 防误触 | 已实现 | 参数未应用或上次失败时禁用“开始扫描”，Stop 仍保持可用 |
| 失败态保护 | 已实现 | apply/start 失败后阻止继续 start，直到重新 apply 或 stop 处理状态 |
| 真实硬件确认 | 已实现 | REAL 模式下 apply/start 弹窗确认，stop 不弹窗 |
| scan 状态读回 | 已实现 | 通过读取 `0x0009` 显示 running/stopped/unknown |
| 等价 CLI 日志 | 已实现 | GUI apply/start/stop 会记录可复现的 `fpga-host ...` 命令 |
| 写入计划详情 | 已实现 | 默认隐藏寄存器地址，勾选“显示底层地址”后展开 |
| 网络诊断 | 已实现 | 顶部连接栏新增“网络诊断”，记录 endpoint、version、scan_control |

验证：

```powershell
D:\fpga_host_venv\Scripts\python.exe -m unittest discover -s tests
D:\fpga_host_venv\Scripts\python.exe -m compileall -q src tests
D:\fpga_host_venv\Scripts\fpga-host.exe mode normal apply --mock --dry-run --json
D:\fpga_host_venv\Scripts\fpga-host.exe mode laser apply --mock --dry-run --json --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60
```

GUI 行为小验证：

```text
initial_start_enabled False 参数状态: 未应用
after_apply_start_enabled True 参数状态: 已应用
after_dirty_start_enabled False 参数状态: 未应用
```

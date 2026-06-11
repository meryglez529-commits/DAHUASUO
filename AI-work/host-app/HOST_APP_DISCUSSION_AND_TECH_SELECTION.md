# 上位机开发讨论与技术选型

> 状态：技术栈第一轮已确定，尚未开始写上位机代码。
> 背景来源：`AI-work/guide/data-paths/DL4_REG_CONTROL_DEEP_READ.md`、当前 DL5 UNIT_002 需求、用户提出的第一版范围。
> 当前决策：Python Qt 路线，PySide6 优先，PyQt 作为兼容备选；第一版做 CLI 和 mock；第一阶段不打包 `.exe`；DL2 很快会接入，架构需要提前预留。
> 后续详细架构：`HOST_APP_ARCHITECTURE.md`。

## 1. 背景

当前 FPGA 工程是一套 SEM 扫描采集卡控制逻辑。FPGA 侧已有 DL4 寄存器控制链路：

```text
PC 上位机
  -> UDP 32000 寄存器包
  -> FPGA ETHERNET_TOP / ETH_LAN_RX
  -> WR_RD_REG_TOP / LAN_WR_REG
  -> command_monitor_new
  -> DL1 DAC 扫描、DL2 ADC 采集、DL3 remote、DL5 laser sync 等控制参数
```

我们现在要做的第一版上位机，不做完整采图、不做固件升级，先只做：

```text
寄存器控制台
参数配置
start/stop scan
DL5 激光同步参数配置
```

后续再扩展：

```text
DL2: ADC 数据接收、图像显示、保存
DL3: remote 固件升级、QSPI/multiboot 状态管理
```

## 2. 第一版上位机必须解决什么

第一版不是“好看的界面”优先，而是先把控制闭环做稳：

| 任务 | 为什么需要 |
|---|---|
| 选择/绑定本地网卡与 UDP 端口 | FPGA 接收逻辑要求 PC 侧源端口也为 32000 |
| 读版本号 | 用 `0x000A` 验证网络和 DL4 协议是否通 |
| 原始寄存器读写 | 调试时必须能手动读写任意地址 |
| 参数表单 | 避免用户手工拼 `0x0004 = {row,column}` 这种 32-bit 数据 |
| 写后读回确认 | DL4 写命令没有 ACK，必须靠读回做软件闭环 |
| start/stop scan | 扫描启停必须明确，避免改参数时 FPGA 仍在跑 |
| DL5 参数配置 | 配置 laser mode、scan delay、blanker、acq 时序 |
| 日志窗口 | 每次发包、收包、超时、重试都要可追踪 |

### 2.1 新增约束：GUI 给人用，CLI 给 AI/脚本用

用户补充了一个很重要的约束：这个上位机不是只给人点按钮，也要给 AI 和脚本稳定调用。

因此第一版应按“双入口、同核心”的方式设计：

```text
GUI: 给用户使用，负责可视化、表单、按钮、日志、误操作保护
CLI: 给 AI/脚本使用，负责可重复命令、自动化测试、批量读写、结构化输出
Core: 真正的 UDP 协议、寄存器模型、参数打包、校验逻辑只写一份
```

这个约束会直接影响技术选型。不是“先做一个 GUI，以后有空再补 CLI”，而是第一天就把底层能力放在独立核心库里，让 GUI 和 CLI 都调用它。

CLI 本身不难，难点不在命令行，而在是否提前分层：

| 设计方式 | 结果 |
|---|---|
| GUI 里直接写 socket 和寄存器逻辑 | 后面补 CLI 会痛苦，容易复制两套协议代码 |
| 先写 `RegisterClient` / `FpgaDevice` 核心库 | GUI 和 CLI 都只是外壳，CLI 很好做 |

所以第一版建议必须包含一个最小原生 CLI。它不需要漂亮，但要稳定、可脚本化、可输出 JSON。

## 3. FPGA 侧已经确定的协议约束

### 3.1 网络约束

| 项 | 当前值 |
|---|---|
| FPGA 默认 IP | `192.168.1.8` |
| FPGA 默认 MAC | `5C:85:7E:EE:00:00` |
| FPGA UDP 端口 | `32000` (`0x7D00`) |
| PC 本地 UDP 端口 | 建议绑定 `32000` |
| 读回端口 | FPGA 从 UDP `32000` 发回 |

关键点：上位机不要使用随机 UDP 源端口。FPGA 的 `ETH_LAN_RX` 过滤条件要求：

```text
目标 MAC == FPGA MAC
目标 IP  == FPGA IP
UDP 目标端口 == 32000
UDP 源端口   == 32000
```

### 3.2 Payload 格式

写寄存器，14 字节：

```text
55 55 AA AA 00 01 00 06 ADDR_H ADDR_L DATA_3 DATA_2 DATA_1 DATA_0
```

读寄存器，10 字节：

```text
55 55 AA AA 00 02 00 02 ADDR_H ADDR_L
```

读回响应，14 字节：

```text
55 55 AA AA 00 03 00 06 ADDR_H ADDR_L DATA_3 DATA_2 DATA_1 DATA_0
```

所有多字节字段都是大端，高字节先发。

### 3.3 写确认策略

DL4 写命令没有 ACK。因此上位机必须自己定义确认策略：

| 场景 | 策略 |
|---|---|
| 可读回寄存器 | 写后读同地址，比对值 |
| 不可读回寄存器 | 记录为“已发送，未闭环确认” |
| 启停扫描 | 写 `0x0009` 后读回 `0x0009` |
| DL5 timing 参数 | `0x0206~0x020A` 可读回，建议 `write_checked` |
| laser enable / sync 扩展 | `0x020B` laser enable 和 `0x0200~0x0205` sync/ultrafast 已补读回，建议全部 `write_checked` |

## 4. 技术选型要看哪些维度

用户不懂上位机时，可以先不用关心“语言流行不流行”，而看这些实际问题：

| 维度 | 解释 |
|---|---|
| 开发速度 | 多快能做出能跑的第一版 |
| 调试方便 | UDP、日志、寄存器表、临时脚本是否容易写 |
| UI 能力 | 表单、按钮、日志、图表、后续图像显示是否舒服 |
| 性能余量 | 未来接 DL2 图像 UDP 数据时是否扛得住 |
| 打包部署 | 能不能打包成用户双击运行的 `.exe` |
| 长期维护 | 后面加 DL2/DL3、改协议、多人维护是否顺手 |
| 工业仪器感 | 界面是否稳重、可靠、像仪器控制软件 |
| 授权/成本 | 是否需要商业授权、是否有 GPL 风险 |
| 团队能力 | 未来维护的人更熟哪种语言/生态 |
| AI 协作友好度 | AI 是否能通过 CLI、JSON、配置文件、mock 模式稳定参与开发和调试 |

## 5. 候选技术方案

### 5.1 Python + PySide6

一句话：最快做出第一版，最适合当前“协议还在演进、需要边调边改”的阶段。

| 项 | 评价 |
|---|---|
| 开发速度 | 很快 |
| UDP 调试 | 很方便，标准库 `socket` 就够 |
| UI | PySide6 可做成熟桌面界面 |
| 后续图像 | 可接 `numpy`、`pyqtgraph`、OpenCV |
| 打包 | 可用 PyInstaller 打包 `.exe`，但体积偏大 |
| 维护 | 对非软件团队较友好 |
| 风险 | 打包和环境管理需要规范；高帧率图像显示要提前设计 |

适合：

```text
第一版寄存器控制台
快速联调 FPGA
后续逐步接 DL2 图像显示
需要大量日志和调试工具
```

不太适合：

```text
极致工业级安装包
非常高帧率、低延迟图像处理
团队完全不能接受 Python 运行环境
```

我的当前倾向：第一版优先选它。

### 5.2 C# + WPF / WinUI

一句话：Windows 桌面软件的正统路线，长期产品化很舒服。

| 项 | 评价 |
|---|---|
| 开发速度 | 中等 |
| UDP 调试 | 很方便，`.NET` 网络库成熟 |
| UI | Windows 原生体验好 |
| 后续图像 | 可做，但高性能图像需要多花设计 |
| 打包 | 很适合交付 Windows `.exe` / 安装包 |
| 维护 | 如果团队熟 C#，长期很好 |
| 风险 | 前期写协议调试工具不如 Python 灵活 |

适合：

```text
明确只做 Windows
希望软件长期产品化
团队有人熟 C#/.NET
希望安装部署更规整
```

不太适合：

```text
需求还在快速变，想每天快速试错
主要开发者不熟 .NET
```

### 5.3 C++ + Qt

一句话：性能和跨平台都强，但开发成本最高。

| 项 | 评价 |
|---|---|
| 开发速度 | 慢 |
| UDP 调试 | 可以，但比 Python/C# 繁琐 |
| UI | Qt 很强 |
| 后续图像 | 性能最好，适合高吞吐 |
| 打包 | 可打包，Qt 依赖要处理 |
| 维护 | 需要 C++ 工程能力 |
| 风险 | 内存、线程、构建系统复杂，调试成本高 |

适合：

```text
后续 DL2 图像吞吐压力很大
需要长期工业软件
团队有 C++/Qt 经验
```

不太适合：

```text
第一版快速验证协议
团队主要精力在 FPGA，不想被桌面工程拖住
```

### 5.3.1 Qt 路线下的两个分支

用户当前倾向选择 Qt。这里需要区分两个概念：

| 路线 | 含义 | 优点 | 风险 | 建议 |
|---|---|---|---|---|
| Python + PySide6/PyQt | 用 Python 调 Qt 界面库 | 开发最快，CLI/mock/core 都容易写，AI 协作友好 | 打包体积偏大，极限性能不如 C++ | 如果第一版要快速闭环，优先考虑 |
| C++ + Qt | 原生 C++ Qt 桌面软件 | 性能和长期产品化最好，工业软件感强 | 开发、构建、调试成本更高 | 如果明确要长期产品化，且接受开发成本，可以选 |

当前已确认走 **PySide6/PyQt 这种 Python Qt 路线**。为了减少实现分叉，第一版建议以 **PySide6** 为主，PyQt 作为兼容备选；除非团队已有明确 PyQt 代码资产，否则不建议两套绑定同时维护。

不管选哪条 Qt 路线，架构都应保持一致：

```text
Qt GUI
CLI
共享 core
真实 UDP transport / mock transport
```

### 5.4 Electron

一句话：用网页技术写桌面软件，界面好做，但程序偏重。

| 项 | 评价 |
|---|---|
| 开发速度 | 中等偏快，如果熟 Web |
| UDP 调试 | Node.js 可做 |
| UI | 很强，前端生态丰富 |
| 后续图像 | 可做，Web canvas/WebGL 方便 |
| 打包 | 成熟，但安装包较大 |
| 维护 | 依赖前端工程体系 |
| 风险 | 对仪器控制来说有点重，实时性和长期稳定性要控制 |

适合：

```text
团队熟前端
希望 UI 很现代
未来有复杂配置页面和可视化
```

不太适合：

```text
只想做一个稳而轻的实验室控制台
不想维护前端构建链
```

### 5.5 Tauri + Web 前端 + Rust 后端

一句话：比 Electron 轻，技术上漂亮，但团队门槛更高。

| 项 | 评价 |
|---|---|
| 开发速度 | 中等偏慢 |
| UDP 调试 | Rust 很稳，但学习成本高 |
| UI | Web 技术，表现力强 |
| 后续图像 | 可做 |
| 打包 | 比 Electron 轻 |
| 维护 | 需要 Rust + 前端经验 |
| 风险 | 技术栈对 FPGA 团队可能偏陌生 |

适合：

```text
团队已经熟 Rust/Web
希望轻量现代桌面应用
```

不太适合：

```text
当前要快速和 FPGA 闭环
用户不想引入太多新技术
```

### 5.6 LabVIEW

一句话：传统仪器上位机路线，对实验室友好，但授权和代码管理要考虑。

| 项 | 评价 |
|---|---|
| 开发速度 | 如果熟 LabVIEW，会很快 |
| UDP 调试 | 支持 |
| UI | 仪器面板风格天然适合 |
| 后续图像 | 可做 |
| 打包 | 依赖 LabVIEW 运行环境/授权 |
| 维护 | 图形化工程多人协作不如文本代码 |
| 风险 | 商业授权成本；版本管理不如代码直观 |

适合：

```text
实验室已有 LabVIEW 生态
使用者习惯仪器面板
不要求开源/轻量部署
```

不太适合：

```text
希望 AI/文本代码持续协作
希望以后用 Git 清晰审查改动
```

### 5.7 MATLAB App Designer

一句话：适合算法和实验验证，不适合作为长期工业控制软件首选。

| 项 | 评价 |
|---|---|
| 开发速度 | 中等，如果已有 MATLAB 习惯 |
| UDP 调试 | 支持，但部署不轻 |
| UI | 可以做实验工具 |
| 后续图像 | MATLAB 处理图像方便 |
| 打包 | 依赖 Runtime，体积大 |
| 维护 | 更偏实验脚本/算法环境 |
| 风险 | 授权和部署成本 |

适合：

```text
算法验证
实验室临时工具
数据处理强依赖 MATLAB
```

不太适合：

```text
长期交付给普通操作员使用
希望轻量安装
```

### 5.8 GUI + CLI 共用核心

一句话：GUI 是人的操作台，CLI 是 AI 和脚本的操作台，两者共用同一套 FPGA 控制核心。

第一版 CLI 不需要做成大而全的系统，先覆盖最关键的闭环：

```text
fpga-host ping
fpga-host read 0x000A
fpga-host write 0x0004 0x04000400
fpga-host write-checked 0x0009 0x00000000
fpga-host start
fpga-host stop
fpga-host dl5 apply --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60
fpga-host dump --range basic --json
```

优点：

```text
协议先跑通
便于自动化测试
GUI 出问题时还能用 CLI 排查
AI 可以直接调用，不需要理解界面坐标和按钮
可以把每次操作保存成可复现命令
```

缺点：

```text
用户体验差
不能代替最终上位机
危险命令需要保护，例如 start/apply 参数必须支持 --dry-run 或 --yes
```

这个路线可以和 Python/PySide6 共存，而且非常适合 Python：同一套底层 `RegisterClient`，CLI 和 GUI 都调用它。CLI 可以先用标准库 `argparse` 实现，减少依赖；如果后续命令变多，再升级到 `Typer` / `Click`。

## 6. 方案对比表

| 方案 | 第一版速度 | 后续图像 | 打包交付 | 调试友好 | 长期产品化 | 总体建议 |
|---|---|---|---|---|---|---|
| Python + PySide6 | 高 | 中高 | 中 | 高 | 中 | Qt 快速闭环路线 |
| C# WPF/WinUI | 中 | 中 | 高 | 中高 | 高 | Windows 产品化推荐 |
| C++ Qt | 低 | 高 | 中高 | 中 | 高 | 用户当前倾向，适合长期产品化 |
| Electron | 中高 | 中高 | 中 | 中 | 中 | 熟 Web 时可选 |
| Tauri | 中 | 中高 | 高 | 中 | 中高 | 技术栈门槛较高 |
| LabVIEW | 中高 | 中 | 中 | 中 | 中 | 实验室已有生态才推荐 |
| MATLAB App | 中 | 中 | 低中 | 中 | 低中 | 算法验证可用 |
| GUI + CLI 共核心 | 高 | 取决于 GUI | 高 | 很高 | 第一版必须保留 |

## 7. 当前推荐路线

我的建议是：

```text
第一版：Python + PySide6/PyQt(Qt GUI) + 原生 CLI + mock + 共享核心库
实现优先级：PySide6 优先，PyQt 作为兼容备选
打包策略：第一阶段源码运行，不打包 .exe；稳定后再 PyInstaller
后续扩展：在同一套 core 上增加 DL2/DL3，DL2 需要提前预留结构
```

原因：

1. 用户已确认 Python Qt 路线，Qt 很适合做仪器类桌面控制台。
2. 上位机必须同时给人和 AI 使用，所以 GUI 与 CLI 要共享 core。
3. PySide6/PyQt 第一版开发快，AI 协作、CLI、mock 模式都顺。
4. 第一阶段不打包 `.exe`，可以减少部署问题，把精力放在 DL4 控制闭环和 DL5 参数配置。
5. 早期最重要的是把 FPGA 控制闭环跑稳，而不是先做复杂安装包。

### 7.1 第一版 CLI 草案

第一版 CLI 的目标不是替代 GUI，而是让协议、寄存器和参数配置变成可复现、可测试、可由 AI 调用的命令。

建议命令形态：

```text
fpga-host ping
fpga-host version
fpga-host read 0x000A
fpga-host write 0x0009 0x00000000
fpga-host write 0x020B 0x00000001
fpga-host stop
fpga-host start
fpga-host scan apply --rows 1024 --cols 1024 --adc-sample 20 --dac-sample 20 --mode 0
fpga-host dl5 apply --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60
fpga-host profile load configs/test_scan.json --dry-run
fpga-host dump --range dl5 --json
```

CLI 必须支持这些工程特性：

| 特性 | 原因 |
|---|---|
| `--json` | AI/脚本可稳定解析，不依赖人眼读日志 |
| `--dry-run` | 先展示将要写哪些寄存器，避免误操作 |
| `--yes` | 对 start、DL5 apply 等危险命令做显式确认 |
| `--timeout-ms` / `--retries` | 现场网络问题可调 |
| `--host-ip` / `--fpga-ip` / `--port` | 多网卡和不同板卡环境可切换 |
| `--mock` | 没有 FPGA 板卡时，AI 也能开发 GUI、CLI 和参数校验 |

内部结构建议：

```text
host_app/
  core/
    protocol.py        # payload encode/decode
    register_client.py # UDP read/write/write_checked
    register_map.py    # 地址、字段、读写能力
    device.py          # scan/dl5/start/stop 高层动作
  cli/
    main.py            # argparse/Typer 命令入口
  gui/
    main_window.py     # PySide6 界面
```

这样 CLI 很好开发，因为 CLI 只负责解析参数、调用 core、打印结果。真正难的 UDP、寄存器打包、读回确认都在 core 里，只写一次。

### 7.2 CLI-Anything 的定位

`HKUDS/CLI-Anything` 的目标是把软件变成更适合 AI Agent 操作的命令行接口，并提供 CLI-Hub 一类的安装/管理方式。

对我们这个项目，建议定位如下：

| 阶段 | 建议 |
|---|---|
| 第一版 | 不依赖 CLI-Anything，先写项目自己的原生 CLI |
| core/CLI 稳定后 | 评估是否把 `fpga-host` 包装成 CLI-Anything 风格的 agent-ready 工具 |
| 后续扩展 | 如果要让不同 AI 工具统一发现、安装、调用上位机能力，再接 CLI-Anything |

原因是：我们第一版最关键的是把 FPGA DL4 协议闭环做稳。原生 CLI 的成本很低，而且能马上服务 GUI、AI 和测试。CLI-Anything 更像后续“把已有 CLI 标准化给 Agent 用”的扩展层，不应该成为第一版的前置依赖。

### 7.3 mock 模式是什么

mock 模式就是“没有 FPGA 板卡时，由软件假装有一块 FPGA 在响应”。

真实模式：

```text
GUI/CLI -> core -> UDP socket -> FPGA 192.168.1.8:32000
```

mock 模式：

```text
GUI/CLI -> core -> MockDevice/MockTransport -> 内存里的虚拟寄存器表
```

它不是真的仿真 RTL，也不会模拟 DAC/ADC 的全部时序。它只是模拟上位机最关心的协议边界：读寄存器、写寄存器、写后读回、超时、错误返回、参数校验。

对当前第一版，mock 至少应该模拟：

| 内容 | mock 行为 |
|---|---|
| 版本号 `0x000A` | 固定返回 `0x000300AC`，用于测试连接流程 |
| 普通可读写寄存器 | 写入后存在内存字典里，读回同样的值 |
| start/stop `0x0009` | 记录 scan 状态，GUI 可以显示 running/stopped |
| DL5 `0x0206~0x020B` | 支持写入、读回、参数范围检查 |
| 不可读寄存器 | 按寄存器表返回“不可读”或只记录已发送 |
| 网络异常 | 可选模拟 timeout、丢包、读回不匹配 |

mock 模式的价值：

1. 没有 FPGA 板卡时，GUI 也能开发和演示。
2. AI 可以跑 CLI 自动测试，不会误操作真实硬件。
3. 参数打包错误可以先在软件里暴露出来。
4. 现场调试前，可以先确认界面按钮、命令行、配置文件流程都通。

mock 模式不是最终验收。真正能不能控制板卡，仍然必须用 real UDP 模式连 FPGA 测。

### 7.4 为 DL2 快速接入预留什么

用户已说明后续 DL2 应该很快要接，所以第一版虽然暂不实现 DL2 数据接收和图像显示，但架构不能只按“寄存器小工具”来写。

需要从一开始区分控制平面和数据平面：

| 平面 | 当前内容 | 后续扩展 |
|---|---|---|
| 控制平面 | DL4 UDP 32000，寄存器读写、参数配置、start/stop、DL5 配置 | 继续扩展 DL2/DL3 的控制寄存器 |
| 数据平面 | 第一版暂不接收 ADC 数据 | 后续接 DL2 ADC 数据流、帧解析、图像缓存、显示、保存 |

第一版代码结构要提前预留：

```text
host_app/
  core/
    control/
      protocol.py
      register_client.py
      register_map.py
      device.py
    data/
      receiver_base.py      # DL2 数据接收接口，第一版可为空实现
      frame_model.py        # 图像/帧数据模型占位
    mock/
      mock_registers.py
      mock_device.py
  cli/
    main.py
  gui/
    main_window.py
    panels/
      connection_panel.py
      register_panel.py
      scan_panel.py
      dl5_panel.py
      log_panel.py
```

DL2 相关的提前设计原则：

1. DL4 控制 UDP 和 DL2 数据 UDP 分开，不让数据接收阻塞寄存器读写。
2. GUI 主线程只负责界面，UDP 收包、解析、保存都放后台线程或 worker。
3. 参数配置结果要能被 DL2 使用，例如 row/column/sample/channel 不能只存在 GUI 控件里，要进入统一配置模型。
4. 日志要区分 control log 和 data log，避免高速数据把控制日志冲掉。
5. mock 模式后续也要能生成假帧，方便无板卡开发图像显示。

因此第一版“不接 DL2”只是不做完整功能，不代表代码结构不考虑 DL2。

## 8. 推荐第一版界面结构

```text
连接
  - 本地网卡 / 本地 IP
  - FPGA IP
  - 本地端口 32000
  - Ping / 读版本号

寄存器控制台
  - 地址输入
  - 数据输入
  - Read32
  - Write32
  - Write checked

基础扫描
  - image_row / image_column
  - adc_sample / dac_sample
  - adc_channel
  - dacx_start / dacx_end
  - dacy_start / dacy_end
  - scan_mode
  - scan_state 显示

DL5 激光同步
  - laser_mode_en
  - scan_delay_time
  - blanker_delay_time
  - blanker_time
  - acq_data_delay_time
  - acq_time
  - Stop -> Apply DL5 -> Readback -> Start 流程按钮

日志
  - TX payload
  - RX payload
  - timeout / retry
  - readback mismatch
```

## 9. 第一版不做什么

为了避免第一版失控，建议明确不做：

```text
不做 ADC 图像显示
不做 32001 数据解析
不做 remote 固件升级
不做复杂用户权限
不做数据库
不做复杂自动脚本批处理/长时间实验编排
不做漂亮皮肤
```

这些都可以后续加，但第一版先把控制链路打牢。

## 10. 需要用户配合决策的问题

| 问题 | 影响 |
|---|---|
| 上位机只跑 Windows 吗？ | 影响 C#/Qt/Python 打包方式 |
| 使用者是否能接受安装 Python 运行环境，还是必须单文件 `.exe`？ | 影响部署路线 |
| 团队里有没有人熟 C#、Python、Qt、LabVIEW？ | 影响长期维护 |
| 第一版是否必须在无 FPGA 板卡时也能演示？ | 决定是否要 mock 模式 |
| 后续 DL2 图像显示是否很快就要接？ | 影响 UI 和数据接收线程设计 |
| 是否需要给非研发人员使用？ | 影响界面复杂度和安全保护 |

## 11. 当前决策

| 决策项 | 当前建议 | 状态 |
|---|---|---|
| 第一版技术栈 | Python + PySide6/PyQt(Qt GUI) + 原生 CLI + 共享核心库 | 已确认 |
| PySide6/PyQt 具体选择 | PySide6 优先，PyQt 作为兼容备选 | 已确认 |
| 是否做 CLI | 做，第一版必须有最小 CLI，给 AI/脚本使用 | 已确认 |
| 是否做 mock 模式 | 做，便于无板调试 GUI/CLI，降低真实硬件误操作风险 | 已确认 |
| 是否打包成 `.exe` | 第一阶段不打包，先源码运行；稳定后再 PyInstaller | 已确认 |
| 是否立即接 DL2 | 第一版不做完整 DL2，但架构必须预留 data plane、后台 worker 和帧模型 | 已确认 |

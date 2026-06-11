# 上位机工程架构设计

> 状态：v0.1 架构草案，尚未开始写上位机代码。
> 技术栈决策：Python + PySide6 优先，PyQt 作为兼容备选；第一版必须包含 GUI、CLI、mock；第一阶段不打包 `.exe`。
> 相关背景：`HOST_APP_DISCUSSION_AND_TECH_SELECTION.md`、`../guide/data-paths/DL4_REG_CONTROL_DEEP_READ.md`。

## 1. 第一版目标

第一版上位机先做控制闭环，不做完整采图和固件升级。

必须完成：

| 功能 | 说明 |
|---|---|
| 连接配置 | 选择本机 IP / FPGA IP / UDP 端口，默认 FPGA `192.168.1.8:32000` |
| 寄存器控制台 | 支持任意地址 `read32`、`write32`、`write_checked` |
| 参数配置 | 把 row、column、sample、channel、scan mode 等参数从人可读表单转换成寄存器写入 |
| start/stop scan | 对扫描启停做明确按钮和 CLI 命令 |
| DL5 参数配置 | 配置 `0x0206~0x020A` timing 和 `0x020B` laser enable，支持写后读回 |
| CLI | 给 AI 和脚本使用，支持 JSON 输出、dry-run、mock |
| mock 模式 | 无 FPGA 板卡时也能开发 GUI/CLI 和跑自动测试 |
| DL2 预留 | 第一版不接 ADC 数据，但代码结构要支持后续快速接入 DL2 数据平面 |

第一版暂不做：

| 暂不做 | 原因 |
|---|---|
| DL2 图像显示 | 需要继续读清 DL2 数据协议、帧格式、吞吐要求 |
| remote 固件升级 | 属于 DL3，第一版范围外 |
| `.exe` 打包 | 先源码运行，把控制链路跑稳后再 PyInstaller |
| 复杂实验编排 | 第一版只做安全、可复现的基础命令 |
| 用户权限 / 数据库 / 皮肤 | 先不消耗工程复杂度 |

## 2. 总体分层

核心原则：GUI 和 CLI 都很薄，真正的协议、寄存器、参数校验、mock 都放在 core。

```text
GUI  -> core -> transport -> real UDP / mock
CLI  -> core -> transport -> real UDP / mock
test -> core -> mock
```

推荐分层：

| 层 | 模块 | 职责 |
|---|---|---|
| 入口层 | `gui/` | PySide6 界面、按钮、表单、日志展示 |
| 入口层 | `cli/` | 命令行参数解析、JSON 输出、exit code |
| 应用层 | `core/control/device.py` | 对外暴露 version、start、stop、apply_scan、apply_dl5 等高层动作 |
| 应用层 | `core/control/scan.py` | 普通扫描参数模型、寄存器写入计划 |
| 应用层 | `core/control/dl5.py` | DL5 参数模型、寄存器写入计划、读回确认 |
| 协议层 | `core/control/protocol.py` | DL4 payload 编码/解码 |
| 寄存器层 | `core/control/register_map.py` | 地址、名称、可读写属性、字段说明 |
| 通信层 | `core/transport/udp_transport.py` | 真实 UDP 发送/接收，必须绑定本地端口 32000 |
| 通信层 | `core/transport/mock_transport.py` | 内存寄存器表、故障注入、无板测试 |
| 数据平面 | `core/data/` | 先放 DL2 接口和帧模型占位，后续接 ADC 数据流 |

## 3. 建议目录骨架

第一阶段建议把代码先放在 `AI-work/host-app/src/` 下，和讨论文档、架构文档在一起，方便 AI 协作和迭代。后续如果要产品化，可以整体迁到工程根目录的 `pc_host/` 或独立仓库。

```text
AI-work/host-app/
  HOST_APP_DISCUSSION_AND_TECH_SELECTION.md
  HOST_APP_ARCHITECTURE.md
  README.md
  pyproject.toml

  src/
    fpga_host/
      __init__.py

      core/
        __init__.py
        config.py
        errors.py
        models.py

        control/
          __init__.py
          protocol.py
          register_map.py
          register_client.py
          device.py
          scan.py
          dl5.py

        transport/
          __init__.py
          base.py
          udp_transport.py
          mock_transport.py

        data/
          __init__.py
          receiver_base.py
          frame_model.py
          dl2_receiver_stub.py

        logging/
          __init__.py
          event_log.py

      cli/
        __init__.py
        main.py
        commands_register.py
        commands_scan.py
        commands_dl5.py
        output.py

      gui/
        __init__.py
        app.py
        main_window.py
        workers.py
        panels/
          __init__.py
          connection_panel.py
          register_panel.py
          scan_panel.py
          dl5_panel.py
          log_panel.py

  configs/
    default_board.json
    profiles/
      basic_scan.json
      dl5_test.json

  tests/
    test_protocol.py
    test_register_map.py
    test_register_client_mock.py
    test_scan_plan.py
    test_dl5_plan.py
```

说明：

| 路径 | 说明 |
|---|---|
| `src/fpga_host/core/` | 上位机核心能力，不能依赖 GUI |
| `src/fpga_host/cli/` | 可以依赖 core，但不能依赖 GUI |
| `src/fpga_host/gui/` | 可以依赖 core，但业务逻辑不能写死在按钮回调里 |
| `configs/` | 板卡默认 IP、端口、参数模板、扫描 profile |
| `tests/` | 第一版主要测 protocol、mock、参数打包和写入计划 |

## 4. 核心对象

建议第一版先定义这些数据模型，避免 GUI 控件值、CLI 参数、寄存器字段各存一套。

| 对象 | 建议位置 | 说明 |
|---|---|---|
| `ConnectionConfig` | `core/config.py` | `host_ip`、`fpga_ip`、`local_port`、`remote_port`、timeout、retries |
| `BoardProfile` | `core/config.py` | 板卡名称、默认 IP、端口、版本号期望值 |
| `RegisterSpec` | `core/control/register_map.py` | 地址、名称、读写属性、默认值、说明 |
| `RegisterValue` | `core/models.py` | 地址和值的统一表示，便于日志和 JSON 输出 |
| `OperationResult` | `core/models.py` | 成功/失败、读回值、错误类型、耗时、日志 |
| `ScanConfig` | `core/control/scan.py` | row、column、adc_sample、dac_sample、channel、scan_mode 等 |
| `Dl5Config` | `core/control/dl5.py` | laser mode、scan delay、blanker、acq 时序 |
| `LogEvent` | `core/logging/event_log.py` | TX/RX payload、寄存器写入、timeout、mismatch |
| `FrameModel` | `core/data/frame_model.py` | 后续 DL2 图像帧的行列、通道、数据类型、时间戳 |

## 5. DL4 控制协议模块

`protocol.py` 只负责字节编码/解码，不负责 socket。

必须覆盖：

| 函数 | 输入 | 输出 |
|---|---|---|
| `encode_write(addr, value)` | 16-bit addr, 32-bit value | 14-byte payload |
| `encode_read(addr)` | 16-bit addr | 10-byte payload |
| `decode_read_response(payload)` | UDP payload | addr, value |
| `validate_payload(payload)` | UDP payload | command、length、addr、data |

DL4 已知格式：

```text
write: 55 55 AA AA 00 01 00 06 ADDR_H ADDR_L DATA_3 DATA_2 DATA_1 DATA_0
read : 55 55 AA AA 00 02 00 02 ADDR_H ADDR_L
resp : 55 55 AA AA 00 03 00 06 ADDR_H ADDR_L DATA_3 DATA_2 DATA_1 DATA_0
```

约束：

1. 所有多字节字段按大端处理。
2. 地址只允许 `0x0000~0xFFFF`。
3. 数据只允许 `0x00000000~0xFFFFFFFF`。
4. 解码失败时返回明确错误，不在 GUI/CLI 里猜。

## 6. Transport 设计

`transport` 只负责“发 payload、收 payload”，不理解寄存器含义。

接口建议：

```text
class Transport:
    open()
    close()
    transact(payload: bytes, expect_response: bool) -> bytes | None
```

真实 UDP：

| 项 | 要求 |
|---|---|
| 本地端口 | 必须能绑定 `32000`，因为 FPGA 侧过滤 UDP 源端口 |
| 远端端口 | 默认 `32000` |
| 远端 IP | 默认 `192.168.1.8` |
| timeout | CLI/GUI 可配置，默认建议 `500 ms` 起步 |
| retries | 默认建议读操作 1~2 次重试，写操作不盲目重发危险命令 |

mock transport：

| 行为 | 说明 |
|---|---|
| 内存寄存器表 | 写入后可读回 |
| 固定版本号 | `0x000A` 默认返回 `0x000300AC` |
| 可读写属性 | 根据 `register_map.py` 判断不可读/不可写 |
| scan 状态 | `0x0009` 写入后更新 running/stopped 状态 |
| DL5 寄存器 | `0x0206~0x020B` 支持写入和读回 |
| 故障注入 | 可模拟 timeout、丢包、读回 mismatch |

## 7. Register Client

`register_client.py` 是控制链路的核心低层 API。

建议接口：

```text
read32(addr) -> int
write32(addr, value) -> OperationResult
write_checked(addr, value) -> OperationResult
dump(registers) -> list[RegisterValue]
```

规则：

1. 写命令没有 ACK，不可把 UDP send 成功当成 FPGA 已配置成功。
2. 可读寄存器默认使用 `write_checked`。
3. 不可读寄存器写入后只能记录“已发送，未闭环确认”。
4. `0x0206~0x020A` DL5 timing 寄存器走 `write_checked`。
5. `0x0200~0x0205` sync/ultrafast 已补读回，可走 `write_checked`。
6. `0x020B` laser enable 已补读回，可走 `write_checked`。

## 8. 高层 Device API

GUI 和 CLI 不应直接拼寄存器序列，应调用高层 API。

建议：

```text
FpgaDevice.version()
FpgaDevice.read_register(addr)
FpgaDevice.write_register(addr, value, checked=False)
FpgaDevice.stop_scan()
FpgaDevice.start_scan()
FpgaDevice.apply_scan_config(config, dry_run=False)
FpgaDevice.apply_dl5_config(config, stop_before_apply=True, dry_run=False)
```

DL5 推荐流程：

```text
stop_scan
write_checked 0x020B laser_mode_en = 0
write_checked 0x0206 scan_delay_time
write_checked 0x0207 blanker_delay_time
write_checked 0x0208 blanker_time
write_checked 0x0209 acq_data_delay_time
write_checked 0x020A acq_time
write_checked 0x020B laser_mode_en = 1
optional start_scan
```

`dry_run=True` 时只生成写入计划和日志，不实际发包。

## 9. CLI 设计

第一版 CLI 是 AI 和脚本的主入口。它要稳定、可解析、可复现。

运行方式：

```text
python -m fpga_host.cli.main version --mock --json
python -m fpga_host.cli.main read 0x000A --json
python -m fpga_host.cli.main write 0x0009 0x00000000 --yes
python -m fpga_host.cli.main dl5 apply --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60 --dry-run --json
```

后续安装为包后，可增加 `fpga-host` console script。

命令建议：

| 命令 | 说明 |
|---|---|
| `version` | 读 `0x000A`，验证连接和协议 |
| `read ADDR` | 读单个寄存器 |
| `write ADDR VALUE` | 写单个寄存器 |
| `write-checked ADDR VALUE` | 写后读回 |
| `dump --range basic/dl5/all` | 批量读取 |
| `start` | 启动扫描 |
| `stop` | 停止扫描 |
| `scan apply ...` | 写入普通扫描参数 |
| `dl5 apply ...` | 写入 DL5 参数 |
| `profile load FILE` | 从 JSON profile 加载参数 |

CLI 输出：

1. 默认输出人可读文本。
2. `--json` 输出稳定 JSON，供 AI 和脚本解析。
3. 失败时 stderr 输出简短错误，JSON 模式下也要给结构化错误。

exit code 建议：

| code | 含义 |
|---|---|
| `0` | 成功 |
| `2` | 参数错误或配置文件错误 |
| `10` | UDP timeout |
| `11` | 写后读回 mismatch |
| `12` | payload/protocol 解码错误 |
| `20` | 危险操作缺少 `--yes` |

## 10. GUI 设计

GUI 第一版已证明更像工程调试工具。用户试用后明确反馈：V2 应以人的使用便捷性为优先，不应让用户手填寄存器地址。新的 GUI 方向见 `HOST_APP_GUI_UX_V2_PLAN.md`。

### 10.1 V1 调试型页面

页面结构：

| Panel | 内容 |
|---|---|
| Connection | host IP、FPGA IP、端口、mock/real 切换、读版本号 |
| Register Console | addr/value 输入，read/write/write_checked，结果显示 |
| Scan Config | row、column、sample、channel、mode、start/stop |
| DL5 Config | laser mode、scan delay、blanker、acq 参数，apply/readback |
| Log | 控制日志、TX/RX payload、错误、耗时 |

线程原则：

1. GUI 主线程只做界面更新。
2. 所有可能 timeout 的 UDP 操作都放 worker。
3. worker 通过 Qt signal 把 `OperationResult` 和 `LogEvent` 发回界面。
4. 后续 DL2 数据接收必须单独 worker，不与 DL4 控制 worker 混用。

按钮安全规则：

| 操作 | 保护 |
|---|---|
| start scan | GUI 显示当前参数摘要 |
| stop scan | 可直接执行 |
| apply DL5 | 默认 stop -> apply -> readback，可选 apply 后 start |
| 写不可读寄存器 | 显示“无法读回确认” |
| real 模式 | 状态栏明显显示 real/mock，避免误操作 |

### 10.2 V2 人本模式页面

V2 主界面应改为三种工作模式：

```text
普通扫描
超快扫描
激光同步
```

寄存器控制台保留为高级调试入口，不作为主流程。

## 11. 配置文件

第一版使用 JSON，避免引入 YAML 依赖。

`configs/default_board.json` 示例：

```json
{
  "name": "SGSC_SEM_325T_V3_172",
  "fpga_ip": "192.168.1.8",
  "local_port": 32000,
  "remote_port": 32000,
  "timeout_ms": 500,
  "retries": 1,
  "expected_version": "0x000300AC"
}
```

`configs/profiles/dl5_test.json` 示例：

```json
{
  "scan": {
    "rows": 1024,
    "cols": 1024,
    "adc_sample": 20,
    "dac_sample": 20,
    "adc_channel": 4,
    "scan_mode": 0
  },
  "dl5": {
    "laser_mode": 1,
    "scan_delay": 100,
    "blanker_delay": 20,
    "blanker_time": 80,
    "acq_delay": 30,
    "acq_time": 60
  }
}
```

## 12. DL2 扩展预留

DL2 很快要接，所以第一版必须预留数据平面，但不实现完整数据接收。

预留模块：

| 模块 | 第一版状态 | 后续用途 |
|---|---|---|
| `core/data/receiver_base.py` | 定义接口 | 数据 UDP receiver 的统一抽象 |
| `core/data/frame_model.py` | 定义数据结构 | 表示图像帧、行列、通道、时间戳 |
| `core/data/dl2_receiver_stub.py` | 空实现或 mock | 后续替换为真实 DL2 receiver |
| `gui/workers.py` | 先支持 control worker | 后续增加 data worker |
| `log_panel.py` | 先显示 control log | 后续分 control/data 两类日志 |

设计约束：

1. DL4 控制平面和 DL2 数据平面分开。
2. 控制命令不能被高速数据接收阻塞。
3. 扫描参数必须进入统一 `ScanConfig`，后续 DL2 解帧可以复用。
4. DL2 具体 UDP 端口、帧头、字节序、丢包策略，需要进入 DL2 deep read 后再定。
5. mock 后续要能生成假帧，用于无板卡调试图像显示。

## 13. 测试策略

第一版测试重点放在不会依赖 FPGA 的部分。

| 测试 | 目标 |
|---|---|
| `test_protocol.py` | payload 编码/解码字节完全正确 |
| `test_register_map.py` | 地址表读写属性正确 |
| `test_register_client_mock.py` | mock 下 read/write/write_checked 行为正确 |
| `test_scan_plan.py` | 扫描参数生成的寄存器写入计划正确 |
| `test_dl5_plan.py` | DL5 生成 `0x0206~0x020A/0x020B` 写入计划，支持 dry-run |

建议先用 `pytest`，如果想减少依赖，也可以先用 Python 标准库 `unittest`。由于后续 GUI 和协议都会变，`pytest` 的开发体验更好。

## 14. 开发阶段

建议按这个顺序开工：

| 阶段 | 内容 | 验收 |
|---|---|---|
| P0 | 创建目录骨架、`pyproject.toml`、README | `python -m fpga_host.cli.main --help` 能运行 |
| P1 | 实现 `protocol.py` 和测试 | DL4 三种 payload 编解码测试通过 |
| P2 | 实现 `mock_transport` + `register_client` | mock 下 read/write/write_checked 测试通过 |
| P3 | 实现 CLI 基础命令 | `version/read/write/dl5 apply --dry-run --json` 可用 |
| P4 | 实现 GUI 基础界面 | mock 模式下可点按钮完成寄存器读写和 DL5 配置 |
| P5 | 接真实 FPGA DL4 | real UDP 下能读 `0x000A`，能 start/stop |
| P6 | DL2 deep read 后接数据平面 | 明确端口、帧格式、缓存和显示方案 |

## 15. 开工前仍需确认

| 问题 | 当前建议 |
|---|---|
| Python 版本 | 使用当前环境里的 Python 3.12 |
| Qt 绑定 | PySide6 优先 |
| CLI 框架 | 第一版用标准库 `argparse`，后续命令复杂再看 Typer |
| 测试框架 | 建议 `pytest` |
| 代码位置 | 第一阶段放 `AI-work/host-app/src/`，后续产品化再迁出 |
| DL2 细节 | 需要后续补 DL2 deep read 后再实现 |

## 16. 当前实现状态（2026-06-01）

已按本架构创建第一版源码，位置为 `AI-work/host-app/`。

| 阶段 | 状态 | 说明 |
|---|---|---|
| P0 | 已实现并验证 | `pyproject.toml`、README、`src/fpga_host/`、configs、tests 已创建；`python -m fpga_host.cli.main --help` 可运行 |
| P1 | 已实现并验证 | `protocol.py` 支持 DL4 write/read/read-response payload 编解码 |
| P2 | 已实现并验证 | `mock_transport.py`、`udp_transport.py`、`register_client.py` 已实现；mock 下读写和写后读回通过测试 |
| P3 | 已实现并验证 | CLI 支持 `version/read/write/write-checked/dump/start/stop/scan apply/dl5 apply/profile load/data mock-frame`，支持 `--mock`、`--json`、`--dry-run`、`--yes` |
| P4 | 代码已实现，环境未启动验证 | GUI 面板已实现：Connection/Register/Scan/DL5/Log；当前 Python 环境未安装 PySide6/PyQt，需安装 Qt binding 后启动验证 |
| P5 | 代码已实现，硬件未实测 | real UDP transport 已实现，按本地端口 32000 绑定；当前未连接真实 FPGA，因此未读实板 `0x000A` |
| P6 | 接口与 mock 已实现，真实解析待 DL2 deep read | 已有 `core/data/receiver_base.py`、`frame_model.py`、`dl2_receiver_stub.py` 和 CLI `data mock-frame`；真实 DL2 UDP 帧解析仍需后续精读 DL2 协议 |

本轮验证命令：

```powershell
$env:PYTHONPATH='src'
python -m unittest discover -s tests
python -m fpga_host.cli.main --help
python -m fpga_host.cli.main version --mock --json
python -m fpga_host.cli.main write-checked 0x020B 1 --mock --yes --json
python -m fpga_host.cli.main dl5 apply --mock --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60 --dry-run --json
python -m fpga_host.cli.main profile load configs/profiles/dl5_test.json --mock --dry-run --json
python -m fpga_host.cli.main data mock-frame --rows 4 --cols 4 --channels 2 --json
python -m compileall -q src tests
```

验证结果：

```text
unittest: 17 tests OK
compileall: OK
CLI mock commands: OK
Qt binding probe at first implementation: PySide6/PyQt6/PyQt5 missing in system Python
Environment setup on 2026-06-01: PySide6_Essentials 6.11.1 installed in D:\fpga_host_venv
```

See `HOST_APP_ENVIRONMENT.md` for the prepared Python/Qt environment and real-board test commands.

## 17. GUI V2 实现状态（2026-06-01 10:01）

根据用户试用反馈，GUI 已从“寄存器/扫描/DL5 分页工具”改为“人先选择工作模式”的工作台。

当前主界面：

| 区域 | 状态 |
|---|---|
| 顶部连接栏 | 可切换 mock/real，配置 FPGA IP、本机 IP、端口，读版本 |
| 模式控制 | 默认页，包含普通扫描、超快扫描、激光同步三种模式 |
| 参数区 | 用户填写图像行列、采样、ADC 通道、ADC 间隔、扫描模式和当前模式专属参数 |
| 运行区 | 提供预览写入计划、应用参数、开始扫描、停止扫描 |
| 写入计划 | 只显示步骤、动作、值、确认方式，不要求用户手填寄存器地址 |
| 高级调试 | 保留 raw register console 和完整连接配置，用于 AI/工程调试 |

本轮验证：

```text
unittest: 21 tests OK
compileall: OK
CLI mode normal dry-run: OK
GUI instantiate: OK, FPGA Host Console (PySide6)
```

下一步仍是 P5/V2-P7：等 FPGA 板连接后，在 real UDP 下读 `0x000A` version，并分别验证普通、超快、激光三种模式的 apply/start/stop。

### 17.1 UI 安全交互补充（2026-06-01 10:47）

已按 `HOST_APP_UI_FIRST_PRINCIPLES.md` 补充第一批仪器控制台式交互：

| 能力 | 状态 |
|---|---|
| 参数 dirty 状态 | 参数或模式改动后 Start 禁用，提示未应用 |
| 失败态保护 | apply/start 失败后阻止继续 start |
| Stop 优先 | Stop 不受 dirty/失败态限制 |
| scan 状态读回 | 读取 `0x0009` 显示 running/stopped/unknown |
| 等价 CLI 命令 | GUI apply/start/stop 写入日志，方便 AI/脚本复现 |
| 写入计划详情 | 默认隐藏寄存器地址，可勾选展开 |
| 网络诊断 | 顶部连接栏可读 version 和 scan_control，并记录 endpoint |

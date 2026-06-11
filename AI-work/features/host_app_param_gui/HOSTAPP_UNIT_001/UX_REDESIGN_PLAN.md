# Host App GUI UX 重构方案

日期：2026-06-11

范围：`AI-work/host-app/src/fpga_host/gui` 当前 PySide6 GUI，重点覆盖顶部连接栏、模式选择、参数编辑、运行控制、写入计划和日志区。

## 检查结论

用户指出的问题与当前代码基本一致，根因不是单个控件样式，而是界面结构仍按“调试面板”堆叠：

| 区域 | 当前代码证据 | 主要问题 |
|---|---|---|
| 窗口标题 | `main_window.py` 使用 `FPGA Host Console ({QT_API})` | `PySide6` 泄漏到用户界面 |
| 顶部栏 | `connection_bar.py` 单个 `QHBoxLayout` 放入 Mock/IP/端口/连接/版本/诊断/version | 主次不分，version 与按钮关联弱，REAL 像按钮又像状态 |
| 工作模式 | `mode_workbench_panel.py` 左侧 `QRadioButton` 组 | 与“模式下拉”原则冲突，并浪费左侧整列空间 |
| 参数区 | 固定 `QTabWidget`，普通模式也保留“模式扩展”页 | 普通模式出现空 Tab，模式变化没有改变信息架构 |
| 参数字段 | 大量 `QFormLayout` + 长 label 括号说明 | 单位、位宽、换算和魔数语义都挤在 label 内 |
| 输入控件 | `_spin()` 未按字段类型设宽，也缺少统一 metadata | 小数字输入框过宽，范围只靠 label 或后端校验 |
| 运行面板 | 右侧 `运行` group 常驻一大列 | 状态、复选框、按钮、结果文字混放，视觉权重不对 |
| 写入计划 | `QTableWidget` 常驻，最小高度 150 | 未展开时仍占空间；“确认=写后读回”是策略不是结果 |
| 日志 | `LogPanel` 是常驻 `QTextEdit` | 空日志仍占底部高度，不符合底部抽屉原则 |

## 设计目标

1. 去掉实现细节泄漏：窗口标题和用户文案不出现 `PySide6`。
2. 让工作流一眼可读：连接设备 -> 选择模式 -> 修改参数 -> 应用参数 -> 开始/停止扫描 -> 查看计划/日志。
3. 让模式成为一级上下文：模式使用下拉控件，普通模式不显示空扩展页，超快/激光显示对应专属页。
4. 让参数单位外显：label 只放名称，单位、范围、换算、写入寄存器放到独立字段或 tooltip。
5. 让状态靠近动作：`未应用`、`readback mismatch`、`start 禁用原因` 必须贴近 `应用参数/开始扫描`。
6. 降低常驻噪声：写入计划和日志默认折叠，只有有内容或用户展开时占高度。

## 目标布局

建议从三列常驻布局改成“顶部连接条 + 模式工作条 + 参数主区 + 抽屉”的布局：

```text
FPGA Host Console
MOCK/REAL 状态  Host 自动(0.0.0.0):32000  FPGA 192.168.1.8:32000  [连接] [读版本] version=... [诊断]

模式 [普通扫描 v]    参数状态: 未应用    [预览] [应用参数] [开始扫描] [停止扫描]
开始扫描禁用原因: 参数已修改但尚未应用

参数主区
  图像/采集        DAC 波形        增益与行帧        超快同步/激光同步（仅对应模式显示）
  分组网格控件      简化波形图        gain 小矩阵       专属参数

写入计划  18 steps / 18 checked / 0 sent-only  [显示底层地址] [展开]
日志      0 error / 0 warning / 3 info          [展开]
```

左侧“工作模式”整列删除，回收给参数区和写入计划抽屉。右侧“运行”整列改成顶部工作条，状态和按钮横向靠近。

## 分区方案

### 1. 顶部连接栏

改动：

- 窗口标题改为 `FPGA Host Console`，不拼接 Qt backend。
- `MOCK/REAL` 不做大红按钮，改为状态 chip + 明确开关或下拉：
  - `MOCK`：蓝色/灰蓝状态，表示仿真传输。
  - `REAL`：琥珀色状态，表示真实硬件；红色只留给错误/危险。
- 连接相关控件分成三组：
  - 环境：Mock/Real。
  - Endpoint：本机 IP、本机端口、FPGA IP、FPGA 端口。
  - Device：读版本按钮 + version 值。
- `0.0.0.0` 显示为 `自动(0.0.0.0)`，tooltip 写明“绑定所有本机网卡，不代表未配置”。
- `连接` 是主按钮；`网络诊断` 是次按钮/图标按钮；`读版本` 与 `version` 值放在同一小组。

实现位置：

- `main_window.py`：窗口标题。
- `connection_bar.py`：拆成 `EnvironmentSelector`、`EndpointEditor`、`DeviceIdentity` 三个子控件，仍由 `ConnectionBar` 聚合。

### 2. 模式选择

改动：

- 删除左侧 `QRadioButton` 模式栏。
- 在模式工作条使用 `QComboBox`：
  - `普通扫描`
  - `超快扫描`
  - `激光同步`
- 切换模式时同步三件事：
  - 重新生成写入计划。
  - 参数状态变为未应用。
  - 参数 Tab 可见性随模式变化。

普通模式不再显示“模式扩展”空页；超快模式显示 `超快同步` 页；激光模式显示 `激光同步` 页。

实现位置：

- `mode_workbench_panel.py`：`_build_mode_selector()` 替换为 `_build_mode_toolbar()`。
- `_set_mode()`：不要再写 status bar 的 `mode: ...`，避免与工作条重复。

### 3. 参数输入组件

当前问题的核心是缺少参数 metadata。建议新增一个轻量字段描述层：

```python
@dataclass(frozen=True)
class ParamSpec:
    key: str
    label: str
    register: int | None
    bit_range: str | None
    minimum: int
    maximum: int
    default: int
    display_base: int
    input_unit: str
    hardware_hint: str
    equivalent: Callable[[int], str] | None
    tooltip: str
```

对应 UI 组件 `ParamField`：

- 左侧：短 label，例如 `ADC 间隔`。
- 中间：紧凑输入框，宽度按类型固定。
- 右侧：单位 chip，例如 `ADC cycles`、`20ns steps`、`us`、`DAC code`。
- 次级文字：等价换算，例如 `50 -> FPGA x50 = 2500 words`、`30 steps ~= 600 ns`。
- tooltip：寄存器地址、bit 位、RTL 解释、边界条件。
- dirty 标记：字段值与 last-applied snapshot 不同时显示小色条或 `*`。

建议输入宽度：

| 类型 | 宽度 | 示例 |
|---|---:|---|
| boolean/enum | 110 px | trigger source、scan mode |
| 2-bit gain | 72 px | ADC1 gain |
| 4-bit/小整数 | 80 px | scan state/mode |
| 16-bit decimal | 96 px | rows、cols、steps |
| 16-bit hex | 110 px | `0x1999` |
| 32-bit count | 130 px | frame waiting |

### 4. 参数 Tab 重排

#### 图像/采集

分为两个小组：

- 图像尺寸：rows、cols。
- ADC/扫描：每点采样、ADC 通道、ADC 间隔、扫描模式、行触发源。

`扫描模式` 改成语义化下拉：

- `参数扫描模式 (code 1)`：当前 RTL 注释明确 `4'h1` 才进入参数扫描模式。
- 其他 code 放到“高级 raw code”折叠项，默认不暴露裸 SpinBox。

`外部行触发` 改成 `行触发源`：

- `自由运行`
- `等待 TRIGGER_IN`

#### DAC 波形

按 X/Y/时序分组，不再交错：

- X 轴：X 起始码、X 结束码、X 点数。
- Y 轴：Y 起始码、Y 结束码。
- 回扫/恢复：X 线首恢复、X 回扫下降。

`X 点数覆盖 (0=跟随列数)` 改成：

- checkbox：`X 点数跟随列数`
- 关闭 checkbox 后才启用数值输入 `X 点数覆盖`

增加一个小型 `QGraphicsView` 或自绘 widget，显示：

- X 起始/结束电平。
- Y 起始/结束电平。
- X 回扫下降、线首恢复的大致位置。

这不是装饰图，而是帮助用户理解寄存器对波形的影响。

#### 增益与行帧

改成两个分组：

- 增益矩阵：
  - ADC1/ADC2/ADC3/ADC4 四列或两列小矩阵。
  - DAC X / DAC Y 单独一行。
  - 2-bit gain 用 0~3 下拉或小步进控件，旁边显示 `2-bit code`。
- 行/帧：
  - 帧间等待：`FIFO words` + `约 value * 20ns`。
  - 行重复次数。
  - 交错扫描：`row_m` / `row_n` 成对显示，tooltip 说明 bit packing：`0x0014 = {row_m, row_n}`。

#### 模式专属页

普通模式：

- 不显示专属 Tab。
- 在模式工作条放一个小状态：`扩展关闭：ultrafast=0, laser=0`。

超快模式：

- Tab 名称 `超快同步`。
- 分组：sync 宽度、sync 延时、ADC 超快采集。
- `sync*_width` 显示 `20ns steps`，等价显示 `value * 20ns`，tooltip 写 `RTL 内部 <<2 到 ui_clk`。
- `sync_delay*` 显示 `ui_clk cycles`，等价显示 `value * 5ns`。

激光模式：

- Tab 名称 `激光同步`。
- `laser enable` 用明确开关：`应用后启用激光同步`。
- `scan_delay` 显示 `eth_clk cycles`，等价 `value * 8ns`。
- `blanker_delay/time` 显示 `ui_clk cycles`，等价 `value * 5ns`。
- `acq_delay` 显示 `20ns steps`，等价 `value * 20ns`。
- `acq_time` 同时显示两种含义：`ADC samples / 20ns steps`。

### 5. 运行控制

右侧大面板改成顶部模式工作条：

- `当前模式` 由下拉本身表达，不再重复文本。
- `扫描状态` 显示为 compact chip：`stopped/running/unknown`。
- `参数状态` 紧贴 `应用参数` 和 `开始扫描`。
- `开始扫描` 禁用时，按钮旁直接显示原因，例如 `先应用参数`，不只依赖 tooltip。
- `显示底层地址` 从运行面板移到写入计划抽屉标题栏。
- `普通扫描 写入计划已生成` 这种结果提示移到写入计划抽屉标题，避免和参数状态重复。

### 6. 写入计划表

写入计划默认折叠，只显示摘要：

```text
写入计划 18 steps / 18 checked / 0 sent-only / last preview: 普通扫描
```

展开后表头改为：

| 列 | 含义 |
|---|---|
| 步骤 | 序号 |
| 动作 | 人可读动作 |
| 计划值 | 将写入的值 |
| 确认策略 | `write_checked` / `send only` |
| 结果 | 未执行 / OK / mismatch / timeout |

只有用户勾选 `显示底层地址` 时才显示地址列和 bit packing tooltip。

### 7. 日志区

改成底部抽屉：

- 默认折叠，高度约 28~32 px。
- 标题显示统计：`日志 0 error / 0 warning / 5 info`。
- 出现 error 时自动展开或高亮标题。
- 空日志不占整条 QTextEdit 高度。
- status bar 不再重复 `mode: 普通扫描`，只保留连接摘要或最后一条短状态。

### 8. 颜色与图标

颜色语义固定：

| 颜色 | 用途 |
|---|---|
| 蓝/灰蓝 | Mock、信息 |
| 琥珀 | Real 硬件、未应用、需确认 |
| 绿 | 已应用、读回 OK、连接成功 |
| 红 | 错误、readback mismatch、危险确认 |
| 灰 | 未连接、禁用、空状态 |

按钮加图标，但不引入新依赖：

- 优先使用 Qt `QStyle.StandardPixmap`。
- 若后续允许依赖，再评估 `qtawesome`。

### 9. 实施步骤

#### P0：结构清理，不改寄存器行为

- 去掉窗口标题中的 `{QT_API}`。
- 顶部栏拆组，调整连接/诊断/版本主次。
- 模式改为 `QComboBox`。
- 普通模式隐藏专属 Tab。
- 写入计划和日志改为可折叠抽屉。
- 右侧运行面板改成顶部工作条。

验证：

- `python -m compileall src`
- `python -m unittest discover -s tests`
- GUI mock 启动，三种模式切换无异常。

#### P1：参数字段 metadata 和单位外显

- 新增 `param_widgets.py`：`ParamSpec`、`ParamField`、`UnitHint`、dirty 标记。
- 所有 label 去掉括号长说明。
- 输入框按字段类型固定宽度。
- 增加等价换算显示和 tooltip。
- `scan_mode`、触发源、gain、X 点数跟随列数语义化。

验证：

- 修改任意参数后，对应字段和全局状态显示 dirty。
- `start` 禁用原因可见。
- 预览计划值与当前 `ModeConfig.to_plan()` 完全一致。

#### P2：可视化和读回结果

- DAC 波形小图。
- 写入计划表增加执行结果列。
- apply 后把 `write_checked` 的 OK/mismatch 显示回表格。
- version/readback/diagnostics 结果进入设备状态摘要。

#### P3：截图验收与细节打磨

- 桌面窗口 1120x720、1366x768、1600x900 截图检查。
- 检查没有大面积空 Tab。
- 检查按钮文字不溢出。
- 检查无重复状态、无空日志占位。

## 验收标准

1. 窗口标题不出现 `PySide6`。
2. 顶部栏能清楚区分 Mock/Real、连接主动作、诊断次动作、version 结果。
3. 本机 IP `0.0.0.0` 明确显示为自动绑定。
4. 工作模式使用下拉，不再使用左侧单选栏。
5. 普通模式下不存在空的“模式扩展”页。
6. 数值输入宽度按类型收敛，小数字不再占 400 px。
7. 单位、范围、换算关系不再塞进 label 括号。
8. `scan_mode`、trigger、gain、X 点数覆盖都有语义化控件。
9. 修改字段后能看到字段级 dirty 和全局未应用状态。
10. `开始扫描` 禁用时，界面直接说明原因。
11. 写入计划默认折叠，展开后区分“确认策略”和“执行结果”。
12. 日志默认折叠，空日志不占主界面高度。
13. 红色只用于错误/危险，不再用于普通 REAL 状态块。

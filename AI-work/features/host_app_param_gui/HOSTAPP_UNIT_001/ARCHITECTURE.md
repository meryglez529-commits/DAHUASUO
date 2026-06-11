# Host App 参数分类与 GUI 架构

## 地址标准

当前 host-app 以 `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` 的写寄存器表为协议标准。

| 地址 | host-app 语义 | 读回策略 |
|---|---|---|
| `0x0205` | `sync2_pixel_tri_width` | checked write |
| `0x020B` | `laser_mode_en` | checked write |
| `0x0206`~`0x020A` | DL5 timing | checked write |

RTL 读 case 已同步：`0x0200~0x0205` 可读回 sync/ultrafast 参数，`0x020B` 可读回 `laser_mode_en`。host-app 因此可以对这些地址做 checked write。

## 参数分组

| 分组 | 寄存器 | GUI 位置 | 单位策略 |
|---|---|---|---|
| 基础扫描 / ADC | `0x0000`, `0x0001`, `0x0002`, `0x0004`, `0x0009` | 基础扫描 tab | 行列/点数/ADC cycles |
| DAC 几何 | `0x0005`, `0x0006`, `0x0007`, `0x000F` | DAC 几何 tab | DAC code、pixels、us x50 |
| 增益 / 帧 / 行 | `0x0003`, `0x0008`, `0x0013`, `0x0014` | 增益/帧/行 tab | 2-bit code、FIFO words、count |
| ultrafast / sync | `0x0200`~`0x0205` | 模式扩展 tab | ADC cycles、ui_clk cycles、20ns steps、us x50 |
| DL5 激光 | `0x0206`~`0x020B` | 模式扩展 tab | 8ns steps、5ns steps、20ns steps / ADC samples |
| 维护/高级 | `0x000C`, `0x000D`, `0x000E`, `0x0010`~`0x0012` | raw register | remote/offset/heartbeat 专用流程暂不纳入 |

## 单位规则

GUI 和 CLI 不接受“泛化 ns”。控件直接写 RTL 原始值，并在 label/help 中说明每步含义。

| 类型 | 示例 | 上位机写入 |
|---|---|---|
| `eth_clk` step | `scan_delay_time` | cycle count，8ns/step |
| `ui_clk` step | `blanker_delay_time`, `blanker_time`, `sync_sig_delay1/2` | cycle count，5ns/step |
| 20ns step | `sync*_width`, `acq_data_delay_time`, `acq_time` | step count，RTL 内部 `<<2` 到 ui_clk |
| ADC sample/cycle | `adc_interval`, `adc_acq_delay`, `acq_dead_time`, laser `acq_time` | ADC DCO count，50MHz 时约 20ns/step |
| FIFO word | `frame_waiting_time`, `dac_sample` | word/sample count，50MHz DAC DCO 时约 20ns/word |
| us x50 | `dacx_recovery_time`, `dax_fall_time`, `ultrafast_line_rec` | user-facing us，FPGA 内部乘 50 |

完整审计表见 `PARAM_UNITS_AUDIT.md`。

## 写入计划

### 普通模式

1. 写 `0x0009` 停止扫描。
2. 写 `0x020B=0` 关闭 laser，checked。
3. 写 `0x0202=0` 关闭 ultrafast，checked。
4. 写扫描基础、DAC 几何、增益/帧/行参数。
5. 保持 `scan_state=0`，由用户显式 start。

### 超快模式

1. 停止扫描并关闭 laser。
2. 写扫描基础、DAC 几何、增益/帧/行参数。
3. 写 `sync1_width`、`sync2_width`、`adc_acq_delay`、`sync_delay1/2`、`acq_dead_time`。
4. 写 `0x0202` 使能 ultrafast。
5. 校验 `adc_sample > adc_acq_delay + acq_dead_time + 2`。

### 激光同步模式

1. 停止扫描并关闭 ultrafast。
2. 写扫描基础、DAC 几何、增益/帧/行参数。
3. 写 `0x020B=0`，checked。
4. 写 `0x0206`~`0x020A` timing。
5. 写 `0x020B=laser_mode`，checked。
6. laser enable 时校验 `acq_time >= 2`。

## GUI 布局

`ModeWorkbenchPanel` 是主工作台：

| 区域 | 内容 |
|---|---|
| 左侧 | 模式选择：普通扫描、超快扫描、激光同步 |
| 中间 | 参数 tabs：基础扫描、DAC 几何、增益/帧/行、模式扩展 |
| 右侧 | 当前模式、扫描状态、参数状态、预览/应用/启停 |
| 下方 | 写入计划表，可切换显示底层地址 |

GUI 的“应用参数”只负责写参数，开始扫描仍由“开始扫描”显式触发。

## 验证策略

- `ScanConfig` 单测：新增寄存器 `0x0003/0x0008/0x0013/0x0014` 进入计划，raw unit 不被隐式换算。
- `Dl5Config` 单测：laser enable 地址为 `0x020B`。
- `ModeConfig` 单测：`0x020B` 和 `0x0205` 均为 checked write。
- CLI dry-run：laser plan 可 JSON 输出。
- `python -m compileall src` 验证语法。
- `python -m unittest discover -s tests` 验证行为。

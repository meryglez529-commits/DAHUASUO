# command_monitor_new.v 上位机参数覆盖对照

> 日期：2026-06-11
> 范围：基于当前 `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` 写/读寄存器表，以及 `AI-work/host-app` 当前 Python 上位机实现。
> 说明：本文里的“当前设置”指 host-app 的 GUI/CLI/mode 写入计划和默认 profile，不代表已经从实板读回的当前寄存器值。

## 1. 结论先看

`command_monitor_new.v` 是 DL4 控制面的集中解码点。上位机通过 UDP 寄存器写入后，这个模块把 32-bit payload 拆成 ADC、DAC、扫描状态、ultrafast、DL5、offset、remote 等硬件参数。

当前 host-app 已按用户确认迁移到当前 RTL 写表，并覆盖普通扫描和 DL5/ultrafast 主流程所需的大部分参数：

- 普通/激光/超快三种模式都会写入扫描基础参数和新增高级项：`0x0000/0x0001/0x0002/0x0003/0x0004/0x0005/0x0006/0x0007/0x0008/0x000F/0x0013/0x0014/0x0009`。
- ultrafast 模式会额外写 `0x0200/0x0201/0x0202/0x0203/0x0204/0x0205`，当前 RTL 已补这些地址的读回，host-app 按 checked write 处理。
- DL5 激光模式会额外写 `0x0206/0x0207/0x0208/0x0209/0x020A/0x020B`；`0x020B` 当前 RTL 已补读回，host-app 按 checked write 处理。

地址处理状态：

- 当前 RTL 写 case 里 `0x020B` 写 `laser_mode_en`，`0x0205` 写 `sync2_pixel_tri_wigth`。
- host-app 已改为 `0x020B=laser_mode_en`、`0x0205=sync2_pixel_tri_width`。
- RTL 读 case 已同步：`0x0205` 读回 `sync2_pixel_tri_wigth`，`0x020B` 读回 `laser_mode_en`。

单位处理状态：

- 单位审计已记录在 `AI-work/features/host_app_param_gui/HOSTAPP_UNIT_001/PARAM_UNITS_AUDIT.md`。
- GUI/CLI 直接输入 RTL 原始步进/计数值，并在标签/help 中标明 `5ns/step`、`8ns/step`、`20ns/step`、ADC cycles、FIFO words、us x50 等差异。

## 2. 证据入口

| 类别 | 文件/位置 | 说明 |
|---|---|---|
| RTL 模块端口 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v:42-107` | 输出给 ADC/DAC/DL5/offset/remote 的全部控制参数 |
| RTL 复位默认值 | `command_monitor_new.v:154-203` | `eth_rst` 后的默认参数 |
| RTL 写寄存器表 | `command_monitor_new.v:252-385` | `wr_reg_valid` 到各参数的地址解码 |
| RTL 读寄存器表 | `command_monitor_new.v:407-440` | `rd_reg_valid` 时可读回的地址 |
| host-app 扫描参数 | `AI-work/host-app/src/fpga_host/core/control/scan.py` | `ScanConfig.to_registers()` |
| host-app 模式计划 | `AI-work/host-app/src/fpga_host/core/control/modes.py` | normal/ultrafast/laser 写入顺序 |
| host-app DL5 参数 | `AI-work/host-app/src/fpga_host/core/control/dl5.py` | `Dl5Config` 和 safe apply 顺序 |
| host-app CLI/GUI | `cli/main.py`, `gui/panels/mode_workbench_panel.py` | 用户可调参数入口 |

## 3. 当前 host-app 默认写入计划

默认 `basic_scan.json` / GUI 初始值：

| 参数 | 当前默认 |
|---|---:|
| `rows` | `1024` |
| `cols` | `1024` |
| `adc_sample` / `dac_sample` | `20` |
| `adc_channel` | `4` |
| `adc_interval` | `0` |
| `scan_mode` | `1` |
| `clk_sel` | GUI 显式写 `0`/`1`，CLI 默认不写 |
| `adc1~4_gain` | `2` |
| `dacx/dacy_gain` | `3` |
| `dacx_strat_level` | `0x1999` |
| `dacx_end_level` | `0xE665` |
| `dacx_tk_point` | 跟随 `cols`，默认 `1024` |
| `dacx_recovery_time` | `50 us`，FPGA 内部 `x50` |
| `dacy_strat_level` | `0x3BBB` |
| `dacy_end_level` | `0xC443` |
| `frame_waiting_time` | `0 FIFO words` |
| `dax_fall_time` | `20 us`，FPGA 内部 `x50` |
| `row_repeat,row_m,row_n` | `1,0,1` |

由这些值生成的普通扫描基础寄存器：

| 地址 | 默认写入值 | 来源 |
|---|---:|---|
| `0x0000` | `0x00000000` | GUI 显式设置 `clk_sel=0`；CLI 省略时不写 |
| `0x0001` | `0x01000004` | `(rows*cols << 4) \| adc_channel` |
| `0x0002` | `0x00000014` | `adc_sample == dac_sample == 20` |
| `0x0003` | `0x00000FAA` | ADC gain=2，DAC gain=3 |
| `0x0004` | `0x04000400` | `{rows, cols}` |
| `0x0005` | `0x1999E665` | `{dacx_start, dacx_end}` |
| `0x0006` | `0x04000032` | `{dacx_tk_point, dacx_recovery_time}` |
| `0x0007` | `0x3BBBC443` | `{dacy_start, dacy_end}` |
| `0x0008` | `0x00000000` | `frame_waiting_time` |
| `0x000F` | `0x00000014` | `dax_fall_time` |
| `0x0013` | `0x00000001` | `row_repeat` |
| `0x0014` | `0x00000001` | `{row_m,row_n}` |
| `0x0009` | `0x00000010` | `{adc_interval=0, scan_mode=1, scan_state=0}` |

`--start-after` 会在计划末尾再写一次 `0x0009 = 0x00000011`，即把 `scan_state` 置 1。

## 4. 寄存器覆盖对照表

| 地址 | RTL 参数/位域 | 硬件作用 | RTL 复位默认 | RTL 读回 | host-app 当前覆盖 | 当前 host-app 设置方式/默认值 | 备注 |
|---|---|---|---:|---|---|---|---|
| `0x0000` | `clk_sel = bit0` | 时钟/触发选择位，后级消费 | `0` | 有 | GUI 覆盖，CLI 可选 | GUI 外部行触发 checkbox；CLI `--clk-sel` | `0` 自由运行，`1` 每行等 `TRIGGER_IN` |
| `0x0001` | `[24:4] adc_len_single`, `[3:0] adc_channel` | ADC 单帧长度和通道选择 | `{1, 15}` | 有 | 已覆盖 | `ScanConfig`: 默认 `0x01000004` | `adc_len_single` 默认 `rows*cols` |
| `0x0002` | `adc_sample`, `dac_sample` 同步写 | ADC 平均点数 / DAC dwell 共用参数 | `50` | 有，仅读 `adc_sample` | 已覆盖 | `ScanConfig`: 默认 `20` | host-app 强制 `adc_sample == dac_sample` |
| `0x0003` | 6 个 2-bit gain | `adc1~4_gain`, `dacx_gain`, `dacy_gain` | ADC gain=`2`, DAC gain=`3` | 有 | 已覆盖 | GUI/CLI gain 字段；默认 `0x00000FAA` | 2-bit code，不是时间 |
| `0x0004` | `[31:16] image_row`, `[15:0] image_column` | 图像行列；同步计算 `image_point`；触发 `dacy_step_flag` | `1024 x 1024` | 有 | 已覆盖 | 默认 `0x04000400` | 必须写，否则 Y 步进可能仍是复位/旧值 |
| `0x0005` | `[31:16] dacx_strat_level`, `[15:0] dacx_end_level` | X 方向 DAC 起止电平 | `0x8000,0x8000` | 有 | 已覆盖 | 默认 `0x1999E665` | CLI/GUI 未直接暴露，使用内置默认；JSON profile 可覆盖字段 |
| `0x0006` | `[31:16] dacx_tk_point`, `[15:0] dacx_recovery_time` | X 点数/恢复时间；触发 `dacx_step_flag` | `128,1` | 有 | 已覆盖 | 默认 `0x04000032` | 关键寄存器；写入才会重算 `dacx_step` |
| `0x0007` | `[31:16] dacy_strat_level`, `[15:0] dacy_end_level` | Y 方向 DAC 起止电平；触发 `dacy_step_flag` | `0x8000,0x8000` | 有 | 已覆盖 | 默认 `0x3BBBC443` | CLI/GUI 未直接暴露，使用内置默认；JSON profile 可覆盖字段 |
| `0x0008` | `frame_waiting_time` | 帧间等待时间 | `0` | 有 | 已覆盖 | GUI/CLI frame wait；默认 `0` | FIFO words，约 20ns/word，不是 us |
| `0x0009` | `[31:8] adc_interval`, `[7:4] scan_mode`, `[3:0] scan_state` | 扫描间隔、模式、启停状态 | `0x00001310` | 有 | 已覆盖 | 默认 stop=`0x00000010`，start=`0x00000011` | 注意：host-app 默认 `adc_interval=0`，覆盖 RTL reset 的 `19` |
| `0x000A` | `version_number` | 固件版本读回 | `{3,172}` | 有 | 只读 | `version` 命令读 | 不应写 |
| `0x000B` | `remote_result_reg[2]` | remote/DDR/QSPI 状态快照 | `0` | 有 | 只读 | `dump/read` 可读 | 不应写 |
| `0x000C` | `remote_rstn = bit0` | remote 数据写 DDR/QSPI 复位/使能 | `0` | 有 | raw only | register map 有；模式计划不写 | remote 升级功能需要单独流程 |
| `0x000D` | `heart_beat` | PC 心跳；写 `0x5555AAAA` 可清心跳计数 | `0` | 有 | raw only | register map 有；模式计划不写 | 当前 host-app 没有定时心跳任务 |
| `0x000E` | `pc_ack` | PC acknowledge；仅扫描运行时 `pc_ack_r` 保持 | `0xAA5555AA`/软清后 `0` | 无读回 | raw only | register map 标 write-only | 当前模式流程不使用 |
| `0x000F` | `dax_fall_time` | X 回扫/跨行等待相关时间 | `20` | 有 | 已覆盖 | 默认 `20` | 支持 raw sweep，但没有自动 sweep 脚本 |
| `0x0010` | `offset_adc1_adc2` | ADC1/2 offset 配置 | `0` | 有 | raw only | register map 有；模式计划不写 | offset/FRAM 流程未做 GUI |
| `0x0011` | `offset_adc3_adc4` | ADC3/4 offset 配置 | `0` | 有 | raw only | register map 有；模式计划不写 | offset/FRAM 流程未做 GUI |
| `0x0012` | `offset_dacx_dacy`; 写入产生 `wr_offset_flag` | DAC X/Y offset 配置并触发保存/输出 | `0` | 有 | raw only | register map 有；模式计划不写 | 写入有一拍触发副作用，建议未来做专用按钮 |
| `0x0013` | `row_repeat`，写 0 硬件强制为 1 | 行重复次数 | `1` | 有 | 已覆盖 | GUI/CLI `row_repeat`；默认 `1` | host-app 校验 >=1 |
| `0x0014` | `[31:16] row_m`, `[15:0] row_n`，`row_n=0` 强制为 1 | 行分组/重复扫描参数 | `0,1` | 有 | 已覆盖 | GUI/CLI `row_m/row_n`；默认 `0,1` | host-app 校验 `row_n>=1` |
| `0x0200` | `sync1_pixel_tri_wigth[15:0]` | ultrafast/sync1 脉宽 | `1` | 有 | 已覆盖（ultrafast） | 默认 `0`，checked write | 20ns steps，FPGA 内部 `<<2` |
| `0x0201` | `adc_acq_delay[31:0]` | ADC 采集延时 | `0` | 有 | 已覆盖（ultrafast） | 默认 `0`，checked write | ADC DCO cycles |
| `0x0202` | `[31:1] ultrafast_line_rec`, `[0] ultrafast_mode` | ultrafast 行记录参数和使能 | line_rec=`1`, mode=`0` | 有 | 已覆盖 | normal/laser 写 `0` 关闭；ultrafast 默认写 `1` 使能 | 读回值重组为 `{line_rec[30:0], mode}` |
| `0x0203` | `[31:16] sync_sig_delay1`, `[15:0] sync_sig_delay2` | sync1/sync2 延迟 | `0,0` | 有 | 已覆盖（ultrafast） | 默认 `0`，checked write | ui_clk cycles |
| `0x0204` | `acq_dead_time[31:0]` | ADC 采集死区 | `0` | 有 | 已覆盖（ultrafast） | 默认 `0`，checked write | ADC DCO cycles |
| `0x0205` | `sync2_pixel_tri_wigth[15:0]` | sync2 脉宽写参数 | `1` | 有 | 已覆盖（ultrafast） | GUI/CLI `sync2_width`，checked write | 20ns steps，FPGA 内部 `<<2` |
| `0x0206` | `scan_delay_time[15:0]` | DL5 laser 后 scan delay | `0` | 有 | 已覆盖（laser） | CLI/GUI 必填/可调；`dl5_test` 为 `100` | 正常 |
| `0x0207` | `blanker_delay_time[15:0]` | DL5 blanker delay | `0` | 有 | 已覆盖（laser） | `dl5_test` 为 `20` | 正常 |
| `0x0208` | `blanker_time[15:0]` | DL5 blanker 脉宽 | `0` | 有 | 已覆盖（laser） | `dl5_test` 为 `80` | 正常 |
| `0x0209` | `acq_data_delay_time[15:0]` | DL5 ADC/acq 延时 | `0` | 有 | 已覆盖（laser） | `dl5_test` 为 `30` | 正常 |
| `0x020A` | `acq_time[15:0]` | DL5 acq 窗宽 | `0` | 有 | 已覆盖（laser） | `dl5_test` 为 `60` | 正常 |
| `0x020B` | `laser_mode_en = bit0` | DL5 激光模式使能 | `0` | 有 | 已覆盖（laser/normal/ultrafast） | `Dl5Config`/mode plan，checked write | 已补 RTL 读回 |

## 5. 按功能分组看缺口

### 5.1 普通扫描/DAC 基础参数

host-app 已覆盖正常启动后 DAC 出波形所需的关键参数，尤其是：

- `0x0005/0x0006/0x0007/0x000F` 已纳入 `ScanConfig.to_registers()`。
- `0x0006` 会触发 `dacx_step_flag`，这是避免 X 方向步进为 0 的关键。
- `0x0004` 和 `0x0007` 会触发 `dacy_step_flag`，保证 Y 方向步进刷新。

当前不足是 X/Y 电平和 recovery/fall 参数在 GUI/CLI mode 页没有直接入口，只能靠内置默认或 JSON profile 字段覆盖。

### 5.2 ADC 采集参数

host-app 已覆盖：

- `adc_len_single`
- `adc_channel`
- `adc_sample`
- `adc_interval`
- `scan_state`

需要注意：RTL reset 默认 `adc_interval=19`，host-app 默认 `adc_interval=0`。如果硬件时序上需要保持 19，应把 host-app 默认值或 profile 改回 19；如果 0 是当前验证过的新默认，则文档应记录这个决策。

### 5.3 ultrafast 参数

host-app 已覆盖 `0x0200~0x0204`，当前 RTL 已补读回，host-app 使用 checked write。

`sync2_pixel_tri_wigth` 已按当前 RTL 写表接入 `0x0205`，并已补读回。

### 5.4 DL5 激光同步参数

host-app 已覆盖 DL5 timing 参数 `0x0206~0x020A`，并已把 laser enable 迁移到 `0x020B`：

| 项 | host-app 认为 | 当前 RTL 写表 | 当前 RTL 读表 |
|---|---|---|---|
| laser enable | `0x020B` | `0x020B` | `0x020B` |
| sync2 width | `0x0205` | `0x0205` | `0x0205` |

当前 RTL 读表已同步，host-app 可用 checked write 做闭环确认。

### 5.5 offset / remote / heartbeat / ack

这些参数在 `command_monitor_new.v` 中存在，但 host-app 目前没有专用工作流：

- `0x000C remote_rstn`
- `0x000D heart_beat`
- `0x000E pc_ack`
- `0x0010~0x0012 offset`
- `0x0013/0x0014 row repeat/group`

它们可以通过 raw register console 或 CLI `write/read` 临时操作，但没有模式化流程、参数校验、危险确认文案或专用 readback/report。

## 6. 建议的下一步

1. 确认 host-app 默认 `adc_interval=0` 是否确实优于 RTL reset 默认 `19`。
2. offset/remote/heartbeat/ack 仍建议保持 raw register 或另建专用维护流程，不混入扫描模式应用。
3. 若要上板自动验证 L8，新增 sweep 命令，批量写 `0x000F` 和 DL5 timing，并记录测量结果。

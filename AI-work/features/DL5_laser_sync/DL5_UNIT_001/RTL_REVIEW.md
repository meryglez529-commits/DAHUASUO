# DL5_UNIT_001 RTL 审查入口

> 本文件回答三个问题：AI 改了哪里、为什么改、你审 RTL 时应该重点看哪里。

> 2026-05-27 需求复核结论：本文件只用于审查 UNIT_001 的历史 RTL 改动。用户已指出第一版需求方向存在偏差；后续新需求和第二轮 RTL 审查入口见 `../DL5_UNIT_002/RTL_REVIEW.md`。

## 1. 总览

DL5 本轮 RTL 改动围绕一条新链路展开：

```text
laser_sync_in
  -> laser_sync_blanker_ctrl(ui_clk)
  -> blanker_pulse / laser_acq_pulse / laser_event_busy / pixel_done_pulse
  -> dacdata_config CDC
  -> parameter_dacdata_gen 推进像素
  -> dac_output mux 到 adc_tri / sync_pixel_tri1 / sync_pixel_tri2
```

没有新增 blanker 物理输出引脚；只新增 `laser_sync_in` 顶层输入端口。

## 2. 改动文件清单

| 文件 | 改动类型 | 为什么改 | 你重点检查 |
|---|---|---|---|
| `AXI_DDR.srcs/sources_1/new/laser_sync_blanker_ctrl.v` | 新增模块 | DL5 核心控制器 | 状态机、时间窗口、`scan_state` 门控、`laser_period - 1` 边界 |
| `AXI_DDR.srcs/sim_1/new/tb_laser_sync_blanker_ctrl.v` | 新增 testbench | 单元验证 DL5 控制器 | TC1-TC8 是否覆盖你的真实边界 |
| `AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v` | 修改 State 3 | laser 模式下一个像素只写 1 个 FIFO word，然后等激光周期结束 | `laser_pixel_written` 是否在所有路径清零；旧模式是否保持 |
| `AXI_DDR.srcs/sources_1/new/dac_output.v` | 修改输出 mux | laser 模式覆盖 `adc_tri/sync1/sync2` | blanker 极性、`adc_tri` 停扫行为、旧 ultrafast 模式是否保持 |
| `AXI_DDR.srcs/sources_1/new/dacdata_config.v` | 修改集成和 CDC | 接入 DL5 控制器，跨 `eth_clk/ui_clk/dac_dco` | CDC 同步链、`pixel_done_pulse` toggle 同步、端口接线 |
| `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` | 修改寄存器表 | 新增 6 个 DL5 参数寄存器 | 地址 0x0205-0x020A、默认值、读回值 |
| `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | 修改顶层接线 | 新增 `laser_sync_in` 并把参数接到下游 | 顶层端口、wire、模块例化 |
| `AXI_DDR.xpr` | 项目文件更新 | 把新 RTL/testbench 注册到 Vivado | `laser_sync_blanker_ctrl.v` 和 testbench 是否在工程里 |

## 3. 逐文件审查点

### 3.1 `laser_sync_blanker_ctrl.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 42-63 | 模块端口 | `laser_sync_in` 是异步输入；输出均为 `ui_clk` 域 |
| 67-92 | `laser_sync_in` 3 级同步和上升沿检测 | 50ns 脉冲在 200MHz 下理论可采到；只检测上升沿 |
| 102-105 | blanker/acq 时间换算 | blanker 单位 5ns；acq 单位 20ns，内部左移 2 变 5ns |
| 131-179 | IDLE/BUSY/DONE 状态机 | 只在 `laser_mode_en & scan_state` 为 1 时响应；DONE 只打一拍 `pixel_done_pulse_ui` |

风险关注：

- `laser_period=0` 没有 FPGA 侧夹紧；上位机必须写合法值。
- 忙期间第二个激光脉冲会被忽略，这是设计决策。
- `blanker_time=0` 或 `acq_time=0` 等价关闭对应输出，仿真已覆盖。

### 3.2 `parameter_dacdata_gen.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 65-71 | 新增 `laser_mode_en/pixel_done_pulse` 输入 | 两个信号都在 `eth_clk` 域使用 |
| 202-205 | `laser_pixel_written` | laser 模式 one-shot 写 FIFO 的核心标志 |
| 337-373 | State 3 laser 分支 | 第一次进入 State 3 写 1 个 FIFO word；之后停 `wr_en` 等 `pixel_done_pulse` |
| 253、625 | 清 `laser_pixel_written` | 复位/default 路径要清标志，避免下一像素卡住 |

风险关注：

- 旧模式分支在 `laser_mode_en=0` 时应保持原行为。
- 新模式依赖 `dac_output` 在 FIFO 不读时保持 DAX/DAY。
- 如果 `pixel_done_pulse` 丢失，State 3 会等待；上板时可用 ILA 看 `pixel_done_pulse_eth`。

### 3.3 `dac_output.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 40-49 | 新增 laser 模式输入 | 语义是否与上游一致 |
| 106-126 | `laser_mode_en` 和 `laser_acq_pulse` 到 `dac_dco` 同步 | `adc_tri` 在 `dac_dco` 域输出 |
| 244-259 | `adc_tri` mux | laser 模式下 `scan_state=0` 强制 0 |
| 381-390 | `sync_pixel_tri1` mux | `blanker_pulse` 走原有取反路径，物理输出低有效 |
| 490-491 | `sync_pixel_tri2` mux | laser 模式直接输出 `laser_event_busy` |

风险关注：

- `laser_mode_en` 与 `ultrafast_mode` 互斥由上位机保证。
- `blanker_pulse` 进入 `sync_pixel_tri1` 后被取反，示波器上看到的是低有效窗口。
- `sync_pixel_tri2` 的新语义还需要外设实测确认。

### 3.4 `dacdata_config.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 72-79 | 新增 DL5 参数和 `laser_sync_in` 端口 | 参数来自 `command_monitor_new` |
| 153-156 | CDC 说明 | 这里是 DL5 跨域总说明 |
| 168-214 | `eth_clk -> ui_clk` 双 FF | 参数慢变同步 |
| 223-237 | 例化 `laser_sync_blanker_ctrl` | `ui_clk`、`scan_state_ui`、参数接线 |
| 240-260 | `pixel_done_pulse_ui -> eth_clk` toggle 同步 | 单拍跨域不能用普通双 FF |
| 293-319 | 连接 `parameter_dacdata_gen` 和 `dac_output` | 检查 mode/pulse/blanker/acq/busy 的去向 |

风险关注：

- 参数要求先写稳定后再开 `laser_mode_en`。
- `pixel_done_pulse` 频率由激光周期决定，正常远低于 `eth_clk`，toggle 同步适用。

### 3.5 `command_monitor_new.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 100-110 | 新增 6 个输出寄存器 | 地址说明写在端口注释里 |
| 202-208 | reset 默认值 | `laser_mode_en=0`；`laser_period=400` |
| 365-385 | 写寄存器 case | 0x0205-0x020A |
| 443-448 | 读回 case | PC 可读回 DL5 参数 |

地址表：

| 地址 | 名称 | 单位 |
|---|---|---|
| `0x0205` | `laser_mode_en` | bit[0] |
| `0x0206` | `blanker_delay_time` | 5ns |
| `0x0207` | `blanker_time` | 5ns |
| `0x0208` | `acq_data_delay_time` | 20ns，内部乘 4 |
| `0x0209` | `acq_time` | 20ns，内部乘 4 |
| `0x020A` | `laser_period` | 5ns |

风险关注：

- 文件中已有一个旧问题：`0x0200` case 重复，见 341-362 行附近。本轮没有修，避免扩大 DL5 改动面。

### 3.6 `ETH_TOP.v`

关键位置：

| 行号附近 | 内容 | 审查点 |
|---|---|---|
| 157 | 新增顶层 `laser_sync_in` | 目前无 XDC 引脚约束 |
| 219-224 | 新增 DL5 参数 wire | 从命令寄存器到下游 |
| 566-571 | `command_monitor_new` 输出连接 | 6 个参数 |
| 693-699 | `dacdata_config` 输入连接 | 参数和 `laser_sync_in` 进入 DL5 链路 |

风险关注：

- `laser_sync_in` 顶层已有，但 `fpga_pin.xdc` 还没有约束引脚。

## 4. 本轮没有做的事

- 没有给 `laser_sync_in` 写 XDC，因为硬件引脚号还没确认。
- 没有修改既有 `0x0200` 重复 case 问题。
- 没有跑上板验证。
- 没有完成 DL5 集成 testbench；当前集成层验证来自 RTL elaboration 和 synth。

## 5. 审查建议

建议你按这个顺序看：

1. 先看 `laser_sync_blanker_ctrl.v`，确认 DL5 时序语义是不是你要的。
2. 再看 `dac_output.v`，重点确认 blanker 低有效和 sync2 语义。
3. 再看 `parameter_dacdata_gen.v` State 3，确认 laser 模式只写 1 个像素 word 的策略。
4. 最后看 `dacdata_config.v` 和 `ETH_TOP.v`，确认跨域和接线。

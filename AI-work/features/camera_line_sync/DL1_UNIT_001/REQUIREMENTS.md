# DL1_UNIT_001 需求 - 相机行同步

## 目标

将现有 `TRIGGER_H` 输出用作相机行有效信号，覆盖普通、超快和激光扫描模式。物理输出低有效：仅在一条有效 X 扫描线期间为低。

## 已确认需求

| 项目 | 需求 |
|---|---|
| 物理输出 | 复用顶层 `TRIGGER_H`，FPGA 引脚 F15；保留现有 XDC 的 `LVCMOS33` 约束。 |
| 极性 | 低有效：空闲为高，有效扫描线为低。 |
| 覆盖范围 | 仅有效像素区；不包含行首恢复/Tb、X 回扫、帧间等待与空闲。 |
| 普通模式 | 每一次实际 X 扫描产生一段低有效窗口。 |
| 超快模式 | 与普通模式使用相同的逐行窗口规则。 |
| 激光模式 | 第一有效激光像素开始时拉低；跨越 laser 间隙持续为低；最后一个有效激光像素结束后释放。 |
| `row_repeat` | 每一次重复的实际 X 扫描均视为一行，各自产生一个窗口。 |
| FIFO/IP 范围 | 不修改 `fifo_generator_4` 宽度、XCI 和现有 35-bit 接口。 |

## 已有事实

- `ETH_TOP.v:875` 当前将 `TRIGGER_H` 固定为 `1'b0`，尚未承担功能。
- `fpga_pin.xdc:90,111` 将 `TRIGGER_H` 约束到 F15/LVCMOS33。
- 普通与超快模式的有效像素由 `parameter_dacdata_gen` 的 State 3 写入，且 `adc_tri=1`。
- 激光模式每次收到有效 laser 边沿后，由 State 16 写入一个像素；State 14 等待期间不写 FIFO，`dac_output` 在无读操作时保持末级寄存器。
- 当前激光模式会将 FIFO `[32:34]` 强制清零；sync1 blanker 已走独立 laser 路径，故 `[34]`、`[33]` 仅在激光模式可复用。

## RTL 必须满足的行为

1. `dac_output` 增加内部高有效 `camera_line_active` 与低有效 `camera_line_sync` 输出。
2. 普通与超快模式中，`camera_line_active` 必须跟随 DAC 时钟域真实的 `adc_tri` 有效区，不能使用上游 `eth_clk` 状态机直接驱动。
3. 激光模式中，FIFO `[34]` 为单 word 行开始标志，FIFO `[33]` 为单 word 行结束标志；`dac_output` 收到开始后锁存有效，收到最后像素标志后在下一 DAC 时钟撤销。
4. 激光模式的位复用不得进入原有 sync1/sync2 整形器，也不得改变 `TRIGGER_OUT`。
5. `ETH_TOP` 仅替换 `assign TRIGGER_H = 1'b0`；`TRIG_V`、`TRIG_CLOCK`、`TRIG_BLANK`、`TRIGGER_OUT` 保持原有语义。

## 待确认硬件项

RTL 与 XDC 定义 F15 为 3.3 V CMOS。上板前应确认相机同步输入可接受 3.3 V、低有效 CMOS 信号，且线缆连接至板卡 `TRIG_H` 接口。

## 不在本单元范围

- 修改 FIFO 位宽/IP 或 XDC。
- 增加上位机可见的延时、脉宽配置寄存器。
- 改变 DAC 模拟数据、ADC 触发、激光 blanker 或既有超快同步输出。

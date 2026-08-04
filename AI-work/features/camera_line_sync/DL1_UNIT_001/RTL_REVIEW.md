# DL1_UNIT_001 RTL 审查

## 2026-08-04 实现后审查

| 文件 | 变更 | 审查结论 | 风险 |
|---|---|---|---|
| `parameter_dacdata_gen.v` | 激光 State 16 用 FIFO `[34]/[33]` 标记本行首/尾 word | 非激光模式仍使用既有 sync 位；FIFO 宽度不变 | `dacx_tk_point`、`dac_sample` 必须保持既有的非零合法约束 |
| `dac_output.v` | 增加 DAC 域 `camera_line_active`、末 word 后一拍释放和低有效输出 | 普通/超快跟随拆包后的 `[32]`；激光标记被屏蔽在旧 sync 整形器外 | `laser_mode_en` 运行中切换仍沿用项目原有 CDC 假设，应仅在停扫时切换 |
| `dacdata_config.v` | 透传相机同步端口 | 不改变 DAC、ADC、sync1/2 数据或控制路径 | 低 |
| `ETH_TOP.v` | `TRIGGER_H` 从常量 0 改接相机同步 | F15/XDC 不变；其他 TRIG 输出未修改 | 上板前确认相机输入接受 3.3V、低有效 CMOS |

聚焦仿真覆盖普通、超快、激光间隔、激光行尾和激光标记不进入旧 sync2，结果 PASS。独立综合未达到时序门，详见 `IMPLEMENTATION.md`；不得据此生成 bitstream。

## 审查状态

待实施。

## 必查项

| 项目 | 检查要求 |
|---|---|
| FIFO 合约 | FIFO 必须保持 35 bit，不得编辑 XCI/IP。 |
| 普通/超快 | `TRIGGER_H` 仅在 DAC 域 `adc_tri` 有效区为低。 |
| 激光行首 | FIFO `[34]` 只能在一行首像素置位并置行有效锁存。 |
| 激光行尾 | FIFO `[33]` 必须在最后像素完成之后才撤销行有效。 |
| 激光隔离 | 位复用不得触发 sync1/sync2 状态机或改变 `TRIGGER_OUT`。 |
| 模式保持 | `laser_mode_en=0` 时 FIFO `[34:33]` 的既有 sync 行为不变。 |
| IO 保持 | 仅替换 `TRIGGER_H` 固定 0 驱动，XDC 不变。 |

## 审查证据

待 RTL diff 与仿真完成后填写。

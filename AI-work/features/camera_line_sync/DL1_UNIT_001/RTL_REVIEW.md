# DL1_UNIT_001 RTL 审查

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

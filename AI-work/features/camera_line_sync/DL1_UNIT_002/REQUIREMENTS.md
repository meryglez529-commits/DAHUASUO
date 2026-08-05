# DL1_UNIT_002：修复激光模式相机行同步错位

## 1. 问题与已确认事实

相机行同步输出为低有效信号 `camera_line_sync`，顶层由 `ETH_TOP` 接到 `TRIGGER_H`。普通模式的上板 DAC-ILA 对照已通过：每一条 16 点、每点 1 us 扫描线得到连续 16.000 us 的低电平，并在回扫和行首恢复阶段回到高电平。

激光模式的同一输出始终为高。该结论不是由外部接线推测得出，而是由 `DL5_UNIT_006` 的 ETH/DAC 双时钟 ILA 同时证明：

- 在 `parameter_dacdata_gen.v` 中，激光行首标记 FIFO[34] 由 `State16 && dac_sample_cnt==0` 组合生成；
- `para_config_wr_en` 是 State16 内以非阻塞赋值更新的寄存器。实际首笔 FIFO 写入发生时，计数器已经从 0 进入后续值，FIFO[34] 没有写入首个有效像素 word；
- 行尾 FIFO[33] 也没有和最终 DAX/DAY word 使用同一寄存器流水级，DAC-ILA 已看到它早于最终 `0xE664` 像素出现。因此仅修正 bit34 会造成行同步在末点前提前释放。

原始证据：`../../DL5_laser_dax_diagnosis/DL5_UNIT_006/out/ila/eth_full_line_TRIG_20260805_144245.csv` 与 `../../DL5_laser_dax_diagnosis/DL5_UNIT_006/out/ila/dac_tail_camera_TRIG_20260805_144245.csv`。

## 2. 已确认需求

| 编号 | 需求 |
|---|---|
| R1 | 仅修复激光模式下相机同步标记与实际 FIFO 有效 word 的错位；普通、超快模式的功能语义不得改变。 |
| R2 | 激光模式下 `TRIGGER_H` 为低有效：从本行首个有效 DAX/DAY word 输出开始拉低，到本行最后一个有效 DAX/DAY word 输出完毕后释放。 |
| R3 | 两个相邻激光脉冲之间没有新 FIFO word 时，输出仍必须保持低；该空隙仍属于同一条扫描线。 |
| R4 | 释放必须与回扫/非像素的第一个 DAC word 对齐，不能覆盖回扫，也不能在最终像素之前变高。 |
| R5 | 不改变异步 DAC FIFO 的宽度、深度、IP、复位、读写使能策略、寄存器地址、上位机协议、XDC 或物理引脚。 |
| R6 | 修复必须覆盖 `dac_sample=1` 的边界条件；此时同一有效 word 可同时携带行首和行尾标记。 |

## 3. 范围与非目标

本单元只处理 FIFO[34]/[33] 在激光模式下的写侧对齐问题。

- 不修改 `State14` 的激光等待逻辑；它还负责 blanker/采集触发，借用它修相机信号会引入额外触发风险。
- 不修改 DAC FIFO 格式 `{sync2, sync1, adc_tri, DAX, DAY}`，也不把相机信号改为独立 FIFO 或新寄存器。
- 不在本单元同时修复此前记录的行首恢复模型、外部激光周期、blanker 可靠性或模拟波形问题。
- 不以示波器上视觉估计替代 DAC 时钟域 ILA 的对齐判定。

## 4. 验收标准

1. 激光模式、16 X 点、`dac_sample=50`：DAC ILA 中 FIFO[34] 恰好出现在首个有效 DAX word，FIFO[33] 恰好出现在最后一个有效 DAX word；`camera_line_sync` 在两者之间持续为低。
2. 最后一个有效 DAX word 仍处于低电平窗口内；第一个回扫 word 开始时为高电平。
3. 同一参数下普通模式继续得到 16.000 us 的低窗口、6.000 us 的高窗口；超快模式保留原 FIFO[32]/原 sync1、sync2 行为。
4. `dac_sample=1`、单 X 点及多 X 点边界用例无漏起始、无提前释放。
5. RTL 仿真、综合、实现和上板 ILA 全部留存可复现证据；若时序或资源不满足，不生成交付 bitstream。

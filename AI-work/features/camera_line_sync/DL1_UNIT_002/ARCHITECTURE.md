# DL1_UNIT_002：激光相机行同步错位修复架构（待实施）

## 1. 结论

采用最小改动的“标记寄存化并与 DAX/DAY 同流水级写 FIFO”方案。

不改变 DAC FIFO，也不改变 `dac_output.v` 的激光行同步状态机。写侧的 FIFO[34]/[33] 不再使用 `current_state` 和计数器直接组合出来的 `laser_line_start/end`，而是复用已经与 `DAX_DATA`、`DAY_DATA`、`para_config_wr_en` 同拍更新的 `sync_pixel_tri2/1` 寄存器。这样 FIFO 在实际接受一个 word 时，标记、DAX、DAY 来自同一条寄存器流水线。

## 2. 当前错误时序

| State16 观察点 | 组合 FIFO[34] | 已寄存的 `para_config_wr_en` | 实际结果 |
|---|---:|---:|---|
| 首次进入，`dac_sample_cnt=0` | 1 | 0 | 首行标记出现，但 FIFO 不写入。 |
| 下一拍，开始实际写入 | 0 | 1 | 首个有效 DAX/DAY word 没有 bit34。 |
| 末点附近 | bit33 按当前组合计数产生 | 与 DAX/DAY 的寄存器级不同 | bit33 会早于最终有效 DAX/DAY word。 |

因此，错误并不在 DAC 域相机状态机、TRIGGER_H 物理输出或外部 laser 输入，而是写侧“组合 marker”和“寄存器化 FIFO 写 word”之间多出的一个流水级。

## 3. RTL 改动设计

目标文件：`AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v`。

### 3.1 FIFO 打包

保留 bit32 的激光模式语义，取消 bit33/34 的激光组合旁路：

```verilog
// 保留：激光 ADC 触发走独立路径，FIFO[32] 为 0。
wire fifo_bit32 = laser_mode_en ? 1'b0 : adc_tri;

// 修复：所有模式都从同一组已寄存的像素标记打包。
wire fifo_bit33 = sync_pixel_tri1;
wire fifo_bit34 = sync_pixel_tri2;
assign para_config_data = {fifo_bit34, fifo_bit33, fifo_bit32, DAX_DATA, DAY_DATA};
```

删除仅服务于上述旁路的 `laser_line_start`、`laser_line_end` 组合 wire，避免以后再次绕开实际 FIFO 写流水。

### 3.2 State16 中同拍生成 marker

在激光模式唯一的 `State16` 写 word 分支中，和现有 `DAX_DATA`、`DAY_DATA`、`para_config_wr_en` 一起赋值：

```verilog
sync_pixel_tri2 <= (dacx_tk_point_cnt == 16'd0) &&
                   (dac_sample_cnt == 32'd0);
sync_pixel_tri1 <= (dacx_tk_point_cnt == dacx_tk_point - 1'b1) &&
                   (dac_sample_cnt == dac_sample - 1'b1);
```

上述代码是实施意图，不是已下发修改。前提沿用当前合法参数约束：`dacx_tk_point >= 1`、`dac_sample >= 1`。实施时需保持非激光状态对两个寄存器的原有赋值不变，并将该条件写成与现有位宽一致的形式。

### 3.3 DAC 域保持不动

`dac_output.v` 继续使用当前机制：FIFO[34] 置位 `camera_line_active`，FIFO[33] 置位 `camera_line_end_pending`，下一 DAC 时钟释放。

修复后，bit33 所在 word 就是最终有效 DAX/DAY word；因此在读出该 word 的周期相机仍低，下一周期装载回扫 word 时输出转高，恰好满足“有效像素区按整行覆盖”。`dac_sample=1` 时 bit34、bit33 同在一个 word：状态机先启动低窗口、再挂起结束，下一拍释放，仍可正确覆盖这个唯一像素。

## 4. 数据、控制和 CDC 边界

| 项目 | 源时钟域 | 目的时钟域 | 方案 | 本次是否改变 |
|---|---|---|---|---|
| FIFO[34]/[33] 与 DAX/DAY | 写侧扫描状态机（`eth_clk`） | DAC FIFO 读侧（`dac_dco`） | 既有异步 FIFO | 否；仅使各位同寄存器级。 |
| 相机行有效状态 | FIFO 读侧 | `dac_dco` | `camera_line_active/end_pending` | 否。 |
| `camera_line_sync` 至 TRIGGER_H | `dac_dco` | FPGA 输出 | 既有组合取反 | 否。 |
| 激光输入、blanker、采集触发 | 各自既有 CDC | 既有域 | 不触及 State14 | 否。 |

本方案没有增加 CDC、异步控制或 FIFO 背压耦合；仅消除既有写侧的时序错位。

## 5. 兼容性约束

| 模式 | 修复前正确路径 | 修复后预期 | 必测回归 |
|---|---|---|---|
| 普通 | FIFO[32] 直接控制相机低窗口 | 完全相同 | 16 点、`dac_sample=50` 的 16 us 低 / 6 us 高。 |
| 超快 | FIFO[32] 控制相机；sync1/2 保留原整形 | 完全相同 | 相机窗口与 legacy sync1/2 同时观察。 |
| 激光 | FIFO[34]/[33] 错位 | 首/末有效 word 精确对齐，跨激光间隔保持低 | 16 点及边界用例。 |

不修改 `dac_output.v` 的功能逻辑是兼容性关键：普通/超快的已验证 FIFO[32] 路径完全不经过此次修复的 State16 激光 marker 条件。

## 6. 一次性补齐的 ILA 观测方案

为避免仅靠外部波形猜测，在修复版本中保留现有 `ila_2` 的深度和 IP 配置，仅重新利用当前 16-bit `probe2`（原为 DAY，非本问题的关键量）：

```text
probe2[3] = laser_mode_en_dac
probe2[2] = camera_line_active
probe2[1] = para_config_dout[34]  // 实际读出的行首 word
probe2[0] = para_config_dout[33]  // 实际读出的行尾 word
probe2[15:4] = 0
```

同时保留：`probe0=camera_line_sync`、`probe1=DAX_DATA`、`probe3=prog_empty`、`probe4=para_config_rd_en`、`probe5=para_config_rd_en_r`、`probe6=FIFO[33]`。这只改变 ILA 输入连接，不改 `.xci` 端口宽度、采样深度或 XDC。它能在一次重新实现后同时确认：行首、行尾、相机状态、FIFO 读时序和实际 DAX 输出的相对关系。

## 7. 验证计划与通过门槛

| 阶段 | 用例/检查 | 通过条件 |
|---|---|---|
| 写侧仿真 | 实例化真实 `parameter_dacdata_gen`，记录每个 `para_config_wr_en` 的 35-bit word | 首个实际写入 word 仅一次 bit34=1；末个实际写入 word 仅一次 bit33=1。 |
| DAC 域仿真 | 基于 DL1_UNIT_001 的 `dac_output` 受控 FIFO testbench | 低窗口覆盖首/末 word，空档不释放，首个 tail word 变高。 |
| 边界仿真 | `dac_sample=1`、`dac_sample=4`、`dac_sample=50`；单 X 和多 X | 无漏首、无提前尾、无额外窗口。 |
| 普通/超快回归 | 原 DL1_UNIT_001 的 TC1/TC2/TC5 加精确窗口断言 | FIFO[32] 相机语义和 legacy sync 语义不变。 |
| 综合/实现 | 项目管理 `synth_1 -> impl_1`，再写 bitstream | 0 ERROR / 0 CRITICAL WARNING；时序、BRAM 与现有诊断构建比较并记录。 |
| 上板 ILA | 激光 16x16、`dac_sample=50`、2 us laser 周期 | bit34 与第一个有效 DAX 同拍，bit33 与最终有效 DAX 同拍，且 `camera_line_sync` 跨全部激光间隔为低。 |
| 示波器复核 | CH 接 TRIGGER_H，另一通道接 AOUT1/DAX | 低窗口从首像素至末像素；回扫开始转高。 |

仿真先通过才启动综合；实现时序收敛才生成 bitstream；上板验收必须同时具备 ILA 和示波器观察。任何一项不满足都停止交付并保留日志。

## 8. 回退

本次不修改 FIFO/IP/XDC，因此回退只需重新下载已验证的诊断镜像及配套 LTX：

`../../DL5_laser_dax_diagnosis/DL5_UNIT_006/out/bitstream/ETH_TOP_dl5_dax_diag.bit`

`../../DL5_laser_dax_diagnosis/DL5_UNIT_006/out/bitstream/ETH_TOP_dl5_dax_diag.ltx`

代码回退使用本单元实施前的 Git 提交；在没有全部验证通过前，不将修复镜像作为稳定版本。

# parameter_dacdata_gen.v 新旧版本对比

> 对比时间：2026-05-22
> 旧版：`AXI_DDR.srcs/parameter_dacdata_gen_old.v`（407 行，14.8 KB，用户手动备份）
> 新版：`AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v`（585 行，26.9 KB，当前工程在用）
> diff 量级：+241 行 / −63 行

新版相对旧版**新增了 3 项功能 + 1 个预留端口**，并把 FIFO 字段从 33-bit 扩到 35-bit。新版还做了 Mode 3 式的中文教学性注释，那部分不算功能差异。

---

## 1. 双路同步脉冲输出（sync_pixel_tri1 / sync_pixel_tri2）

**最大的新增功能。** 每个像素 ADC 采样窗口（State 3）的**前 N 拍**输出 sync 高电平，让外部设备能拿到比 `adc_tri` 更精细的"采样开始"标记。

新增输入：

| 端口 | 位宽 | 含义 |
|---|---|---|
| `sync1_pixel_tri_wigth` | 16-bit | sync1 的脉冲宽度（拍数） |
| `sync2_pixel_tri_wigth` | 16-bit | sync2 的脉冲宽度（拍数）|

新增内部寄存器：`sync_pixel_tri1`、`sync_pixel_tri2`

行为（在 [State 3](../../AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v#L343-L350)）：

```verilog
if(dac_sample_cnt < sync1_pixel_tri_wigth - 1)
    sync_pixel_tri1 <= 1'b1;
else
    sync_pixel_tri1 <= 1'b0;
if(dac_sample_cnt < sync2_pixel_tri_wigth - 1)
    sync_pixel_tri2 <= 1'b1;
else
    sync_pixel_tri2 <= 1'b0;
```

其余所有状态（0/1/2/11/12/13/default）显式清零 sync_pixel_tri1/2，保证只在像素采样窗口里跳。**两路独立宽度**——典型用途是给两个不同设备分别送同步标志。

---

## 2. ultrafast 扫描模式（线首恢复时间双套路）

新增输入：

| 端口 | 位宽 | 含义 |
|---|---|---|
| `ultrafast_mode` | 1-bit | 0 = 常规 Tb；1 = 用 ultrafast_line_rec |
| `ultrafast_line_rec` | 32-bit | 超快模式下的线首恢复时间（同样 *50 转 FIFO word） |

实现：

| 旧版 | 新版 |
|---|---|
| `dacx_tb_point` 是 wire（32-bit），直接连 `dacx_recovery_time*50` | `dacx_tb_point` 改成 **reg（36-bit）**，在 [State 0](../../AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v#L260-L263) 根据 `ultrafast_mode` 二选一装入 |
| 没有 ultrafast 概念 | 新增两个常驻 wire：`dacx_tb_point_reg`（旧逻辑的 50× 倍乘）和 `ultrafast_line_rec_reg`（新增的 50× 倍乘） |

```verilog
// 新版 State 0
if(ultrafast_mode == 1'b1)
    dacx_tb_point <= ultrafast_line_rec_reg;
else
    dacx_tb_point <= dacx_tb_point_reg;
```

注意：`ultrafast_mode` 在 State 0 才采样，所以**这个开关只在每条扫描线的开始处生效**，扫描过程中切换不会马上影响 Tb。

---

## 3. 像素采样长度上限提升

| 参数 | 旧版位宽 | 新版位宽 | 含义 |
|---|---|---|---|
| `dac_sample` 端口 | `[23:0]` | `[31:0]` | 每像素最长拍数：16M → 4G |
| `dac_sample_cnt` 内部 | `[23:0]` | `[31:0]` | 跟着扩 |
| `dacx_tb_point_cnt` 内部 | `[31:0]` | `[35:0]` | Tb 计数器扩，因为新版要兼容 ultrafast 的 32-bit 输入再 ×50 = 36-bit |
| `dacx_tb_point` 寄存器 | wire 32-bit | reg 36-bit | 同上 |

允许更慢的扫描或更长的像素停留（典型用途：低速、高精度 SEM 成像）。

---

## 4. 预留端口 line_count / line_count_en

```verilog
output reg [15:0] line_count,
output reg        line_count_en,
```

新版注释明确说："本模块当前不驱动这两个信号，超快行号实际由 `adcdata_acq` 生成并回传"（[parameter_dacdata_gen.v:65-67](../../AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v#L65-L67)）。

**这是顶层例化匹配用的占位**。DL2 的 ADC 通路里 `adcdata_acq` 提供 line_count，最终上层可能两边接同名端口，所以这边也声明出来。改新功能时如果不涉及"行号"，可以忽略这俩。

---

## 5. FIFO word 格式（35-bit）

| bit | 旧版（33-bit） | 新版（35-bit） |
|---|---|---|
| `[34]` | — | **`sync_pixel_tri2`** ← 新增 |
| `[33]` | — | **`sync_pixel_tri1`** ← 新增 |
| `[32]` | `adc_tri` | `adc_tri` |
| `[31:16]` | `DAX_DATA` | `DAX_DATA` |
| `[15:0]` | `DAY_DATA` | `DAY_DATA` |

```verilog
// 旧版 line 64
assign para_config_data = {adc_tri, DAX_DATA, DAY_DATA};
// 新版 line 119
assign para_config_data = {sync_pixel_tri2, sync_pixel_tri1, adc_tri, DAX_DATA, DAY_DATA};
```

`para_config_data` 端口位宽也从 `[32:0]` 改成 `[34:0]`。

---

## 6. 配对改动清单（联动检查）

新版扩了 FIFO 宽度，**以下文件必须同步改过**：

| 联动点 | 文件 / IP | 怎么验证 |
|---|---|---|
| 异步 FIFO 宽度 | `fifo_generator_4.xci` | xci 里 `Input Data Width` / `Output Data Width` 是否是 35-bit |
| 下游拆包 | `AXI_DDR.srcs/sources_1/new/dac_output.v` | 读 FIFO 后是否把 `[34]/[33]` 拆给 sync 输出 |
| sync 输出引脚 | `AXI_DDR.srcs/constrs_1/new/fpga_pin.xdc` | 是否有 sync_pixel_tri1/2 对应的 IO 约束 |
| 顶层例化 | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` 和 `dacdata_config.v` | 是否传入 `sync1_pixel_tri_wigth`、`sync2_pixel_tri_wigth`、`ultrafast_mode`、`ultrafast_line_rec` |
| 寄存器配置 | `command_monitor_new.v` + `dacdata_config.v` | PC 写哪个寄存器映射到这 4 个参数 |

> 这份对比文档**没有**核对上面这些联动点。要新增功能前，至少要先确认 `dac_output.v` 已经会拆 35-bit、`fifo_generator_4` 已经是 35-bit、xdc 里有 sync 引脚——否则新功能落不到外部。

---

## 7. 不变的部分（仅做了注释加强）

- 14 个 state 的整体结构和跳转关系
- 三个除法器例化（`row_step_div`、`row_cycle_div`、`dax_step_div`）
- 交错扫描逻辑（State 6~10）
- 行重复（State 5）、帧等待（State 11）、X 下降斜坡（State 12/13）
- 反压握手（`para_config_prog_full` / `wr_rst_busy`）
- 复位与 default 兜底

---

## 8. 用户的下一步意图（2026-05-22 对话）

用户表示当前不是调任何一个已有的新功能，而是要"**在新版基础上再新增一个功能**"。

具体新增什么功能待用户后续告知。本文件作为闭环起步点：

- 提醒新增功能前先看上面"配对改动清单"是否齐全
- 提醒新增信号要追加到 FIFO word 时，必须**同步**改 `fifo_generator_4` 和 `dac_output.v`
- 提醒 ultrafast_mode 只在 State 0 采样，切换时机要想清楚

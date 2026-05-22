# DL2 ADC-DDR-Ethernet 代码阅读指导手册

这份文档用于精读 DL2：从 AD9258 采样输入开始，经 ADC 采样/平均、通道聚合、FDMA 写 DDR、FDMA 读 DDR、以太网 UDP 发送，最后到 SGMII 发送口。

它不是架构摘要，而是一份“带你重新打开源码”的阅读手册。第一遍读的时候，把本文和源码并排放，按步骤搜关键字，不要从每个文件第一行一路读到底。

## 0. 使用方法

DL2 的真实生产方向是输入链路，所以第一遍按数据正向读：

```text
AD9258 并行数据和 DCO
  -> ETH_TOP 顶层裁位和连线
  -> adcdata_config 包装层
  -> adcdata_acq 单通道采样/平均
  -> row_repeat_module 行重复平均
  -> adcdata_get 多通道聚合成 64-bit
  -> fdma_controller1_write 写 DDR
  -> MSXBO_FDMA_1 / MIG DDR3
  -> fdma_controller1_read 从 DDR 读回
  -> LAN_TX_FREAME 转成以太网 8-bit payload
  -> ETHERNET_TOP / LAN_TX_MUX / LAN_TX_TOP / lan_tx
  -> UDP 32001 发送
```

推荐阅读顺序如下：

| Pass | 打开文件 | 本轮只解决的问题 |
|---:|---|---|
| 1 | `ETH_TOP.v` | DL2 外部 ADC 输入、内部主信号、DDR/以太网接口名是什么 |
| 2 | `adcdata_config.v` | DL2 内部由哪些子模块串起来，主数据在哪里换时钟域 |
| 3 | `adcdata_acq.v` | 单路 ADC 如何在 DCO 域按触发、间隔、平均数产生 16-bit 点 |
| 4 | `row_repeat_module.v` | 单路平均点进入 `ui_clk` 后如何做行重复平均 |
| 5 | `adcdata_get.v` | 1/2/4 路 ADC 如何按 `adc_channel` 打成 64-bit |
| 6 | `fdma_controller1_write.v` | 64-bit 点包如何按 128 beat 写入 DDR |
| 7 | `system.bd` 与 `MSXBO_FDMA` | `pkg1_*` 读写请求如何进入 MIG DDR3 |
| 8 | `fdma_controller1_read.v` | DDR 中的数据什么时候被读出 |
| 9 | `LAN_TX_FREAME.v` | DDR 读出的 64-bit 数据如何转成 UDP payload |
| 10 | `ETHERNET_TOP.v`、`LAN_TX_MUX.v`、`LAN_TX_TOP.v`、`lan_tx.v` | payload 如何被仲裁、封 UDP/IP/ETH 头并送到 TEMAC |
| 11 | `command_monitor_new.v` | 哪些上位机寄存器影响 DL2 |

每个主要步骤都按固定格式写：

```text
本步目标
搜索入口
本模块相关信号
先忽略
代码阅读顺序
读完应能回答
下一步
```

## 1. 先建立最小心智模型

DL2 的业务数据是 ADC 采样结果，不是 DDR 本身，也不是以太网本身。DDR 是缓存，UDP 是回传通道。

### 1.1 主数据形态

| 位置 | 数据名 | 位宽 | 语义 | 有效条件 | 变化 |
|---|---:|---:|---|---|---|
| 顶层 ADC 管脚 | `adc1_da/db`, `adc2_da/db` | 16 each | AD9258 并行采样输入 | 对应 `adc*_dco*` 边沿 | 外设输入 |
| 顶层送入采集模块 | `adc*_d*[15:2]` | 14 each | 截掉低 2 bit 的 ADC 样本 | 顶层连续连接 | 16-bit 输入裁成 14-bit |
| 单通道采集输入 | `{2'b0, adc*_d[13:0]}` | 16 | 补 0 后的无符号样本 | `adc_dco` 域 | 14-bit 扩成 16-bit |
| 单通道平均输出 | `adc_average_data[39:24]` | 16 | `adc_sample_reg` 个点的平均值 | `adc_average_data_en` | 累加除法后取商的 16 bit |
| 行重复后输出 | `div_adc*_out` | 16 each | 可选多行重复平均后的每通道样本 | `div_adc_rd_en` 读出 | DCO 域跨到 `ui_clk`，再可能按 `row_repeat` 平均 |
| 多通道聚合 | `adc_data_mix` | 64 | 按 `adc_channel` 选择后的 1/2/4 通道样本包 | `adc_data_mix_wr_en` | byte swap 后打包 |
| FDMA 写 DDR | `pkg1_wr_data` | 64 | 写入 DDR 的 ADC 数据 beat | `pkg1_wr_en` | 128 beat 为一包 |
| FDMA 读 DDR | `pkg1_rd_data` | 64 | 从 DDR 读出的 ADC 数据 beat | `pkg1_rd_en` | 128 beat 为一包 |
| UDP payload FIFO | `fifo_dout` | 8 | 待发 UDP payload 字节 | `fifo_rd_en` | 64-to-8 宽度转换 |
| 以太网发送 | `data_tx_data` | 8 | 交给 UDP 发送仲裁的数据字节 | `data_tx_valid` | 加 12 字节应用头，再由 `lan_tx` 加网络头 |

### 1.2 最小通路图

```text
adc1_da/db, adc2_da/db + adc DCO
  -> adcdata_acq x4
     - trigger: adc_tri
     - average: adc_sample / adc_sample_reg
     - CDC: fifo_generator_1, adc_dco -> ui_clk
  -> row_repeat_module x4
     - optional row repeat averaging
     - output FIFO in ui_clk
  -> adcdata_get
     - channel selection by adc_channel
     - output adc_data_mix[63:0]
  -> fdma_controller1_write
     - fifo_generator_3
     - pkg1_wr_* to MSXBO_FDMA_1
  -> DDR3 through system.bd / MIG
  -> fdma_controller1_read
     - pkg1_rd_* from MSXBO_FDMA_1
  -> LAN_TX_FREAME
     - fifo_generator_9, ui_clk 64-bit -> eth_clk 8-bit
     - app frame header AA55/CC55
  -> ETHERNET_TOP / LAN_TX_MUX / LAN_TX_TOP / lan_tx
  -> UDP destination port 32001
```

### 1.3 时钟域

| 时钟域 | 来源 | DL2 中的作用 |
|---|---|---|
| `adc1_dcoa/b`, `adc2_dcoa/b` | AD9258 DCO 输入，经 BUFG | 每路 ADC 原始采样、触发状态机、求平均 |
| `ui_clk` | MIG `ui_clk`，200 MHz | 行重复、通道聚合、FDMA 写/读 DDR |
| `eth_clk` / `user_axis_clk` | SGMII/TEMAC 用户时钟 | UDP payload 发包、以太网仲裁 |
| `clk200m` | `sysclk` PLL/MMCM | MIG sys/ref clock，不直接承载 DL2 payload |

## 2. 第一步：打开 `ETH_TOP.v`

文件：`AXI_DDR.srcs/sources_1/new/ETH_TOP.v`

本步目标：确认 DL2 的外部输入边界、内部主模块、DDR `pkg1_*` 通道和以太网发送接口。

搜索入口：

```text
adcdata_config U5
adc1_da
adc2_da
adc1_dcoa
adc2_dcob
pkg1_wr
pkg1_rd
data_tx_data
prog_full
adc_tri
```

本模块相关信号：

| 类别 | 信号/实例 | 作用 |
|---|---|---|
| ADC 外部数据 | `adc1_da/db`, `adc2_da/db` | 两片 AD9258 的 4 路并行数据 |
| ADC 外部时钟 | `adc1_dcoa`, `adc1_dcob`, `adc2_dcoa`, `adc2_dcob` | 每通道采样 DCO |
| 顶层裁位 | `adc*_d*[15:2]` | 只把 14 bit 送入 DL2 |
| 触发输入 | `adc_tri` | 来自 DAC 链路，启动 ADC 采集窗口 |
| DL2 包装层 | `adcdata_config U5` | DL2 主数据链路入口 |
| DDR ADC 通道 | `pkg1_wr_*`, `pkg1_rd_*` | 连接 `system_wrapper` 的第二路 FDMA |
| 以太网 payload | `data_tx_data`, `data_tx_valid`, `data_req`, `data_ACK`, `prog_full`, `tx_data_done` | 交给 `ETHERNET_TOP` 的 ADC 数据发送接口 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `ddr3_ctrl U07` 的 `pkg_*` | 那是远程升级/配置 DDR 通路，不是 DL2 |
| DAC 输出 `DAX_DATA/DAY_DATA` 的细节 | 只需要知道它产生 `adc_tri` |
| `fram_cfg`, `offset_dac_cfg`, `multiboot` | 支撑配置或升级，不承载 DL2 ADC 数据 |
| AD9258 SPI 配置细节 | 先只读采样数据路径，不读芯片寄存器初始化 |

代码阅读顺序：

1. 先看顶层端口中 ADC 数据和 DCO 端口。
2. 搜 `system_wrapper U3`，确认 `pkg1_wr_*` 和 `pkg1_rd_*` 接到 BD。
3. 搜 `adcdata_config U5`，看 ADC 输入、参数输入、以太网发送接口、DDR `pkg1_*` 连接。
4. 注意顶层把 `adc*_d*[15:2]` 接入 `adcdata_config`，不是完整 16 bit。
5. 搜 `dacdata_config U6` 附近，只确认 `adc_tri` 的来源，不展开 DAC 链路。

读完应能回答：

```text
DL2 的外部 Source 是 4 路 AD9258 并口数据加各自 DCO。
顶层把每路 [15:2] 送进 adcdata_config，模块内部再补 2 bit 到 16 bit。
DL2 使用 system_wrapper 的 pkg1_wr/pkg1_rd 这一路 FDMA，不是远程升级那一路 pkg_wr/pkg_rd。
ADC 数据最终通过 ETHERNET_TOP 的 data_req/data_tx_data/data_tx_valid 接口发送。
```

下一步：打开 `adcdata_config.v`，确认 DL2 内部模块串接。

关键证据：

| 证据 | 文件位置 |
|---|---|
| `adcdata_config U5` 接顶层 ADC、以太网和 `pkg1_*` | `ETH_TOP.v:489-537` |
| 顶层裁位 `[15:2]` | `ETH_TOP.v:498-501` |
| `system_wrapper` 暴露 `pkg1_*` 第二路 FDMA | `ETH_TOP.v:411-422` |
| `adc_tri` 来自 DAC 链路 | `ETH_TOP.v:486-487`, `ETH_TOP.v:577-581` |

## 3. 第二步：打开 `adcdata_config.v`

文件：`AXI_DDR.srcs/sources_1/new/adcdata_config.v`

本步目标：把 DL2 的内部流水线分成 5 段：4 路采样、通道聚合、DDR 写、DDR 读、以太网发包。

搜索入口：

```text
module adcdata_config
BUFG
adcdata_acq
adcdata_get
fdma_controller1_write
fdma_controller1_read
LAN_TX_FREAME
adc_data_mix_wr_en
pkg_rd_en
```

本模块相关信号：

| 类别 | 信号/实例 | 作用 |
|---|---|---|
| ADC DCO BUFG | `adc1_dcoa_bufg` 等 | 把外部 DCO 变成内部采样时钟 |
| 单通道输出 | `div_adc*_out` | 每路采样/平均/行重复后的 16-bit 数据 |
| 单通道可读计数 | `div_adc*_rd_data_count` | 给聚合模块判断是否足够读 |
| 聚合读使能 | `div_adc_rd_en` | 同时从各路输出 FIFO 读一个聚合周期 |
| 64-bit 写入 | `adc_data_mix_wr_en`, `adc_data_mix_wr_fifo` | 进入 DDR 写侧 FIFO 的主数据合同 |
| DDR 写侧 | `fdma_controller1_write ddr3_wr` | 把 64-bit 数据按包写入 DDR |
| DDR 读侧 | `fdma_controller1_read ddr3_rd` | 按以太网侧请求从 DDR 读数据 |
| 发包侧 | `LAN_TX_FREAME` | 把 DDR 读出的 64-bit 数据转成 UDP payload |

先忽略：

| 先忽略 | 原因 |
|---|---|
| LED 计数器 | 只是 DCO 活动指示 |
| `ila_0` 调试实例 | 先读数据合同，ILA 后面做验证点 |
| `line_count` 细节 | 第一遍先走普通 ADC 数据，超快模式行号后面在发包模块看 |

代码阅读顺序：

1. 看端口，确认 `eth_clk`、`ui_clk`、4 个 ADC DCO、4 路 ADC 数据、控制参数、DDR 和以太网接口。
2. 看 `rstnr0/rstnr1`，理解 DL2 用 `scan_state` 在 `ui_clk` 域生成内部复位/启动。
3. 看 4 个 BUFG，确认每路 DCO 独立进 `adcdata_acq`。
4. 读 4 个 `adcdata_acq` 例化，记录每路 `adc_dco` 与 `adc_data` 对应关系。
5. 读 `adcdata_get` 例化，确认 4 路 `div_adc*_out` 在 `ui_clk` 域汇成 `adc_data_mix_wr_fifo`。
6. 读 `fdma_controller1_write/read` 例化，确认 DDR 写读都在 `ui_clk` 域。
7. 读 `LAN_TX_FREAME` 例化，确认 `pkg_rd_en/pkg_rd_data` 是以太网发包的输入数据。

读完应能回答：

```text
adcdata_config 不直接处理每个采样点算法，它是 DL2 的装配层。
采样发生在各 ADC DCO 域，聚合和 FDMA 发生在 ui_clk 域，UDP payload 发送发生在 eth_clk 域。
主合同是 adc_data_mix_wr_en + adc_data_mix_wr_fifo[63:0]。
```

下一步：打开 `adcdata_acq.v`，读清楚单通道 16-bit 数据怎么产生。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 模块端口 | `adcdata_config.v:21-72` |
| BUFG 处理 ADC DCO | `adcdata_config.v:106-110` |
| 4 个 `adcdata_acq` | `adcdata_config.v:137-207` |
| `adcdata_get` 汇聚 | `adcdata_config.v:209-224` |
| DDR 写读与发包实例 | `adcdata_config.v:226-280` |

## 4. 第三步：打开 `adcdata_acq.v`

文件：`AXI_DDR.srcs/sources_1/new/adcdata_acq.v`

本步目标：读懂“一路 ADC 数据”如何被触发、延时/间隔采样、按 `adc_sample` 求平均，并通过 FIFO 跨到 `ui_clk`。

搜索入口：

```text
module adcdata_acq
sync_module
adc_tri_r
adc_valid_point
adc_interval_reg
state
acq_en
adc_sum_cnt
div_gen_0
fifo_generator_1
row_repeat_module
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 采样时钟 | `adc_dco` | 本路 ADC 的数据时钟 |
| 输入数据 | `adc_data[15:0]` | 进入单通道采样的样本 |
| 触发 | `adc_tri` | 上升沿触发一次采集窗口 |
| 参数同步 | `adc_sample_r2`, `adc_interval_r2`, `image_column_r2`, `ultrafast_mode_r2` 等 | 跨到 `adc_dco` 域后的参数 |
| 采集窗口 | `acq_en` | 为 1 时参与累加平均 |
| 有效点数 | `adc_valid_point` | 本次采集窗口要产生多少个平均点 |
| 平均触发 | `adc_divide_en` | 一个平均窗口完成，启动除法 IP |
| 平均结果 | `adc_average_data[39:24]` | 除法输出中作为 16-bit 平均样本的字段 |
| CDC FIFO | `fifo_generator_1` | `adc_dco` 写，`ui_clk` 读 |
| 下一级 | `row_repeat_module` | 在 `ui_clk` 域继续处理 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| ILA `ila_12` | 调试观察点，先不影响数据合同 |
| 旧的注释块 `adc_valid_point` always 版本 | 当前有效代码是连续赋值 |
| ADC 芯片配置含义 | 这里已经是数字样本入口 |

代码阅读顺序：

1. 先看端口，明确这是单通道模块：一个 `adc_dco`、一组 `adc_data`、一个 `div_adc_out`。
2. 看 `sync_module`，确认 `rstn` 同步进 `adc_dco` 域。
3. 看 65-88 行参数同步，注意 `adc_tri` 和各参数都在 `adc_dco` 域打拍。
4. 看 `adc_valid_point` 和 `adc_interval_reg`，分普通模式和 `ultrafast_mode` 两种采集长度/间隔。
5. 读 115-205 行状态机：
   - `state 0` 等 `adc_tri` 上升沿；
   - `state 1` 等 `adc_interval_reg`；
   - `state 2` 打开 `acq_en`，产生有效平均点；
   - `state 3` 是超快模式行间 dead time。
6. 读 214-236 行平均累加：`adc_sum_cnt < adc_sample_reg - 1` 时累加，窗口结束拉高 `adc_divide_en`。
7. 读 `div_gen_0`，确认除法的 divisor 是 `adc_sample_reg`，dividend 是 `adc_sum_data`。
8. 读 `fifo_generator_1`，确认平均结果从 `adc_dco` 写入，从 `ui_clk` 读出。
9. 最后进入 `row_repeat_module` 例化，只确认它消耗 `fifo1_dout/fifo1_empty`，输出 `div_adc_out`。

读完应能回答：

```text
adcdata_acq 的输出不是每个 ADC 原始点，而是按 adc_sample_reg 求平均后的 16-bit 点。
普通模式有效点数约为 image_column * adc_sample；超快模式有效点数由 adc_sample、adc_acq_delay 和 acq_dead_time 组合得到。
第一个关键 CDC 是 fifo_generator_1：写时钟 adc_dco，读时钟 ui_clk，数据 16 bit。
```

下一步：打开 `row_repeat_module.v`，看平均点在 `ui_clk` 域如何继续处理。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 单通道端口 | `adcdata_acq.v:21-38` |
| `adc_tri` 和参数同步 | `adcdata_acq.v:65-88` |
| 有效点和间隔计算 | `adcdata_acq.v:90-107` |
| 采集状态机 | `adcdata_acq.v:115-205` |
| 求平均和除法 | `adcdata_acq.v:208-249` |
| DCO 到 `ui_clk` FIFO | `adcdata_acq.v:250-263` |
| 行重复模块 | `adcdata_acq.v:265-277` |

## 5. 第四步：打开 `row_repeat_module.v`

文件：`AXI_DDR.srcs/sources_1/new/row_repeat_module.v`

本步目标：读懂 `row_repeat` 如何把多次行数据累加后再平均输出。如果 `row_repeat == 1`，它基本是透传并写入下一级 FIFO。

搜索入口：

```text
module row_repeat_module
row_repeat
fifo1_rd_en
fifo1_empty
ram_wea
row_repeat_cnt
div_gen_4
fifo_generator_0
div_adc_rd_en
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 输入 FIFO 读 | `fifo1_empty`, `fifo1_rd_en`, `fifo1_dout` | 从 `adcdata_acq` 的 CDC FIFO 取平均点 |
| 行重复参数 | `row_repeat_r2`, `image_column_r2` | 决定按多少行做重复平均，以及一行多少点 |
| 暂存 RAM | `ram_addr`, `ram_din`, `ram_dout`, `ram_wea` | 累加多行同一列位置 |
| 输出除法 | `div_gen_4` | 对 `row_repeat` 做平均 |
| 输出 FIFO | `fifo_generator_0` | `ui_clk` 同步 FIFO，供 `adcdata_get` 读取 |
| 下游读 | `div_adc_rd_en` | 多通道聚合模块统一读出 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `blk_mem_gen_0` IP 内部实现 | 只需要知道它是按列地址保存累加值 |
| 乱码注释 | 不影响当前合同 |
| 除法 IP 的流水延迟 | 第一遍只确认 valid 和输出位段 |

代码阅读顺序：

1. 先看端口，确认输入来自上一步 FIFO，输出是 `div_adc_out[15:0]` 和 `div_adc_rd_data_count`。
2. 看 35-49 行参数同步，把 `row_repeat/image_column` 同步到 `ui_clk`。
3. 看状态机 72-189 行：
   - `state 0` 非空就读 `fifo1_dout`；
   - `state 2` 是 `row_repeat == 1` 的直接输出路径；
   - `state 3/4` 是前几次重复行的 RAM 累加；
   - `state 5` 是最后一次重复行，累加后启动除法输出。
4. 看 `div_gen_4`，确认 dividend 是累加值，divisor 是 `row_repeat_r2`。
5. 看 `fifo_generator_0`，确认 `adc_data_en` 写入，`div_adc_rd_en` 读出。

读完应能回答：

```text
row_repeat_module 把单通道平均点变成最终可供聚合的 div_adc_out。
row_repeat == 1 时直接输出；row_repeat > 1 时按 image_column 位置用 RAM 累加多行，再除以 row_repeat。
它的输出 FIFO 是 ui_clk 同步 FIFO，由 adcdata_get 统一读。
```

下一步：打开 `adcdata_get.v`，确认 1/2/4 通道如何统一成 64-bit 合同。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 模块端口 | `row_repeat_module.v:20-31` |
| 参数同步 | `row_repeat_module.v:35-49` |
| 行重复状态机 | `row_repeat_module.v:72-189` |
| `row_repeat` 除法 | `row_repeat_module.v:190-202` |
| 输出 FIFO | `row_repeat_module.v:204-212` |

## 6. 第五步：打开 `adcdata_get.v`

文件：`AXI_DDR.srcs/sources_1/new/adcdata_get.v`

本步目标：建立 DL2 的统一 64-bit 主数据合同：`adc_data_mix_wr_en + adc_data_mix[63:0]`。

搜索入口：

```text
module adcdata_get
adc_channel
div_adc_rd_en
div_adc_rd_data_count
div_adc1_out_r
adc_data_mix_cnt
case
adc_data_mix_wr_en
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 通道选择 | `adc_channel[3:0]` | bit0-3 对应 4 路 ADC 是否参与 |
| 输出 FIFO 计数 | `div_adc*_rd_data_count` | 被选中的通道至少有 6 个点才读 |
| 统一读使能 | `div_adc_rd_en` | 同时推进各路 `row_repeat_module` 输出 FIFO |
| byte swap | `div_adc*_out_r = {low, high}` | 每个 16-bit 样本做大小端交换 |
| 打包计数 | `adc_data_mix_cnt[1:0]` | 决定 1/2 通道模式下几次读凑一个 64-bit |
| 主输出 | `adc_data_mix_wr_en`, `adc_data_mix[63:0]` | 后级 DDR 写的唯一主数据合同 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `ila_5` | 调试用，验证阶段再看 |
| 具体上位机如何设置 `adc_channel` | 先在 `command_monitor_new` 最后读 |

代码阅读顺序：

1. 看端口，确认 4 路 16-bit 输入和一个 64-bit 输出。
2. 看 `adc_channel_r0/r1/r2`，确认通道选择在 `ui_clk` 域打拍。
3. 看 49-62 行 `div_adc_rd_en` 生成：被选中通道 `rd_data_count >= 6` 后才允许统一读。
4. 看 64-71 行 byte swap，记住每个 16-bit 点发送前交换高低字节。
5. 看 74-139 行 `case(adc_channel_r2)`：
   - 单通道模式：4 个 16-bit 点凑 1 个 64-bit；
   - 双通道模式：2 次读，每次 2 个通道，共 64-bit；
   - 三/四通道模式：每次读直接输出 `{ch1,ch2,ch3,ch4}`，未选中的三通道组合也仍按 4 通道格式输出。
6. 对照 `adc_data_mix_wr_en`，确认什么时候这个 64-bit 包有效。

读完应能回答：

```text
adcdata_get 的统一输出宽度永远是 64 bit。
adc_channel 改变的是一个 64-bit 包中包含多少个时刻、多少个通道，而不是改变后级 DDR 位宽。
每个 16-bit 样本在打包前做了 byte swap。
```

下一步：打开 `fdma_controller1_write.v`，看 64-bit 合同如何写入 DDR。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 模块端口 | `adcdata_get.v:21-35` |
| 被选中通道 FIFO 计数门限 | `adcdata_get.v:49-62` |
| byte swap | `adcdata_get.v:64-71` |
| `adc_channel` 打包规则 | `adcdata_get.v:73-139` |

## 7. 第六步：打开 `fdma_controller1_write.v`

文件：`AXI_DDR.srcs/sources_1/new/fdma_controller1_write.v`

本步目标：确认 64-bit `adc_data_mix` 如何进入写侧 FIFO，并以 128 个 64-bit beat 为一包写 DDR。

搜索入口：

```text
module fdma_controller1_write
PKG_SIZE
pkg_wr_size
W0_REQ
rd_data_count
pkg_wr_areq
pkg_wr_last
pkg_wr_addr
cache_wr_size
fifo_generator_3
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 输入合同 | `adc_data_mix_wr_en`, `adc_data_mix_wr_fifo[63:0]` | 来自 `adcdata_get` 的主数据 |
| 写侧 FIFO | `fifo_generator_3` | `ui_clk` 同步 FIFO，缓存待写 DDR 数据 |
| 写包大小 | `PKG_SIZE = 128`, `pkg_wr_size = 128` | 每次 FDMA 写 128 个 64-bit beat |
| 写请求 | `W0_REQ`, `pkg_wr_areq` | FIFO 中至少 128 个 beat 后发起写请求 |
| 写握手 | `pkg_wr_en`, `pkg_wr_last` | FDMA 消费数据和包结束 |
| 地址 | `pkg_wr_addr` | 每包加 1024 byte，2GB 处回绕 |
| 写入累计 | `cache_wr_size` | 已写入字节数，供读侧判断可读数据 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| AXI 协议内部细节 | 这个文件只到 `pkg_wr_*` 用户接口，AXI 在 `MSXBO_FDMA` 内 |
| 默认分支中的重置 | 第一遍先看正常 IDLE-S0-S1-S2 流程 |

代码阅读顺序：

1. 看端口，确认输入数据和 `pkg_wr_*` 用户接口都在 `ui_clk` 域。
2. 看 `PKG_SIZE`，把 128 beat 转成 1024 byte。
3. 看 `W0_REQ <= (rd_data_count >= PKG_SIZE)`，确认触发写包条件。
4. 看状态机：IDLE 等请求，S0 拉 `pkg_wr_areq`，S1 等 `pkg_wr_last`，S2 更新地址和 `cache_wr_size`。
5. 看 `fifo_generator_3`，确认写入是 `adc_data_mix_wr_en`，读出是 `pkg_wr_en`，输出是 `pkg_wr_data`。

读完应能回答：

```text
DL2 写 DDR 的最小粒度是 128 个 64-bit beat，也就是 1024 byte。
pkg_wr_en 是 FDMA 返回的读 FIFO 使能，不是 adcdata_get 直接驱动。
cache_wr_size 以字节为单位累计，用来让读侧知道 DDR 中有多少未读数据。
```

下一步：打开 `system.bd` 和 `MSXBO_FDMA`，确认 `pkg1_wr_*` 真正进入 MIG DDR3。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 写控制端口 | `fdma_controller1_write.v:21-32` |
| 128 beat 包大小 | `fdma_controller1_write.v:35-37` |
| FIFO 数量触发写请求 | `fdma_controller1_write.v:48-54` |
| 写状态机和地址递增 | `fdma_controller1_write.v:64-101` |
| 写 FIFO | `fdma_controller1_write.v:103-111` |

## 8. 第七步：打开 `system.bd` 与 `MSXBO_FDMA`

文件：

- `AXI_DDR.srcs/sources_1/bd/system/system.bd`
- `user_src/MSXBO_FDMA_1.0/hdl/MSXBO_FDMA_v1_0.v`
- `user_src/MSXBO_FDMA_1.0/hdl/MSXBO_FDMA_v1_0_M00_AXI.v`

本步目标：确认 DL2 用的是 `MSXBO_FDMA_1`，它通过 AXI interconnect 访问 MIG DDR3，数据宽度 64 bit，burst 长度 128。

搜索入口：

```text
MSXBO_FDMA_1
pkg1_wr
pkg1_rd
M00_AXI
axi_interconnect_1
mig_7series_0
C_M00_AXI_DATA_WIDTH
C_M00_AXI_BURST_LEN
pkg_wr_en
pkg_rd_en
```

本模块相关信号：

| 类别 | 信号/结构 | 作用 |
|---|---|---|
| BD 中的 DL2 FDMA | `MSXBO_FDMA_1` | ADC 数据专用 DDR master |
| AXI master | `MSXBO_FDMA_1/M00_AXI` | 进入 AXI interconnect 的主接口 |
| DDR slave | `mig_7series_0/S_AXI` | DDR3 用户侧 AXI slave |
| 用户写接口 | `pkg1_wr_areq/addr/data/size/en/last` | 从 RTL 写控制器接入 FDMA |
| 用户读接口 | `pkg1_rd_areq/addr/data/size/en/last` | 从 RTL 读控制器接入 FDMA |
| AXI 数据宽度 | `C_M00_AXI_DATA_WIDTH = 64` | 与 `adc_data_mix` 一致 |
| AXI burst | `C_M00_AXI_BURST_LEN = 128` | 与 `PKG_SIZE` 一致 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `MSXBO_FDMA_0` | 这是远程升级/配置那一路，不是 DL2 |
| MIG 物理 DDR3 管脚 | 全工程文档已记录，这里只看 DL2 用户接口 |
| AXI interconnect 内部子 coupler | 第一遍只需要确认连到 MIG |

代码阅读顺序：

1. 在 `system.bd` 搜 `MSXBO_FDMA_1`，确认参数 `C_M00_AXI_BURST_LEN=128`、`C_M00_AXI_DATA_WIDTH=64`。
2. 在 `system.bd` 搜 `MSXBO_FDMA_1_M00_AXI`，确认它接到 `axi_interconnect_1/S01_AXI`。
3. 搜 `axi_interconnect_1_M00_AXI`，确认 interconnect master 接 `mig_7series_0/S_AXI`。
4. 搜 `pkg1_wr_*` 和 `pkg1_rd_*`，确认外部端口接到 `MSXBO_FDMA_1`。
5. 打开 `MSXBO_FDMA_v1_0.v`，只看用户接口端口和 M00_AXI 例化。
6. 打开 `MSXBO_FDMA_v1_0_M00_AXI.v`，只看 `pkg_wr_en/pkg_rd_en` 的含义：它们等于 AXI 写/读数据握手成功。
7. 看 `pkg_wr_last/pkg_rd_last` 生成，确认按 `pkg_*_size - 1` 计数结束一包。

读完应能回答：

```text
DL2 的 pkg1_* 通道使用 MSXBO_FDMA_1。
用户侧 64-bit 数据通过 AXI master 写/读 MIG DDR3。
pkg_wr_en/pkg_rd_en 是 AXI 数据通道实际传输成功的节拍。
```

下一步：打开 `fdma_controller1_read.v`，看什么时候从 DDR 读数据给以太网。

关键证据：

| 证据 | 文件位置 |
|---|---|
| `MSXBO_FDMA_1` 参数 | `system.bd:272-283` |
| FDMA1 到 interconnect | `system.bd:1043-1048` |
| interconnect 到 MIG | `system.bd:1050-1054` |
| `ui_clk` 接 FDMA1/MIG/interconnect | `system.bd:1143-1154` |
| `pkg1_*` 接 FDMA1 | `system.bd:1169-1208` |
| FDMA 顶层用户接口 | `MSXBO_FDMA_v1_0.v:13-24`, `MSXBO_FDMA_v1_0.v:77-88` |
| `pkg_wr_en/pkg_rd_en/last` 定义 | `MSXBO_FDMA_v1_0_M00_AXI.v:152-158` |

## 9. 第八步：打开 `fdma_controller1_read.v`

文件：`AXI_DDR.srcs/sources_1/new/fdma_controller1_read.v`

本步目标：确认 DDR 读侧什么时候发 `pkg_rd_areq`，读地址如何推进，以及它如何防止读超过已写数据。

搜索入口：

```text
module fdma_controller1_read
pkg_rd_size
cache_wr_size
cache_rd_size
cache_size
read_req
rd_req
pkg_rd_areq
pkg_rd_last
pkg_rd_addr
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 写侧累计 | `cache_wr_size` | 来自写控制器，累计已写字节数 |
| 读侧累计 | `cache_rd_size` | 本模块累计已读字节数 |
| 可读缓存量 | `cache_size = cache_wr_size - cache_rd_size` | 判断 DDR 中未读数据量 |
| 以太网侧请求 | `read_req` | 来自 `LAN_TX_FREAME` 的 `fdma_rd_req` |
| 实际读触发 | `rd_req` | `cache_size >= 2048 && read_req_r1` |
| 读包大小 | `pkg_rd_size = 128` | 每次读 128 个 64-bit beat |
| 读地址 | `pkg_rd_addr` | 每包加 1024 byte，2GB 处回绕 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `ila_6` | 只观察 `cache_size`，后面验证再用 |
| `pkg_rd_data` 的消费 | 本模块只发读请求，数据流向在 `adcdata_config` 和 `LAN_TX_FREAME` 看 |

代码阅读顺序：

1. 看端口，确认 `pkg_rd_data/en/last` 是 FDMA 返回的数据，但这个模块不直接处理 `pkg_rd_data`。
2. 看 `read_req_r0/r1`，确认以太网侧请求在 `ui_clk` 域打拍。
3. 看 `pkg_rd_size = 128`。
4. 看 `cache_size = cache_wr_size - cache_rd_size`。
5. 看 `rd_req` 条件，注意门限是 2048 byte，也就是至少两包写入量。
6. 看状态机：IDLE 等 `rd_req`，S0 拉 `pkg_rd_areq`，S1 等 `pkg_rd_last`，S2 更新读地址和 `cache_rd_size`。

读完应能回答：

```text
DDR 读侧由 LAN_TX_FREAME 的 fdma_rd_req 拉动，但只有 cache_size >= 2048 byte 时才真正读。
每次读 128 个 64-bit beat，即 1024 byte。
读出的 pkg_rd_data 不在本文件处理，而是在 adcdata_config 中直接接到 LAN_TX_FREAME。
```

下一步：打开 `LAN_TX_FREAME.v`，看读出的 64-bit 数据如何转成 UDP payload。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 模块端口 | `fdma_controller1_read.v:21-32` |
| 读请求同步 | `fdma_controller1_read.v:35-47` |
| 读包大小 | `fdma_controller1_read.v:49` |
| 可读量判断 | `fdma_controller1_read.v:65-78` |
| 读状态机和地址递增 | `fdma_controller1_read.v:80-118` |

## 10. 第九步：打开 `LAN_TX_FREAME.v`

文件：`AXI_DDR.srcs/sources_1/imports/new/LAN_TX_FREAME.v`

本步目标：读懂 DDR 读出的 64-bit ADC 数据如何跨到 `eth_clk`，如何按包加应用层头，如何请求以太网发送。

搜索入口：

```text
module LAN_TX_FREAME
fifo_generator_9
fdma_rd_req
all_image_point
data_wr_pack_num
data_ACK
package_count
tx_byte_count
head_data
fsm_r
fifo_rd_en
data_tx_data_o
data_tx_valid_o
ultrafast_mode
line_count
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| DDR 读入 | `adc_data_mix_wr_en`, `adc_data_mix_wr_fifo[63:0]` | 实际接的是 `pkg_rd_en/pkg_rd_data` |
| 数据 CDC/宽转 | `fifo_generator_9` | `ui_clk` 写 64-bit，`eth_clk` 读 8-bit |
| 读 DDR 请求 | `fdma_rd_req` | 当发送 FIFO 低于阈值时请求读 DDR |
| 总 payload 字节数 | `all_image_point` | 根据 `image_point` 和 `adc_channel` 算本帧总字节量 |
| 应用头 | `head_data` | 普通模式 `AA55 AA55 + package_count + length`，超快模式 `CC55 CC55 ...` |
| 发送请求 | `data_req_o` | 请求 `LAN_TX_MUX` 给 ADC 数据发送机会 |
| 发送握手 | `data_ACK_i`, `tx_data_done` | 以太网仲裁应答与发送完成 |
| payload 输出 | `data_tx_data_o[7:0]`, `data_tx_valid_o` | 进入以太网发送仲裁 |
| 超快支路 | `line_count`, `line_count_en`, `fifo_generator_2` | 超快模式下发送行号/计数信息 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `vio_2` 的 `single_frame_count/frame_count` 来源细节 | 第一遍先知道它们控制每包 payload 长度和帧数 |
| `pc_ack` 等等待逻辑中的状态 4 | 当前状态机从状态 3 回状态 0，状态 4 看起来不是普通主链必经路径 |
| ILA `ila_10` | 后面作为验证信号组 |

代码阅读顺序：

1. 看端口，确认它一边接 `pkg_rd_*` 数据，一边接以太网 `data_req/data_ACK/data_tx_*`。
2. 看 `fifo_generator_2`，这是超快模式行号路径，先记为旁路。
3. 看 `fifo_generator_9`，确认 DDR 读出的 64-bit 数据在 `ui_clk` 写入，`eth_clk` 读出 8-bit `fifo_dout`。
4. 看 87-95 行 `fdma_rd_req`：发送 FIFO 低于 30000 时请求 DDR 继续读。
5. 看 `all_image_point` 计算：单通道乘 2 byte，双通道乘 4 byte，三/四通道乘 8 byte。
6. 看 `data_wr_pack_num = 1`，理解每次请求发送一包。
7. 看状态机：
   - `fsm 0`：等待 `scan_state`，判断是否够一包数据，准备 `head_data` 和 `data_wr_last_pack_num`；
   - `fsm 1`：等以太网仲裁 `data_ACK` 上升沿；
   - `fsm 2`：普通 ADC 数据发送，先发 12 字节应用头，再读 `fifo_dout`；
   - `fsm 5`：超快模式发送 `line_count_tx`；
   - `fsm 3`：拉低请求，等 `tx_data_done`。
8. 看 `fifo_rd_en` 的时机：普通模式在应用头快发完时提前读 FIFO，使 payload 字节对齐。

读完应能回答：

```text
LAN_TX_FREAME 是 DDR 到以太网的关键桥：ui_clk 64-bit 输入，eth_clk 8-bit 输出。
它发送的用户 payload 前有 12 字节应用头；以太网/IP/UDP 头由后面的 lan_tx 再添加。
普通模式从 fifo_generator_9 读 ADC 数据，超快模式走 line_count 旁路。
```

下一步：打开以太网发送链 `ETHERNET_TOP.v`、`LAN_TX_MUX.v`、`LAN_TX_TOP.v` 和 `lan_tx.v`。

关键证据：

| 证据 | 文件位置 |
|---|---|
| 模块端口 | `LAN_TX_FREAME.v:21-46` |
| 行号 CDC FIFO | `LAN_TX_FREAME.v:49-63` |
| 64-to-8 数据 FIFO | `LAN_TX_FREAME.v:72-85` |
| DDR 读请求 | `LAN_TX_FREAME.v:87-95` |
| `all_image_point` 计算 | `LAN_TX_FREAME.v:97-109` |
| 发送状态机 | `LAN_TX_FREAME.v:142-320` |
| 普通模式 payload 输出 | `LAN_TX_FREAME.v:235-258` |
| 超快模式 payload 输出 | `LAN_TX_FREAME.v:260-283` |

## 11. 第十步：打开以太网发送链

文件：

- `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v`
- `AXI_DDR.srcs/sources_1/imports/new/LAN_TX_MUX.v`
- `AXI_DDR.srcs/sources_1/imports/new/LAN_TX_TOP.v`
- `AXI_DDR.srcs/sources_1/imports/user/lan_tx.v`

本步目标：确认 `LAN_TX_FREAME` 的 8-bit payload 如何被仲裁、进入 UDP 发送 FIFO，并最终形成 AXI-Stream 到 TEMAC。

搜索入口：

```text
data_req
data_ACK
data_wr_pack_num
data_wr_last_pack_num
data_tx_data
data_tx_valid
DES_PORT_UDP_TX1
LAN_TX_MUX
S_TX_DATA
LAN_TX_TOP
fifo_lan_tx
lan_tx
wr_fifo_rden
lan_data
```

本模块相关信号：

| 类别 | 信号/模块 | 作用 |
|---|---|---|
| 目标 UDP 端口 | `DES_PORT_UDP_TX1 = 16'h7D01` | ADC 数据上传端口，十进制 32001 |
| 顶层以太网口 | `data_req/data_ACK/data_tx_data/data_tx_valid` | DL2 数据进入以太网发送仲裁 |
| 仲裁器 | `LAN_TX_MUX` | 在读寄存器响应、ADC 数据、ARP、ICMP 间选择发送源 |
| ADC 数据分支 | `S_TX_DATA` | `data_ACK_o` 应答，透传 `data_tx_*` 到 UDP 发送 FIFO |
| UDP 发送顶层 | `LAN_TX_TOP` | `fifo_lan_tx` 缓存 payload，`lan_tx` 添加网络头 |
| payload FIFO | `fifo_lan_tx` | 8-bit 同步 FIFO，`prog_full` 反馈给 `LAN_TX_FREAME` |
| 发送核心 | `lan_tx` | 添加 42 字节 ETH/IP/UDP 头，输出 AXI-Stream |
| TEMAC 输入 | `tx_axis_fifo_tdata/valid/last` | 最终送 SGMII TEMAC example design |

先忽略：

| 先忽略 | 原因 |
|---|---|
| ARP/ICMP/RD_REG 分支内部 | 只需知道它们可能和 ADC 数据抢发送仲裁 |
| UDP 接收和远程升级 | 不属于 DL2 回传方向 |
| MAC/IP 参数来源细节 | 第一遍只确认 ADC payload 进入 `DES_PORT_UDP_TX1` |

代码阅读顺序：

1. 在 `ETHERNET_TOP.v` 看端口 49-57，确认 ADC 数据发送接口。
2. 看 `DES_PORT_UDP_TX1 = 16'h7D01`，确认 DL2 发往 UDP 32001。
3. 看 `LAN_TX_TOP` 例化，确认 `prog_full` 从 UDP payload FIFO 反馈出来。
4. 看 `LAN_TX_MUX` 例化，确认 ADC 数据分支接 `data_req_i/data_ACK_o/data_tx_*` 和 `data_port`。
5. 打开 `LAN_TX_MUX.v`，只读 `S_IDLE` 和 `S_TX_DATA`：请求时给 `data_ACK_o`，发送中透传 payload，`wr_done_i` 后给 `tx_data_done`。
6. 打开 `LAN_TX_TOP.v`，看 `fifo_lan_tx` 和 `lan_tx` 例化，确认 payload 被缓存并送给网络封包模块。
7. 打开 `lan_tx.v`，看 `WR_IDLE -> WR_START -> WR_HEAD -> WR_PACKET -> WR_END`，确认先发 42 字节网络头，再读 payload FIFO。
8. 看 `wr_fifo_rden` 和 `lan_data`，确认 `WR_PACKET` 时才从 FIFO 读 payload。

读完应能回答：

```text
LAN_TX_FREAME 不直接驱动 TEMAC，它先通过 ETHERNET_TOP 的 data_* 接口请求发送。
LAN_TX_MUX 的 S_TX_DATA 分支把 ADC payload 送到 LAN_TX_TOP。
LAN_TX_TOP/lan_tx 再添加 42 字节网络头，形成 tx_axis_fifo_tdata/valid/last。
ADC 数据发送 UDP 目的端口是 0x7D01，也就是 32001。
```

下一步：打开 `command_monitor_new.v`，只读影响 DL2 的寄存器。

关键证据：

| 证据 | 文件位置 |
|---|---|
| `ETHERNET_TOP` ADC 发送端口 | `ETHERNET_TOP.v:49-57` |
| UDP 32001 | `ETHERNET_TOP.v:146-147` |
| `LAN_TX_MUX` 接 ADC 分支 | `ETHERNET_TOP.v:336-360` |
| `LAN_TX_MUX` 的 `S_TX_DATA` 分支 | `LAN_TX_MUX.v:88-141` |
| `LAN_TX_TOP` payload FIFO 和 `lan_tx` | `LAN_TX_TOP.v:21-100` |
| `lan_tx` 状态机与 payload 读取 | `lan_tx.v:180-186`, `lan_tx.v:221-342` |

## 12. 第十一步：打开 `command_monitor_new.v`

文件：`AXI_DDR.srcs/sources_1/new/command_monitor_new.v`

本步目标：只整理影响 DL2 的上位机寄存器，不展开 DAC 扫描、偏置、远程升级等其它控制。

搜索入口：

```text
adc_len_single
adc_channel
adc_sample
image_row
image_column
image_point
adc_interval
scan_state
row_repeat
adc_acq_delay
ultrafast_mode
acq_dead_time
pc_ack
```

本模块相关信号：

| 地址 | 字段 | 影响 DL2 的位置 | 说明 |
|---:|---|---|---|
| `16'h0001` | `adc_len_single <= wr_reg_data[24:4]`, `adc_channel <= wr_reg_data[3:0]` | `adcdata_get`, `LAN_TX_FREAME` | 通道选择会改变 64-bit 打包语义和总字节数 |
| `16'h0002` | `adc_sample <= wr_reg_data[31:0]` | `adcdata_acq` | 每个输出点的平均样本数，同时也赋给 DAC sample |
| `16'h0003` | `adc1_gain` 到 `adc4_gain` | 顶层继电器/模拟前端 | 影响模拟输入量程，不改变数字路径 |
| `16'h0004` | `image_row`, `image_column`, `image_point = row * column` | `adcdata_acq`, `row_repeat_module`, `LAN_TX_FREAME` | 图像尺寸和总点数 |
| `16'h0009` | `adc_interval`, `scan_mode`, `scan_state` | `adcdata_acq`, `adcdata_config`, `LAN_TX_FREAME` | 采样间隔和启动状态 |
| `16'h000E` | `pc_ack` | `LAN_TX_FREAME` | 和发送等待/确认相关 |
| `16'h0013` | `row_repeat` | `row_repeat_module` | 行重复平均次数，0 会被改成 1 |
| `16'h0201` | `adc_acq_delay` | `adcdata_acq` | 超快模式采集延时 |
| `16'h0202` | `ultrafast_mode`, `ultrafast_line_rec` | `adcdata_acq`, `LAN_TX_FREAME` | 切换超快模式和行号相关发送 |
| `16'h0204` | `acq_dead_time` | `adcdata_acq` | 超快模式死区时间 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `dacx_*`, `dacy_*`, `scan_mode` 的 DAC 细节 | 只在 DL2 中关心 `scan_state` 是否启动采集和发包 |
| `remote_rstn`, `remote_result` | 远程升级链路 |
| offset/FRAM 相关寄存器 | 不改变 DL2 数字数据路径 |
| 读寄存器响应全部展开 | 只需用来核对字段可回读 |

代码阅读顺序：

1. 看模块端口 33-78，只摘出 DL2 参数输出。
2. 看复位默认值 100-148，记录默认通道、尺寸、平均数、间隔和模式。
3. 看写寄存器 case 191-281，只读上表地址。
4. 看读寄存器 case 296-317，确认关键字段可读回。
5. 看 `pc_ack_r` 逻辑 381-392，确认只有 `scan_state[0]` 为 1 且 `pc_ack_flag` 时更新。

读完应能回答：

```text
DL2 的采集长度、平均数、通道选择、图像尺寸、采样间隔、行重复和超快模式都来自 command_monitor_new。
这些寄存器在 eth_clk 域写入，随后在 adcdata_acq 或 row_repeat_module 内部按目标时钟域打拍使用。
```

下一步：回到本文的数据形态表、CDC 表和风险表，做验证计划。

关键证据：

| 证据 | 文件位置 |
|---|---|
| DL2 参数端口 | `command_monitor_new.v:33-78` |
| 默认值 | `command_monitor_new.v:100-148` |
| 写寄存器字段 | `command_monitor_new.v:191-281` |
| 读寄存器字段 | `command_monitor_new.v:296-317` |
| `pc_ack_r` 更新 | `command_monitor_new.v:381-392` |

## 13. CDC 和缓存结构

| 结构 | 写时钟 | 读时钟 | 数据 | 写条件 | 读条件 | 风险/关注点 |
|---|---|---|---|---|---|---|
| `sync_module` in `adcdata_acq` | `rstn` 原域 | `adc_dco` | reset 控制 | `rstn` 变化 | `adc_dco` 域使用 | 只同步 reset，不同步 ADC 数据 |
| 参数打拍 in `adcdata_acq` | 近似来自 `eth_clk/ui_clk` | `adc_dco` | `adc_tri`, `adc_sample`, `adc_interval`, `image_column`, `ultrafast_mode` 等 | 每个 `adc_dco` 周期采样 | `adc_dco` 状态机使用 | 多 bit 参数直接打拍，若采集中改变可能出现跨域不一致，需要协议约束 |
| `fifo_generator_1` | `adc_dco` | `ui_clk` | 16-bit 平均 ADC 点 | `adc_average_data_en` | `row_repeat_module` 的 `fifo1_rd_en` | 没看到 full/prog_full 反馈，需确认 FIFO 深度和最坏速率 |
| `fifo_generator_0` | `ui_clk` | `ui_clk` | 16-bit 行重复后点 | `adc_data_en` | `adcdata_get` 的 `div_adc_rd_en` | 同步 FIFO，无 full 反馈 |
| `fifo_generator_3` | `ui_clk` | `ui_clk` | 64-bit `adc_data_mix` | `adc_data_mix_wr_en` | FDMA 的 `pkg_wr_en` | 写入速率超过 DDR 写出时可能溢出，源码未接 full |
| DDR3/MIG | `ui_clk` | `ui_clk` | 64-bit beat 经 AXI | `pkg1_wr_*` | `pkg1_rd_*` | 写读地址都 2GB 回绕，慢速以太网可能导致旧数据被覆盖 |
| `fifo_generator_9` | `ui_clk` | `eth_clk` | 64-bit 写入，8-bit 读出 | `pkg_rd_en` | `LAN_TX_FREAME` 的 `fifo_rd_en` | 64-to-8 宽转和跨域，是 DDR 到以太网关键 CDC |
| `fifo_generator_2` | `adc_dco` | `eth_clk` | 16-bit `line_count` | `line_count_en` | 超快模式 `line_rd_en` | 超快模式旁路，需确认 16-bit 到 8-bit 发送是否符合协议 |
| `fifo_lan_tx` | `eth_clk` | `eth_clk` | 8-bit UDP payload | `LAN_TX_MUX.tx_fifo_wr_en_o` | `lan_tx.wr_fifo_rden` | `prog_full` 反馈到 `LAN_TX_FREAME` 暂停 payload 输出 |

## 14. 模式和分支

| 分支/模式 | 选择条件 | 数据来源 | 数据去向 | 特殊行为 |
|---|---|---|---|---|
| 普通采集 | `ultrafast_mode == 0` | `adc_valid_point = image_column * adc_sample` | 平均点进入 DDR 和 UDP | 一次 `adc_tri` 后产生一段采集窗口 |
| 超快采集 | `ultrafast_mode == 1` | `adc_sample - adc_acq_delay - acq_dead_time - 2` | 采集数据同样进 DDR；发包可走行号 `CC55` 分支 | `adc_interval_reg = adc_acq_delay`，支持 dead time 和多列/行计数 |
| 单通道 | `adc_channel` one-hot | 一个 16-bit 通道 | 4 个时刻凑 64-bit | 总字节数 `image_point * 2` |
| 双通道 | `adc_channel` 两 bit | 两个 16-bit 通道 | 2 个时刻凑 64-bit | 总字节数 `image_point * 4` |
| 三/四通道 | `adc_channel` 为 3 或 4 个 bit | 4 路槽位 | 每次读直接 64-bit | 三通道组合仍输出 `{ch1,ch2,ch3,ch4}` 形态，总字节数按 `image_point * 8` |
| 普通 UDP 数据 | `ultrafast_mode == 0` 且 FIFO 数据足够 | `fifo_generator_9.fifo_dout` | `data_tx_data_o` | 应用头 `AA55 AA55 + package_count + length` |
| 超快 UDP 行号 | `ultrafast_mode == 1 && !empty` | `line_count_tx` | `data_tx_data_o` | 应用头 `CC55 CC55...`，payload 长度 14 |

## 15. 验证信号分组

| 组 | 观察重点 | 建议观察信号 |
|---|---|---|
| ADC 入口组 | 触发后是否开始采集 | `adc_tri_r1`, `state`, `acq_en`, `adc_data`, `adc_valid_point_cnt`, `adc_sample_reg` |
| 单通道平均组 | 平均窗口是否按预期输出 | `adc_sum_cnt`, `adc_sum_data`, `adc_divide_en`, `adc_average_data_en`, `adc_average_data[39:24]` |
| DCO 到 `ui_clk` CDC 组 | 每通道 FIFO 是否正常过域 | `fifo1_empty`, `fifo1_rd_en`, `fifo1_dout`, `div_adc_rd_data_count`, `div_adc_out` |
| 通道聚合组 | `adc_channel` 打包是否正确 | `adc_channel_r2`, `div_adc_rd_en`, `div_adc*_out_r`, `adc_data_mix_cnt`, `adc_data_mix_wr_en`, `adc_data_mix` |
| DDR 写组 | 64-bit 数据是否按包写入 | `rd_data_count`, `W0_REQ`, `pkg_wr_areq`, `pkg_wr_en`, `pkg_wr_last`, `pkg_wr_addr`, `cache_wr_size` |
| DDR 读组 | 可读数据是否被按需读出 | `cache_size`, `fdma_rd_req`, `pkg_rd_areq`, `pkg_rd_en`, `pkg_rd_last`, `pkg_rd_addr`, `pkg_rd_data` |
| 发包桥组 | 64-bit 到 8-bit 与包头是否正确 | `fifo_rd_data_count`, `fsm_r`, `data_req_o`, `data_ACK_i`, `byte_cnt`, `data_tx_valid_o`, `data_tx_data_o`, `prog_full` |
| 以太网仲裁组 | ADC payload 是否被仲裁到 UDP | `LAN_TX_MUX.state`, `data_ACK_o`, `tx_fifo_wr_en_o`, `tx_fifo_din_o`, `wr_done_i`, `tx_data_done` |
| TEMAC 输出组 | UDP/IP/ETH 输出是否推进 | `tx_axis_fifo_tvalid`, `tx_axis_fifo_tlast`, `tx_axis_fifo_tdata`, `tx_axis_fifo_tready` |

## 16. 待确认和风险点

| 风险 | 说明 | 建议 |
|---|---|---|
| 多 bit 参数跨域只打拍 | `adcdata_acq` 中 `adc_sample/adc_interval/image_column/ultrafast_mode/acq_dead_time` 等多 bit 参数直接在 `adc_dco` 域逐级寄存。如果上位机在采集中改参数，可能采到不一致组合。 | 协议上限制只能在 `scan_state=0` 时改采集参数，或增加影子寄存器和启动沿锁存。 |
| `adc_sample_reg` 可能为 0 或下溢 | 超快模式下 `adc_sample_r2 - adc_acq_delay_r2 - acq_dead_time_r2 - 2` 是无符号计算，参数不合法会下溢；除法 divisor 也可能异常。 | 上位机或 RTL 增加参数范围检查。 |
| FIFO full 未反馈 | `fifo_generator_1/0/3` 关键 FIFO 没看到 full/prog_full 反馈到生产者。 | 查 IP 深度，按最坏 ADC 速率、DDR stall、以太网速率做裕量计算；ILA 加 full/prog_full。 |
| DDR 环形地址覆盖 | 写读地址都在 2GB 范围回绕，`cache_wr_size/cache_rd_size` 是 64-bit 累计，但未看到防止写追上读的硬保护。 | 长时间采集或以太网慢速时需要确认不会覆盖未发送数据。 |
| `LAN_TX_FREAME` 超快行号 16-to-8 发送可疑 | `data_tx_data_o` 是 8 bit，`line_count_tx` 是 16 bit，状态 5 中直接赋值可能只发送低 8 bit，或依赖 FIFO/时序产生不明显的两字节行为。 | 对照上位机协议确认 `CC55` 包 payload 的两个字节顺序，必要时显式拆高低字节。 |
| `data_wr_pack_num` 固定为 1 | `LAN_TX_FREAME` 每次请求只发一包，分包靠状态机多次请求，而不是一次请求多包。 | 确认 `lan_tx`/上位机协议期望就是单包请求循环。 |
| 三通道组合按四通道槽位发 | `adcdata_get` 的 3 路组合进入与 4 路相同分支，包里包含 4 个槽位。 | 上位机解析要按 8 byte/点处理，确认未选通道数据是否允许存在。 |
| `command_monitor_new` 重复 `16'h0200` | 虽然这更影响同步触发宽度，但同属采集/扫描控制寄存器风险。后一个 `sync2_pixel_tri_wigth` 分支通常不可达。 | 结合协议确认第二个地址是否应为其它值。 |

## 17. 关键证据索引

| 证据 | 文件位置 |
|---|---|
| 顶层 `ETH_TOP` 是综合顶层 | `AXI_DDR.xpr:638` |
| DL2 顶层实例 | `ETH_TOP.v:489-537` |
| 顶层 ADC 裁位 | `ETH_TOP.v:498-501` |
| `system_wrapper` 的 `pkg1_*` | `ETH_TOP.v:411-422` |
| `adcdata_config` 内部串接 | `adcdata_config.v:137-280` |
| 单通道触发和平均 | `adcdata_acq.v:115-249` |
| DCO 到 `ui_clk` FIFO | `adcdata_acq.v:250-263` |
| 行重复平均 | `row_repeat_module.v:72-212` |
| 通道聚合打包 | `adcdata_get.v:49-139` |
| DDR 写控制 | `fdma_controller1_write.v:35-111` |
| DDR 读控制 | `fdma_controller1_read.v:49-118` |
| FDMA1 到 MIG | `system.bd:1043-1054` |
| FDMA1 用户接口 | `system.bd:1169-1208` |
| FDMA 数据握手定义 | `MSXBO_FDMA_v1_0_M00_AXI.v:152-158` |
| DDR 到 UDP payload | `LAN_TX_FREAME.v:72-320` |
| UDP 32001 | `ETHERNET_TOP.v:146-147` |
| 以太网 ADC 数据仲裁 | `LAN_TX_MUX.v:88-141` |
| UDP payload FIFO 和网络发送 | `LAN_TX_TOP.v:53-97`, `lan_tx.v:180-342` |
| DL2 控制寄存器 | `command_monitor_new.v:191-281` |


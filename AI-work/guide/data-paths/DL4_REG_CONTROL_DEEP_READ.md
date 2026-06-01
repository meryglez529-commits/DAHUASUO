# DL4 以太网寄存器控制链路代码阅读指导手册

这份文档的目标不是替你把 RTL 背下来，而是带你按源码重新走一遍 DL4：

```text
PC UDP 寄存器包
  -> ETHERNET_TOP / ETH_LAN_RX 识别 32000 端口
  -> WR_RD_REG_TOP / LAN_WR_REG 拆成 WR_REG/RD_REG 命令
  -> command_monitor_new 解码成 ADC/DAC/remote/offset 控制寄存器
  -> DL1、DL2、DL3 和支撑模块消费这些控制量
```

DL4 和 DL1/DL2 的区别是：这里的主数据不是 ADC 样本，也不是 DAC 坐标，而是“上位机写入的一条 32-bit 寄存器命令”。读这条链路时，要把 `WR_REG_VALID + WR_REG_ADDR + WR_REG_DATA` 当成主合同。

## 0. 使用方法

建议把本文档和源码并排看。每一轮只解决一个问题，不要一打开 `ETH_TOP.v` 就把 ADC、DAC、DDR、QSPI 全部展开。

| Pass | 打开文件 | 本轮只解决的问题 |
|---:|---|---|
| 1 | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | DL4 在顶层的边界是什么，谁产生寄存器命令，谁消费控制参数 |
| 2 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v` | UDP 端口如何分流到寄存器读写链路，读回包如何回到 UDP 发送口 |
| 3 | `AXI_DDR.srcs/sources_1/imports/new/ETH_LAN_RX.v` | 收到的 UDP payload 如何变成 `LAN_RX_TYPE=1` 的字节流 |
| 4 | `AXI_DDR.srcs/sources_1/imports/new/WR_RD_REG_TOP.v`、`LAN_WR_REG.v` | 字节流如何拆成 `WR_REG_*` 和 `RD_REG_*` |
| 5 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` | 写寄存器地址如何变成 DL1/DL2/DL3 控制参数 |
| 6 | `command_monitor_new.v` | 读寄存器如何返回 32-bit 状态值，哪些地址只写不读 |
| 7 | `ETH_TOP.v` | 解码后的控制参数分别接到哪些业务模块 |
| 8 | `LAN_RD_REG.v`、`LAN_TX_MUX.v` | 读寄存器响应包如何发回 PC |

## 1. 最小心智模型

DL4 是控制面。它在 `eth_clk/user_axis_clk` 域里接收上位机 UDP 包，把 payload 解释成寄存器读写，再把寄存器值扇出到其它业务链路。

真实数据方向：

```text
PC UDP payload
  -> ETH_LAN_RX.lan_data_out[7:0]
  -> LAN_WR_REG
  -> WR_REG_VALID / WR_REG_ADDR / WR_REG_DATA
  -> command_monitor_new
  -> scan_state、scan_mode、adc_sample、dac_sample、image_row/column、ultrafast_mode ...
```

读回方向：

```text
PC UDP read request
  -> LAN_WR_REG 产生 RD_REG_VALID / RD_REG_ADDR
  -> command_monitor_new 返回 RD_REG_DATA
  -> LAN_RD_REG 打包 14 字节响应
  -> LAN_TX_MUX 选择读回通道
  -> UDP 发送口
```

先记住三个合同：

| 合同 | 位宽 | 含义 | 有效条件 |
|---|---:|---|---|
| `lan_data_valid + lan_data_out[7:0]` | 1 + 8 | 已经通过 MAC/IP/UDP 过滤后的 payload 字节流 | `ETH_LAN_RX` 在目标端口匹配时拉高 |
| `WR_REG_VALID + WR_REG_ADDR + WR_REG_DATA` | 1 + 16 + 32 | 写一个 FPGA 控制寄存器 | `LAN_WR_REG` 完成写命令解析后给 1 拍脉冲 |
| `RD_REG_VALID + RD_REG_ADDR -> RD_REG_DATA` | 1 + 16 -> 32 | 读一个 FPGA 控制寄存器 | `LAN_WR_REG` 完成读命令解析后给 1 拍脉冲，`command_monitor_new` 返回数据 |

## 2. 第一步：打开 `ETH_TOP.v`

文件：`AXI_DDR.srcs/sources_1/new/ETH_TOP.v`

本步目标：确认 DL4 的顶层边界。你要知道寄存器命令从哪个模块出来，最后变成哪些控制参数。

搜索入口：

```text
WR_REG_VALID
RD_REG_VALID
command_monitor_new U4
ETHERNET_TOP
adcdata_config U5
dacdata_config U6
ddr3_ctrl U07
fram_cfg U8
```

本模块相关信号：

| 类别 | 信号/实例 | 作用 |
|---|---|---|
| 寄存器写命令 | `WR_REG_VALID/ADDR/DATA` | 以太网寄存器写入口，送给 `command_monitor_new` |
| 寄存器读命令 | `RD_REG_VALID/ADDR` | 以太网寄存器读入口，送给 `command_monitor_new` |
| 读回数据 | `RD_REG_DATA` | `command_monitor_new` 返回给以太网读响应 |
| 控制解码模块 | `command_monitor_new U4` | DL4 的核心解码点 |
| DL2 消费者 | `adcdata_config U5` | 消费 `adc_sample/adc_channel/image_column/ultrafast_mode/scan_state` 等 |
| DL1 消费者 | `dacdata_config U6` | 消费 DAC 起止电平、步进、同步脉冲、`scan_mode/scan_state` 等 |
| DL3 消费者 | `ddr3_ctrl U07` | 消费 `remote_rstn` |
| 支撑消费者 | `fram_cfg U8`、`offset_dac_cfg U9` | 消费 offset 参数和写入触发 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `adc*_d*`、`pkg1_*` 细节 | 这是 DL2 数据链路，不是寄存器控制链路本身 |
| `DAX_DATA/DAY_DATA` 生成细节 | 这是 DL1 输出链路 |
| `pkg_*` DDR 读写细节 | 这是 DL3 remote 数据链路 |
| ILA probe 具体位宽 | 这里只用它们确认可观测信号，不影响主合同 |

代码阅读顺序：

1. 先看 `ETHERNET_TOP U02` 端口连接，确认 `user_axis_clk` 输出到顶层后命名为 `eth_clk`，`WR_REG_* / RD_REG_*` 从这里出来。
2. 看 `command_monitor_new U4`，确认 `WR_REG_*` 是它的输入，`RD_REG_DATA` 是它的输出。
3. 沿着 `command_monitor_new` 的输出往下扫 `adcdata_config U5`、`dacdata_config U6`、`ddr3_ctrl U07`、`fram_cfg U8`。
4. 只记录哪些控制量接到哪个模块，暂时不要进入这些消费者模块的内部。

读完应能回答：

```text
DL4 的核心主合同是 WR_REG/RD_REG。
WR_REG/RD_REG 由 ETHERNET_TOP 产生，在 eth_clk 域进入 command_monitor_new。
command_monitor_new 的输出再控制 DL1、DL2、DL3 和 offset/FRAM 支撑逻辑。
```

下一步：打开活动的 `ETHERNET_TOP.v`，看 UDP 端口如何进入寄存器链路。

## 3. 第二步：打开 `ETHERNET_TOP.v`

文件：`AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v`

本步目标：确认寄存器链路使用哪个 UDP 端口、哪个 payload 分流类型，以及读回数据如何发出。

搜索入口：

```text
DES_PORT_UDP_RX0
ETH_LAN_RX_INST
WR_RD_REG_TOP_inst
LAN_TX_MUX_inst
DES_PORT_UDP_TX0
```

本模块相关信号：

| 类别 | 信号/实例 | 作用 |
|---|---|---|
| 寄存器 UDP 接收端口 | `DES_PORT_UDP_RX0 = 16'h7D00` | 32000 端口，注释标为 write and read reg |
| 读回 UDP 发送端口 | `DES_PORT_UDP_TX0 = 16'h7D00` | 读寄存器响应仍从 32000 发回 |
| ADC 数据发送端口 | `DES_PORT_UDP_TX1 = 16'h7D01` | 32001，和 DL4 读回竞争发送仲裁 |
| UDP payload 分流 | `ETH_LAN_RX_INST` | 输出 `LAN_RX_TYPE`、`LAN_DATA_NUM`、`lan_data_valid/out` |
| 寄存器解析 | `WR_RD_REG_TOP_inst` | 只吃 `LAN_RX_TYPE=1` 的 payload |
| 发送仲裁 | `LAN_TX_MUX_inst` | 在读回、ADC 数据、ARP、ICMP 之间选一路发 UDP |

先忽略：

| 先忽略 | 原因 |
|---|---|
| SGMII、ARP、ICMP 的底层帧格式 | 它们是网口基础设施，不改变寄存器命令合同 |
| `upgrade_data_rx` | 它吃 `LAN_RX_TYPE=4`，属于 DL3 remote 数据，不是寄存器读写 |
| ADC `data_req/data_ACK` | 这是 DL2 上传数据通道，只在发送仲裁里和读回共享出口 |

代码阅读顺序：

1. 看端口常量：`DES_PORT_UDP_RX0=16'h7D00`、`DES_PORT_UDP_TX0=16'h7D00`、`DES_PORT_UDP_TX1=16'h7D01`。
2. 看 `ETH_LAN_RX_INST`，确认它根据 UDP 端口输出 `LAN_RX_TYPE` 和 payload 字节。
3. 看 `WR_RD_REG_TOP_inst`，确认它接收 `lan_data_valid/out` 和 `LAN_RX_TYPE`，输出 `WR_REG_* / RD_REG_*`。
4. 看 `LAN_TX_MUX_inst`，确认读回响应通过 `RD_REG_req/read_resp_tx_*` 进入 UDP 发送仲裁，端口为 `DES_PORT_UDP_TX0`。

读完应能回答：

```text
PC 应把寄存器读写 UDP 包发到 32000 端口。
ETH_LAN_RX 将这个端口标成 LAN_RX_TYPE=1。
WR_RD_REG_TOP 只解析 LAN_RX_TYPE=1 的 payload。
读回响应也从 32000 端口返回。
```

下一步：打开 `ETH_LAN_RX.v`，确认 `LAN_RX_TYPE=1` 是如何产生的。

## 4. 第三步：打开 `ETH_LAN_RX.v`

文件：`AXI_DDR.srcs/sources_1/imports/new/ETH_LAN_RX.v`

本步目标：确认 UDP/IP/MAC 过滤之后，payload 字节流怎样交给寄存器解析模块。

搜索入口：

```text
DES_PORT_UDP_RX0_i
LAN_RX_TYPE
LAN_DATA_NUM
lan_data_valid
port_type_judge
data_rx
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 端口匹配输入 | `DES_PORT_UDP_RX0_i` | 寄存器读写端口 |
| payload 长度 | `LAN_DATA_NUM` | 由 `IP_PACKET_LENGTH_REC - 28` 得到，表示 UDP payload 字节数 |
| payload 类型 | `LAN_RX_TYPE` | `4'd1` 表示寄存器读写，`4'd4` 表示 remote |
| payload 字节 | `lan_data_valid + lan_data_out[7:0]` | 给下游模块逐字节解析 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| MAC/IP header 每个字段的完整校验 | 第一轮只关心 payload 是否被分到寄存器链路 |
| `LAN_RX_TYPE=2/3/4` | 其它 UDP 业务类型，DL4 只用 type 1 |
| ILA `lan_rx_lia` | 调试观察，不参与逻辑合同 |

代码阅读顺序：

1. 看模块端口，确认 `DES_PORT_UDP_RX0_i` 的注释就是 `LAN_RX_TYPE=1 write and read reg`。
2. 找 `port_type_judge` 状态。
3. 看 `SOR_PORT_REC == DES_PORT_UDP_RX0_i` 这个分支：匹配后 `lan_data_valid <= 1`、`LAN_RX_TYPE <= 4'd1`。
4. 看 `LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28`，理解这里减掉 IP+UDP 头，留下 payload 长度。
5. 看 `data_rx` 状态，确认后续 payload 字节持续从 `lan_data_in` 输出到 `lan_data_out`。

读完应能回答：

```text
ETH_LAN_RX 不知道寄存器地址含义。
它只负责把发到 UDP 32000 的 payload 标记为 LAN_RX_TYPE=1，并按字节吐给 WR_RD_REG_TOP。
```

下一步：打开 `WR_RD_REG_TOP.v` 和 `LAN_WR_REG.v`，看 payload 字节格式。

## 5. 第四步：打开 `WR_RD_REG_TOP.v` 和 `LAN_WR_REG.v`

文件：

```text
AXI_DDR.srcs/sources_1/imports/new/WR_RD_REG_TOP.v
AXI_DDR.srcs/sources_1/imports/new/LAN_WR_REG.v
```

本步目标：确认上位机 payload 的命令格式，以及它如何变成 `WR_REG_*` / `RD_REG_*`。

搜索入口：

```text
module WR_RD_REG_TOP
LAN_WR_REG_inst
LAN_RD_REG
LAN_RX_TYPE_i == 4'd1
HEAD_TYPE == 32'h5555AAAA
CMD_TYPE == 16'h0001
CMD_TYPE == 16'h0002
WR_REG_VALID_o
RD_REG_VALID_o
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 输入字节流 | `lan_data_valid_i + lan_data_i[7:0]` | 从 `ETH_LAN_RX` 来的 payload |
| 类型过滤 | `LAN_RX_TYPE_i == 4'd1` | 只解析寄存器端口的 payload |
| 4 字节滑窗 | `data_type = {r3,r2,r1,r0}` | 逐字节移位形成 32-bit 对齐窗口 |
| 写输出 | `WR_REG_VALID_o/ADDR_o/DATA_o` | 写 `command_monitor_new` |
| 读输出 | `RD_REG_VALID_o/ADDR_o` | 读 `command_monitor_new` |
| 读延迟 | `RD_REG_VALID_r[2]` | `WR_RD_REG_TOP` 给读响应模块延迟 2 拍 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `RD_REG_req_o/RD_ACK_i` 的发送仲裁细节 | 第四步先把读写命令拆包读通，回包放到最后一步 |
| `LAN_DATA_NUM_i` | 这个模块端口接了长度，但当前状态机主要靠命令内 `LEN_TYPE` 判断 |
| 注释里的乱码 | 以实际状态机和信号名为准 |

代码阅读顺序：

1. 先看 `WR_RD_REG_TOP.v`：确认它只是包了一层 `LAN_WR_REG` 和 `LAN_RD_REG`。
2. 进入 `LAN_WR_REG.v`，看前面的 `LAN_RX_TYPE_i == 4'd1 && lan_data_valid_i`，确认其它 payload 被丢弃。
3. 看 `data_type = {lan_data_i_r3,lan_data_i_r2,lan_data_i_r1,lan_data_i_r0}`，理解状态机每到关键字节数时从滑窗取 16/32 bit 字段。
4. 按状态 0-8 读写命令：
   - header 必须是 `55 55 AA AA`，对应 `HEAD_TYPE == 32'h5555AAAA`。
   - `CMD_TYPE == 16'h0001` 表示写寄存器。
   - 写命令长度 `LEN_TYPE` 应为 `16'h0006`，后面是 2 字节地址 + 4 字节数据。
   - 完成后产生 1 拍 `WR_REG_VALID_o`。
5. 按状态 9-11 读命令：
   - `CMD_TYPE == 16'h0002` 表示读寄存器。
   - 读命令长度 `LEN_TYPE` 应为 `16'h0002`，后面是 2 字节地址。
   - 完成后产生 1 拍 `RD_REG_VALID_o`。

上位机 payload 格式可以按下面记：

| 命令 | Payload 字节 | 含义 |
|---|---|---|
| 写寄存器 | `55 55 AA AA 00 01 00 06 AA AA DD DD DD DD` | `AA AA` 是 16-bit 地址，`DD DD DD DD` 是 32-bit 数据 |
| 读寄存器 | `55 55 AA AA 00 02 00 02 AA AA` | `AA AA` 是 16-bit 地址 |

读完应能回答：

```text
DL4 的写合同是：收到写 payload 后，LAN_WR_REG 输出一拍 WR_REG_VALID，同时给出 16-bit 地址和 32-bit 数据。
DL4 的读合同是：收到读 payload 后，LAN_WR_REG 输出一拍 RD_REG_VALID，同时给出 16-bit 地址。
```

下一步：打开 `command_monitor_new.v`，看这些地址真正控制什么。

## 6. 第五步：打开 `command_monitor_new.v` 的写寄存器表

文件：`AXI_DDR.srcs/sources_1/new/command_monitor_new.v`

本步目标：建立“地址 -> 寄存器字段 -> 消费模块”的主表。这是 DL4 最核心的一步。

搜索入口：

```text
module command_monitor_new
if(wr_reg_valid)
case (wr_reg_addr)
16'h0000
16'h0200
step_module
pc_ack
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 写入口 | `wr_reg_valid/wr_reg_addr/wr_reg_data` | 从 `LAN_WR_REG` 来的写命令 |
| 读入口 | `rd_reg_valid/rd_reg_addr/rd_reg_data` | 读命令和返回数据 |
| DL1 参数 | `dac_sample`、`image_row`、`dacx_*`、`dacy_*`、`scan_mode`、`scan_state` | 控制 DAC 扫描和触发 |
| DL2 参数 | `adc_len_single`、`adc_channel`、`adc_sample`、`adc_interval`、`adc_acq_delay`、`acq_dead_time` | 控制 ADC 采样、通道、上传长度 |
| 共用参数 | `image_column`、`image_point`、`row_repeat`、`ultrafast_mode` | 同时影响 DL1/DL2 |
| DL3 参数 | `remote_rstn` | 控制 remote/DDR/QSPI 链路 |
| 支撑参数 | gain、offset、FRAM 写触发 | 模拟前端和偏置配置 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `step_module` 内部除法细节 | 先知道写某些寄存器会触发步进重算即可 |
| heartbeat 超时策略的历史注释 | 当前有效逻辑较短，第一轮只记录 `0x000D` 作用 |
| 各消费者内部如何同步参数 | 第五步只读解码表，跨域使用放到第七步 |

代码阅读顺序：

1. 看端口声明，确认所有输出都在 `eth_clk` 域由本模块寄存。
2. 看复位默认值，记住默认 `image_row/image_column=1024`、`scan_mode=1`、`scan_state=0`、`dacx/dacy` 起止默认 `0x8000`。
3. 看 `if(wr_reg_valid) case(wr_reg_addr)`，逐项建立寄存器表。
4. 注意 `0x0002` 同时写 `dac_sample` 和 `adc_sample`，这解释了 DL1/DL2 共用一个 sample 参数。
5. 注意 `0x0004` 写 `image_row/image_column` 并计算 `image_point=row*column`。
6. 注意 `0x0006` 和 `0x0007` 通过 `dacx_step_flag/dacy_step_flag` 触发 `step_module` 重算 64-bit 步进。
7. 注意 `0x0200` 出现了两次：第一次写 `sync1_pixel_tri_wigth`，第二次想写 `sync2_pixel_tri_wigth`。这是一个需要和上位机协议核对的风险点。

写寄存器主表：

| 地址 | `wr_reg_data` 位段 | 输出寄存器 | 主要消费者 | 说明 |
|---|---|---|---|---|
| `0x0000` | `[0]` | `clk_sel` | `dacdata_config` | 触发/时钟选择相关 |
| `0x0001` | `[24:4]`、`[3:0]` | `adc_len_single`、`adc_channel` | `adcdata_config` | ADC 上传长度和通道选择 |
| `0x0002` | `[31:0]` | `dac_sample`、`adc_sample` | DL1、DL2 | 每点 DAC 停留/ADC 平均共用参数 |
| `0x0003` | `[11:0]` | `adc*_gain`、`dacx/y_gain` | 配置/模拟支撑 | 增益选择 |
| `0x0004` | `[31:16]`、`[15:0]` | `image_row`、`image_column`、`image_point` | DL1、DL2 | 图像尺寸，`image_point=row*column` |
| `0x0005` | `[31:16]`、`[15:0]` | `dacx_strat_level`、`dacx_end_level` | DL1 | X 起止电平 |
| `0x0006` | `[31:16]`、`[15:0]` | `dacx_tk_point`、`dacx_recovery_time` | DL1 | X 点数/恢复时间，同时触发 X 步进重算 |
| `0x0007` | `[31:16]`、`[15:0]` | `dacy_strat_level`、`dacy_end_level` | DL1 | Y 起止电平，同时触发 Y 步进重算 |
| `0x0008` | `[31:0]` | `frame_waiting_time` | DL1 | 帧间等待 |
| `0x000F` | `[31:0]` | `dax_fall_time` | DL1 | X 回落时间/模式 |
| `0x0009` | `[31:8]`、`[7:4]`、`[3:0]` | `adc_interval`、`scan_mode`、`scan_state` | DL1、DL2 | 采样间隔、扫描模式、启停状态 |
| `0x000C` | `[0]` | `remote_rstn` | DL3 | remote/DDR/QSPI 复位使能 |
| `0x000D` | `[31:0]` | `heart_beat` | 本模块 | 心跳/保活相关 |
| `0x000E` | `[31:0]` | `pc_ack` | `LAN_TX_FREAME` | PC ack，在扫描启动时有效 |
| `0x0010` | `[31:0]` | `offset_adc1_adc2` | `fram_cfg` | ADC1/2 offset |
| `0x0011` | `[31:0]` | `offset_adc3_adc4` | `fram_cfg` | ADC3/4 offset |
| `0x0012` | `[31:0]` | `offset_dacx_dacy`、`wr_offset_flag` | `fram_cfg` | DAC X/Y offset，并产生写 FRAM 脉冲 |
| `0x0013` | `[15:0]` | `row_repeat` | DL2/DL1 | 行重复，写 0 时强制为 1 |
| `0x0014` | `[31:16]`、`[15:0]` | `row_m`、`row_n` | DL1 | 隔行/分组扫描参数，`row_n` 写 0 时强制为 1 |
| `0x0200` | `[15:0]` | `sync1_pixel_tri_wigth` | DL1 sync1 | sync1 宽度 |
| `0x0201` | `[31:0]` | `adc_acq_delay` | DL2 ultrafast | 超快模式采集延时 |
| `0x0202` | `[31:1]`、`[0]` | `ultrafast_line_rec`、`ultrafast_mode` | DL1、DL2 | 超快模式和行恢复时间 |
| `0x0203` | `[31:16]`、`[15:0]` | `sync_sig_delay1`、`sync_sig_delay2` | DL1 sync | sync 输出延时 |
| `0x0204` | `[31:0]` | `acq_dead_time` | DL2 ultrafast | 超快模式死区 |
| `0x0205` | `[0]` | `laser_mode_en` | DL5 laser sync | 1=启用激光同步模式；按当前设计约束，应只在 `scan_state=0` 时切换 |
| `0x0206` | `[15:0]` | `scan_delay_time` | DL5 laser sync | laser 上升沿到写新像素的延时；当前 UNIT_002 设计按 eth_clk 拍，约 8ns 步进 |
| `0x0207` | `[15:0]` | `blanker_delay_time` | DL5 laser sync | laser 到 blanker 输出延时；ui_clk 域 5ns 步进 |
| `0x0208` | `[15:0]` | `blanker_time` | DL5 laser sync | blanker 窗口宽度；ui_clk 域 5ns 步进 |
| `0x0209` | `[15:0]` | `acq_data_delay_time` | DL5 laser sync | laser 到 ADC 采集窗口延时；上位机按 20ns 步进配置，内部 `<<2` 到 ui_clk 拍 |
| `0x020A` | `[15:0]` | `acq_time` | DL5 laser sync | ADC 采集窗口宽度；上位机按 20ns 步进配置，内部 `<<2` 到 ui_clk 拍 |
| `0x0200` | `[15:0]` | `sync2_pixel_tri_wigth` | DL1 sync2 | 和 sync1 地址重复，疑似协议/代码风险 |

读完应能回答：

```text
command_monitor_new 是 DL4 的寄存器影子表。
它在 eth_clk 域把地址和 32-bit 数据翻译成 DL1/DL2/DL3 的控制参数。
0x0200 重复定义需要重点核对，因为它可能导致 sync2 宽度无法独立配置。
```

下一步：仍在 `command_monitor_new.v`，看读回表和派生寄存器。

## 7. 第六步：读 `command_monitor_new.v` 的读回表和派生逻辑

文件：`AXI_DDR.srcs/sources_1/new/command_monitor_new.v`

本步目标：确认 PC 读寄存器时能读回哪些值，哪些写寄存器没有读回入口。

搜索入口：

```text
if(rd_reg_valid)
case (rd_reg_addr)
version_number
remote_result_reg
step_module dax_step_module
step_module day_step_module
pc_ack_r
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 读入口 | `rd_reg_valid/rd_reg_addr` | 读请求 |
| 读返回 | `rd_reg_data` | 32-bit 读回值 |
| 版本号 | `version_number={16'd3,16'd172}` | `0x000A` 读回 |
| remote 状态 | `remote_result_reg[2]` | `0x000B` 读回，做了 3 级寄存 |
| 步进派生 | `dacx_step/dacy_step` | 由 `step_module` 根据起止电平和点数计算，不直接读回 |
| PC ack 派生 | `pc_ack_r` | `scan_state[0]` 为 1 时才保持写入的 `pc_ack` |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `step_module` 的具体算法 | 已在 DL1 背景中看过，这里只关心它由哪些寄存器触发 |
| 被注释掉的心跳复位旧逻辑 | 当前有效逻辑里 `heart_rst` 不会被超时置 1 |
| `0x0201~0x0204` 的读回 | 当前读回 case 没列这些地址，文档只按实际代码记录 |

代码阅读顺序：

1. 看 `if(rd_reg_valid) case(rd_reg_addr)`，逐项对照写表。
2. 注意读回表覆盖 `0x0000~0x0014` 的主要基础参数，但没有覆盖 `0x0200~0x0204`。
3. 看 default：未知地址读回 `32'h11223344`。
4. 看 `remote_result_reg`，理解 `remote_result` 被延迟 3 拍后读回。
5. 看两个 `step_module` 实例：`dacx_step_flag` 和 `dacy_step_flag` 是写寄存器时的一拍重算触发。
6. 看 `pc_ack_r`：只有 `scan_state[0]` 为 1 时，写 `0x000E` 才会保持到 `pc_ack_r`，否则清 0。

读寄存器主表：

| 地址 | 读回内容 | 说明 |
|---|---|---|
| `0x0000` | `{31'd0, clk_sel}` | 时钟/触发选择 |
| `0x0001` | `{7'd0, adc_len_single, adc_channel}` | ADC 长度和通道 |
| `0x0002` | `adc_sample` | 注意写时 `adc_sample` 和 `dac_sample` 同值，读回只读 `adc_sample` |
| `0x0003` | gain 打包 | ADC/DAC gain |
| `0x0004` | `{image_row, image_column}` | 图像尺寸 |
| `0x0005` | `{dacx_strat_level, dacx_end_level}` | X 起止电平 |
| `0x0006` | `{dacx_tk_point, dacx_recovery_time}` | X 点数/恢复 |
| `0x0007` | `{dacy_strat_level, dacy_end_level}` | Y 起止电平 |
| `0x0008` | `frame_waiting_time` | 帧等待 |
| `0x000F` | `dax_fall_time` | X 回落 |
| `0x0009` | `{adc_interval, scan_mode, scan_state}` | 采样间隔/模式/启停 |
| `0x000A` | `version_number` | 版本号 `3.172` 的打包值 |
| `0x000B` | `remote_result_reg[2]` | remote 状态 |
| `0x000C` | `{31'd0, remote_rstn}` | remote 复位 |
| `0x000D` | `heart_beat` | 心跳值 |
| `0x0010` | `offset_adc1_adc2` | offset |
| `0x0011` | `offset_adc3_adc4` | offset |
| `0x0012` | `offset_dacx_dacy` | offset |
| `0x0013` | `{16'd0, row_repeat}` | 行重复 |
| `0x0014` | `{row_m, row_n}` | 分组/隔行参数 |
| `0x0205` | `{31'd0, laser_mode_en}` | DL5 激光同步模式开关 |
| `0x0206` | `{16'd0, scan_delay_time}` | DL5 scan delay |
| `0x0207` | `{16'd0, blanker_delay_time}` | DL5 blanker delay |
| `0x0208` | `{16'd0, blanker_time}` | DL5 blanker width |
| `0x0209` | `{16'd0, acq_data_delay_time}` | DL5 acq delay |
| `0x020A` | `{16'd0, acq_time}` | DL5 acq width |
| 其它 | `32'h11223344` | 未定义地址默认值 |

读完应能回答：

```text
PC 读回不是完整镜像。0x0200~0x0204 在当前代码里没有读回 case。
UNIT_002 新增的 0x0205~0x020A 已有读回 case。
读未知地址会返回 0x11223344。
步进值 dacx_step/dacy_step 是派生输出，不通过读寄存器返回。
```

下一步：回到 `ETH_TOP.v`，把寄存器输出和消费者模块对应起来。

## 8. 第七步：回到 `ETH_TOP.v` 看消费者

文件：`AXI_DDR.srcs/sources_1/new/ETH_TOP.v`

本步目标：确认 `command_monitor_new` 输出不是终点，它们分别约束 DL1、DL2、DL3 和支撑链路。

搜索入口：

```text
adcdata_config U5
dacdata_config U6
ddr3_ctrl U07
fram_cfg U8
offset_dac_cfg U9
```

本模块相关信号：

| 消费模块 | 接收的 DL4 控制量 | 影响 |
|---|---|---|
| `adcdata_config U5` | `row_repeat`、`image_point`、`adc_len_single`、`adc_channel`、`adc_sample`、`image_column`、`adc_interval`、`ultrafast_mode`、`acq_dead_time`、`adc_acq_delay`、`scan_state[0]`、`pc_ack` | DL2 采样窗口、平均、通道打包、DDR/以太网上传和 ultrafast 行计数 |
| `dacdata_config U6` | `dac_sample`、`image_row`、`dacx_*`、`dacy_*`、`frame_waiting_time`、`dax_fall_time`、`scan_mode`、`ultrafast_mode`、`ultrafast_line_rec`、`sync_sig_delay*`、`scan_state[0]`、`row_repeat`、`sync*_pixel_tri_wigth`、`row_m/row_n`、`clk_sel` | DL1 DAC 扫描轨迹、触发、sync 输出 |
| `ddr3_ctrl U07` | `remote_rstn` | DL3 remote 数据写 DDR/读 QSPI 的启停 |
| `fram_cfg U8` | `wr_offset_flag`、`offset_*` | 写入或保存 offset 参数 |
| `offset_dac_cfg U9` | `offset_adc*`、`offset_dac*` | 把 FRAM/offset 参数输出到板级偏置 DAC/I2C |

先忽略：

| 先忽略 | 原因 |
|---|---|
| 各消费者内部状态机 | 这些已经属于 DL1/DL2/DL3 深读内容 |
| `pkg*_` FDMA 信号 | 寄存器只控制它们的行为，不直接搬运这些数据 |
| 板级模拟配置细节 | 当前目标是建立控制参数路由 |

代码阅读顺序：

1. 对照 `command_monitor_new U4` 的输出端口，看每个控制量在顶层 wire 名字是否一致。
2. 看 `adcdata_config U5` 端口，只记录 DL2 消费了哪些参数。
3. 看 `dacdata_config U6` 端口，只记录 DL1 消费了哪些参数。
4. 看 `ddr3_ctrl U07`，确认 DL4 对 DL3 的直接控制主要是 `remote_rstn`。
5. 看 `fram_cfg U8` 和 `offset_dac_cfg U9`，确认 offset 参数的两级消费关系。

读完应能回答：

```text
DL4 本身不采样、不扫描、不写 DDR。
它给其它模块提供参数，真正的数据链路行为发生在 DL1/DL2/DL3 消费这些参数之后。
```

下一步：读回链路还差最后一段，打开 `LAN_RD_REG.v` 和 `LAN_TX_MUX.v`。

## 9. 第八步：打开 `LAN_RD_REG.v` 和 `LAN_TX_MUX.v`

文件：

```text
AXI_DDR.srcs/sources_1/imports/new/LAN_RD_REG.v
AXI_DDR.srcs/sources_1/imports/new/LAN_TX_MUX.v
```

本步目标：确认读寄存器响应怎样被打包并通过 UDP 发回 PC。

搜索入口：

```text
packet_array
REG_VALID
RD_REG_req_o
RD_ACK_i
S_RD_REG
read_resp_tx_valid_i
read_resp_port
wr_last_pack_num_o <= 16'd14
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 读返回输入 | `REG_VALID/REG_ADDR/REG_DATA` | 来自 `WR_RD_REG_TOP` 和 `command_monitor_new` |
| 响应包数组 | `packet_array[0:13]` | 固定 14 字节读回 payload |
| 发送请求 | `RD_REG_req_o` | 通知 `LAN_TX_MUX` 需要发读回包 |
| 发送应答 | `RD_ACK_i` | `LAN_TX_MUX` 允许读回通道发送 |
| 读回发送态 | `S_RD_REG` | `LAN_TX_MUX` 选择读回 payload，端口为 `read_resp_port` |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `S_TX_DATA` | ADC 数据上传，不是寄存器读回 |
| `S_ARP/S_ICMP` | 网络基础响应 |
| UDP header 生成细节 | `LAN_TX_MUX` 只把 payload 和端口交给 UDP 发送模块 |

代码阅读顺序：

1. 看 `LAN_RD_REG.v` 的 `packet_array`，确认响应格式固定为 14 字节：
   - `55 55 AA AA`
   - `00 03`
   - `00 06`
   - 2 字节地址
   - 4 字节数据
2. 看 `REG_VALID` 分支，确认它锁存 `REG_ADDR/REG_DATA` 并拉高 `RD_REG_req_o`。
3. 看等待 `RD_ACK_i` 上升沿后进入发送状态。
4. 看发送状态连续输出 14 个字节的 `lan_data_valid_o/lan_data_o`。
5. 打开 `LAN_TX_MUX.v`，看 `S_IDLE` 中 `RD_REG_req_i` 优先于 `data_req_i`。
6. 看 `S_RD_REG`：`wr_pack_num_o=1`、`wr_last_pack_num_o=14`、`DES_PORT_o=read_resp_port`，并把 `read_resp_tx_data_i` 写入 UDP payload FIFO。

读回响应 payload 格式：

| 字节 | 内容 | 含义 |
|---:|---|---|
| 0-3 | `55 55 AA AA` | 响应头 |
| 4-5 | `00 03` | 读寄存器响应命令 |
| 6-7 | `00 06` | 后续地址 2 字节 + 数据 4 字节 |
| 8-9 | `REG_ADDR` | 被读地址 |
| 10-13 | `REG_DATA` | 32-bit 读回值 |

读完应能回答：

```text
读寄存器响应是 14 字节 payload。
LAN_TX_MUX 在读回请求和 ADC 上传同时存在时，代码顺序上先服务 RD_REG_req_i。
读回使用 32000 端口，ADC 数据上传使用 32001 端口。
```

下一步：如果要调板，就按最后的验证信号组抓 ILA。

## 10. 数据形态变化表

| 位置 | 数据名 | 位宽 | 语义 | 有效条件 | 变化 |
|---|---|---:|---|---|---|
| UDP payload | 写包 payload | 14 byte | header + cmd + len + addr + data | UDP 32000 收到完整包 | 外部网络数据 |
| UDP payload | 读包 payload | 10 byte | header + cmd + len + addr | UDP 32000 收到完整包 | 外部网络数据 |
| `ETH_LAN_RX` | `lan_data_out` | 8 | payload 字节 | `lan_data_valid=1` 且 `LAN_RX_TYPE=1` | 去掉 MAC/IP/UDP 头 |
| `LAN_WR_REG` | `data_type` | 32 | 4 字节滑动窗口 | `lan_data_valid_r=1` | 字节流临时拼成 32-bit |
| `LAN_WR_REG` | `WR_REG_ADDR` | 16 | 控制寄存器地址 | 写包解析完成 | 从 payload 地址字段拆出 |
| `LAN_WR_REG` | `WR_REG_DATA` | 32 | 控制寄存器数据 | 写包解析完成 | 从 payload 数据字段拆出 |
| `command_monitor_new` | 控制寄存器输出 | 多种 | DL1/DL2/DL3 参数 | `wr_reg_valid=1` 且地址命中 | 地址解码和字段拆分 |
| `command_monitor_new` | `RD_REG_DATA` | 32 | 读回状态/参数 | `rd_reg_valid=1` 且地址命中 | 地址选择 |
| `LAN_RD_REG` | 读回 payload | 14 byte | header + `00 03` + len + addr + data | 收到 `RD_ACK` 后 | 读回数据重新打包成字节流 |

## 11. CDC 和缓冲结构

DL4 主解析链路基本在一个时钟域内：

```text
ETHERNET_TOP.user_axis_clk -> 顶层 eth_clk -> WR_RD_REG_TOP -> command_monitor_new
```

| 结构 | 写时钟 | 读时钟 | 数据 | 写条件 | 读条件 | 风险 |
|---|---|---|---|---|---|---|
| DL4 寄存器解析主链 | `user_axis_clk/eth_clk` | 同域 | `WR_REG_* / RD_REG_*` | UDP payload 被解析 | `command_monitor_new` 直接采样 | 低，主链同域 |
| 读回发送仲裁 | `user_axis_clk` | 同域进入 UDP 发送模块 | 读回 payload 字节 | `LAN_RD_REG` 输出 valid | `LAN_TX_MUX` 选中 S_RD_REG | 中，和 ADC 上传共享发送出口，但代码优先读回 |
| 控制量进入 DL1 | `eth_clk` | `dac_dco/ui_clk` 等 | DAC/scan/sync 参数 | 写寄存器后保持 | 消费模块内部同步或采样 | 中，需在 DL1 验证参数同步 |
| 控制量进入 DL2 | `eth_clk` | `ui_clk/adc_dco` | ADC/ultrafast 参数 | 写寄存器后保持 | `adcdata_config/adcdata_acq` 内部同步 | 中，需在 DL2 验证触发边界 |
| 控制量进入 DL3 | `eth_clk` | `ui_clk/clk50m` | `remote_rstn` | 写 `0x000C` | `ddr3_ctrl` 消费 | 中，remote 链路另需深读 |

## 12. 风险和待确认点

| 风险 | 代码证据 | 影响 | 建议 |
|---|---|---|---|
| `0x0200` 重复 case | `command_monitor_new.v` 写表中 `0x0200` 同时用于 `sync1_pixel_tri_wigth` 和 `sync2_pixel_tri_wigth` | `sync2` 宽度可能无法通过上位机独立配置 | 和上位机协议核对，确认第二个是否应为 `0x0205` 或其它地址 |
| `0x0201~0x0204` 无读回 | 读回 case 到 `0x0014` 后 default | 上位机写 ultrafast 参数后无法直接读回确认 | 如果协议需要闭环确认，补读回地址 |
| 写 `0x0002` 同时改 `dac_sample` 和 `adc_sample` | `0x0002` 分支两个寄存器同写 | DAC 停留时间和 ADC 平均长度绑定 | 确认上位机是否预期二者永远一致 |
| 读回优先于 ADC 上传 | `LAN_TX_MUX` 的 `S_IDLE` 先判断 `RD_REG_req_i` 再判断 `data_req_i` | 频繁读寄存器可能短暂抢占 ADC 上传 UDP 口 | 调试时可以接受，正式高吞吐时注意读寄存器频率 |
| 控制量跨域依赖消费者同步 | DL4 输出都在 `eth_clk` 域，DL1/DL2 有其它时钟域 | 启停/参数边界若同步不当会影响一帧 | 用 DL1/DL2 ILA 验证 `scan_state`、sample、ultrafast 参数更新时机 |

## 13. 关键证据索引

| 结论 | 证据位置 | 读源码时看什么 |
|---|---|---|
| `ETHERNET_TOP` 输出寄存器读写主合同 | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v:335`、`ETH_TOP.v:379` | `WR_REG_VALID/ADDR/DATA`、`RD_REG_VALID/ADDR/DATA` 从以太网顶层接出 |
| `command_monitor_new` 是集中解码点 | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v:500` | `WR_REG_*`、`RD_REG_*` 接入 `command_monitor_new U4` |
| 寄存器端口是 UDP 32000 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v:140` | `DES_PORT_UDP_RX0/TX0 = 16'h7D00` |
| UDP payload 先由 `ETH_LAN_RX` 分类 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v:268`、`ETHERNET_TOP.v:313` | `ETH_LAN_RX_INST` 输出 `LAN_RX_TYPE/lan_data_out` 给 `WR_RD_REG_TOP_inst` |
| 32000 端口对应 `LAN_RX_TYPE=1` | `AXI_DDR.srcs/sources_1/imports/new/ETH_LAN_RX.v:263` | 端口匹配后设置 `LAN_RX_TYPE <= 4'd1` |
| `WR_RD_REG_TOP` 只是包装写解析和读响应 | `AXI_DDR.srcs/sources_1/imports/new/WR_RD_REG_TOP.v:44`、`WR_RD_REG_TOP.v:66` | `LAN_WR_REG` 产生读写命令，`LAN_RD_REG` 产生读回 payload |
| 写包命令号是 `0x0001`，读包命令号是 `0x0002` | `AXI_DDR.srcs/sources_1/imports/new/LAN_WR_REG.v:144` | `CMD_TYPE` 分支选择写或读 |
| 写寄存器地址和数据从 payload 中拆出 | `AXI_DDR.srcs/sources_1/imports/new/LAN_WR_REG.v:162`、`LAN_WR_REG.v:171` | 先取 16-bit 地址，再取 32-bit 数据 |
| `command_monitor_new` 写寄存器表 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v:191` | `case(wr_reg_addr)` 定义上位机地址协议 |
| `0x0200` 重复定义 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v:254`、`command_monitor_new.v:271` | sync1/sync2 宽度地址冲突 |
| `command_monitor_new` 读回表 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v:293` | `case(rd_reg_addr)` 定义可读地址 |
| 读回响应固定 14 字节 | `AXI_DDR.srcs/sources_1/imports/new/LAN_RD_REG.v:38`、`LAN_RD_REG.v:95` | `packet_array[0:13]` 和发送状态 |
| 读回发送优先于 ADC 数据上传 | `AXI_DDR.srcs/sources_1/imports/new/LAN_TX_MUX.v:90`、`LAN_TX_MUX.v:93` | `S_IDLE` 先判断 `RD_REG_req_i` 再判断 `data_req_i` |

## 14. 上板验证信号组

寄存器写入最小验证：

```text
eth_clk
eth_rstn
LAN_RX_TYPE
lan_data_valid
lan_data_out
WR_REG_VALID
WR_REG_ADDR
WR_REG_DATA
```

写入到参数生效验证：

```text
WR_REG_VALID
WR_REG_ADDR
WR_REG_DATA
scan_state
scan_mode
adc_sample
dac_sample
image_row
image_column
ultrafast_mode
```

读回验证：

```text
RD_REG_VALID
RD_REG_ADDR
RD_REG_DATA
RD_REG_req
RD_ACK
lan_data_valid_rd
lan_data_rd
DES_PORT_UDP
```

排查 `sync2` 配置问题时优先看：

```text
WR_REG_VALID
WR_REG_ADDR
WR_REG_DATA
sync1_pixel_tri_wigth
sync2_pixel_tri_wigth
```

如果写 `0x0200` 只改变 `sync1_pixel_tri_wigth`，而 `sync2_pixel_tri_wigth` 不变，就说明重复 case 风险在综合后的硬件行为里确实影响了 sync2 配置。

## 15. 上位机开发协议补充（2026-05-30）

本节把前面的 RTL 阅读结果收敛成“上位机可以直接实现”的协议说明。结论是：DL4 已经足够支持一个基础上位机的寄存器读写层，但原文档还不够支撑一个可靠、可维护的完整应用；缺的主要是 PC 侧 socket 约束、读写确认策略、寄存器可读性边界、扫描/激光模式配置流程，以及错误处理约定。

### 15.1 网络端点与过滤条件

| 项 | 当前结论 | 源码证据 |
|---|---|---|
| FPGA 默认 IP | `192.168.1.8` (`0xC0A80108`) | `LAN_RX_ARP.v:44-52` |
| FPGA 默认 MAC | `5C:85:7E:EE:00:00` | `LAN_RX_ARP.v:51-52` |
| FPGA UDP 固定端口 | `32000` (`0x7D00`) | `ETHERNET_TOP.v:191-197` |
| 寄存器读写业务类型 | `LAN_RX_TYPE=1` | `ETH_LAN_RX.v:315-320` |
| 寄存器读回端口 | 仍为 `32000` | `LAN_TX_MUX.v:137-147` |

PC 侧不要用随机本地 UDP 端口。`ETH_LAN_RX` 的实际过滤条件是：

```text
目标 MAC == FPGA MAC
目标 IP  == FPGA IP
UDP 目标端口 == 32000
UDP 源端口   == 32000
```

因此上位机建议：

```text
bind(local_ip, 32000)
sendto(fpga_ip=192.168.1.8, fpga_port=32000)
recvfrom(local_port=32000)
```

PC 网卡建议放在同一网段，例如 `192.168.1.x/24`。首次通信前可先 `ping 192.168.1.8` 或发送 ARP，让板卡学习 PC 的 MAC/IP；读回 UDP 使用 ARP 学到的 PC 地址作为目的地址。

### 15.2 Payload 编解码

所有多字节字段都是大端，高字节先发。

写寄存器：

```text
55 55 AA AA 00 01 00 06 ADDR_H ADDR_L DATA[31:24] DATA[23:16] DATA[15:8] DATA[7:0]
```

读寄存器：

```text
55 55 AA AA 00 02 00 02 ADDR_H ADDR_L
```

读回响应：

```text
55 55 AA AA 00 03 00 06 ADDR_H ADDR_L DATA[31:24] DATA[23:16] DATA[15:8] DATA[7:0]
```

上位机底层可以按下面的函数模型实现：

```python
def pack_write(addr: int, data: int) -> bytes:
    return (
        b"\x55\x55\xaa\xaa"
        + b"\x00\x01"
        + b"\x00\x06"
        + addr.to_bytes(2, "big")
        + data.to_bytes(4, "big")
    )

def pack_read(addr: int) -> bytes:
    return (
        b"\x55\x55\xaa\xaa"
        + b"\x00\x02"
        + b"\x00\x02"
        + addr.to_bytes(2, "big")
    )

def parse_read_response(payload: bytes, expected_addr: int) -> int:
    if len(payload) < 14:
        raise ValueError("short read response")
    if payload[0:8] != b"\x55\x55\xaa\xaa\x00\x03\x00\x06":
        raise ValueError("bad read response header")
    addr = int.from_bytes(payload[8:10], "big")
    if addr != expected_addr:
        raise ValueError(f"read response addr mismatch: 0x{addr:04X}")
    return int.from_bytes(payload[10:14], "big")
```

### 15.3 读写确认策略

写命令本身没有 ACK 包。上位机不要假设 `sendto()` 成功就等于 FPGA 已经写入。

建议策略：

| 寄存器类型 | 推荐确认方式 |
|---|---|
| 有读回 case 的寄存器 | 写后读同地址，比对读回值 |
| 只写寄存器 | 写后读一个相关状态寄存器，或延时后继续流程 |
| 启停类寄存器 `0x0009` | 写后读 `0x0009`，确认 `scan_state/scan_mode/adc_interval` |
| DL5 `0x0205~0x020A` | 写后逐项读回，确认参数影子寄存器已更新 |
| `0x0200~0x0204` | 当前不能直接读回；只能通过 ILA/外部波形或后续补 RTL 读回确认 |

读命令建议超时重试：

```text
read timeout: 100~500 ms 起步
retry: 3 次
失败后重新 ARP/ping，再重试一次会话
```

调试时可以频繁读寄存器；正式采集时不要高频轮询，因为 `LAN_TX_MUX` 读回响应优先于 ADC 数据上传，可能短暂抢占 UDP 发送出口。

### 15.4 上位机寄存器模型建议

上位机不要在 UI 层到处手写地址和 bit slice。建议建三层：

| 层 | 职责 |
|---|---|
| UDP transport | 绑定本地 32000、发包、收包、超时、重试、解析响应 |
| Register client | `read32(addr)`、`write32(addr,data)`、`write_checked(addr,data)` |
| Domain model | `set_image_size(row,column)`、`set_scan_timing(...)`、`set_laser_sync(...)`、`start_scan()`、`stop_scan()` |

寄存器值打包规则建议集中在一个表或枚举里，例如：

```text
0x0001 = {7'd0, adc_len_single[20:0], adc_channel[3:0]}
0x0004 = {image_row[15:0], image_column[15:0]}
0x0005 = {dacx_start[15:0], dacx_end[15:0]}
0x0006 = {dacx_tk_point[15:0], dacx_recovery_time[15:0]}
0x0007 = {dacy_start[15:0], dacy_end[15:0]}
0x0009 = {adc_interval[23:0], scan_mode[3:0], scan_state[3:0]}
0x0202 = {ultrafast_line_rec[30:0], ultrafast_mode[0]}
0x0203 = {sync_sig_delay1[15:0], sync_sig_delay2[15:0]}
```

### 15.5 安全配置流程

普通扫描参数建议流程：

```text
1. stop_scan: 写 0x0009，把 scan_state 置 0，保留/设置 adc_interval 和 scan_mode
2. 写图像尺寸、DAC 起止、电平、sample、row_repeat 等参数
3. 对有读回的关键参数做 write_checked
4. 如需 ADC 上传，准备 PC 接收 32001 端口的数据
5. start_scan: 写 0x0009，把 scan_state 置 1
```

DL5 激光同步模式建议流程：

```text
1. stop_scan
2. 写 0x0205 = 0，确保先关 laser mode
3. 写 0x0206~0x020A：scan_delay / blanker_delay / blanker_time / acq_delay / acq_time
4. 写 0x0205 = 1
5. 读回 0x0205~0x020A，确认参数
6. start_scan
```

切换 `laser_mode_en` 时遵守“停扫描 -> 改模式和参数 -> 开扫描”。这是 DL5 当前 RTL 复位/状态机策略的一部分，不建议在扫描中途热切模式。

### 15.6 当前还不能只靠 DL4 解决的事

| 缺口 | 对上位机的影响 | 建议 |
|---|---|---|
| 写命令无 ACK | 上位机必须自己做写后读或流程级确认 | 寄存器 client 默认提供 `write_checked` |
| `0x0200~0x0204` 无读回 | sync/ultrafast 部分参数不能闭环确认 | 后续若上位机必须显示真实值，建议补 RTL 读回 |
| `0x0200` 重复 case | `sync2_pixel_tri_wigth` 通常不可配置 | 上位机先禁用 sync2 宽度配置，或等 RTL 修地址 |
| ADC 数据上传协议属于 DL2 | DL4 只能启动/配置采集，不能解释 32001 数据 | 上位机的数据接收/解析要继续看 DL2 文档 |
| remote 固件升级属于 DL3 | DL4 只负责 `remote_rstn` 和结果读回 | 固件升级页面要继续看 DL3 文档 |
| 上板网络环境未记录 | PC IP、网卡选择、ARP 行为会影响连通性 | 上位机提供网卡选择、ping/ARP 检查和连接诊断 |

### 15.7 上位机最小可行版本

第一版上位机建议先做成一个“寄存器控制台 + 参数表单”，不要一开始就把采图、波形、DL5 全塞进去。

最小功能：

```text
1. 选择本地网卡 / 本地 IP，绑定 UDP 32000
2. 读版本号 0x000A，期望返回 0x000300AC
3. 任意 read32/write32 调试面板
4. 基础参数表：0x0001~0x0014
5. DL5 参数表：0x0205~0x020A
6. stop_scan / start_scan 两个明确按钮
7. 日志窗口显示每次发包、收包、超时、重试、读回值
```

等这层稳定后，再接 DL2 的 ADC 数据 UDP 32001 接收和图像显示。

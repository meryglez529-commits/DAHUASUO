# DL3 remote 固件升级 / DDR / QSPI 代码阅读指导手册

这份文档用于精读 DL3：PC 通过以太网发送 remote 固件数据，FPGA 把 UDP payload 解析成固件字节流，先写入 DDR，再从 DDR 读出并通过 QSPI 控制器烧录到配置 Flash。

它不是模块功能清单，而是一份“带你重新打开源码”的阅读手册。第一遍读的时候，把本文和源码并排放，按步骤搜关键字，不要从每个文件第一行一路读到底。

## 0. 使用方法

DL3 的真实生产方向是输入链路，所以第一遍按数据正向读：

```text
PC UDP 32004 remote payload
  -> ETHERNET_TOP / ETH_LAN_RX 标成 LAN_RX_TYPE=4
  -> upgrade_data_rx 校验 remote 包头、提取长度、8-bit 字节转 16-bit word
  -> ddr3_ctrl / fdma_controller_write 跨到 ui_clk，按 64-bit FDMA beat 写 DDR
  -> fdma_controller_read 从 DDR 读回，转成 clk_50m 域 4-bit nibble
  -> multiboot_cfg_new / qspi_cfg 按 QSPI 命令擦除、页编程 Flash
  -> qspi_d0~d3 / qspi_csb / qspi_clk
```

推荐阅读顺序如下：

| Pass | 打开文件 | 本轮只解决的问题 |
|---:|---|---|
| 1 | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v` | DL3 在顶层的边界是什么，remote 数据接到哪几个模块 |
| 2 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v`、`ETH_LAN_RX.v` | UDP 32004 如何变成 `LAN_RX_TYPE=4` 的 payload 字节流 |
| 3 | `AXI_DDR.srcs/sources_1/new/upgrade_data_rx.v` | remote payload 格式是什么，如何变成 `remote_wr_en/remote_wr_data` |
| 4 | `AXI_DDR.srcs/sources_1/new/ddr3_ctrl.v`、`fdma_controller_write.v` | 16-bit remote 数据如何跨时钟并写入 DDR |
| 5 | `AXI_DDR.srcs/sources_1/new/fdma_controller_read.v` | DDR 中的数据如何读出并变成 QSPI 需要的 4-bit nibble |
| 6 | `AXI_DDR.srcs/sources_1/new/multiboot_cfg_new.v`、`imports/new/qspi_cfg.v` | QSPI 烧录状态机如何消费 `data_in` 并反馈结果 |
| 7 | `command_monitor_new.v` | 哪些寄存器控制/观测 DL3 |

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

DL3 的业务数据是“固件/配置文件字节流”，不是 DDR 本身，也不是 QSPI 控制命令本身。DDR 是中转缓存，QSPI 是最终外设写入接口。

### 1.1 主数据形态

| 位置 | 数据名 | 位宽 | 语义 | 有效条件 | 变化 |
|---|---:|---:|---|---|---|
| UDP 32004 payload | remote 包 | 8 bit byte | 固件升级文件流，前 12 字节含魔数和长度 | UDP 目标端口 32004 且 MAC/IP 匹配 | 外部网络输入 |
| `ETH_LAN_RX` 输出 | `lan_data_out` | 8 | 去掉 MAC/IP/UDP 头后的 payload 字节 | `lan_data_valid=1 && LAN_RX_TYPE=4` | 网络包转成业务字节流 |
| `upgrade_data_rx` 滑窗 | `lan_data[95:0]` | 96 | 最近 12 个字节，用于识别 `55AA55AA00000000 + length` | `lan_data_valid_r=1` | 字节流临时成 12-byte 窗口 |
| remote 长度 | `remote_len` | 32 | 固件文件有效字节数 | 包头命中且 length > 100 | payload 字段解释成长度 |
| remote 写流 | `remote_wr_data` | 16 | 两个连续文件字节组成的 16-bit word | `remote_wr_en=1` | 8-bit 字节两两合并 |
| FDMA 写 FIFO | `pkg_wr_data` | 64 | 写入 DDR 的 remote 数据 beat | `pkg_wr_en=1` | FIFO 把 16-bit 输入聚合为 64-bit 输出 |
| DDR 读返回 | `pkg_rd_data` | 64 | 从 DDR 读出的 remote 数据 beat | `pkg_rd_en=1` | DDR 中转 |
| QSPI 预取 FIFO | `sec_data` | 32 | 从 DDR 读出的数据进一步整理后送低速 FIFO | `pre_rd_en/sec_wr_en` | 64-bit 到 32-bit FIFO 级联 |
| QSPI 输入 | `data_in` | 4 | QSPI quad program 每拍使用的 4-bit nibble | `data_in_flag=1` | 32-bit FIFO 到 4-bit nibble |
| QSPI 引脚 | `qspi_d0~d3` | 4 | Flash 四线数据 | `qspi_csb=0`，`bir` 控制方向 | 写入外部配置 Flash |

### 1.2 最小通路图

```text
PC UDP 32004
  -> ETH_LAN_RX
     LAN_RX_TYPE=4, lan_data_out[7:0]
  -> upgrade_data_rx
     header: 55 AA 55 AA 00 00 00 00
     length: 32-bit remote_len
     file bytes padded to 1024-byte boundary
     output: remote_wr_en + remote_wr_data[15:0]
  -> fdma_controller_write
     eth_clk 16-bit -> FIFO -> ui_clk 64-bit
     pkg_wr_* writes DDR in 128-beat bursts
  -> DDR3 through system_wrapper / MSXBO_FDMA / MIG
  -> fdma_controller_read
     pkg_rd_* reads DDR in 128-beat bursts
     ui_clk FIFO -> clk_50m FIFO
     output: data_in[3:0] when qspi_cfg raises data_in_flag
  -> qspi_cfg
     erase sectors from 0x0100_0000
     program pages, max 256 bytes/page
     report remote_result / remote_complete
  -> qspi_d0~d3, qspi_csb, qspi_clk
```

### 1.3 时钟域

| 时钟域 | 来源 | DL3 中的作用 |
|---|---|---|
| `user_axis_clk` / `eth_clk` | SGMII/TEMAC 用户时钟 | UDP 接收分流、`upgrade_data_rx`、remote 写流 |
| `ui_clk` | MIG `ui_clk`，200 MHz | remote 数据写 DDR、从 DDR 读回 |
| `clk_50m` | 系统 PLL 输出 | QSPI 控制状态机、QSPI CCLK 生成 |
| QSPI 引脚时钟 | `qspi_clk = ~clk_50m & ~qspi_csb`，经 STARTUPE2 输出 CCLK | 外部配置 Flash 串/四线传输 |

## 2. 第一步：打开 `ETH_TOP.v`

文件：`AXI_DDR.srcs/sources_1/new/ETH_TOP.v`

本步目标：确认 DL3 的顶层边界。你要知道 remote 数据从以太网模块出来后接到哪里，DDR 使用哪一路 FDMA 通道，QSPI 最终由哪个模块驱动。

搜索入口：

```text
remote_len
remote_wr_en
remote_wr_data
remote_rx_done
remote_complete
remote_rstn
multiboot_cfg_new U7
ddr3_ctrl U07
pkg_wr
pkg1_wr
qspi_d0
STARTUPE2
```

本模块相关信号：

| 类别 | 信号/实例 | 作用 |
|---|---|---|
| remote 接收输出 | `remote_len`, `remote_wr_en`, `remote_wr_data`, `remote_rx_done` | 来自 `ETHERNET_TOP`，表示已解析出的固件数据流 |
| remote 控制 | `remote_rstn` | 来自 `command_monitor_new`，控制 remote 链路复位/使能 |
| remote 完成反馈 | `remote_complete`, `remote_result` | 来自 QSPI/multiboot 侧，反馈烧录状态 |
| DDR remote 通道 | `pkg_wr_*`, `pkg_rd_*` | 不带 1 的 FDMA 通道，属于 DL3 |
| DDR ADC 通道 | `pkg1_wr_*`, `pkg1_rd_*` | 带 1 的 FDMA 通道，属于 DL2，读 DL3 时不要混 |
| QSPI 控制 | `multiboot_cfg_new U7`, `STARTUPE2` | 生成 QSPI 指令和 CCLK |
| remote DDR 控制 | `ddr3_ctrl U07` | 写 DDR、读 DDR，并给 QSPI 提供 nibble 数据 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `adcdata_config U5` 和 `pkg1_*` | 这是 DL2 ADC 数据回传，不是 remote 固件链路 |
| DAC/ADC/FRAM/offset 外设配置 | 支撑板级工作，不承载 remote 文件字节 |
| `write_rom_flag/write_rom_data` | 顶层有 wire，但当前主链只用 `remote_result/remote_complete` 反馈 |

代码阅读顺序：

1. 先看顶层端口里的 `qspi_d0~d3/qspi_csb`，确认 DL3 的外部 Sink 是配置 Flash。
2. 看 `ETHERNET_TOP U02` 端口连接，确认 `remote_*` 从以太网子系统出来。
3. 看 DDR 注释和 `system_wrapper U3`，确认不带 1 的 `pkg_*` 是 remote 通道，带 1 的 `pkg1_*` 是 ADC 通道。
4. 看 `multiboot_cfg_new U7`，确认 `remote_rx_done` 触发 QSPI 烧录，`remote_len` 给出文件长度。
5. 看 `ddr3_ctrl U07`，确认它同时接收 `remote_wr_*` 和连接 `pkg_*`，并输出 `data_in_flag/data_in` 给 QSPI。

读完应能回答：

```text
DL3 从 ETHERNET_TOP 输出 remote_wr_en/remote_wr_data 开始，使用 pkg_* 写 DDR；
远程数据接收完成后 remote_rx_done 触发 multiboot_cfg_new/qspi_cfg；
ddr3_ctrl 再通过 pkg_rd_* 从 DDR 读回并给 qspi_cfg 提供 4-bit data_in。
```

下一步：打开 `ETHERNET_TOP.v` 和 `ETH_LAN_RX.v`，确认 UDP 32004 怎样变成 `LAN_RX_TYPE=4`。

## 3. 第二步：打开 `ETHERNET_TOP.v` 和 `ETH_LAN_RX.v`

文件：

```text
AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v
AXI_DDR.srcs/sources_1/imports/new/ETH_LAN_RX.v
```

本步目标：确认 DL3 使用哪个 UDP 端口，以及 payload 如何被标成 remote 类型。

搜索入口：

```text
DES_PORT_UDP_RX3
16'h7D04
LAN_RX_TYPE <= 4'd4
upgrade_data_rx_inst
remote_wr_en
remote_wr_data
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| remote UDP 端口 | `DES_PORT_UDP_RX3 = 16'h7D04` | PC 发送 remote 固件数据的 UDP 目标端口，十进制 32004 |
| payload 类型 | `LAN_RX_TYPE=4` | `ETH_LAN_RX` 对 remote payload 的分类 |
| payload 字节流 | `lan_data_valid + lan_data_out[7:0]` | 给 `upgrade_data_rx` 的逐字节输入 |
| payload 长度 | `LAN_DATA_NUM` | UDP payload 字节数，供观测；`upgrade_data_rx` 主要使用包内 length |
| remote 解析实例 | `upgrade_data_rx_inst` | 消费 `LAN_RX_TYPE=4` 的字节流 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| 端口 32000 的寄存器读写 | 这是 DL4 |
| 端口 32001 的 ADC 回传 | 这是发送方向 DL2 |
| ARP/ICMP/TEMAC 细节 | 它们保证网络可达，但不改变 remote payload 合同 |

代码阅读顺序：

1. 在 `ETHERNET_TOP.v` 看端口常量，确认 `DES_PORT_UDP_RX3=16'h7D04`。
2. 看 `ETH_LAN_RX_INST` 的输出连接：`LAN_RX_TYPE/lan_data_valid/lan_data_out`。
3. 在 `ETH_LAN_RX.v` 搜 `DES_PORT_UDP_RX3_i`，看端口匹配分支。
4. 确认匹配后 `LAN_RX_TYPE <= 4'd4`，并进入 `data_rx` 状态持续吐 payload 字节。
5. 回到 `ETHERNET_TOP.v` 看 `upgrade_data_rx_inst`，确认它只看 `LAN_RX_TYPE_i`、`lan_data_valid_i`、`lan_data_i`。

读完应能回答：

```text
PC remote 数据要发到 UDP 32004。
ETH_LAN_RX 只负责去掉网络头并标记 LAN_RX_TYPE=4，不解释 remote 文件格式。
真正的 remote 包头和长度由 upgrade_data_rx 解析。
```

下一步：打开 `upgrade_data_rx.v`，读 remote 应用层 payload 格式。

## 4. 第三步：打开 `upgrade_data_rx.v`

文件：`AXI_DDR.srcs/sources_1/new/upgrade_data_rx.v`

本步目标：确认 remote payload 的应用层格式、有效数据长度、补零规则，以及 8-bit 字节如何变成 16-bit 写流。

搜索入口：

```text
LAN_RX_TYPE_i == 4'd4
lan_data[87:24] == 64'h55AA55AA00000000
remote_len
remote_len_cnt
remote_rx_done
remote_complete
remote_wr_en
remote_wr_data
remote_rstn
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 输入过滤 | `LAN_RX_TYPE_i == 4'd4 && lan_data_valid_i` | 只接收 remote payload |
| 12-byte 滑窗 | `lan_data[95:0]` | 识别包头和长度 |
| 固定包头 | `55 AA 55 AA 00 00 00 00` | remote 应用层魔数 |
| 文件长度 | `remote_len` | 32-bit 有效字节数，要求大于 100 |
| 文件数据 | `wr_fifo_en + wr_fifo_data[7:0]` | 逐字节固件数据 |
| DDR 写流 | `remote_wr_en + remote_wr_data[15:0]` | 两个字节合成一个 16-bit word |
| 完成标志 | `remote_rx_done` | 文件接收并补齐 1024-byte 边界后置 1 |
| 清完成标志 | `remote_complete` | QSPI 烧录侧处理完成后清 `remote_rx_done` |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `byte_cnt` 仅观测 | 主要用于 ILA，不决定数据合同 |
| `ila_11` | 调试观测，不改变主链路 |
| `LAN_DATA_NUM` | 这个模块未直接使用它，remote 文件长度来自 payload 内的 `remote_len` |

代码阅读顺序：

1. 看第一个 always，确认只有 `LAN_RX_TYPE=4` 的字节能进入 `lan_data_r`。
2. 看 96-bit `lan_data` 滑窗，理解它保存最近 12 个字节。
3. 看状态 0：当 `lan_data[87:24]==64'h55AA55AA00000000` 且当前拼出的 32-bit length 大于 100 时，锁存 `remote_len`。
4. 看状态 1：后续每个有效字节作为文件数据输出到 `wr_fifo_data`。
5. 看状态 2：如果 `remote_len` 不是 1024 的整数倍，补 0 到下一个 1024-byte 边界，再拉高 `remote_rx_done`。
6. 看最后一个 always：`bir` 每拍翻转，两个 8-bit 字节合成一个 16-bit `remote_wr_data`，并打一拍 `remote_wr_en`。
7. 看状态 3：等待 `remote_complete` 后回到空闲，允许下一次 remote 传输。

上位机 remote payload 格式可以记为：

| 字节 | 内容 | 含义 |
|---:|---|---|
| 0-3 | `55 AA 55 AA` | remote 包头 |
| 4-7 | `00 00 00 00` | 固定保留字段 |
| 8-11 | `remote_len[31:0]` | 后续文件有效字节数，大端拼接 |
| 12... | 文件数据 | 固件/配置文件内容 |

读完应能回答：

```text
upgrade_data_rx 把 UDP 32004 payload 解释为 remote 文件包；
它输出的 remote_wr_data 是 16-bit word，而不是 8-bit 字节；
文件尾部会补 0 到 1024-byte 边界，随后 remote_rx_done 拉高。
```

下一步：打开 `ddr3_ctrl.v` 和 `fdma_controller_write.v`，看 16-bit remote 写流如何进入 DDR。

## 5. 第四步：打开 `ddr3_ctrl.v` 和 `fdma_controller_write.v`

文件：

```text
AXI_DDR.srcs/sources_1/new/ddr3_ctrl.v
AXI_DDR.srcs/sources_1/new/fdma_controller_write.v
```

本步目标：确认 remote 写流如何跨 `eth_clk -> ui_clk`，如何按 FDMA burst 写入 DDR。

搜索入口：

```text
fdma_controller_write ddr3_wr
remote_wr_en
remote_wr_data
fifo_generator_10
rd_data_count
PKG_SIZE
BURST_SIZE
pkg_wr_areq
pkg_wr_addr
pkg_wr_data
pkg_wr_size
remote_rstn_r
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 写入源 | `remote_wr_en + remote_wr_data[15:0]` | 来自 `upgrade_data_rx` 的 16-bit 文件数据 |
| 跨域同步 | `sync_signal(remote_rstn)` | 把 remote 使能/复位同步到 `ui_clk` |
| 写 FIFO | `fifo_generator_10` | `eth_clk` 写 16-bit，`ui_clk` 读 64-bit |
| 一包长度 | `PKG_SIZE=128` | FDMA 每次搬 128 个 64-bit beat |
| 字节地址步进 | `BURST_SIZE={1'b0,PKG_SIZE,3'd0}=1024` | 每个 128 beat burst 等于 1024 byte |
| 写请求 | `pkg_wr_areq` | 向 FDMA 发起写 DDR 请求 |
| 写地址 | `pkg_wr_addr` | DDR byte address，每包加 1024 |
| 写数据 | `pkg_wr_data[63:0]` | 给 FDMA 的 64-bit beat |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `fdma_controller_read` | 下一步再读读回侧 |
| system_wrapper / MIG 内部 AXI | 这里先确认 `pkg_*` 用户合同，不展开 BD/IP |
| ADC 的 `pkg1_*` | 与 DL3 无关 |

代码阅读顺序：

1. 先看 `ddr3_ctrl.v` 端口，确认它只是包装 write/read 两个 controller。
2. 看 `fdma_controller_write` 端口，建立输入 `remote_wr_*` 和输出 `pkg_wr_*` 的合同。
3. 看 `sync_signal`，确认 `remote_rstn` 从 `eth_clk` 同步到 `ui_clk`，决定地址是否清零。
4. 看 `fifo_generator_10`，确认写侧 `wr_clk=eth_clk`，读侧 `rd_clk=ui_clk`，`remote_wr_data` 进 FIFO，`pkg_wr_data` 出 FIFO。
5. 看 `W0_REQ <= (rd_data_count >= PKG_SIZE-2)`，理解 FIFO 里数据够一包附近时发起 FDMA 写。
6. 看状态机：`S0` 拉 `pkg_wr_areq`，`S1` 等 `pkg_wr_last`，`S2` 地址加 1024。
7. 看 `pkg_wr_size={24'd0,PKG_SIZE}`，确认 FDMA 看到的是 128 beat。

读完应能回答：

```text
DL3 写 DDR 的基本单位是 128 个 64-bit beat，也就是 1024 byte。
upgrade_data_rx 已经把文件补齐到 1024-byte 边界，所以 fdma_controller_write 可以整包写。
pkg_wr_addr 是 byte 地址，每写完一包加 1024；remote_rstn 低时地址清零。
```

下一步：打开 `fdma_controller_read.v`，看 DDR 数据如何被读出并变成 QSPI nibble。

## 6. 第五步：打开 `fdma_controller_read.v`

文件：`AXI_DDR.srcs/sources_1/new/fdma_controller_read.v`

本步目标：确认 `remote_rx_done` 如何触发 DDR 读回，读回数据如何从 64-bit beat 变成 QSPI 使用的 4-bit 数据。

搜索入口：

```text
remote_en
remote_en_reg
pkg_rd_areq
pkg_rd_addr
pkg_rd_size
pkg_rd_data
fifo_generator_5
fifo_generator_8
data_in_flag
data_in
BURST_SIZE
pre_prog_full
sec_prog_full
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 读启动 | `remote_en` | 顶层接 `remote_rx_done`，表示文件已完整写入 DDR |
| 同步后启动 | `remote_en_r`, `remote_en_reg[31]` | 把启动信号跨到 `ui_clk` 并延迟，形成持续读请求 |
| 读请求 | `pkg_rd_areq`, `pkg_rd_addr`, `pkg_rd_size=128` | 向 FDMA 请求读 128 个 64-bit beat |
| DDR 返回 | `pkg_rd_en + pkg_rd_data[63:0]` | FDMA 返回的 remote 数据 |
| 第一级 FIFO | `fifo_generator_5` | `ui_clk` 下缓存 FDMA 读回，输出 `sec_data[31:0]` |
| 第二级 FIFO | `fifo_generator_8` | `ui_clk -> clk_50m`，输出 `data_in[3:0]` |
| QSPI 拉取 | `data_in_flag` | 来自 `qspi_cfg`，表示 QSPI 当前需要下一个 4-bit nibble |

先忽略：

| 先忽略 | 原因 |
|---|---|
| FIFO IP 具体深度 | 先按端口合同理解，深度需要查 IP 配置时再补 |
| 被注释掉的 byte swap 代码 | 当前有效代码直接 `.din(pkg_rd_data)` |
| QSPI 状态机细节 | 下一步再读 |

代码阅读顺序：

1. 看 `remote_en` 如何经 `sync_signal` 到 `remote_en_r`，再移位到 `remote_en_reg[31]`。
2. 看 `rd_req = remote_en_reg[31] & (!pre_prog_full)`，确认第一级 FIFO 未满时才继续读 DDR。
3. 看 FDMA 读状态机：`S0` 拉 `pkg_rd_areq`，`S1` 等 `pkg_rd_last`，`S2` 地址加 `BURST_SIZE=1024`。
4. 看 `fifo_generator_5`：`pkg_rd_en/pkg_rd_data` 写入，`pre_rd_en` 读出到 `sec_data`。
5. 看 `pre_rd_en` 条件：第二级 FIFO 未满且第一级 FIFO 非空。
6. 看 `fifo_generator_8`：`ui_clk` 写 `sec_data[31:0]`，`clk_50m` 在 `data_in_flag` 时读出 `data_in[3:0]`。
7. 注意 `remote_en_r` 低时两个 FIFO 复位，读地址也回到 0。

读完应能回答：

```text
DDR 读回不是自动送 QSPI，而是由 qspi_cfg 的 data_in_flag 一拍拍拉取 4-bit data_in。
fdma_controller_read 负责把 DDR 的 64-bit beat 缓冲并跨到 clk_50m 域。
remote_rx_done 保持期间，读地址按 1024 byte 一包持续递增。
```

下一步：打开 `multiboot_cfg_new.v` 和实际工程引用的 `imports/new/qspi_cfg.v`，看 QSPI 如何消费这些 nibble。

## 7. 第六步：打开 `multiboot_cfg_new.v` 和 `qspi_cfg.v`

文件：

```text
AXI_DDR.srcs/sources_1/new/multiboot_cfg_new.v
AXI_DDR.srcs/sources_1/imports/new/qspi_cfg.v
```

本步目标：确认 remote 数据如何被 QSPI 状态机消费、烧录地址范围是什么、烧录结果如何反馈。

搜索入口：

```text
qspi_cfg qspi_cfg_inst
program_byte_count
data_in_flag
data_in
qspi_cfg_en_reg
start_address
erase_state
program_state
judge_program_state
remote_result
remote_complete
flash_type
spi1_4_sendword
```

本模块相关信号：

| 类别 | 信号 | 作用 |
|---|---|---|
| 烧录触发 | `qspi_cfg_en` | 顶层接 `remote_rx_done`，上升沿启动 QSPI 状态机 |
| 文件长度 | `program_byte_count` | 来自 `remote_len`，同步到 `clk_50m` 后传入 `qspi_cfg` |
| QSPI 数据拉取 | `data_in_flag` | QSPI 编程阶段请求下一个 4-bit nibble |
| QSPI 数据 | `data_in[3:0]` | 来自 DDR 读出 FIFO 的 nibble |
| 起始地址 | `start_address=32'h01000000` | remote 文件写入 Flash 的起始地址 |
| 页编程 | `program_state`, `rec_cnt<=256` | 每页最多编程 256 byte |
| 擦除 | `erase_state`, `ctrl_address += 65536` | 按 64KB sector 擦除 |
| 结果码 | `remote_result` | `0x02020202` 成功，`0x03030303` 编程失败，`0x01010101` ID/类型失败路径 |
| 完成脉冲 | `remote_complete` | 通知 `upgrade_data_rx` 清 `remote_rx_done` |
| QSPI 引脚方向 | `bir`, `qspi_dout`, `qspi_din` | 控制四线数据方向 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| `new/qspi_cfg.v` | 工程实际引用 `imports/new/qspi_cfg.v`，另一份是旧/备用拷贝 |
| 每个 Flash 厂商命令的电气细节 | 先读状态机合同，手册细节放到风险项 |
| `ila_4` | 调试观察，不参与数据合同 |

代码阅读顺序：

1. 在 `multiboot_cfg_new.v` 看 `remote_config_len` 如何打 3 拍同步到 `clk_50m`。
2. 看 `qspi_cfg_inst`，确认 `program_byte_count`、`data_in_flag/data_in`、`remote_result/remote_complete` 的方向。
3. 在 `qspi_cfg.v` 看 `qspi_cfg_en_reg`，确认 `qspi_cfg_en` 上升沿触发状态机。
4. 看 `flash_type` 分支，确认代码支持多种 Flash 命令表：S25FL256、MT25QL256、IS25LP256D。
5. 看擦除流程：`reset_state -> rdid_state -> checkid_state -> clear_reg_flag_state -> wr_reg_cfg_state -> erase_state`，按 64KB sector 擦除到 `0x01FF0000`。
6. 看编程流程：`program_state` 中写 enable + fast program，`rec_cnt` 每页最多 256 字节。
7. 看 `spi1_4_sendword`：当 `program_flag=1` 时，先发送命令/地址，再拉 `data_in_flag`，用 `data_in[3:0]` 驱动 QSPI 四线数据。
8. 看 `judge_program_state`：成功时置 `remote_result=32'h02020202` 且 `remote_complete=1`；失败路径置 `32'h03030303`。

读完应能回答：

```text
qspi_cfg 不保存整份文件；它在 page program 阶段通过 data_in_flag 从 fdma_controller_read 拉 4-bit nibble。
remote 文件从 Flash 地址 0x01000000 开始烧录，每页最多 256 字节，擦除按 64KB sector。
烧录完成后 remote_result/remote_complete 反馈给 command_monitor_new 和 upgrade_data_rx。
```

下一步：打开 `command_monitor_new.v`，确认上位机如何启动/查询 DL3。

## 8. 第七步：打开 `command_monitor_new.v`

文件：`AXI_DDR.srcs/sources_1/new/command_monitor_new.v`

本步目标：确认 DL3 的控制寄存器和读回寄存器。

搜索入口：

```text
remote_rstn
remote_result
remote_result_reg
16'h000B
16'h000C
rd_reg_data
wr_reg_addr
```

本模块相关信号：

| 类别 | 信号/地址 | 作用 |
|---|---|---|
| 写控制 | `0x000C[0] -> remote_rstn` | remote 链路复位/使能 |
| 读状态 | `0x000B -> remote_result_reg[2]` | QSPI 烧录结果，做 3 拍寄存后返回 |
| 读控制 | `0x000C -> {31'd0, remote_rstn}` | 上位机可读回 remote 使能状态 |

先忽略：

| 先忽略 | 原因 |
|---|---|
| ADC/DAC/offset 寄存器 | 不影响 DL3 remote 文件数据本身 |
| `0x0200~0x0204` ultrafast/sync | 属于 DL1/DL2 参数 |
| 心跳和 `pc_ack` | 支撑控制面，不承载 remote 数据 |

代码阅读顺序：

1. 看端口 `remote_result` 和 `remote_rstn`，确认它们分别来自/去往 DL3。
2. 看 `remote_result_reg[0:2]`，确认结果做 3 拍寄存后被 PC 读回。
3. 看写寄存器 case 的 `16'h000C`，确认 `wr_reg_data[0]` 控制 `remote_rstn`。
4. 看读寄存器 case 的 `16'h000B` 和 `16'h000C`，确认 PC 如何查询结果和使能状态。

读完应能回答：

```text
PC 写 0x000C[0] 控制 remote 链路；
PC 读 0x000B 可以拿到 qspi_cfg 的 remote_result；
PC 读 0x000C 可以确认 remote_rstn 当前值。
```

下一步：按数据形态表和 CDC 表做 ILA/仿真验证。

## 9. 数据形态变化表

| 位置 | 数据名 | 位宽 | 语义 | 有效条件 | 变化 |
|---|---|---:|---|---|---|
| PC UDP payload | remote 包 | 8 | `55AA55AA00000000 + length + file bytes` | UDP 32004 收到 payload | 外部文件数据 |
| `ETH_LAN_RX` | `lan_data_out` | 8 | remote payload 字节 | `LAN_RX_TYPE=4 && lan_data_valid=1` | 去掉网络头 |
| `upgrade_data_rx` | `remote_len` | 32 | 文件有效字节数 | 包头命中，length > 100 | payload 字段转长度 |
| `upgrade_data_rx` | `wr_fifo_data` | 8 | 文件字节，尾部可能补 0 | 状态 1/2 | 有效文件 + 1024 对齐填充 |
| `upgrade_data_rx` | `remote_wr_data` | 16 | 两个文件字节合成一个 word | `remote_wr_en=1` | 8-bit -> 16-bit |
| `fdma_controller_write` | `pkg_wr_data` | 64 | 写 DDR beat | `pkg_wr_en=1` | FIFO 聚合 16-bit -> 64-bit |
| DDR | remote 数据 | 64 beat | 1024-byte burst 存储 | `pkg_wr_areq/pkg_wr_last` | 中转缓存 |
| `fdma_controller_read` | `pkg_rd_data` | 64 | DDR 读回 beat | `pkg_rd_en=1` | 从 DDR 读回 |
| `fdma_controller_read` | `sec_data` | 32 | 第二级 FIFO 输入 | `pre_rd_en/sec_wr_en` | 64-bit FIFO 输出整理成 32-bit |
| `fdma_controller_read` | `data_in` | 4 | QSPI 四线编程 nibble | `data_in_flag=1` | 32-bit -> 4-bit |
| `qspi_cfg` | `qspi_dout/qspi_din` | 4 | QSPI 四线引脚数据 | `qspi_csb=0` | 内部 nibble 驱动外部 Flash |

## 10. CDC 和缓冲结构

| 结构 | 写时钟 | 读时钟 | 数据 | 写条件 | 读条件 | 风险 |
|---|---|---|---|---|---|---|
| `sync_signal(remote_rstn)` | `eth_clk` | `ui_clk` | remote 使能/复位 | `remote_rstn` 变化 | `fdma_controller_write` 使用 | 控制跨域，需确认低电平清 FIFO 时序 |
| `fifo_generator_10` | `eth_clk` | `ui_clk` | 16-bit remote word -> 64-bit FDMA beat | `remote_wr_en` | `pkg_wr_en` | 若 remote 发送不连续或 FIFO 配置不匹配，可能影响 1024-byte 对齐 |
| `sync_signal(remote_en)` | `eth_clk` | `ui_clk` | `remote_rx_done` | remote 接收完成 | 触发 DDR 读 | `remote_rx_done` 保持到 `remote_complete`，读侧会持续发起读 |
| `fifo_generator_5` | `ui_clk` | `ui_clk` | 64-bit DDR beat -> 32-bit `sec_data` | `pkg_rd_en` | `pre_rd_en` | 需要确认 FIFO IP 的宽度转换配置 |
| `fifo_generator_8` | `ui_clk` | `clk_50m` | 32-bit -> 4-bit QSPI nibble | `sec_wr_en` | `data_in_flag` | QSPI 拉取节奏和 DDR 预取深度要匹配 |
| `remote_config_len_reg[0:2]` | `eth_clk` 来源 | `clk_50m` 寄存 | 32-bit 长度 | `remote_len` 变化 | `qspi_cfg` 使用 | 它是多 bit 总线打拍，依赖长度在烧录期间稳定 |
| `STARTUPE2` CCLK | `clk_50m/qspi_cfg` | QSPI Flash | `qspi_clk` | `qspi_csb=0` | 外部 Flash 接收 | 需上板确认 CCLK/CS 时序满足 Flash 手册 |

## 11. 控制寄存器和状态读回

| 地址 | 方向 | 字段 | 影响 DL3 的位置 | 说明 |
|---|---|---|---|---|
| `0x000C` | 写 | `wr_reg_data[0] -> remote_rstn` | `upgrade_data_rx`、`fdma_controller_write` | 低时清 remote 接收和写 DDR 地址，高时允许 remote 链路工作 |
| `0x000B` | 读 | `remote_result_reg[2]` | PC 读回 QSPI 结果 | `qspi_cfg` 成功时常见为 `0x02020202`，失败路径有 `0x01010101/0x03030303` |
| `0x000C` | 读 | `{31'd0, remote_rstn}` | PC 读回控制状态 | 用于确认 remote 链路是否释放 |

## 12. 风险和待确认点

| 风险 | 代码证据 | 影响 | 建议 |
|---|---|---|---|
| remote 包长度只用 payload 内 length，不用 UDP payload 长度 | `upgrade_data_rx.v` 解析 `remote_len`，未使用 `LAN_DATA_NUM` | PC 若 length 和 UDP 实际发送字节不一致，硬件按 length 等待/补齐 | 上位机协议必须保证 length 与真实文件字节一致 |
| remote 数据补齐到 1024 byte | `upgrade_data_rx.v` 使用 `remote_len[9:0]` 补 0 | Flash 会写入补零区域；若文件长度未页/扇区对齐，需要确认上位机预期 | 明确协议：length 是有效字节，DDR 写入按 1024 对齐 |
| DDR 读侧以 `remote_rx_done` 保持为启动条件 | `fdma_controller_read.v` 中 `remote_en` 接 `remote_rx_done` | 在 `remote_complete` 前读侧可能持续预取 | 用 ILA 看 `pkg_rd_addr/pkg_rd_areq` 和 `data_in_flag` 是否按预期停下 |
| 多 bit `remote_config_len` 跨到 `clk_50m` 只是 3 拍寄存 | `multiboot_cfg_new.v` 的 `remote_config_len_reg` | 如果长度在烧录期间变化可能读错 | 依赖 `remote_len` 在一次 remote 流程中保持稳定；上板验证 |
| 实际引用的 `qspi_cfg.v` 在 `imports/new`，另有旧拷贝 | `AXI_DDR.xpr` 指向 `sources_1/imports/new/qspi_cfg.v` | 读错文件会得到不同端口和状态机 | 以 `.xpr` / synth tcl 中的 `imports/new/qspi_cfg.v` 为准 |
| Flash 类型/命令依赖外设手册 | `qspi_cfg.v` 中按 `flash_type` 切命令表 | 不同 Flash 可能状态位含义不同 | 核对板上 Flash 型号和 `flash_type` 配置来源 |
| `write_rom_flag/write_rom_data` 顶层未继续展开 | `ETH_TOP.v` 中有 wire 连接到 `multiboot_cfg_new` | 可能是记录 Flash 类型的支撑链路，但不影响主数据烧录 | 后续若要补完整升级状态管理，再追这一路 |

## 13. 关键证据索引

| 结论 | 证据位置 | 读源码时看什么 |
|---|---|---|
| remote 使用 UDP 32004 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v:185`、`:195` | `DES_PORT_UDP_RX3 = 16'h7D04` |
| 32004 对应 `LAN_RX_TYPE=4` | `AXI_DDR.srcs/sources_1/imports/new/ETH_LAN_RX.v:342`、`:348` | 端口匹配后设置 `LAN_RX_TYPE <= 4'd4` |
| `upgrade_data_rx` 消费 remote 字节流 | `AXI_DDR.srcs/sources_1/imports/ethernet/ETHERNET_TOP.v:358`、`:365` | `upgrade_data_rx_inst` 输出 `remote_len/remote_wr_*` |
| remote 包头和长度 | `AXI_DDR.srcs/sources_1/new/upgrade_data_rx.v:106`、`:108` | `55AA55AA00000000 + length` |
| remote 补齐 1024-byte 边界 | `AXI_DDR.srcs/sources_1/new/upgrade_data_rx.v:127`、`:135` | `remote_len[9:0]` 不为 0 时补 0 |
| 8-bit 转 16-bit 写流 | `AXI_DDR.srcs/sources_1/new/upgrade_data_rx.v:171`、`:176` | `remote_wr_data <= {data_reg, wr_fifo_data}` |
| remote 写 DDR 使用 `pkg_*` | `AXI_DDR.srcs/sources_1/new/ETH_TOP.v:738`、`:752` | `ddr3_ctrl U07` 接不带 1 的 `pkg_*` |
| 写 DDR 一包 128 beat / 1024 byte | `AXI_DDR.srcs/sources_1/new/fdma_controller_write.v:50`、`:51` | `PKG_SIZE=128`，`BURST_SIZE=1024` |
| 写侧 FIFO 跨 `eth_clk -> ui_clk` | `AXI_DDR.srcs/sources_1/new/fdma_controller_write.v:110` | `fifo_generator_10` |
| DDR 读由 `remote_rx_done` 触发 | `AXI_DDR.srcs/sources_1/new/ddr3_ctrl.v:82` | `remote_en(remote_rx_done)` |
| 读侧将 DDR 数据送给 QSPI nibble FIFO | `AXI_DDR.srcs/sources_1/new/fdma_controller_read.v:166`、`:172` | `fifo_generator_8` 用 `data_in_flag` 读出 |
| QSPI 烧录触发和文件长度 | `AXI_DDR.srcs/sources_1/new/multiboot_cfg_new.v:61`、`:63` | `qspi_cfg_en` 和 `program_byte_count` |
| QSPI 起始地址 | `AXI_DDR.srcs/sources_1/imports/new/qspi_cfg.v:104` | `start_address=32'h01000000` |
| QSPI 每页最多 256 byte | `AXI_DDR.srcs/sources_1/imports/new/qspi_cfg.v:437`、`:440` | `rec_cnt <= 256` |
| QSPI 成功/失败结果码 | `AXI_DDR.srcs/sources_1/imports/new/qspi_cfg.v:459`、`:465` | `remote_result` 赋值 |
| remote 控制寄存器 | `AXI_DDR.srcs/sources_1/new/command_monitor_new.v:297`、`:391`、`:392` | `0x000C` 写 remote_rstn，`0x000B` 读结果 |

## 14. 上板/ILA 验证信号组

remote 接收最小验证：

```text
eth_clk
eth_rstn
LAN_RX_TYPE
lan_data_valid
lan_data_out
remote_rstn
remote_len
remote_wr_en
remote_wr_data
remote_rx_done
```

DDR 写入验证：

```text
ui_clk
fdma_rstn
remote_rstn_r
rd_data_count
W0_REQ
pkg_wr_areq
pkg_wr_en
pkg_wr_last
pkg_wr_addr
pkg_wr_data
pkg_wr_size
```

DDR 读出到 QSPI FIFO 验证：

```text
remote_en
remote_en_r
pkg_rd_areq
pkg_rd_en
pkg_rd_last
pkg_rd_addr
pkg_rd_data
pre_prog_full
pre_prog_empty
sec_prog_full
data_in_flag
data_in
```

QSPI 烧录验证：

```text
clk_50m
qspi_cfg_en
program_byte_count
current_state
flash_type
ctrl_address
program_flag
data_in_flag
data_in
qspi_csb
qspi_clk
qspi_dout
qspi_din
remote_result
remote_complete
```

PC 读回验证：

```text
WR_REG_VALID
WR_REG_ADDR=16'h000C
WR_REG_DATA[0]
RD_REG_VALID
RD_REG_ADDR=16'h000B
RD_REG_DATA
remote_result
remote_result_reg
```


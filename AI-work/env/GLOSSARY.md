# Glossary

> 工程内的缩写、自创术语、业务概念对照。新缩写出现就追加。

## 模块/接口缩写

| 缩写 | 全称/含义 | 出处 |
|---|---|---|
| FDMA | Frame DMA，本工程使用 user_src/MSXBO_FDMA_1.0 的 AXI 突发读写控制器 | `fdma_controller_*.v`、`user_src/MSXBO_FDMA_1.0` |
| LAN | 局域网/以太网相关 | `LAN_*.v` 一族 |
| EPHY | Ethernet PHY 配置/握手 | `ephy_top.v`、`vio_ephy.xci` |
| TEMAC | Tri-mode Ethernet MAC（Xilinx LogiCORE） | `SGMII_TEMAC.xci` |
| SGMII | Serial Gigabit Media Independent Interface（千兆串行以太网物理层） | `SGMII_PHY.xci`、`SGMII_TEMAC.xci` |
| ARP | 地址解析协议 | `ARP_TOP.v`、`LAN_RX_ARP.v`、`LAN_TX_ARP.v` |
| ICMP | Internet Control Message Protocol（ping） | `ICMP_TOP.v` |
| MIG | Memory Interface Generator（Xilinx DDR 控制器） | `system.bd` 内核 |
| QSPI | Quad SPI Flash 接口 | `qspi_cfg.v` |
| MULTIBOOT | Xilinx 远程升级方案 | `multiboot_cfg_new.v` |
| MDIO | Management Data IO（PHY 控制接口） | `phy_mdio_wr.v` |
| FRAM | Ferroelectric RAM（非易失存储，I²C） | `fram_cfg.v` |
| MSXBO | 工程命名前缀（具体来源待确认） | `MSXBO_FDMA_*`、`MSXBO_OVSensorRGB565_0` |

## 业务术语

| 术语 | 含义 |
|---|---|
| 扫描 / scan | 一次完整的 DAC 波形输出循环（一帧），驱动电子束按 X/Y 偏转扫描 |
| 帧 / frame | 一次完整扫描覆盖的全部像素 |
| 像素 / pixel | 一个扫描位置；每个像素会触发一次 ADC 采集 |
| 行 / line | 一帧内的一行扫描（X 方向） |
| 行恢复 / line recovery | 扫描线之间的回扫/稳定时间 |
| ultrafast 模式 | 高速扫描模式；行首恢复时间由 `ultrafast_line_rec` 参数控制 |
| ADC 触发 / adc_tri | 由 DAC 链生成的脉冲，告诉 ADC 现在该采样 |
| 平均/抽取 / averaging | ADC 在一个像素窗口内连续采样多次，求平均后输出一个值 |
| 步进 / step | 扫描参数：相邻两个像素之间 DAC 值的增量 |
| 通道 / channel | 4 路 ADC 数据通道（2 片 AD9258 × 2）；可配置使用 1/2/4 通道 |
| 远程升级 / remote upgrade | PC 通过以太网下发新 bitstream，写入 QSPI 触发 multiboot |
| sync1 / sync2 | DAC 链产生的两路外部同步输出，时序由参数 `sync1_pixel_tri_wigth` / `sync2_pixel_tri_wigth` 控制 |

## 信号约定

| 信号风格 | 约定 |
|---|---|
| `*_en` | 高电平有效使能 |
| `*_n` / `*_rstn` | 低电平有效（含复位） |
| `*_p / *_n` 配对 | 差分对（LVDS、SGMII、DDR DQS 等） |
| `*_valid / *_ready` | AXI Stream 风格握手 |
| `*_wr_en / *_rd_en` | FIFO 接口 |
| `*_dco` | Data Clock Output（来自外部 ADC/DAC 的回送时钟） |
| `*_pixel_tri_wigth` | 注意原工程拼写是 `wigth`（非 `width`），保持不改 |

## 数据链路编号（来自 Mode 1/2）

| 编号 | 名称 | 主文件 |
|---|---|---|
| DL1 | DAC 扫描输出与触发 | `dacdata_config.v`、`parameter_dacdata_gen.v`、`dac_output.v` |
| DL2 | ADC → DDR → 以太网 | `adcdata_config.v`、`adcdata_acq.v`、`adcdata_get.v`、FDMA + MIG + ETHERNET_TOP |
| DL3 | 远程升级 / multiboot | `ETHERNET_TOP.v`、`ddr3_ctrl.v`、`multiboot_cfg_new.v`、`qspi_cfg.v` |
| DL4 | 寄存器控制 | `ETHERNET_TOP.v`、`command_monitor_new.v`、各 `*_cfg.v` |

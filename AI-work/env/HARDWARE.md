# Hardware

> 板子接口与片外器件清单。改了硬件（换板、换颗粒）就更新这份文件。

## FPGA

| 项 | 值 | 证据 |
|---|---|---|
| 系列 | Kintex-7 | |
| 型号 | `xc7k325tffg676-2` | `AXI_DDR.xpr`、`AXI_DDR.tcl:341` |
| 封装 | FFG676 | |
| 速度等级 | -2 | |
| 板号 / 项目代号 | SGSC_SEM_325T_V3_171 | 工程目录名 |

## 片外器件

> 来源：`AI-work/guide/FPGA_PROJECT_GUIDE.md` + `AI-work/guide/data-paths/DL*.md`。型号已确定，速度/规格部分仍待确认。

| 器件 | 用途 | 接口 | 控制模块 / IP | 备注 |
|---|---|---|---|---|
| **AD9258** ×2 | 双通道 14-bit ADC，工程里 2 片合计 4 路通道 | 并行 LVDS（数据）+ SPI（配置） | `ad9258_cfg.v`、`ad9258_config.v`、`adcdata_acq.v`、`adcdata_config.v` | DCO 50 MHz；`fpga_pin.xdc:294-295`、`:383-384` 约束 DCO；采样率 `> ⚠️ 待确认`（DL2 推测 ~ 50MSPS） |
| **AD9747** | 双通道 16-bit DAC（X/Y 偏转） | 并行（`dac_p1d/dac_p2d`）+ SPI 配置 | `ad9747_cfg.v`、`dac_output.v`、`dacdata_config.v`、`parameter_dacdata_gen.v` | DCO 50 MHz；`fpga_pin.xdc:206` 约束；输出公式为 `65535-DAX/DAY` |
| **AD9517** | 时钟分发 | SPI | `ad9517_cfg.v` | 输出多路差分时钟（AD9258/AD9747 时钟来源） |
| **DDR3** | 主存 | MIG 7-Series AXI | `system.bd` 内 MIG + `ddr3_ctrl.v` + 两个 FDMA（user_src/MSXBO_FDMA_1.0） | 颗粒型号 `> ⚠️ 待确认`；ui_clk = 200 MHz |
| **Ethernet PHY** | SGMII 千兆 | SGMII（GTX）+ MDIO | `SGMII_PHY.xci`、`SGMII_TEMAC.xci`、`ephy_top.v`、`phy_mdio_wr.v` | PHY 芯片型号 `> ⚠️ 待确认`；`gtrefclk` = 125 MHz，`fpga_pin.xdc:409-411` |
| **QSPI Flash** | 配置 + 远程升级 | QSPI（STARTUPE2 + 用户 IO） | `qspi_cfg.v` + `multiboot_cfg_new.v` | 容量 / 型号 `> ⚠️ 待确认` |
| **FRAM** | 偏置/板级配置非易失 | I²C（`FRAM_SCL/SDA`） | `fram_cfg.v` | 容量 / 型号 `> ⚠️ 待确认` |
| **偏置 DAC + 板级 I²C** | 模拟偏置配置 | I²C（`ADC1_SCL/SDA`、`ADC2_SCL/SDA`） | `offset_cfg.v`、`offset_dac_cfg.v` | 偏置 DAC 型号 `> ⚠️ 待确认` |
| **OV5640 摄像头** | 图像传感器（用途待确认） | DVP + I²C | `OV5640IIC_0.xci`、`MSXBO_OVSensorRGB565_0.xci` | 用途 `> ⚠️ 待确认`，可能是辅助/调试，未在主数据通路 |
| 外部触发口 | `TRIGGER_IN`、`TRIGGER_OUT`、`TRIG_*` | LVTTL | `dacdata_config.v` 内同步逻辑 | 用于外同步 / 行同步 |
| 板级控制 | `LED`、`FAN`、`UART_*` | GPIO/UART | 顶层直连 | 调试/状态 |

## 主时钟

| 时钟 | 频率 | 来源 | 服务的数据链路 | CDC 风险 |
|---|---|---|---|---|
| `sys_clk` | 100 MHz | 板上晶振（外部端口） | `sysclk` IP 输入 | 低 |
| `clk200m` | 200 MHz | `sysclk.clk_out1` | MIG 输入 | 中（进 BD 后生成 ui_clk） |
| `clk10m` | 10 MHz | `sysclk.clk_out2` | AD9258/9517/9747 配置、FRAM/offset DAC 延时 | 低 |
| `clk50m` | 50 MHz | `sysclk.clk_out3` | 以太网配置、QSPI、`FPGA_50M` ODDR | 中 |
| `ui_clk` | 200 MHz | MIG `ui_clk` | DDR3 / FDMA / ADC 打包 | 中（跨 ADC/ETH/DAC 域） |
| `eth_clk` | ~125 MHz `⚠️ 待确认` | TEMAC 用户时钟 | 以太网协议、寄存器、DAC 参数计算 | 中 |
| `dac_dco` | 50 MHz | AD9747 DCO（外部环回） | `dac_output` 输出 | 中（参数经 FIFO 从 eth_clk 跨过来） |
| `adc1_dco_*` / `adc2_dco_*` | 50 MHz | AD9258 DCO（外部） | `adcdata_acq` 采样 | **高**（4 个采样时钟最后汇到 ui_clk） |
| `gtrefclk` | 125 MHz | 外部 SGMII 参考时钟 | TEMAC/PHY | 由 IP 自动处理 |

## IO 关键约束位置

- 主约束：`AXI_DDR.srcs/constrs_1/new/fpga_pin.xdc`
- 关键证据行：
  - `sys_clk`：`fpga_pin.xdc:25-27`
  - `dac_dco`：`fpga_pin.xdc:206`
  - ADC DCO：`fpga_pin.xdc:294-295`、`:383-384`
  - SGMII gtrefclk：`fpga_pin.xdc:409-411`

## 主要数据链路（来自 Mode 1/2）

| 编号 | 链路 | 端点 | 详细 |
|---|---|---|---|
| DL1 | DAC 扫描输出与触发 | 参数 → DAX/DAY/adc_tri/sync → AD9747/ADC | `AI-work/guide/data-paths/DL1_DAC_SCAN_DEEP_READ.md` |
| DL2 | ADC → DDR → 以太网 | AD9258 4路 → FDMA1 → DDR3 → FDMA1 读 → SGMII | `AI-work/guide/data-paths/DL2_ADC_DDR_ETH_DEEP_READ.md` |
| DL3 | 远程升级 | 以太网 → DDR → QSPI/multiboot | `AI-work/guide/data-paths/DL3_REMOTE_QSPI_DEEP_READ.md` |
| DL4 | 寄存器控制 | 以太网 → command_monitor_new → 各 cfg 子模块 | `AI-work/guide/data-paths/DL4_REG_CONTROL_DEEP_READ.md` |

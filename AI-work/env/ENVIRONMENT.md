# Environment

> 工具链快照。改了工具链（升级 Vivado、换仿真器）就更新这份文件。

## 操作系统与外壳

| 项 | 值 |
|---|---|
| OS | Windows 11 Pro 22631 |
| Shell | PowerShell（命令也可走 Bash，但 PowerShell 是首选） |
| 工程根路径 | `D:/XF/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj` |
| 工程根字符长度 | 107（< 240，安全） |
| 最长内部文件预计长度 | ~187（仍在 Windows 长路径阈值内） |

## 工具链

| 工具 | 路径 | 版本 | 状态 |
|---|---|---|---|
| Vivado | `D:/Xilinx/Vivado/2021.1/bin/vivado.bat` | 2021.1（SW Build 3247384） | OK |
| xsim | Vivado 自带 | 2021.1 | **当前选用** |
| ModelSim | `D:/modeltech64_10.6d/win64/vsim.exe` | — | **不可用**：TCL 重建脚本里写的路径不存在 |
| Git | `C:/Program Files/Git/cmd/git.exe` | 已装 | OK |
| Python | `C:/Users/XF/AppData/Local/Python/bin/python.exe` | 3.14.2 | OK（用于 validate 脚本） |
| D2 | 未安装 | — | 暂用 Mermaid 替代，需要大图时再装 |

## 仿真器选择

当前选用：**xsim**（Vivado 自带，零配置）。

> AXI_DDR.tcl 第 353 行原本指向 `D:/modeltech64_10.6d/vivado_lib`，但该目录已不存在。如未来恢复 ModelSim，先用 `compile_simlib` 把 Xilinx 库编译到 `vivado_lib`，验证 `fifo_generator`/`MIG` 这类受影响 IP 能跑通，再切回。

## 文件约定（观察到的现状）

| 项 | 值 | 说明 |
|---|---|---|
| 源文件编码 | **混合**：GBK 与 UTF-8 都存在 | 抽样 8 个 `sources_1/new/*.v`：`ad9258_cfg.v`、`ad9517_cfg.v` 是 GBK；`ad9258_config.v` 不可解码；`ad9747_cfg.v`、`adcdata_*` 是 UTF-8 |
| 注释语言 | 中文为主，Xilinx 例程保持英文 | |
| 换行符 | **混合**：LF 与 CRLF 都有 | `ad9747_cfg.v` 是 CRLF，其余多数是 LF；git 默认会把 LF 转 CRLF（看到 commit 时的 warning） |
| 缩进 | 4 空格为主，部分 Tab | 新写文件统一用 4 空格 |

**AI 写新文件的约定**：UTF-8（无 BOM）+ LF。改动既有文件保持其原编码不变；如果文件是 GBK 且需要新加中文注释，要么转为 UTF-8（在 RULES.md 里需要先问），要么用 ASCII。

## 磁盘

| 盘 | 剩余空间 |
|---|---|
| D: | ~314 GB（充足） |

## License

| IP / 模块 | 类型 | 状态 |
|---|---|---|
| `SGMII_TEMAC` | 付费（Tri-Mode Ethernet MAC LogiCORE） | 待 `check_env.tcl` 在 Step 6 确认 |
| `SGMII_PHY` | 付费（同上家族） | 待 Step 6 确认 |
| `MIG 7 Series` | 免费 | OK |
| 其他（FIFO/ILA/VIO/div_gen 等） | 免费 | OK |

## 工程内 IP 概览（41 个 .xci）

按类别归一下，仅作环境摘要，详细清单见 `AI-work/guide/FPGA_PROJECT_GUIDE.md`：

| 类别 | 数量 | 示例 |
|---|---|---|
| FIFO Generator | 12 | `fifo_generator_0..11`、`fifo_lan_tx`、`sync_fifo_sig` |
| ILA / VIO | 13 | `ila_0..12`、`ila_ephy`、`ila_SGMII_example_top`、`ARP_RX_ILA`、`vio_1/2`、`vio_ephy`、`vio_ethernet_top` |
| 时钟/除法 | 6 | `sysclk`、`div_gen_0..4` |
| 以太网 | 2 | `SGMII_PHY`、`SGMII_TEMAC` |
| 存储 | 1 | `blk_mem_gen_0` |
| 图像传感器 | 2 | `MSXBO_OVSensorRGB565_0`、`OV5640IIC_0` |
| 其他 | 5 | `lan_rx_lia`、`ARP_RX_ILA` 等 |

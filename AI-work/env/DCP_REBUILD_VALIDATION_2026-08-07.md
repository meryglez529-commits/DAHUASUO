# 受跟踪 DCP 重建验证 — 2026-08-07

## 结论

本仓库受跟踪的 4 个 DCP 对应两个旧式自定义 IP 核：`MSXBO_OVSensorRGB565` 与 `OV5640IIC`。在独立 Git worktree、Vivado 2021.1、`xc7a100tfgg484-2` 下，对两个核心的 HDL 源进行 OOC 综合并 `write_checkpoint` 均成功。

这证明两个 IP **有可用 HDL 源、可在当前工具链重建 DCP**；同时也证明当前主工程不会把旧式 IP 封装自动识别为 `get_ips` 对象。因此，4 个现有 DCP 现在仍必须保留：删除它们还需要单独完成并验证“旧式封装到当前工程 IP 管理方式”的迁移。

## 通过证据

| 核心 | 综合输入 | 结果 | 新 DCP SHA-256 |
|---|---|---|---|
| `MSXBO_OVSensorRGB565` | `AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565.v` | PASS | `5103CA78623C3FFB99A0BBBC187322A29F967B904FB0EF6ED9C8C425B8ACF59C` |
| `OV5640IIC` | `AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/src/{I2C_OV5640_RGB565_Config,i2c_timing_ctrl,OV5640IIC}.v` | PASS | `F5CEA654D512F5C5FBDBF7C6257672245DADFDB157CFD310DEA9DAC80D390FF3` |

两项综合均从 `user_src` 可追溯到同名核心的源 IP：

- `user_src/MSXBO_OVSensorRGB565_1.0/IPSRC/MSXBO_OVSensorRGB565.v`
- `user_src/OV5640_IIC/IPSRC/` 下的三个 Verilog 源文件

## 4 个 DCP 的处置

| DCP | 对应核心 | 当前处置 |
|---|---|---|
| `AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565_0.dcp` | `MSXBO_OVSensorRGB565` | 保留；核心 HDL 重建已通过，封装迁移未验证 |
| `AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0.dcp` | `OV5640IIC` | 保留；核心 HDL 重建已通过，封装迁移未验证 |
| `user_src/MSXBO_OVSensorRGB565_1.0/prj/.../synth_1/MSXBO_OVSensorRGB565.dcp` | `MSXBO_OVSensorRGB565` | 保留；该子工程的历史产物，待独立 IP 打包迁移后再清理 |
| `user_src/OV5640_IIC/prj/OV5640_IIC.runs/synth_1/OV5640IIC.dcp` | `OV5640IIC` | 保留；该子工程的历史产物，待独立 IP 打包迁移后再清理 |

## 未通过的路径及原因

在干净 worktree 中 `open_project AXI_DDR.xpr` 后，`get_ips MSXBO_OVSensorRGB565_0` 返回 `IP_NOT_FOUND`。这不是 HDL 综合失败，而是主工程没有将这个旧式封装登记为当前 Vivado 的可管理 IP 对象。原因线索：封装元数据仍含 Vivado 2017.4 和历史绝对 archive 路径，而本工程运行于 Vivado 2021.1。

因此，禁止仅凭“HDL 可综合”删除 DCP；实际迁移必须在单独 `chore/ip-packaging-migration` 分支完成，并至少验证：IP catalog 可发现、主工程可打开、IP status 无阻塞、综合和实现通过。

## 可复现命令

```powershell
& 'D:\Xilinx\Vivado\2021.1\bin\vivado.bat' -mode batch -nojournal -nolog `
  -source AI-work\scripts\validate_custom_ip_sources.tcl
```

脚本输出仅写入 `AI-work/reports/baseline/dcp-rebuild-*/`，该目录被忽略，不污染设计源。

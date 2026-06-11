# Host App 参数覆盖与 GUI 重设计实现记录

## 2026-06-11

### 已完成

| 项 | 状态 | 说明 |
|---|---|---|
| 地址对齐 | done | `0x0205=sync2_pixel_tri_width`，`0x020B=laser_mode_en` |
| 单位审计 | done | 新增 `PARAM_UNITS_AUDIT.md` |
| 参数模型 | done | `ScanConfig` 补 gain、frame waiting、row repeat、row_m/row_n、`clk_sel` |
| RTL 读回表 | done | `command_monitor_new.v` 补 `0x0200~0x0205`、`0x020B` 读回 |
| GUI UX 重构 V1 | done | 顶部栏分组、模式下拉、动态模式页、参数分组/单位提示、写入计划/日志抽屉 |
| GUI 两页版 | done | 参数区收敛为“共用参数/模式参数”两页；DAC X/Y 起止改为人类坐标输入，由 GUI 转换为 16-bit DAC code |
| DL5 模型 | done | `Dl5Config` laser enable 写 `0x020B`，读回表补齐后使用 checked write |
| ultrafast 模型 | done | 新增 `sync2_width`，增加 ADC 分母下溢校验 |
| GUI | done | `ModeWorkbenchPanel` 改为参数 tabs，并在 label 中标注单位 |
| CLI | done | 新增高级扫描参数选项，help 标注 raw unit / step resolution |
| 测试 | done | 更新地址、模式计划、单位 raw value、register map/mock 测试 |

### 修改文件

| 文件 | 主要改动 |
|---|---|
| `AXI_DDR.srcs/sources_1/new/command_monitor_new.v` | 补齐 sync/ultrafast 和 `0x020B` laser enable 读回 |
| `AI-work/host-app/src/fpga_host/core/control/register_map.py` | 更新 `0x0205/0x020B` 和 `0x0200~0x0205` 可读属性，修正若干 RTL reset 默认值 |
| `AI-work/host-app/src/fpga_host/core/control/scan.py` | 扩展扫描参数和校验，生成更多寄存器 |
| `AI-work/host-app/src/fpga_host/core/control/dl5.py` | `laser_mode_en` 改写 `0x020B`，`acq_time>=2` |
| `AI-work/host-app/src/fpga_host/core/control/modes.py` | normal/ultrafast/laser 写入计划按新地址和单位更新 |
| `AI-work/host-app/src/fpga_host/core/control/device.py` | 保留按 register map 自动选择 checked/unchecked 的写入能力 |
| `AI-work/host-app/src/fpga_host/cli/main.py` | CLI option/help 增补单位 |
| `AI-work/host-app/src/fpga_host/cli/commands_scan.py` | 新扫描参数接入 `ScanConfig` |
| `AI-work/host-app/src/fpga_host/gui/panels/mode_workbench_panel.py` | GUI 参数分组、两页结构、DAC 区域坐标到 raw code 转换、模式专属 ADC 延时 |
| `AI-work/host-app/src/fpga_host/gui/panels/scan_panel.py` | 基础 scan panel 标签补单位 |
| `AI-work/host-app/tests/*` | 单测按新协议更新 |

### 验证

```powershell
cd AI-work/host-app
python -m compileall src
python -m unittest discover -s tests
```

结果：

- `compileall`: PASS
- `unittest`: PASS，23 tests

### 未执行

- 未做真实 FPGA UDP 写入。
- 未跑 Vivado 综合/实现/bitstream。
- 未跑 Vivado 综合/实现/bitstream；当前只做 RTL 文本补丁和 host-app 单测。

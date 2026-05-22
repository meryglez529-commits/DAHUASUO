# AI-work

这是 `fpga-project-reader` skill 为本工程（AXI_DDR）建立的协作工作区。所有 skill 产出（工程地图、数据通路精读、单文件注释、协作环境）都收纳在这里，不污染原工程目录。

## 目录用途

| 子目录 | 谁写 | 装什么 |
|---|---|---|
| `guide/` | Mode 1 全工程地图 + Mode 2 数据通路精读 | `FPGA_PROJECT_GUIDE.md`、`IP-INVENTORY.md`、`CLOCKS.md`、`data-paths/*.md`、`diagrams/*.d2` 和渲染后的 `.svg` |
| `annotations/` | Mode 3 单文件注释 | 每次注释一份说明：注释了哪个文件、为什么、改了什么。源文件本体仍在工程目录原位 |
| `env/` | Mode 4 协作环境搭建 | `ENVIRONMENT.md`、`HARDWARE.md`、`RULES.md`、`FOCUS.md`、`SNAPSHOTS.md`、`GLOSSARY.md` |
| `scripts/` | Mode 4 | 从 skill 模板复制并定制的 `.tcl`/`.py`，可直接 `vivado -mode batch -source` 调用 |
| `sim/` | 闭环协作中 AI 写的 testbench | `*.v`、`.do` |
| `sim_out/` | 闭环协作产物 | 仿真 log、csv、wdb（不进 git） |
| `reports/` | 闭环协作产物 | 综合/时序/DRC 报告（不进 git） |

## 顶层文件

- `LOG.md`：协作日志，每次对话和每轮改动追加一行
- `OPEN-QUESTIONS.md`：四个 mode 共享的待解决问题清单

## 如何回滚

见 `env/SNAPSHOTS.md`。基线快照在 Mode 4 setup 时建立。

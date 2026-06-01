# fpga-project-reader 文档与交付管理改进记录

> 目的：记录本次 DL5 开发后暴露出的 `fpga-project-reader` 技能缺陷，作为稍后修改 skill 的设计依据。本文不是正式工程上下文，也不是 skill 实现文件。

## 1. 背景

`fpga-project-reader` 的本意是让 AI 快速接手任意 FPGA 工程，并能继续和用户协作开发新功能。

当前工程里：

- `AI-work/guide/FPGA_PROJECT_GUIDE.md` 是工程总览。
- `AI-work/guide/data-paths/DL1~DL4_*.md` 是既有主数据通路的稳定上下文。
- `DL5` 是新增的第五条数据通路：飞秒激光同步采集模式。

这次 DL5 开发暴露出两个问题：

1. `AI-work/guide/data-paths/DL5_LASER_SYNC_MODE_DESIGN.md` 在 RTL 已实现、仿真 PASS、综合 PASS 后仍停留在“进入 plan / 实现阶段”。
2. AI 可以自己跑仿真并声明 PASS，但用户无法方便地在 Vivado 里复现、打开波形、检查关键点。

## 2. 用户真正需要什么

用户不需要一套复杂的文档管理体系。用户需要的是：

1. **AI 工作要留痕**
   需求怎么定的、计划怎么定的、AI 实际做了什么、做到哪一步，都要有记录。

2. **需求和执行计划要共同维护**
   新功能开始时，用户和 AI 先整理需求、边界、执行计划和验证方法，再去写 RTL。

3. **AI 做完后必须更新进度**
   不能出现“文档还写着准备实现，但代码已经改完、sim/synth 已过”的情况。

4. **RTL 审查要清楚**
   工程很大，AI 可能一次改很多 RTL。用户需要知道：
   - 改了哪些文件。
   - 为什么改。
   - 改了什么。
   - 应该重点检查哪里。
   - 哪些地方风险最大。

5. **仿真要能由用户复现**
   AI 不能只说“仿真通过”。用户需要：
   - 用哪个 testbench。
   - 在 Vivado 里怎么跑。
   - Tcl Console 复制什么命令。
   - 跑完怎么看结果。
   - 怎么打开波形。
   - 重点看哪些信号。
   - 什么现象算对。

6. **文档要少而有用**
   不默认生成一堆 `STATUS.md / BACKLOG.md / DECISIONS.md / TRACE.md / REVIEW_CHECKLIST.md`。默认只保留用户真正会打开的入口。

## 3. 核心原则

以后按三句话管理：

**`guide/` 管事实，`features/` 管过程。**

**一次功能开发 = 一个 `DLx_UNIT_NNN/` 工作包。**

**每个工作包默认只有三个核心入口：`WORK.md`、`RTL_REVIEW.md`、`SIM_REPLAY.md`。**

含义：

- `guide/` 只放已经读清楚、实现完成、可作为上下文复用的稳定事实。
- `features/` 放新增功能开发过程，包括需求、计划、AI 工作记录、RTL 审查入口和仿真复现入口。
- 未验证或正在开发的内容不能写进 `guide/` 当成事实。
- 功能完成后，把已验证结果提炼进入 `guide/data-paths/*_AS_BUILT.md`。
- AI 不能只说“已完成”或“仿真 PASS”；必须留下用户能接收、能检查、能复现的工作包。

## 4. 推荐目录结构

```text
AI-work/
  guide/
    FPGA_PROJECT_GUIDE.md
    data-paths/
      DL1_..._DEEP_READ.md
      DL2_..._DEEP_READ.md
      DL3_..._DEEP_READ.md
      DL4_..._DEEP_READ.md
      DL5_LASER_SYNC_AS_BUILT.md

  features/
    DL5_laser_sync/
      DL5_UNIT_001/
        WORK.md
        RTL_REVIEW.md
        SIM_REPLAY.md

        sim/
          run_gui.tcl
          run_batch.tcl
          waves.wcfg
          expected.md

        out/
          sim/
            xsim.log
            waveform.wdb
            result.txt
            sim_result.csv
          synth/
            run_synth.log
            utilization_synth.rpt

      DL5_UNIT_002/
        WORK.md
        RTL_REVIEW.md
        SIM_REPLAY.md
        ...
```

这里的 `DL5_UNIT_001` 不是“一个仿真用例”，而是 **DL5 的第一次完整开发单元**：第一次需求、第一次设计、第一次 RTL 实现、第一次仿真/综合和第一次交接都归在这个目录下。

后续如果用户觉得 DL5 还要加功能，不继续修改 `DL5_UNIT_001` 的历史记录，而是创建 `DL5_UNIT_002`。`guide/data-paths/DL5_LASER_SYNC_AS_BUILT.md` 只记录已经完成并验证的 DL5 当前事实。

## 5. 三个核心文档

### DLx_UNIT_NNN/WORK.md

主工作记录。它是本开发单元的需求、计划、进度和结果入口。

`WORK.md` 应该回答：

- 本次目标是什么。
- 需求是怎么确认的。
- 哪些内容明确不做。
- 执行计划是什么。
- 当前进度到哪一步。
- AI 已完成哪些工作。
- 验证结果是什么。
- 还有哪些未完成或待用户确认。
- 关键决策有哪些。

建议结构：

```text
# DL5_UNIT_001 工作记录

## 1. 本次目标
## 2. 需求确认
## 3. 不做的内容
## 4. 执行计划
## 5. 当前进度
## 6. AI 已完成的工作
## 7. 验证结果
## 8. 未完成 / 待用户确认
## 9. 关键决策记录
```

规则：

- AI 每完成一个阶段，必须更新 `WORK.md` 的“当前进度”和“AI 已完成的工作”。
- 仿真或综合通过后，必须把证据路径写进“验证结果”。
- 如果本轮还没完成，不能把未完成内容写成已经完成的事实。

### DLx_UNIT_NNN/RTL_REVIEW.md

用户审查 RTL 的入口。

`RTL_REVIEW.md` 应该回答：

- AI 改了哪些 RTL 文件。
- 为什么改。
- 每个文件具体改了什么。
- 用户应该重点看哪里。
- 可能影响旧功能的点。
- 哪些地方风险最大。

建议结构：

```text
# RTL 改动审查

## 1. 改动总览

| 文件 | 为什么改 | 改了什么 | 用户重点检查 | 风险 |
|---|---|---|---|---|

## 2. 建议审查顺序
## 3. 关键代码位置
## 4. 可能影响旧功能的点
## 5. 尚未确认的问题
```

示例表格：

| 文件 | 为什么改 | 改了什么 | 用户重点检查 | 风险 |
|---|---|---|---|---|
| `laser_sync_blanker_ctrl.v` | 新增 DL5 控制模块 | 产生 blanker/acq/busy/pixel_done | 状态机、计数边界、`scan_state` 门控 | 激光周期边界 |
| `command_monitor_new.v` | 新增 DL5 参数寄存器 | `0x0205~0x020A` | reset 默认值、地址冲突 | 上位机协议 |
| `dac_output.v` | laser 模式替换输出源 | mux `adc_tri/sync1/sync2` | 极性、停扫行为、旧模式不变 | 旧 DL1 行为回归 |

规则：

- AI 每次改 RTL 后，必须更新 `RTL_REVIEW.md`。
- 如果一次改了多个文件，必须说明每个文件为什么改。
- 不允许只写“修改了若干 RTL”。

### DLx_UNIT_NNN/SIM_REPLAY.md

用户在 Vivado 里复现仿真和查看波形的入口。

`SIM_REPLAY.md` 应该回答：

- 本次仿真验证什么。
- testbench 是哪个。
- 仿真 top 是哪个。
- 如何在 Vivado GUI 里重新跑仿真。
- 如何打开 AI 已跑出的波形。
- PowerShell 如何 batch 重跑。
- 重点看哪些信号。
- 什么现象算通过。
- AI 的仿真结果在哪里。
- 哪些场景还没覆盖。

建议结构：

```text
# Vivado 仿真复现

## 1. 本次仿真验证什么
## 2. testbench 和 top
## 3. Vivado GUI 重新跑仿真
## 4. Vivado GUI 打开已有波形
## 5. PowerShell batch 重跑
## 6. 重点信号
## 7. 通过标准
## 8. AI 已生成的结果
## 9. 未覆盖场景
```

规则：

- 所有 Vivado Tcl 命令必须写成可直接复制粘贴的完整代码块。
- 不要求用户记 Tcl 命令。
- 不允许只写 `<project_root>` 或 `<case-id>` 让用户自己替换。
- 如果命令没有实际验证过，必须标注“未验证”。

## 6. Vivado 仿真复现要求

每次 AI 跑仿真以后，必须留下用户可以复查的仿真材料。

不能只留下：

```text
xsim PASS
```

至少要留下：

```text
DLx_UNIT_NNN/
  SIM_REPLAY.md
  sim/
    run_gui.tcl
    run_batch.tcl
    waves.wcfg
    expected.md
  out/
    sim/
      xsim.log
      waveform.wdb
      result.txt
      sim_result.csv
```

说明：

- `.wdb` 是 Vivado/xsim 的波形数据库，保存真实仿真信号变化。
- `.wcfg` 是 Vivado 波形窗口配置，保存要显示哪些信号、分组和显示格式。
- `.wdb` + `.wcfg` 组合起来，用户可以在 Vivado 中打开 AI 跑出来的波形并直接看重点信号。

### Tcl Console 示例：重新跑仿真

`SIM_REPLAY.md` 中应提供这种完整命令块：

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj

open_project AXI_DDR.xpr

source AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/run_gui.tcl
```

### Tcl Console 示例：打开 AI 已跑出的波形

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj

open_project AXI_DDR.xpr

open_wave_database AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
open_wave_config AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/waves.wcfg
```

### PowerShell 示例：batch 重跑

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj

D:\Xilinx\Vivado\2021.1\bin\vivado.bat -mode batch -source AI-work\features\DL5_laser_sync\DL5_UNIT_001\sim\run_batch.tcl
```

## 7. 文档同步 Gate

技能需要增加一个收尾检查：每次实现、仿真或综合后，不允许只更新 `LOG.md`。

必须检查：

- 是否有相关 RTL 文件时间晚于 `WORK.md` 或 `RTL_REVIEW.md`。
- 是否有仿真 log 中出现 PASS 但 `WORK.md` / `SIM_REPLAY.md` 未记录。
- 是否有 `run_synth.log` 出现 BUILD PASS 但 `WORK.md` 未记录。
- 是否有 feature 已完成但 `guide/data-paths/*_AS_BUILT.md` 未创建或未更新。
- 是否有 `guide/` 文档仍包含“进入实现阶段”“后续 plan”“待实现”等与当前状态冲突的措辞。
- 是否有 AI 跑过仿真但没有提供用户可复查的 `SIM_REPLAY.md`、`run_gui.tcl`、`waves.wcfg` 或波形/日志证据。

如果发现不一致，技能应报告：

```text
DOC STALE:
- 过期文档：
- 最新代码/日志证据：
- 需要更新：
```

如果发现仿真不可复查，技能应报告：

```text
SIM NOT REVIEWABLE:
- 缺失的复查材料：
- 已有仿真证据：
- 需要补充：
```

并在最终回答里明确说明文档或仿真交付未同步，不能宣称工作完全收尾。

## 8. 用户验收 Gate

每轮 AI 修改 RTL 后，最终回答必须给出用户验收入口。

最低要求：

- 从哪个 `WORK.md` 开始看。
- RTL 改动见哪个 `RTL_REVIEW.md`。
- Vivado 仿真复现见哪个 `SIM_REPLAY.md`。
- 仿真结果和波形在哪里。
- 仍待人工确认什么。

技能应避免只回答：

```text
已完成，仿真通过。
```

应回答成：

```text
本轮工作记录：AI-work/features/DL5_laser_sync/DL5_UNIT_001/WORK.md
RTL 审查入口：AI-work/features/DL5_laser_sync/DL5_UNIT_001/RTL_REVIEW.md
Vivado 仿真复现：AI-work/features/DL5_laser_sync/DL5_UNIT_001/SIM_REPLAY.md
仿真结果：AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/xsim.log
波形：AI-work/features/DL5_laser_sync/DL5_UNIT_001/out/sim/waveform.wdb
仍待人工确认：...
```

## 9. skill 模式调整

当前 `fpga-project-reader` 的既有模式应保留：

1. **Mode 1 - Whole-project map**
   读整个工程，生成 `FPGA_PROJECT_GUIDE.md`，识别主数据链路。

2. **Mode 2 - Selected-path deep read**
   精读某条已有数据通路，产出稳定上下文。

3. **Mode 3 - Single-file close read / annotation**
   精读或注释某个 RTL/source 文件。

4. **Mode 4 - Co-work environment setup**
   只负责基础协作环境搭建，包括 Vivado/xsim 探测、baseline、回滚、`RULES.md`、通用脚本、`check_env.tcl`。Mode 4 不负责具体新功能开发。

新增：

5. **Mode 5 - Feature development**
   负责新功能开发单元，例如 `DL5_UNIT_001`。它使用 Mode 1/2 产生的上下文和 Mode 4 准备好的环境，完成需求整理、执行计划、RTL 改动、仿真、综合、用户交接，以及最终 as-built 回写。

一句话边界：**Mode 4 修路，Mode 5 开车开发功能。**

## 10. DL5 的补救建议

当前 DL5 可以按下面步骤整理：

1. 新建 `AI-work/features/DL5_laser_sync/DL5_UNIT_001/`。
2. 把现有 `DL5_LASER_SYNC_MODE_DESIGN.md` 中仍有效的需求、设计和决策迁入 `WORK.md`。
3. 新建 `RTL_REVIEW.md`，列出本轮实际改过的 RTL 文件、改动原因、用户检查点。
4. 新建 `SIM_REPLAY.md`，提供 Vivado GUI / PowerShell 可复制命令。
5. 整理 `sim/run_gui.tcl`、`sim/run_batch.tcl`、`sim/waves.wcfg`、`sim/expected.md`。
6. 整理 `out/sim/`，放用户可复查的 log、result、wdb、csv。
7. 整理 `out/synth/`，放综合 log 和 utilization 报告。
8. 新建或重写 `guide/data-paths/DL5_LASER_SYNC_AS_BUILT.md`，只写当前已实现且已验证的事实。
9. 将旧 `DL5_LASER_SYNC_MODE_DESIGN.md` 改为归档入口，或删除后在 `LOG.md` 记录迁移。
10. 保留未完成项：
    - `laser_sync_in` 引脚号和 XDC 约束待硬件确认。
    - 上板验证待用户执行。
    - `sync_pixel_tri2` 是否确认为外设需要的 `laser_event_busy` 语义仍待实际接外设确认。

## 11. 需要修改 skill 的点

稍后修改 `fpga-project-reader` 时，建议加入：

- 新增 Feature Development 模式。
- 明确 `guide/` 与 `features/` 的边界。
- 定义 `<DLx>_UNIT_NNN` 工作包机制。
- 明确 Mode 4 只做基础环境搭建，Mode 5 才做新功能开发。
- 默认模板只保留 `WORK.md`、`RTL_REVIEW.md`、`SIM_REPLAY.md` 三个核心入口。
- 加入文档同步 Gate。
- 加入 Human-verifiable simulation Gate。
- 加入用户验收 Gate。
- 加入 stale-doc 检查脚本或至少检查规则。
- 加入 sim 复现模板：`run_batch.tcl`、`run_gui.tcl`、`expected.md`、`waves.wcfg`。
- 修改 Mode 5 的收尾规则：实现或验证后必须同步相关 unit 文档、as-built 文档和用户可复查仿真包。

## 12. 最重要的规则

不要让一个文档同时承担“计划”和“事实”两种角色。

不要让 AI 的验证只停留在 AI 自己能看懂的日志里。

不要生成一堆用户不会看的管理文档。

计划可以变化，事实必须能被代码和日志证明；仿真可以由 AI 跑，但结果必须能被用户在 Vivado 里复查。

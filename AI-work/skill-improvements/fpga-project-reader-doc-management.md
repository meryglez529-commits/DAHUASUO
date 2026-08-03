# fpga-cowork Mode 5 改进设计稿

> 目的：把本工程 DL5 协作开发中摸出来的经验，整理成 `fpga-cowork` skill 后续要吸收的设计依据。
>
> 重要结论：`DL5_UNIT_001` 更像事后补救交付包；`DL5_UNIT_002` 才是真正的 Mode 5 原型。

## 1. 当前问题

这个工程已经证明，AI 不是只需要“读 FPGA 工程”，还要能和用户长期协作开发新功能。DL5 开发暴露出几类问题：

1. **需求没先对齐，RTL 可能做错方向**
   `DL5_UNIT_001` 可以 sim/synth PASS，但后续用户复核发现需求方向有偏差。

2. **过程产物散落**
   D 盘根目录、工程根目录、`AI-work/features/*/sim/` 下都有脚本、log、ILA CSV、`xsim.dir`、`vivado*.log` 等产物。新功能闭环必须把这些收进对应 unit。

3. **仿真环境很特殊**
   本机有 E-SafeNet 加密，普通 xsim 调用会失败；Vivado batch/GUI 又各有坑。仿真能跑通本身就是环境知识，不能只藏在某个 feature 的脚本里。

4. **文档会局部过期**
   `IMPLEMENTATION.md` 里可能前面写 7/7 PASS，后面旧章节还写“集成仿真未开始”。Mode 5 必须有状态同步 gate。

5. **用户需要能接手**
   用户不仅要知道“AI 说 PASS”，还要能看需求、看架构、审 RTL、复现仿真、看 ILA/综合证据。

## 2. Mode 4 和 Mode 5 的边界

一句话：

**Mode 4 修路，Mode 5 开车。**

### Mode 4 - Co-work Environment Setup

Mode 4 负责建立“这个工程怎么安全闭环”的基础环境，不负责具体新功能。

应包含：

- Vivado 路径、版本、license、xsim/ModelSim 可用性。
- 工程根、工程文件、路径长度、文件编码、换行符。
- 可回滚 baseline 和回滚演练。
- `RULES.md`：哪些能改、哪些必须先问、闭环刹车条件。
- 项目级脚本模板：`AI-work/scripts/*.tcl`。
- 项目级仿真能力说明：**本工程推荐新增 `AI-work/env/SIMULATION.md` 或继续维护 `AI-work/guide/VIVADO_SIM_SOP.md`**。

### Mode 5 - Feature Development

Mode 5 负责一个具体新功能/修改闭环，例如 `DL5_UNIT_002`。

它使用 Mode 1/2 的工程上下文，使用 Mode 4 的工具链和规则，然后完成：

- 需求对齐。
- 架构方案。
- RTL 修改。
- 仿真。
- 综合/实现/bitstream（按用户需要）。
- ILA/上板辅助验证（按用户需要）。
- 证据归档。
- 最终 as-built 回写。

Mode 5 不能替代 Mode 4。如果仿真环境没摸清、规则没确认、回滚没准备，不能直接进入 RTL 改动。

## 3. Vivado 仿真 SOP 放哪里

结论：**项目级仿真 SOP 属于 Mode 4；单个功能的仿真复现属于 Mode 5。**

当前文件：

```text
AI-work/guide/VIVADO_SIM_SOP.md
```

记录的是当前工程的“仿真活法”：

- E-SafeNet 加密 `init.tcl` 导致单独 `xsim.exe` 失败。
- Vivado batch + `launch_simulation` 会 Broken pipe。
- GUI `launch_simulation` 被 `wbtcv.exe` 卡死的定位和处理。
- 当前唯一稳定 batch 路径：Vivado batch 里 `exec xvlog/xelab`，再用 Vivado 内置 `xsim` 命令。
- xelab `exec` 返回码误判、IP sim 文件手动列入 prj 等经验。

这些不是 DL5 独有的功能知识，而是**本工程环境知识**，所以应该由 Mode 4 维护。

推荐规则：

| 内容 | 所属 | 推荐位置 |
|---|---|---|
| 本机/本工程 Vivado 仿真坑、可用路径、工具链限制 | Mode 4 | `AI-work/env/SIMULATION.md` 或 `AI-work/guide/VIVADO_SIM_SOP.md` |
| 通用脚本模板，如 `run_manual.tcl` 的骨架 | Mode 4 | `AI-work/scripts/templates/` 或 skill 模板 |
| 某个 unit 的 testbench、TC、波形怎么看 | Mode 5 | `<UNIT>/sim/SIM_REPLAY.md` |
| 某个 unit 的仿真脚本 | Mode 5 | `<UNIT>/sim/run_manual.tcl`、`run_gui.tcl` |
| 某个 unit 的仿真结果 | Mode 5 | `<UNIT>/out/sim/` |

如果 Mode 5 开发中发现新的仿真坑，应当：

1. 先在当前 unit 的 `IMPLEMENTATION.md` 记录问题和修复过程。
2. 跑通后，把可复用经验回写到项目级 `VIVADO_SIM_SOP.md` 或 `env/SIMULATION.md`。
3. 在 `LOG.md` 记录“由哪个 unit 发现并更新了项目级 SOP”。

## 4. Mode 5 标准工作包

以 `DL5_UNIT_002` 为原型，Mode 5 的默认工作包不再是 `WORK/RTL_REVIEW/SIM_REPLAY` 三件套，而是按开发阶段组织。

推荐结构：

```text
AI-work/features/
  <feature-slug>/
    <DLx_UNIT_NNN>/
      REQUIREMENTS.md
      ARCHITECTURE.md
      IMPLEMENTATION.md
      RTL_REVIEW.md              # 可选；多文件 RTL 改动或交付审查时必须有

      sim/
        SIM_REPLAY.md
        run_gui.tcl
        run_manual.tcl
        run_batch.tcl            # 若本工程可用
        waves.wcfg               # 若能稳定保存波形布局

      synth/
        run_synth.tcl            # 若本 unit 需要综合闭环

      impl/
        run_impl.tcl             # 若本 unit 需要实现/bitstream
        run_bitstream.tcl

      ila/
        program.tcl
        capture_*.tcl
        export_*.tcl

      out/
        sim/
        regression/
        synth/
        impl/
        bitstream/
        ila/
        hw_debug/

      evidence/
```

`UNIT` 是一次完整开发单元，不是一个仿真用例。需求方向变化、上板阶段变化、重大方案变化，都应该新建下一个 `UNIT_NNN`，不要篡改已完成历史。

## 5. 各阶段产物

### 5.1 需求对齐阶段

产物：`REQUIREMENTS.md`

应该回答：

- 用户真实要解决的物理/业务问题是什么。
- 外部时序图怎么理解。
- 参数语义、单位、步进、边界。
- 哪些信号是物理 IO，哪些只是内部逻辑。
- 哪些截图/文档内容只是示意，不做。
- 已确认问题和待确认问题。

`DL5_UNIT_002/REQUIREMENTS.md` 的好例子：

- 明确 `Scan_X_Signal` 没有物理输出。
- 明确 `dwell_time = dac_sample`。
- 明确行切换期间 laser 脉冲忽略。
- 明确 `scan_delay_time`、blanker、acq 的单位。
- 用 Q1~Q7 把讨论结论落成表格。

Gate：需求不清楚时，AI 不应该开始 RTL。

### 5.2 架构方案阶段

产物：`ARCHITECTURE.md`

应该回答：

- 数据路径和触发路径怎么分。
- 新状态机如何插入旧状态机。
- CDC 边界在哪里，用什么同步方式。
- FIFO/BRAM/DDR/IP 如何影响时序。
- 哪些旧模式必须保持逐拍不变。
- 风险和约束公式是什么。
- 仿真、综合、ILA 分别验证什么。

`DL5_UNIT_002/ARCHITECTURE.md` 的好例子：

- 把数据路径和触发路径分离。
- 分析 FIFO 水位导致 DAC 路径延迟，但 acq/blanker 走独立 toggle。
- 明确 State 14/15/16 的职责。
- 明确 `laser_mode_en=0` 时普通模式零变化。
- 写出行末斜坡排空约束公式。

Gate：复杂 RTL 改动前必须先有可审查的架构方案。

### 5.3 RTL 实施阶段

产物：`IMPLEMENTATION.md`，必要时补 `RTL_REVIEW.md`

`IMPLEMENTATION.md` 应该回答：

- 实施顺序。
- 每个模块改到哪里。
- 当前完成状态。
- elaborate/sim/synth/impl 的状态。
- 遇到的问题、修复过程、证据日志。
- 变更记录。

如果一次改了多个 RTL 文件，或者用户需要审查交付，应补 `RTL_REVIEW.md`：

| 文件 | 为什么改 | 改了什么 | 用户重点检查 | 风险 |
|---|---|---|---|---|

Gate：每次 RTL 改动后，至少 `IMPLEMENTATION.md` 要同步；多文件改动不能只写“改了 RTL”。

### 5.4 仿真阶段

产物：

```text
sim/SIM_REPLAY.md
sim/run_manual.tcl
sim/run_gui.tcl
out/sim/
out/regression/
```

`SIM_REPLAY.md` 应该回答：

- testbench 是哪个。
- TC1~TCn 各测什么。
- 在 Vivado GUI 里怎么跑。
- 在 batch/PowerShell 里怎么跑。
- 哪些信号必须加到波形。
- 每个 TC 怎么看、什么现象算 PASS。
- AI 已生成哪些 log/result/wdb/csv。

项目级仿真坑不在每个 `SIM_REPLAY.md` 里重复展开，只引用项目级 SOP：

```text
项目级仿真环境坑见 AI-work/guide/VIVADO_SIM_SOP.md
```

Gate：AI 说仿真 PASS 时，必须留下用户能复现或检查的脚本和日志。若无法生成波形，要写明原因。

### 5.5 综合/实现/bitstream 阶段

产物：

```text
synth/run_synth.tcl
impl/run_impl.tcl
impl/run_bitstream.tcl
out/synth/
out/impl/
out/bitstream/
```

`IMPLEMENTATION.md` 必须记录：

- 命令。
- 日志路径。
- ERROR / CRITICAL WARNING。
- WNS/TNS 或综合状态。
- 资源变化。
- 是否生成 bitstream。
- 没跑的原因。

Gate：不能只说“综合过了”；必须有 log/report 证据路径。

### 5.6 ILA / 上板调试阶段

产物：

```text
ila/program.tcl
ila/capture_*.tcl
ila/export_*.tcl
out/ila/
out/hw_debug/
```

要求：

- ILA/VIO 脚本放在当前 unit 的 `ila/`，不要继续散到 D 盘根目录。
- CSV、log、截图说明放在 `out/ila/` 或 `out/hw_debug/`。
- 每次 capture 要记录场景、寄存器配置、触发条件、结果文件。
- 如果 Vivado 默认把 `hw_ila_data_*` 导出到当前目录，脚本必须移动到当前 unit 的 `out/` 目录。

Gate：上板结论必须能追到 ILA/示波器/寄存器读写证据。

### 5.7 As-built 回写阶段

产物：

```text
AI-work/guide/data-paths/<DLx>_<name>_AS_BUILT.md
```

规则：

- `features/` 管过程。
- `guide/` 管稳定事实。
- 未验证的计划不写进 guide。
- 仿真验证但未上板，可以写 as-built，但必须明确“上板未验证”。
- 用户指出需求方向错误时，旧 unit 保留为历史，as-built 不应继续把旧方案写成最终事实。

## 6. 输出目录清洁规则

从现在的 D 盘和工程根目录看，需要给 skill 加一条硬规则：

**任何新运行的 sim/synth/impl/bitstream/ILA 产物，都必须进入当前 unit 的 `out/`。**

常见散落物和归宿：

| 散落物 | 归宿 |
|---|---|
| `vivado*.log` / `vivado*.jou` | `<UNIT>/out/<stage>/` |
| `xvlog.log` / `xelab.log` / `xsim.log` | `<UNIT>/out/sim/` 或 `out/regression/` |
| `xsim.dir` / `xvlog.pb` | 尽量通过脚本工作目录约束到 `<UNIT>/out/sim/work/`；无法避免时在收尾记录并清理 |
| `hw_ila_data_*` | `<UNIT>/out/ila/` 或 `out/hw_debug/` |
| synth/impl/bitstream logs | `<UNIT>/out/synth/`、`out/impl/`、`out/bitstream/` |
| 一次性调试 Tcl | `<UNIT>/ila/`、`sim/`、`synth/` 或 `impl/` |

脚本原则：

- PowerShell/Vivado 命令显式设置 `-log`、`-journal`。
- Tcl 脚本显式创建 `out` 目录。
- ILA export 显式给目标文件路径。
- 若工具强制在当前目录落文件，脚本结束时移动到当前 unit。

## 7. Mode 5 状态同步 Gate

收尾前检查：

- `REQUIREMENTS.md` 是否还与当前方案一致。
- `ARCHITECTURE.md` 是否仍描述当前 RTL，而不是旧方案。
- `IMPLEMENTATION.md` 顶部状态与各章节状态是否一致。
- `SIM_REPLAY.md` 的 TC 数量、脚本名、结果路径是否与实际一致。
- 相关 RTL/脚本是否晚于文档但没有记录。
- PASS / BUILD PASS / ILA 结论是否都写进 `IMPLEMENTATION.md`。
- 运行产物是否还散在 D 盘根或工程根。
- 已验证事实是否回写 as-built。

发现不一致时，最终回答不能说“完全完成”，应报告：

```text
DOC STALE:
- 过期文档：
- 最新证据：
- 需要同步：

ARTIFACT SPILL:
- 散落产物：
- 应移动到：
- 是否已整理：
```

## 8. 最终用户验收入口

Mode 5 最终回答应按实际阶段给入口，不要只说“完成”。

最低格式：

```text
需求入口：AI-work/features/<feature>/<UNIT>/REQUIREMENTS.md
架构入口：AI-work/features/<feature>/<UNIT>/ARCHITECTURE.md
实施进度：AI-work/features/<feature>/<UNIT>/IMPLEMENTATION.md
仿真复现：AI-work/features/<feature>/<UNIT>/sim/SIM_REPLAY.md
仿真证据：AI-work/features/<feature>/<UNIT>/out/sim/
综合证据：AI-work/features/<feature>/<UNIT>/out/synth/（如有）
ILA/上板证据：AI-work/features/<feature>/<UNIT>/out/ila/（如有）
项目级仿真 SOP：AI-work/guide/VIVADO_SIM_SOP.md
仍待确认：
```

## 9. 后续修改 skill 的清单

真正改 `fpga-cowork` 时，应加入：

- 新增 Mode 5 - Feature Development。
- Mode 5 默认以 `DL5_UNIT_002` 为范例，而不是 `DL5_UNIT_001`。
- Mode 4 增加“仿真环境 SOP / Simulation Environment”子阶段。
- `AI-work/` bootstrap 增加 `features/`。
- Mode 5 模板增加：
  - `REQUIREMENTS.md`
  - `ARCHITECTURE.md`
  - `IMPLEMENTATION.md`
  - `sim/SIM_REPLAY.md`
  - `sim/run_manual.tcl`
  - `sim/run_gui.tcl`
  - `synth/`、`impl/`、`ila/` 空目录或 `.gitkeep`
  - `out/` 子目录结构
- 增加状态同步 gate。
- 增加产物散落检查 gate。
- 增加“项目级 SOP 由 Mode 4 维护，Mode 5 引用并反哺”的规则。

## 10. 最重要的规则

不要让 AI 跳过需求对齐直接写 RTL。

不要让项目级环境坑只藏在某个功能包里。

不要让仿真、综合、ILA 产物继续散落在 D 盘或工程根。

不要让计划文档和事实文档混在一起。

Mode 5 的价值不是“AI 能改代码”，而是“用户和 AI 可以把一个硬件功能从需求一路闭环到可验证证据”。

## 11. 对现有 skill 的自查

本节记录对 `fpga-cowork` 现有 Mode 1~4、Stage 0、脚本和模板的自查结果，以及本轮已经落实到 skill 的状态。

### 11.1 临时草稿回收状态

本次讨论前，曾经误把一版 Mode 5 草稿写进了 skill 目录。那版草稿仍按 `WORK.md / RTL_REVIEW.md / SIM_REPLAY.md` 三入口设计，已经和本设计稿中以 `DL5_UNIT_002` 为原型的阶段式工作包冲突。

本轮已按阶段式工作包回收：

| 位置 | 原问题 | 当前状态 |
|---|---|---|
| `SKILL.md` | Mode 5 描述偏向三件套工作包 | 已改为 `REQUIREMENTS / ARCHITECTURE / IMPLEMENTATION / sim/SIM_REPLAY` 阶段式工作包 |
| `references/feature-development.md` | 临时版仍写 `WORK.md` 为核心 | 已按本文 Mode 5 重写 |
| `assets/feature-work-package/` | 临时模板是三件套 | 已改成阶段式模板，并保留 `RTL_REVIEW.md` 作为多文件交付审查入口 |
| `validate-ai-work.py` | 已临时加入 `features/` 检查 | 已保留 Mode 4 检查边界，并新增独立 Mode 5 validator |

### 11.2 Mode 1 - Whole-project map

现有 Mode 1 优点：

- 强调先找系统边界、顶层端口、主数据链路。
- 输出 `FPGA_PROJECT_GUIDE.md` 的结构比较完整。
- 已能把 Ethernet/DDR/QSPI 等支撑资源和真实业务链路区分开。

需要改进：

1. **增加“guide 是稳定事实，不是开发计划”的约束**
   Mode 1 生成的是工程地图，不应该承载新功能实现计划。后续 feature 更新后，只能把已验证事实回写 guide。

2. **增加 Feature Index**
   总 guide 可以新增一个小节或表格，指向当前已有 feature work package：

   ```text
   | Feature | 当前状态 | 过程入口 | 已验证事实 |
   |---|---|---|---|
   | DL5 laser sync | UNIT_002 sim PASS / synth 未跑 | AI-work/features/.../DL5_UNIT_002 | guide/data-paths/DL5_..._AS_BUILT.md |
   ```

3. **增加“产物污染/运行目录”扫描**
   Mode 1 初读时如果看到工程根有 `vivado*.log`、`xsim.dir`、`hw_ila_data_*`、`.Xil`、`*.jou`，应该记录为环境风险，而不是当作源码。

4. **仿真入口不应只写一个历史 testbench**
   `FPGA_PROJECT_GUIDE.md` 里“仿真入口”应区分：
   - 工程原始 simset 入口。
   - 当前项目级仿真 SOP。
   - 各 feature unit 的仿真入口。

### 11.3 Mode 2 - Selected-path deep read

现有 Mode 2 优点：

- `data-path-deep-reading.md` 已经很成熟，强调逐文件阅读手册，不只是总结。
- 强调主数据、数据形态变化、CDC/FIFO、控制如何约束数据。
- `validate-deep-reading-guide.py` 能防止文档退化成摘要。

需要改进：

1. **明确 Mode 2 和 Mode 5 的边界**
   Mode 2 读已有通路，产出稳定理解；Mode 5 改或新增通路，产出开发工作包。不能把 Mode 5 的需求/方案/调试过程塞进 Mode 2 deep read。

2. **增加“读完后可进入 Mode 5”的桥接**
   如果 Mode 2 读到“下一步要改功能”，应输出：

   ```text
   建议新建 feature work package：
   AI-work/features/<feature>/<UNIT>/
   需求待确认：
   风险：
   ```

   但不要自己开始改 RTL。

3. **增加 As-built 使用规则**
   `*_DEEP_READ.md` 是阅读手册；`*_AS_BUILT.md` 是已实现事实。两者不要混用。

4. **验证建议要分层**
   Mode 2 可以提出仿真/ILA 信号组，但不应承诺已经验证。验证执行和证据归档属于 Mode 5。

### 11.4 Mode 3 - Single-file close read / annotation

现有 Mode 3 优点：

- 强调先建立数据模型和上下游关系，再注释文件。
- 强调不改功能 RTL。
- 中文教学注释风格适合当前用户。

需要改进：

1. **增加“注释不是功能开发”的边界**
   Mode 3 只能让一个文件更容易读，不能顺手改状态机或修 bug。若读完发现要改功能，转 Mode 5。

2. **注释记录需要包含版本和差异**
   `AI-work/annotations/parameter_dacdata_gen-diff.md` 这种“新旧版本对比”很有价值，说明 Mode 3 不只是注释，也可以做单文件差异阅读。skill 应明确支持：
   - 单文件教学注释。
   - 单文件新旧 diff 阅读。
   - 单文件 role/context 说明。

3. **注释后要检查和 Mode 5 的关系**
   如果注释对象后来在 Mode 5 被改动，annotation 可能过期。Mode 5 状态同步 gate 应检查相关 annotation 是否需要标注“已过期/对应旧版”。

4. **编码和乱码要前置探测**
   本工程中文注释多，且可能有 legacy 乱码。Mode 3 应先确认文件编码和换行符，再编辑注释。

### 11.5 Mode 4 - Co-work environment setup

现有 Mode 4 优点：

- 很强调 `RULES.md`、baseline、回滚演练。
- 知道要探测 Vivado、仿真器、license、磁盘、编码、路径长度。
- 已有 `validate-ai-work.py` 结构检查。

需要改进：

1. **新增 `env/SIMULATION.md` 或正式接管 `guide/VIVADO_SIM_SOP.md`**
   当前 Mode 4 只要求 `check_env.tcl`，不足以覆盖本机复杂仿真环境。应把以下内容变成 Mode 4 一等产物：
   - batch 可用/不可用路径。
   - GUI 可用/不可用路径。
   - 加密 `init.tcl` 影响。
   - `wbtcv.exe` 卡死处理。
   - IP sim 文件生成和手动 prj 规则。
   - 推荐 `run_manual.tcl` 模板。

2. **`check_env.tcl` 不等于 sim SOP**
   `check_env.tcl` 只能证明工程能打开、compile order 能解析；不能证明复杂 IP testbench 能跑。Mode 4 应增加“最小仿真探针”或至少记录为何不能自动跑。

3. **FOCUS.md 不应承担 Mode 5 需求文档**
   `FOCUS.md` 只记录当前调试焦点。正式需求、架构、实现计划必须在 Mode 5 unit 中。

4. **RULES.md 应加入产物目录约束**
   明确新跑的 log/jou/wdb/csv/ILA 数据必须进入当前 unit 的 `out/`，不能散到 D 盘或工程根。

5. **环境 setup 不应默认问太多**
   当前文档说 setup 阶段问得略啰嗦可以接受；实际协作中应先自动探测，再只问阻塞项，避免把用户拖进工具链细节。

### 11.6 Stage 0 / AI-work Bootstrap

需要改进：

1. `AI-work/README.md` 已按五个 mode 更新。
2. `features/` 已正式进入骨架。
3. `.gitignore` 应区分：
   - 全局 runtime 输出：`sim_out/`、`reports/`。
   - Mode 5 unit 下的 `out/` 是否全部忽略，需要讨论。当前我们希望保留交付证据，但 `.wdb` 很大，可能只保留 log/result/csv，`.wdb` 视项目策略处理。
4. 增加“不要在 D 盘根目录或工程根目录生成新运行产物”的 bootstrap 说明。

### 11.7 Diagram / 可视化

现有 D2 规则够用，但可以补两类图：

- Mode 1：全工程架构图、主数据链路图。
- Mode 5：功能方案图、状态机插入图、CDC/FIFO 时序图。

规则：Mode 5 的方案图放在 `<UNIT>/diagrams/` 或 `ARCHITECTURE.md` 附近；验证后的稳定链路图再回写 `guide/diagrams/`。

### 11.8 脚本和 validator

需要新增或改进：

| 脚本 | 用途 |
|---|---|
| `validate-feature-work-package.py` | 检查 Mode 5 unit 是否有必需阶段文档、out 证据、状态同步 |
| `scan-artifact-spill.py` | 检查 D 盘/工程根是否有新散落的 `vivado*.log`、`hw_ila_data_*`、`xsim.dir` 等 |
| `validate-simulation-sop.py` | 检查 `env/SIMULATION.md` 或 `VIVADO_SIM_SOP.md` 是否记录可用/不可用仿真路径 |
| `run_manual.tcl` 模板 | 适配本机 E-SafeNet 加密环境的 batch 仿真模板 |

现有 `validate-ai-work.py` 只检查 Mode 4，不应承担 Mode 5。应拆开：

- `validate-ai-work.py`：Stage 0 + Mode 4 环境。
- `validate-feature-work-package.py`：Mode 5 单元。
- `validate-deep-reading-guide.py`：Mode 2 阅读手册。

### 11.9 agents/openai.yaml

后续正式修改 skill 后，`agents/openai.yaml` 的 `short_description` 和 `default_prompt` 也要更新。它现在仍偏“map/deep-read/annotate/setup”，没有突出：

- 新功能闭环开发。
- 需求对齐。
- 仿真/综合/ILA 证据归档。
- 项目级仿真 SOP。

### 11.10 优先级建议

建议真正改 skill 时按这个顺序：

1. 回滚或修正临时 Mode 5 草稿，使它和本文一致。
2. 更新 `SKILL.md` 的 Mode 5 总入口。
3. 更新 `ai-work-bootstrap.md`，正式加入 `features/` 和五个 mode。
4. 更新 Mode 4：加入 `env/SIMULATION.md` / 项目级仿真 SOP。
5. 新写 `references/feature-development.md`，以 `DL5_UNIT_002` 为范例。
6. 新建 Mode 5 模板目录。
7. 新增 `validate-feature-work-package.py` 和 artifact spill 检查。
8. 最后再更新 `agents/openai.yaml`。

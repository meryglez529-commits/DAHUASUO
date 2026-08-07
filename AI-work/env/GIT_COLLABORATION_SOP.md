# AXI_DDR 双机 Git 协作 SOP

## 目的与适用范围

本 SOP 用于两位工程师在不同 Windows 电脑上协同维护本 Vivado 2021.1 工程。Git 是设计源的唯一版本历史；Vivado 生成目录、构建产物和板级抓取数据不做实时文件同步。

本 SOP 不授权修改 RTL、XDC、IP、Block Design 或下载板卡。此类改动仍遵循 `RULES.md` 与每个 feature 工作包的验证要求。

## 共同环境基线

两台电脑在开始开发前分别记录并核对：

| 项目 | 约定 |
|---|---|
| Git | 使用同一远程仓库的 `origin`；先 `git fetch --prune`，再开始工作 |
| Vivado | 2021.1；不同补丁、许可或 IP repository 路径必须显式记录 |
| 工程入口 | `AXI_DDR.xpr` |
| 主分支 | `main`，仅放已评审且可复现检查过的改动 |
| 本地生成物 | `AXI_DDR.cache/`、`.gen/`、`.runs/`、`.sim/`、`.Xil/` 等绝不通过网盘同步 |
| 文本处理 | 不批量转换既有 RTL 的编码或换行；新文档 UTF-8（无 BOM）+ LF |

> ⚠️ 当前仓库启用了 `core.autocrlf=true`，而设计源含 LF/CRLF 和 GBK/UTF-8 混合。合并前必须查看实际 diff；不要用“格式化整个文件”解决冲突。

## 文件纳管规则

| 类型 | 策略 | 本工程示例 |
|---|---|---|
| 可重建设计源 | 必须提交 | RTL、testbench、`.xdc/.ucf`、`.xci`、`.bd`、自定义 IP 源码、构建 Tcl、AI-work 文档 |
| Vivado 运行结果 | 忽略 | `AXI_DDR.runs/`、`.cache/`、`.sim/`、`.hw/`、`.ip_user_files/`、日志、WDB、PB |
| 板级证据/正式发布件 | 放 feature 工作包或受控制品库 | bit/LTX、时序与 DRC 报告、ILA CSV；记录关联 commit 和 SHA-256 |
| 不可重建设计交付件 | 逐项批准 | 第三方/加密 IP 的 DCP；必须在交接文档写明来源、版本和重建限制 |

当前受 Git 跟踪的 `.dcp` 共 4 个，应在下一次 IP 清理时逐项确认是否真的不可重建；在未确认前不删除、不移动。

## 分支与合并

```text
main                     已评审、已验证的集成基线
feature/<topic>          一个功能或缺陷修复
debug/<topic>            仅诊断、测试或 ILA 方案
release/<version>        上板/交付冻结分支（仅必要时建立）
```

1. 开工前确保 `git status --short` 为空；若不为空，先提交、stash，或明确保留本地工作，绝不直接 pull/merge。
2. 从最新 `origin/main` 创建自己的 `feature/<topic>` 分支。
3. 一次提交只解决一个可解释问题；提交信息包含修改范围和已运行的验证。
4. 提交前运行 `git diff --check`，检查未预期的整文件换行、编码或工程自动改写。
5. 发起合并前，由另一位工程师至少审阅 RTL/XDC/IP/BD 相关 diff；合并后由指定集成人执行一次项目级构建或按工作包记录 `BLOCKED`。
6. `main` 禁止两人同时直接提交；只通过已审阅的分支合并。

## Vivado 特别规则

### `.xpr`

`.xpr` 是 XML 工程描述，打开 GUI 或调整工程设置时可能被 Vivado 自动修改。两人不得并行修改它。

- 只有“工程管理员”可将 `.xpr` 改动合并入 `main`。
- 改动前先确认其中是否只是历史时间戳/绝对路径，或实际 source set、top、IP repo、器件配置变化。
- 若是实际工程配置变化，提交中必须说明原因、Vivado 版本和重建/验证结果。

### `.xci` 与 `.bd`

- 每次只指定一位负责人编辑同一个 IP 或 Block Design。
- 不手工拼接 XML 冲突；选择一方为基线，在 Vivado/Tcl 中重施另一方改动，然后重新生成并验证。
- 修改 IP/BD 后至少检查 IP status；进入交付分支前还须重新综合/实现。

### 板卡与 ILA

板卡是串行共享资源。每次下载或抓取记录：Git commit、bit/LTX 的 SHA-256、Vivado 版本、板卡编号、操作者、寄存器/测试配置和结论。抓取数据置于 `AI-work/features/<feature>/<unit>/out/ila/` 或团队制品库，不放入根目录。

## 两人每日最小流程

```powershell
# 1. 先确认没有未提交改动，再同步远端信息
git status --short
git fetch --prune origin

# 2. 从 main 建立自己的工作分支（首次）
git switch main
git pull --ff-only origin main
git switch -c feature/<topic>

# 3. 修改、检查并提交
git diff --check
git status --short
git add <明确列出的文件>
git commit -m "<scope>: <change>"

# 4. 推送并请求同事评审
git push -u origin feature/<topic>
```

`git pull --ff-only` 只允许快进，能防止无意中在本地制造合并提交。任何冲突先停止并协商文件责任人；禁止通过“保留两边”把 RTL、XDC、`.xci` 或 `.bd` 的冲突糊过去。

## 当前协作基线（2026-08-07）

| 事项 | 状态 |
|---|---|
| 当前分支 | `main` |
| 当前 HEAD | `dba21d5a0f24522c08591fb0a4ce5c28324fa28c` |
| 远端 | 已配置 `origin` |
| 工作区 | DIRTY：`AXI_DDR.xpr`、`AI-work/LOG.md` 已修改，`AI-work/tmp/` 未跟踪 |
| 结论 | 在上述改动归属明确、提交或隔离前，禁止从 `main` 开始新的协作分支和合并操作 |

## 首次双机落地清单

- [ ] 同事电脑克隆仓库；不复制本机的 `.runs/.cache/.Xil`。
- [ ] 核对 Vivado 2021.1、许可证和自定义 IP repository。
- [ ] 两人分别运行 `git status --short` 和 `git diff --check`，确认基线无意外改动。
- [ ] 指定 IP/BD/.xpr 工程管理员和板卡管理员。
- [ ] 选取一个只改 RTL 的小功能，按 feature 分支 → 评审 → 合并 → 构建验证完成第一次演练。
- [ ] 决定 bit/LTX/ILA 原始数据的内部制品库或 NAS 路径；路径与访问权限写入 `HARDWARE.md` 或 feature 工作包。


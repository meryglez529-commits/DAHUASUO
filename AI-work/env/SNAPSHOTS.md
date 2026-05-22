# Snapshots

> 基线快照与里程碑。回滚命令必须可执行。

## 基线（baseline）

| 项 | 值 |
|---|---|
| 时间 | 2026-05-22 14:10 |
| 方式 | git |
| 引用 | commit `df52990`，tag `baseline-pre-cowork` |
| 工程状态 | 综合通过：⚠️ 未在本次 setup 中重跑；这是 setup 前的现状快照 |
| 包含范围 | 整个 `fpga_prj/`，排除 Vivado 生成物（见根目录 `.gitignore`） |

## 回滚命令

```powershell
# 干净回滚到 baseline（丢弃 working tree 与 staged 改动）
cd D:\XF\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj
git reset --hard baseline-pre-cowork

# 只回滚某个文件
git checkout baseline-pre-cowork -- <relative/path/to/file>

# 看当前与 baseline 的 diff
git diff baseline-pre-cowork
```

## 回滚演练

| 时间 | 改动 | 回滚命令 | 结果 |
|---|---|---|---|
| 2026-05-22 14:15 | 在 `AI-work/LOG.md` 末尾追加一行 `drill` 标记 | `git checkout -- AI-work/LOG.md` | ✅ 还原成功：`git status` 干净，`tail` 验证最后一行恢复为原内容 |

> 演练时同时观察到工程根目录有 untracked 文件 `AXI_DDR.srcs/parameter_dacdata_gen_old.v`（疑似用户调试时的备份）。已记入 OPEN-QUESTIONS，等用户决定处理方式。

## 后续里程碑

每个稳定节点打 tag/备份，追加到下表：

| 时间 | tag/备份 | 说明 |
|---|---|---|
| 2026-05-22 14:10 | `baseline-pre-cowork` | setup 前的现状基线 |

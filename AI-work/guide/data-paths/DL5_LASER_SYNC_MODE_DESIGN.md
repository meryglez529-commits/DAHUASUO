# DL5_LASER_SYNC_MODE_DESIGN 归档入口

> 这个文件原来是 DL5 的需求/设计/执行计划混合文档。现在已经归档，不再作为当前进度或当前事实入口。

## 当前应该看哪里

| 你要看什么 | 新入口 |
|---|---|
| DL5 第一次开发的需求、计划、AI 工作进度 | `../../features/DL5_laser_sync/DL5_UNIT_001/WORK.md` |
| AI 改了哪些 RTL、为什么改、你该审哪里 | `../../features/DL5_laser_sync/DL5_UNIT_001/RTL_REVIEW.md` |
| 怎么在 Vivado 里复现仿真和打开波形 | `../../features/DL5_laser_sync/DL5_UNIT_001/SIM_REPLAY.md` |
| 当前 RTL 已实现且已验证的稳定事实 | `DL5_LASER_SYNC_AS_BUILT.md` |
| 本文件归档前的完整原文 | `../../features/DL5_laser_sync/DL5_UNIT_001/evidence/DL5_LASER_SYNC_MODE_DESIGN_v3_original.md` |

## 归档原因

旧文档停留在“架构定稿 v3，进入 plan / 实现阶段”，但实际 RTL 已经完成、单元仿真 PASS、RTL elaboration PASS、synth_1 PASS。

为了避免用户和 AI 继续把过期计划当作当前状态，本文件只保留跳转入口。后续新增 DL5 功能时，不继续改这个文件，应创建新的工作包，例如：

```text
AI-work/features/DL5_laser_sync/DL5_UNIT_002/
```

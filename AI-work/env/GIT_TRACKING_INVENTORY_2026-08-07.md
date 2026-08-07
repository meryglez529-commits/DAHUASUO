# Git 纳管盘点 — 2026-08-07

## 证据范围

本盘点只读取当前工作树和 Git 索引，未打开 Vivado、未生成 IP、未运行综合/实现，也未修改设计文件。

| 项目 | 观察结果 |
|---|---|
| Git 状态 | 仓库存在，当前在 `main`，已有 `origin` 远端 |
| 设计源 | 172 个 `.v`、4 个 `.vhd`、4 个 `.xdc`、1 个 `.ucf` 受 Git 跟踪 |
| IP/BD 源 | 57 个 `.xci`、1 个 `.bd` 受 Git 跟踪 |
| 工程描述 | 6 个 `.xpr` 受 Git 跟踪，包括主工程 `AXI_DDR.xpr` |
| 生成目录 | 主工程 `.cache/.gen/.hw/.ip_user_files/.runs/.sim/.tmp` 已由根 `.gitignore` 忽略 |
| 二进制 DCP | 4 个 DCP 仍被跟踪；详见下表 |
| LFS | 此工作站未检测到 Git LFS 命令；当前规模不要求引入 LFS |

## 受跟踪 DCP

| 路径 | 大小（bytes） | 处理建议 |
|---|---:|---|
| `AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565_0.dcp` | 16,313 | 先确认是否能由相邻 `.xci` 和 `user_src` 重建 |
| `AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/OV5640IIC_0.dcp` | 41,458 | 同上 |
| `user_src/MSXBO_OVSensorRGB565_1.0/prj/.../synth_1/MSXBO_OVSensorRGB565.dcp` | 24,710 | 倾向于历史子工程生成物；确认使用方后再处理 |
| `user_src/OV5640_IIC/prj/OV5640_IIC.runs/synth_1/OV5640IIC.dcp` | 41,553 | 倾向于历史子工程生成物；确认使用方后再处理 |

不在本次盘点中删除、忽略或迁移这些文件，以免破坏当前可综合性。

## 当前阻塞项

当前工作树包含未提交的 `AXI_DDR.xpr` 和 `AI-work/LOG.md`，并有未跟踪目录 `AI-work/tmp/`。这些可能来自用户正在使用的 Vivado GUI 或既有调试工作；其归属未确认前，不应执行 pull、merge、reset、clean 或批量忽略规则修改。

## 下一次维护建议

1. 在一个单独的 `chore/git-hygiene` 分支中，逐个验证 4 个 DCP 的可重建性。
2. 若确认为可重建，先在干净 clone 验证移除后工程可生成，再更新 `.gitignore` 和文档；不要直接在当前工作树操作。
3. 若不可重建，保留文件并写入来源、生成工具/IP 版本、SHA-256 与使用模块。
4. 仅在团队确认统一 Windows 文本策略后，才考虑添加 `.gitattributes`；它会影响现有混合换行文件，不能作为即时清理动作。

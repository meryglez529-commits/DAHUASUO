# Rules

> 协作合同。AI 改代码前必须读这份文件。用户改了规则要在 LOG.md 记录。

## 文件改动权限

### 可以直接改

- `AXI_DDR.srcs/sources_1/new/*.v` —— 用户自己写的 RTL
- `AXI_DDR.srcs/sources_1/imports/new/*.v` —— 用户 import 进来的 RTL
- `AXI_DDR.srcs/sim_1/**/*.v` —— testbench
- `AI-work/**` —— 协作工作区，AI 自由写

### 改之前必须先告诉用户、得到口头同意

- `AXI_DDR.srcs/constrs_1/**/*.xdc` —— 约束影响时序、引脚、跨域路径
- `AXI_DDR.srcs/sources_1/ip/**/*.xci` —— IP 配置改动会触发重新综合
- `AXI_DDR.srcs/sources_1/bd/**` —— block design 影响系统结构
- `user_src/**` —— 共享 IP repo（FDMA 等），其他工程也可能在用

### 只读，不允许改

- `AXI_DDR.srcs/sources_1/imports/imports/SGMII_*` —— Xilinx 例程
- `AXI_DDR.srcs/sources_1/imports/ethernet/*` —— Xilinx 例程 + 项目早期遗留
- `AXI_DDR.gen/**`、`AXI_DDR.cache/**`、`AXI_DDR.runs/**`、`AXI_DDR.sim/**` —— Vivado 生成物（已在 `.gitignore`）
- `AXI_DDR.hw/**`、`AXI_DDR.ip_user_files/**`、`AXI_DDR.tmp/**` —— 同上
- `.git/**` —— 版本控制目录

### 文件编码处理

- 工程现存 GBK + UTF-8 混合。**保持每个文件原编码**，不要批量转码。
- AI 新建文件统一用 **UTF-8（无 BOM）+ LF**。
- 若要在 GBK 文件里加中文注释：先告诉用户，按用户偏好处理（转 UTF-8 或者用 ASCII）。

## 闭环刹车

| 触发条件 | 动作 |
|---|---|
| 单次仿真 wall-time 超过 10 分钟 | 停下来报告，等用户决定 |
| 同一个测试失败连续 3 轮 | 停下来分析根因，不再机械改 |
| 单日综合次数超过 4 次 | 暂停综合，转仿真层验证 |
| 触及"必须先问"的文件 | 立即停下来问用户 |
| 触及"只读"的文件 | 拒绝改动，提示用户这是只读 |
| 改动 ≥ 10 个文件的一次 commit | 暂停，问用户是否拆分 |

## Pass/Fail 标准

### 仿真层

- testbench 必须 `$display("PASS")` 或 `$display("FAIL: <reason>")`
- xsim 退出码：0 = pass，非 0 = fail
- 关键信号 csv 导出到 `AI-work/sim_out/sim_result.csv`，与 golden 文件比对（若有）
- 当前焦点 DL1 还没有 golden 文件，第一阶段以"signal 行为符合 testbench assert"为判据

### 综合层

- WNS ≥ 0 ns
- WHS ≥ 0 ns
- 无 critical warning
- 资源占用单项变化 < 5%（不允许悄悄涨）
- DRC 报告无 ERROR

### 上板层

不在闭环范围。AI 写 ILA 探针配置和测试脚本，但 JTAG 下板和真实信号观测由用户执行。

## 代码风格观察（基于现有工程扫描）

- 模块名：snake_case（`adcdata_acq`、`fdma_controller_read`、`parameter_dacdata_gen`）
- 信号名：snake_case，下划线分段
- 注释：以中文为主，Xilinx 例程保持英文
- 缩进：4 空格（混入了部分 Tab，新写文件用 4 空格）
- 模块头：无固定模板，但典型有 `module xxx ( ports ); ... endmodule`
- 复位风格：`rstn`（低有效）和 `rst`（高有效）混用，按模块原约定保留
- 状态机风格：用 `parameter` 定义状态常量 + `always @(posedge clk)` 编码
- 时钟与复位常用 sync 同步链（如 `rstn_r1 <= {rstn_r1[4:0], rstn_r0}`）

## Git 约定

- 主分支：`main`
- 基线 tag：`baseline-pre-cowork`（已建）
- AI 每次有意义的改动用一个 commit，commit message 格式：
  ```
  <短摘要>

  - 改动项 1
  - 改动项 2

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```
- 不 push 到远端（用户手动 push）
- 不动 user.name / user.email 配置

## 用户口头确认

- [x] 用户已阅读本文件
- [x] 用户已确认上述规则
- [x] 确认时间：2026-05-22 15:10
- [x] 后续修改需在 LOG.md 留痕

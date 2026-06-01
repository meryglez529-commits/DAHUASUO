# DL5 UNIT_003 实现进度跟踪

> 架构文档：[ARCHITECTURE.md](ARCHITECTURE.md)
> 需求文档：[REQUIREMENTS.md](REQUIREMENTS.md)

## 实施顺序

- [ ] 1. 改 fifo_generator_4 IP（prog_empty 阈值 20 → 2，重生成 IP）
- [ ] 2. 改 parameter_dacdata_gen.v（State 2 加 laser_mode_en 分支 + s2_write_cnt）
- [ ] 3. RTL elaboration（确认无新增 ERROR / CRITICAL WARNING）
- [ ] 4. 回归仿真：跑 TC1~TC12，预期全 PASS
- [ ] 5. 加 TC13：极限场景验证跨行延迟 < 200ns
- [ ] 6. 综合验证（资源 / 时序）

---

## 1. fifo_generator_4 IP 改动

**状态**：未开始

### 1.1 改动操作

打开 Vivado 工程 → IP Sources → 双击 `fifo_generator_4`：

```
Native Ports & Status Flags 选项卡：
  Programmable Empty Type:    Single Programmable Empty Threshold Constant（不变）
  Empty Threshold Assert Value:  20  →  2
  Empty Threshold Negate Value:  21（IP 自动跟随，不用改）
```

→ OK → Generate Output Products（约 5 分钟）→ Lock IP

### 1.2 影响文件

- `AXI_DDR.gen/sources_1/ip/fifo_generator_4/fifo_generator_4.xml`（参数）
- `AXI_DDR.gen/sources_1/ip/fifo_generator_4/fifo_generator_4_sim_netlist.v`（重新生成）
- `AXI_DDR.gen/sources_1/ip/fifo_generator_4/sim/fifo_generator_4.v`（重新生成）
- `AXI_DDR.srcs/sources_1/ip/fifo_generator_4/fifo_generator_4.xci`（配置）

### 1.3 验证

仿真重跑 TC1~TC12，全 PASS 即认为 IP 改动无副作用。
重点观测：TC11 实测 delay_DAC 从 634ns 降到 ~80~140ns。

### 1.4 回退

把 Empty Threshold Assert Value 改回 20，重生成。git 上保留旧 .xci 作为 fallback。

---

## 2. parameter_dacdata_gen.v 改动

**状态**：未开始

### 2.1 新增寄存器

```verilog
reg [1:0] s2_write_cnt;       // State 2 写次数计数器（激光模式专用）
```

放在文件顶部 reg 声明区，与其它 State 计数器为邻。

### 2.2 复位逻辑

复位块（rstn 拉低或 dac_rstn 拉低分支）增加：
```verilog
s2_write_cnt <= 2'd0;
```

### 2.3 State 2 逻辑改动

**当前 State 2 代码**（[parameter_dacdata_gen.v 大约第 350 行附近](../../../AXI_DDR.srcs/sources_1/new/parameter_dacdata_gen.v)，需看实际行号）：

```verilog
2: begin
    if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
        para_config_wr_en       <= 1'b1;
        adc_tri                 <= 1'b0;
        sync_pixel_tri1          <= 1'b0;
        sync_pixel_tri2          <= 1'b0;
        DAX_DATA                <= dax_level[63:48];
        DAY_DATA                <= day_level[63:48];
        if(dacx_tb_point_cnt < dacx_tb_point - 1) begin
            dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
        end
        else begin
            dacx_tb_point_cnt   <= 0;
            if (laser_mode_en) current_state <= 14;
            else               current_state <= 3;
        end
    end
    else
        para_config_wr_en       <= 1'b0;
end
```

**改动后**：

```verilog
2: begin
    if (laser_mode_en) begin
        // ────────── 激光模式：只写 2 次 + 纯排空 ──────────
        if (s2_write_cnt < 2'd2 && para_config_prog_full == 0
            && para_config_wr_rst_busy == 0) begin
            para_config_wr_en   <= 1'b1;
            adc_tri             <= 1'b0;
            sync_pixel_tri1      <= 1'b0;
            sync_pixel_tri2      <= 1'b0;
            DAX_DATA            <= dax_level[63:48];
            DAY_DATA            <= day_level[63:48];
            s2_write_cnt        <= s2_write_cnt + 1'b1;
        end else begin
            para_config_wr_en   <= 1'b0;
        end
        // 计时器仍跑满 dacx_tb_point 拍（行间隔不变）
        if (dacx_tb_point_cnt < dacx_tb_point - 1) begin
            dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
        end else begin
            dacx_tb_point_cnt   <= 0;
            s2_write_cnt        <= 2'd0;
            current_state       <= 14;
        end
    end else begin
        // ────────── 普通模式：原行为不变 ──────────
        if (para_config_prog_full == 0 && para_config_wr_rst_busy == 0) begin
            para_config_wr_en   <= 1'b1;
            adc_tri             <= 1'b0;
            sync_pixel_tri1      <= 1'b0;
            sync_pixel_tri2      <= 1'b0;
            DAX_DATA            <= dax_level[63:48];
            DAY_DATA            <= day_level[63:48];
            if (dacx_tb_point_cnt < dacx_tb_point - 1) begin
                dacx_tb_point_cnt <= dacx_tb_point_cnt + 1'b1;
            end else begin
                dacx_tb_point_cnt <= 0;
                current_state     <= 3;
            end
        end else begin
            para_config_wr_en   <= 1'b0;
        end
    end
end
```

### 2.4 关键设计点

- **激光模式 / 普通模式分支彻底分开**：避免一个分支的写逻辑影响另一个
- **激光模式下 dacx_tb_point_cnt 始终自增**：不依赖 prog_full 反压（因为大部分时间不写 word，反压不会触发）
- **s2_write_cnt 在状态退出时复位**：保证下次进 State 2 重新计数
- **dax_level、day_level 在 State 2 不变**：行起点 DAX/DAY 已在 State 1 设好

### 2.5 default 分支

State 2 不命中时（其它状态），保持 `para_config_wr_en <= 1'b0`，s2_write_cnt 保持不变（其它状态写时 s2_write_cnt 不会被读到，无副作用）。

---

## 3. RTL elaboration

**状态**：未开始

**执行命令**：
```bash
vivado -mode batch -source AI-work/scripts/dl5_elab.tcl -tclargs AXI_DDR.xpr
```

**预期**：
- ERROR = 0
- CRITICAL WARNING = 0（除 UNIT_002 已知遗留的 Project 1-19）
- 资源增量：1 个 2-bit 寄存器（s2_write_cnt），可忽略

---

## 4. 回归仿真：TC1~TC12

**状态**：未开始

### 4.1 预期变化

| TC | 改动前 | 改动后 | 备注 |
|---|---|---|---|
| TC1（普通模式回归） | PASS | PASS | 普通模式 State 2 行为不变 |
| TC2（激光基本流程） | PASS | PASS | 状态机切换正确 |
| TC3（scan_delay 倒计时） | PASS | PASS | State 15 不受影响 |
| TC4（acq 时序） | PASS | PASS | acq 走独立路径，不变 |
| TC5（blanker 时序） | PASS | PASS | blanker 走独立路径，不变 |
| TC6（State 14 门控） | PASS | PASS | toggle 逻辑不变 |
| TC7（mode 切换复位） | PASS | PASS | s2_write_cnt 也要在 mode 切换时复位 |
| TC8（acq 触发独立性） | PASS, delay 76ns | PASS, delay 不变 | 不依赖 FIFO |
| TC9（FIFO drain time） | drain 1128ns | **drain 显著缩短** | State 2 改后 FIFO 净减 |
| TC10（per-pixel DAX） | PASS | PASS | DAX 序列不变 |
| TC11（DAC vs ACQ 路径独立） | delay_DAC=634ns | **delay_DAC ≈ 80~120ns** ✅ | 主要观察点 |
| TC12（行末跨行 DAX） | next-line PASS, drain 3200ns | **drain ≈ 100ns**, DAX 不变 | 主要观察点 |

### 4.2 失败排查路径

1. 如果 TC1（普通模式）失败 → 普通模式分支被错误改动，回查 State 2 普通模式代码
2. 如果 TC10 失败（DAX 序列错） → 查 s2_write_cnt 是否影响了 dax_level 装载逻辑
3. 如果 TC11 仍 ~542ns → IP 改动未生效，检查重新综合
4. 如果 TC12 跨行 DAX ≠ dacx_strat → State 13 末尾 dax_level 截断误差，但 State 2 写的 2 个 word 应当修正；如不修正，需检查 State 1 是否在 dax_level 上重新装载 dacx_strat_level

---

## 5. 新增 TC13：极限场景跨行延迟

**状态**：未设计

### 5.1 测试目标

验证最差场景下跨行延迟 ≤ 200ns。

### 5.2 测试配置

```verilog
laser_mode_en       = 1'b1;
scan_delay_time     = 16'd5;
acq_data_delay_time = 16'd2;
acq_time            = 16'd5;
dac_sample          = 32'd30;
dacx_tk_point       = 16'd3;
dax_fall_time       = 32'd5;       // 5 µs ramp，250 word（极限）
dacx_recovery_time  = 16'd5;       // 5 µs Tb，原写 250 word（激光模式只写 2 个）
image_row           = 16'd2;
laser_period        = 2000;        // 2µs，最快激光周期
```

### 5.3 测试流程

1. 走完第 1 行（3 个 laser 像素）
2. 进入 State 13（行末斜坡）
3. 经 State 5/6/.../1 → State 2（间歇写 2 次）→ State 14
4. State 14 等到下一个 laser
5. 测从 inject_laser → DAX_DATA 切到下一行 dacx_strat 的延迟
6. 验证 DAX 切换的目标值正确

### 5.4 通过判据

- `delay_DAC < 200ns`（PASS 阈值）
- `delay_ACQ ≈ 77ns`（不变，acq 路径独立）
- 下一行第 1 个像素 DAX_DATA == 下一行 dacx_strat 值
- 没有意外的 DAX 跳变或残留

---

## 6. 综合验证

**状态**：未开始

**检查项**：
- [ ] WNS（Worst Negative Slack）≥ 0，所有时钟域
- [ ] LUT 增量 < 0.1%（4 个寄存器影响微小）
- [ ] 无 latch 推断
- [ ] FIFO IP 重新生成后，timing 不退化
- [ ] s2_write_cnt 不被识别为 latch（确保 always 块覆盖所有 state）

---

## 7. 待确认决议（已结清）

| 编号 | 问题 | 决议 | 决议日期 |
|---|---|---|---|
| Q1 | State 13 改动方式 | **不改 State 13**，靠 State 2 改动消化积压 | 2026-06-01 |
| Q2 | State 2 写几次 | **写 2 次**（DAC 驱动余量 + 修正截断误差） | 2026-06-01 |
| Q3 | 普通模式是否同样改动 | **不改**，普通模式 State 2 行为零变化 | 2026-06-01 |
| Q4 | 是否改 prog_empty 阈值 | **改 20 → 2**（IP 允许的最小值） | 2026-06-01 |

---

## 8. 变更记录

| 日期 | 模块 | 变更内容 | 负责人 |
|---|---|---|---|
| 2026-06-01 | — | 创建 DL5_UNIT_003 文档（初版方案 A+C3） | Claude |
| 2026-06-01 | — | 方案改为 A + State 2 写 2 次（用户提议） | Claude |

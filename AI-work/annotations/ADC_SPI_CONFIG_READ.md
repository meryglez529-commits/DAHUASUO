
# ADC 芯片 SPI 配置精读

## 0. 概述

本项目使用两颗芯片完成 ADC 时钟和数据采集：

| 芯片 | 型号 | 数量 | 作用 |
|---|---|---|---|
| 时钟分配 | AD9517-3 | 1 片 | PLL 锁相 + 多路分频，为 ADC/DAC 提供采样时钟 |
| ADC | AD9258 | 2 片 | 双通道 14-bit 50 MSPS ADC，共 4 路模拟输入 |

配置方式都是 FPGA 上电后通过 SPI 写寄存器，时钟源为 `clk10m` (10 MHz)。

```
FPGA (clk10m)
  │
  ├── SPI → AD9517 (时钟芯片)
  │           ├── OUT0: 125 MHz LVPECL (未用/备用)
  │           ├── OUT2: 125 MHz LVPECL (未用/备用)
  │           ├── OUT4: 50 MHz LVDS → ADC1 采样时钟
  │           ├── OUT5: 50 MHz LVDS → ADC2 采样时钟
  │           ├── OUT6: 50 MHz LVDS → DAC 采样时钟
  │           └── OUT7: 50 MHz CMOS → dac_dco 反馈
  │
  ├── SPI → AD9258 #1 (ADC 通道 1+2)
  │           ├── Channel A → adc1_da[15:0]
  │           └── Channel B → adc1_db[15:0]
  │
  └── SPI → AD9258 #2 (ADC 通道 3+4)
              ├── Channel A → adc2_da[15:0]
              └── Channel B → adc2_db[15:0]
```

---

## 1. AD9517 时钟芯片配置

**文件**：`AXI_DDR.srcs/sources_1/new/ad9517_cfg.v`

### 1.1 PLL 频率计算

从 SPI 寄存器值推导：

```
参考时钟 REF = 50 MHz（来自 FPGA clk50m 或外部 50 MHz，由 clk_sel 选择）

PLL 参数（ad9517_cfg.v:40-43）：
  R = 16        (0x0011 = 0x10)
  B = 15        (0x0014 = 0x0F)
  A = 0         (0x0013 = 0x00)
  P = 32        (0x0016 = 0x06，对应 prescaler = 32)

N = P × B + A = 32 × 15 + 0 = 480

VCO 频率 = REF × N / R = 50 × 480 / 16 = 1500 MHz
```

VCO 分频器（ad9517_cfg.v:60）：
```
0x01E0 = 0x01 → VCO divider = 3（编码：0x00=2, 0x01=3, 0x02=4...）
VCO / 3 = 1500 / 3 = 500 MHz → 送入通道分频器
```

### 1.2 输出通道分频

| 通道 | 寄存器 | 分频值 | 输出频率 | 输出类型 | 用途 |
|---|---|---|---|---|---|
| Divide0 → OUT0/1 | 0x0190=0x11 | (1+1)+(1+1)=4 | 500/4 = **125 MHz** | OUT0: LVPECL on, OUT1: off | 备用/SGMII 参考 |
| Divide1 → OUT2/3 | 0x0196=0x11 | 4 | 500/4 = **125 MHz** | OUT2: LVPECL on, OUT3: off | 备用 |
| Divide2 → OUT4/5 | 0x0199=0x44 | (4+1)+(4+1)=10 | 500/10 = **50 MHz** | LVDS (0x42) | ADC 采样时钟 |
| Divide3 → OUT6/7 | 0x019E=0x44 | 10 | 500/10 = **50 MHz** | OUT6: LVDS, OUT7: CMOS | DAC 时钟 |

### 1.3 输出使能状态

| 输出 | 寄存器 | 值 | 状态 | 接口类型 |
|---|---|---|---|---|
| OUT0 | 0x00F0 | 0x08 | **开启** | LVPECL |
| OUT1 | 0x00F1 | 0x0B | 关闭 | — |
| OUT2 | 0x00F4 | 0x08 | **开启** | LVPECL |
| OUT3 | 0x00F5 | 0x0B | 关闭 | — |
| OUT4 | 0x0140 | 0x42 | **开启** | LVDS 3.5 mA |
| OUT5 | 0x0141 | 0x42 | **开启** | LVDS 3.5 mA |
| OUT6 | 0x0142 | 0x42 | **开启** | LVDS 3.5 mA |
| OUT7 | 0x0143 | 0x4A | **开启** | CMOS (OUTB 关闭) |

### 1.4 参考时钟选择（ad9517_cfg.v:44-45, 80）

```verilog
wrrom9A = {..., 13'h001C, 8'h02, ...};  // REF1 (FPGA_50M)
wrrom9B = {..., 13'h001C, 8'h44, ...};  // REF2 (外部 50 MHz)
assign wrrom9 = (clk_sel_reg[2]) ? wrrom9B : wrrom9A;
```

`clk_sel` 信号决定使用哪个参考源。切换时会重新执行整个配置序列（cntr 归零）。

### 1.5 SPI 时序机制

```
clk10m = 10 MHz → SPI SCLK = ~clk10m（反相，即 10 MHz）
每 32 个 clk10m 周期发送一帧 SPI 数据（cntr[4:0] 计数 0-31）
cntr[10:5] 选择第几条命令（共 34 条）
总配置时间 ≈ 34 × 32 / 10 MHz ≈ 109 µs
```

### 1.6 总结：AD9517 产生的时钟

```
50 MHz REF → PLL → 1500 MHz VCO → /3 → 500 MHz
                                         ├── /4  → 125 MHz (OUT0, OUT2) — LVPECL
                                         ├── /10 → 50 MHz  (OUT4, OUT5) — LVDS → ADC
                                         └── /10 → 50 MHz  (OUT6, OUT7) — LVDS/CMOS → DAC
```

---

## 2. AD9258 ADC 芯片配置

**文件**：
- `AXI_DDR.srcs/sources_1/new/ad9258_cfg.v` — 顶层，例化两片 ADC 的配置
- `AXI_DDR.srcs/sources_1/new/ad9258_config.v` — 单片 AD9258 的 SPI 配置逻辑

### 2.1 上电时序（ad9258_config.v:72-91）

```
t = 0        : rstn 释放
t = 0.1 µs   : adc_pwdn = 0（释放硬件 power-down）
t = 2 ms     : adc_oeb = 0（使能数据输出）
t = 3 ms     : adc_dea = adc_deb = 1（使能两通道数据）
t > 3.2 ms   : 开始 SPI 配置
```

**关键**：硬件引脚先释放，等芯片内部稳定后才开始 SPI 写寄存器。`delay_cnt` 用 bit[15] 作为"延时完成"标志（约 3.2 ms @ 10 MHz）。

### 2.2 SPI 寄存器配置表

| 步骤 | 地址 | 值 | AD9258 寄存器含义 | 说明 |
|---|---|---|---|---|
| 1 | 0x0000 | 0x3C | SPI Port Config | **软复位** (bit 5=1) + MSB first |
| 2 (500) | 0x0000 | 0x18 | SPI Port Config | 清除软复位，MSB first，SDO active |
| 3 (501) | 0x0005 | 0x03 | Channel Index | **使能通道 A+B**（bit 0=A, bit 1=B） |
| 4 (502) | 0x0008 | 0x80 | Power Mode | 外部 PWDN 引脚控制，内部正常工作 |
| 5 (503) | 0x000B | 0x00 | Clock | DCO 正常输出（不反相、不关闭） |
| 6 (504) | 0x0014 | 0x80 | Output Mode | **Offset Binary 格式** (bit 7=1) |
| 7 (505) | 0x0014 | 0x80 | Output Mode | 重复写（原本是 0x0018 VREF，已注释掉） |
| 8 (506) | 0x00FF | 0x01 | Transfer | 更新寄存器（使前面的写入生效） |
| 9 (507) | 0x0005 | 0x01 | Channel Index | 只选通道 A |
| 10 (508) | 0x0010 | offset_adcA | Offset Adjust | **通道 A 偏置校正**（来自上位机） |
| 11 (509) | 0x00FF | 0x01 | Transfer | 更新 |
| 12 (510) | 0x0005 | 0x02 | Channel Index | 只选通道 B |
| 13 (511) | 0x0010 | offset_adcB | Offset Adjust | **通道 B 偏置校正**（来自上位机） |
| 14 (512) | 0x00FF | 0x01 | Transfer | 更新 |

### 2.3 关键配置解读

**数据格式 = Offset Binary**（0x0014 = 0x80）：
- 输出范围 0x0000 ~ 0x3FFF（14-bit）
- 中间值 0x2000 对应模拟 0V
- 顶层取 `[15:2]` 后变成 14-bit 直接使用
- 注释提到"20220902 改为 0x80 为了兼容 AD9251"

**偏置校正**（0x0010 = offset_adcX）：
- 每个通道可以独立设置 8-bit 偏置补偿
- `offset_adc1~4` 来自 `command_monitor_new` 的寄存器（通过 `fram_cfg` 保存到 FRAM）
- 这是**硬件级**的 DC offset 校正，在 ADC 内部完成

**DCO 输出**（0x000B = 0x00）：
- DCO = Data Clock Output，ADC 随数据一起输出的同步时钟
- 0x00 = 正常模式（不反相、不关闭）
- 这个 DCO 就是 FPGA 端的 `adc1_dcoa/b`、`adc2_dcoa/b`

**步骤 505 的修改**：
- 原本应该写 wrrom7（0x0018 = 0xC0，VREF 选择）
- 2022-09-02 改为重复写 wrrom6（0x0014 = 0x80）
- 注释说"为了兼容 AD9251"，可能是换了 ADC 型号后 VREF 寄存器地址/含义不同

### 2.4 SPI 时序机制

```
clk10m = 10 MHz → SPI SCLK = ~clk10m
每 32 个 clk10m 周期发送一帧（cntr[4:0] 计数）
cntr[14:5] 选择命令编号

特殊时序：
  - 命令 1 (soft reset) 在 cntr[14:5]=1 时发送
  - 命令 2~14 在 cntr[14:5]=500~512 时发送
  - 中间 499 个空周期 ≈ 499 × 32 / 10 MHz ≈ 1.6 ms（等待软复位完成）
```

### 2.5 两片 ADC 的例化（ad9258_cfg.v:44-69）

```verilog
ad9258_config num1_ad9258_config(  // ADC 芯片 1
    .offset_adcA(offset_adc1),     // 通道 1 偏置
    .offset_adcB(offset_adc2)      // 通道 2 偏置
);
ad9258_config num2_ad9258_config(  // ADC 芯片 2
    .offset_adcA(offset_adc3),     // 通道 3 偏置
    .offset_adcB(offset_adc4)      // 通道 4 偏置
);
```

两片 ADC 配置完全相同，只是偏置值不同。配置并行执行（各自独立的 SPI 总线）。

---

## 3. 顶层例化关系（ETH_TOP.v）

### 3.1 AD9517 例化（ETH_TOP.v:266-291）

```verilog
ad9517_cfg U0(
    .clk10m     (clk10m),       // 10 MHz SPI 时钟
    .rstn       (locked),       // PLL locked 后才开始配置
    .clk_sel    (clk_sel),      // 参考时钟选择（来自 command_monitor_new）
    .pll_ld     (pll_ld),       // PLL lock detect（输入，未使用）
    .pll_sdo    (pll_sdo),      // SPI 读数据（输入，未使用）
    .pll_csn    (pll_csn),      // SPI 片选
    .pll_sclk   (pll_sclk),    // SPI 时钟
    .pll_sdio   (pll_sdio),    // SPI 数据
    .pll_ref_sel(pll_ref_sel), // 硬件参考选择引脚 = 0
    .pll_resetn (pll_resetn)   // 硬件复位引脚 = 1（不复位）
);
```

### 3.2 AD9258 例化（ETH_TOP.v:295-）

```verilog
ad9258_cfg U2(
    .clk10m     (clk10m),
    .rstn       (locked),
    .adc1_*     (...),          // ADC 芯片 1 的 SPI + 控制引脚
    .adc2_*     (...),          // ADC 芯片 2 的 SPI + 控制引脚
    .offset_adc1(offset_adc1),  // 4 路偏置值，来自 fram_cfg
    .offset_adc2(offset_adc2),
    .offset_adc3(offset_adc3),
    .offset_adc4(offset_adc4)
);
```

### 3.3 配置触发条件

两个芯片都用 `locked` 信号作为 `rstn`：
- `locked` = `sysclk` PLL 的锁定信号
- PLL 锁定后才释放复位，开始 SPI 配置
- 配置顺序：先 AD9517（产生时钟），再 AD9258（需要时钟才能工作）
- 实际上两者并行启动，但 AD9258 有 3.2 ms 延时，此时 AD9517 早已配置完毕（~109 µs）

---

## 4. 完整时钟链路验证

```
板级 100 MHz sys_clk
    ↓ (FPGA 内部 PLL: sysclk IP)
    ├── clk200m (200 MHz) → MIG → ui_clk
    ├── clk10m  (10 MHz)  → AD9517 SPI / AD9258 SPI
    └── clk50m  (50 MHz)  → AD9517 REF1 输入 (当 clk_sel=0)
                                ↓ (AD9517 PLL)
                            1500 MHz VCO → /3 = 500 MHz
                                ├── /4 = 125 MHz (OUT0/2, LVPECL, 备用)
                                ├── /10 = 50 MHz (OUT4/5, LVDS) → ADC 采样时钟
                                └── /10 = 50 MHz (OUT6/7, LVDS/CMOS) → DAC 时钟
                                            ↓
                            AD9258 以 50 MHz 采样，DCO = 50 MHz 输出
                                            ↓
                            FPGA 接收 adc*_dco* + adc*_d*[15:0]
```

**关键结论**：ADC 采样率 = **50 MSPS**，由 AD9517 的 OUT4/OUT5 提供。

---

## 5. 偏置校正数据流

```
上位机 → 以太网 → command_monitor_new (寄存器 0x0010~0x0012)
    ↓
offset_adc1~4 (各 8-bit)
    ↓
├── ad9258_cfg → SPI 写入 AD9258 的 0x0010 寄存器（硬件级 DC offset）
└── fram_cfg → 保存到 FRAM（掉电不丢失）
```

偏置值在两个地方生效：
1. **AD9258 内部**：芯片硬件直接补偿 DC 偏移
2. **FRAM 保存**：下次上电时从 FRAM 读回，重新写入 ADC

---

## 6. 注意事项和风险

| 问题 | 说明 | 影响 |
|---|---|---|
| wrrom7 被注释掉 | 0x0018 (VREF) 寄存器未配置，使用芯片默认值 | 如果板级 VREF 不是默认值可能影响量程 |
| AD9251 兼容修改 | 2022-09-02 把 wrrom7 改成重复写 wrrom6 | 说明可能有板子用了 AD9251 替代 AD9258 |
| 偏置值运行时可改 | `offset_adcX` 是 wire，但 SPI 只在上电时写一次 | 运行时改偏置寄存器不会立即生效，需要重新触发配置 |
| clk_sel 切换会重配 AD9517 | `clk_sel_reg[2] != clk_sel_reg[1]` 时 cntr 归零 | 切换参考时钟会导致所有输出时钟短暂中断 |
| 125 MHz 输出用途不明 | OUT0/OUT2 开启但未在 RTL 中明确标注去向 | 可能接到 SGMII 的 gtrefclk，需要看原理图确认 |

---

## 7. 证据索引

| 证据 | 文件位置 |
|---|---|
| AD9517 PLL 参数 (R/B/A/P) | `ad9517_cfg.v:40-43` |
| VCO = 1500 MHz, divider = 3 | `ad9517_cfg.v:60-61` |
| 通道分频 125/50 MHz | `ad9517_cfg.v:63-71` |
| 输出类型 LVDS/CMOS | `ad9517_cfg.v:51-54` |
| 参考时钟选择 | `ad9517_cfg.v:44-45, 80` |
| AD9258 软复位 | `ad9258_config.v:35` |
| 数据格式 Offset Binary | `ad9258_config.v:40` |
| 偏置校正写入 | `ad9258_config.v:44-50` |
| 上电时序 | `ad9258_config.v:72-91` |
| 两片 ADC 例化 | `ad9258_cfg.v:44-69` |
| 顶层 AD9517 例化 | `ETH_TOP.v:266-291` |
| 顶层 AD9258 例化 | `ETH_TOP.v:295` |


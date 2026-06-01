# Vivado 仿真 SOP（标准操作规程）

> 适用范围：当前工程环境（Vivado 2021.1 + E-SafeNet 加密 init.tcl）下，跑包含 IP 的复杂 testbench
>
> 验证日期：2026-05-29，DL5_UNIT_002 集成 testbench 7/7 PASS

## 1. 环境的特殊性

本工程环境有三个会影响仿真的特点：

1. **`D:\Xilinx\Vivado\2021.1\tps\tcl\tcl8.5\init.tcl` 被 E-SafeNet 加密**
   - Vivado 主进程能正常解密读取
   - 但单独调用 `xsim.exe` 的子进程读不了，会报 `missing close-bracket`
2. **工程路径较长**（90+ 字符）
   - Vivado batch 模式下 `launch_simulation` 调用 compile.bat 时容易报 `Spawn failed: Broken pipe`
3. **GUI 模式 `launch_simulation` 会被 `wbtcv.exe`（Webtalk 客户端）卡死**
   - xelab build 完 snapshot 后会 fork `wbtcv.exe` 上报匿名使用统计
   - 公司网络（aTrust 零信任）封锁 Xilinx Webtalk endpoint，wbtcv 死等不返回
   - wbtcv 持有 elaborate.log 句柄，xelab 等 wbtcv 退出，整条调用链卡几小时
   - 通过 RestartManager API 实锤定位：locker = `wbtcv.exe`
   - **修复（已生效）**：把 `D:\Xilinx\Vivado\2021.1\bin\unwrapped\win64.o\wbtcv.exe` 改名为 `wbtcv.exe.bak`
   - xelab 找不到 wbtcv 会打印 `ERROR: wbtcv.exe does not exist` 然后**继续往下走**（非致命错误）
   - 副作用：webtalk 数据上报被禁用（这环境本来也上报不出去，无影响）
   - **风险**：Vivado 升级或重装会恢复 wbtcv.exe，需要重新改名

## 2. 三条仿真路径的可行性

| 路径 | 可行 | 说明 |
|---|---|---|
| Vivado batch + `launch_simulation` | ❌ | Broken pipe |
| 命令行单独跑 `xvlog`/`xelab`/`xsim` | ❌ | xsim 读不了加密 init.tcl |
| Vivado batch + tcl 内部 `exec xvlog/xelab` + 内置 `xsim` 命令 | ✅ | **batch 模式唯一可用路径** |
| Vivado GUI + `launch_simulation` | ✅ | 看波形用，**前提：wbtcv.exe 已改名**（见 §1.3） |

## 3. SOP：Batch 模式跑仿真（推荐）

### 3.1 前置条件

- testbench `.v` 文件已写好并放在 `AXI_DDR.srcs/sim_1/new/`
- `dacdata_config` 之类涉及 IP 的 DUT，IP 在工程里已经例化好

### 3.2 写 testbench

要点：
- module 名字和 file 名字要一致（如 `tb_xxx`）
- 用一个 `reg [31:0] errors` 计数器累计错误
- 每个 TC 末尾根据 errors 是否增加打印 PASS/FAIL
- 最后 `$display("PASS")` 或 `$display("FAIL: ...")` 给 grep 用
- 加 `$finish` 结束仿真
- 加全局超时保护（`#20000000; $finish;`）

模板见 [tb_dl5_unit_002.v](../AXI_DDR.srcs/sim_1/new/tb_dl5_unit_002.v)。

### 3.3 写 run_manual.tcl

文件位置：`AI-work/features/<unit>/sim/run_manual.tcl`

核心结构（去掉错误处理后的精简版）：

```tcl
# 打开工程
open_project AXI_DDR.xpr

# 把 testbench 加到 sim_1
set simset [get_filesets sim_1]
add_files -fileset $simset AXI_DDR.srcs/sim_1/new/tb_xxx.v
set_property top tb_xxx $simset
set_property top_lib xil_defaultlib $simset
update_compile_order -fileset sim_1

# 生成 IP 仿真目标
foreach ip [get_ips -quiet] {
    generate_target Simulation $ip -quiet
}

# 切到 sim 目录
set sim_dir AXI_DDR.sim/sim_1/behav/xsim
cd $sim_dir

# 写 prj 文件，列出所有需要编译的 verilog 源文件
# 关键：IP 的 sim_netlist.v / sim/.v 都要列出来
set fp [open dl5_unit002.prj w]
puts $fp "verilog xil_defaultlib \"path/to/ip/sim_netlist.v\""
puts $fp "verilog xil_defaultlib \"path/to/rtl.v\""
puts $fp "verilog xil_defaultlib \"path/to/tb.v\""
puts $fp "verilog xil_defaultlib \"glbl.v\""
puts $fp "nosort"
close $fp

# Step 1: xvlog （exec 外部进程，OK）
set vivado_bin [file dirname [info nameofexecutable]]
exec [file join $vivado_bin xvlog] --relax -prj dl5_unit002.prj -log xvlog.log

# 检查 xvlog.log 里有没有 ERROR
set log_content [read [open xvlog.log r]]
if {[string match "*ERROR*" $log_content]} { exit 1 }

# Step 2: xelab （exec 外部进程，OK）
exec [file join $vivado_bin xelab] --debug typical --relax --mt 2 \
    -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -L xpm \
    -L fifo_generator_v13_2_5 \
    --snapshot tb_xxx_behav xil_defaultlib.tb_xxx xil_defaultlib.glbl \
    -log xelab.log

# 检查 snapshot 是否生成
set log_content [read [open xelab.log r]]
if {![string match "*Built simulation snapshot*" $log_content]} { exit 1 }

# Step 3: xsim （用 Vivado 内置 tcl 命令，绕开 init.tcl 加密！）
xsim tb_xxx_behav -log xsim.log
run all
```

### 3.4 三个关键陷阱

**陷阱 1：xelab 用 exec 时返回码会误判**

xelab 把进度信息输出到 stderr，Tcl 的 `exec` 会把 stderr 视为错误。**不能用 `if {[catch {exec xelab ...}]}` 判断**。

正确做法：
```tcl
catch {exec [file join $vivado_bin xelab] ...}
# 通过日志内容判断成功
set log [read [open xelab.log r]]
if {![string match "*Built simulation snapshot*" $log]} { exit 1 }
```

**陷阱 2：xsim 必须用 Vivado 内置命令**

```tcl
# ❌ 错误：会报 init.tcl missing close-bracket
exec [file join $vivado_bin xsim] tb_xxx_behav -tclbatch ...

# ✅ 正确：用内置 tcl 命令，继承 Vivado 主进程的 Tcl 环境
xsim tb_xxx_behav -log xsim.log
run all
```

**陷阱 3：IP 的 sim 文件需要手动列出**

`launch_simulation` 在当前环境失败，所以 Vivado 不会自动生成 prj 文件。需要手动列出：

| IP 类型 | 文件位置 |
|---|---|
| FIFO Generator | `AXI_DDR.gen/sources_1/ip/<ip_name>/sim/<ip_name>.v` |
| ILA / VIO | `AXI_DDR.gen/sources_1/ip/<ip_name>/sim/<ip_name>.v` |
| Divider Generator | `AXI_DDR.gen/sources_1/ip/<ip_name>/<ip_name>_sim_netlist.v` |

如果 sim 文件不存在，先在 Vivado 里 `generate_target Simulation [get_ips ip_name]`。

### 3.5 跑仿真

```powershell
cd D:\path\to\fpga_prj
& "D:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch `
    -source AI-work/features/<unit>/sim/run_manual.tcl
```

预期 3-5 分钟跑完。

### 3.6 检查结果

```powershell
# 看每个 TC 是否 PASS
Select-String -Path vivado.log -Pattern "TC\d.*PASS|TC\d.*FAIL|errors ="

# 或者直接看 result.txt（脚本最后写）
Get-Content AI-work/features/<unit>/out/sim/result.txt
```

## 4. SOP：GUI 模式跑仿真（看波形用）

### 4.1 前置：Tcl Console 的工作目录

GUI 模式下，Tcl Console 默认的 `pwd` **不一定**是工程根目录。先确认：

```tcl
pwd
```

如果不在工程根目录，先切过去：

```tcl
cd D:/SGSC_SEM_dahuasuo_325T_V3_172/.../fpga_prj
```

注意 Tcl 用正斜杠 `/`，不是反斜杠。

### 4.2 source 脚本

```tcl
source AI-work/features/<unit>/sim/run_gui.tcl
```

或者用绝对路径直接 source（不用先 cd）：

```tcl
source D:/SGSC_SEM_dahuasuo_325T_V3_172/.../fpga_prj/AI-work/features/<unit>/sim/run_gui.tcl
```

### 4.3 GUI 模式下的 launch_simulation 没问题

GUI 模式下 `launch_simulation` 不会触发 Broken pipe（因为它的进程模型不一样），所以 `run_gui.tcl` 直接用 `launch_simulation` 即可。

### 4.4 看波形

仿真跑完后，Waveform Viewer 自动打开。常用信号：

```
/tb_xxx/DUT/...        - DUT 内部信号
/tb_xxx/<port>          - DUT 端口
/tb_xxx/dut_state       - 探针 wire（如果 tb 里声明了）
```

## 5. 常见问题速查

| 报错 | 根因 | 解决 |
|---|---|---|
| `couldn't read file ... no such file or directory` | Tcl Console 工作目录不对 | `cd` 到工程根目录，或用绝对路径 |
| `ambiguous command name "tcl"` | 误把 `tcl` 当作命令前缀 | `source` 命令前不要加 `tcl` 关键字 |
| `Spawn failed: Broken pipe` | 用了 `launch_simulation`（batch 模式有 bug） | 改用 `run_manual.tcl` |
| `init.tcl: missing close-bracket` | 单独调 `xsim.exe`/`xelab.exe`（吃不到 Vivado 的解密 Tcl） | 用 `run_manual.tcl` 里的 Vivado 内置 `xsim` 命令 |
| `Module <ip_name> not found` | IP 的 sim 文件没生成或没列入 prj | 先 `generate_target Simulation [get_ips]`，再确认 prj 包含 IP sim 文件 |
| xelab 看似失败但其实成功 | exec 把 stderr 误判为错误 | 用日志内容（`Built simulation snapshot`）判断 |
| `wait_state timeout` | 状态机卡住或 RTL 改错 | 加载 wdb 看波形定位 |
| 仿真 `$finish` 后立即退出 | 正常行为 | 看 `$display` 输出确认结果 |
| GUI launch_simulation 卡在 elaborate（xelab 不退出，elaborate.log 被锁） | xelab fork `wbtcv.exe` 上报 webtalk，公司网络封锁让它死等 | 把 `D:\Xilinx\Vivado\2021.1\bin\unwrapped\win64.o\wbtcv.exe` 改名为 `.bak`（见 §1.3） |
| `ERROR: [XSIM 43-3984] Multiple occurrences of option ---mt is not allowed` | simset property `xsim.elaborate.xelab.more_options` 被污染（含 `-mt off`） | Tcl Console 执行 `set_property xsim.elaborate.xelab.more_options "" [get_filesets sim_1]` 清空 |

## 6. 下次复用本 SOP 的清单

跑新的仿真前确认：

- [ ] testbench 文件已加到 `AXI_DDR.srcs/sim_1/new/`
- [ ] 复制 [run_manual.tcl](../features/DL5_laser_sync/DL5_UNIT_002/sim/run_manual.tcl) 到新 unit 的 sim 目录
- [ ] 修改 prj 文件里列的 IP sim 文件（按新 DUT 实际依赖）
- [ ] 修改 xelab 的 snapshot 名字和 top module 名字
- [ ] 修改 xelab 的 `-L` 库列表（按 IP 类型，常见的：`fifo_generator_v13_2_5`、`blk_mem_gen_v8_4_4` 等）

## 7. 验证记录

| 日期 | Unit | testbench | 结果 |
|---|---|---|---|
| 2026-05-29 | DL5_UNIT_002 | tb_dl5_unit_002.v (7 用例) | 7/7 PASS |

# DL5_UNIT_004 回归仿真：激光模式 ADC 采集点数独立控制（TC1~TC15）
# 在 Vivado tcl 内部直接调用 xvlog/xelab/xsim
#
# 用法：vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/run_regression.tcl

set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set sim_dir [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/regression"]

file mkdir $out_dir
file mkdir $sim_dir

open_project $xpr

# 确保 tb 在 sim_1 里
set simset [get_filesets sim_1]
set tb_file [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_004" "sim" "tb_dl5_unit_004_regression.v"]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_004_regression.v]
if {$existing_tb eq ""} {
    add_files -fileset sim_1 $tb_file
}
set_property top tb_dl5_unit_004_regression $simset
set_property top_lib xil_defaultlib $simset
set_property target_simulator XSim [current_project]
update_compile_order -fileset sim_1

# 生成 IP 仿真目标
puts "INFO: generating IP simulation targets..."
foreach ip [get_ips -quiet] {
    generate_target Simulation $ip -quiet
}

# 获取 Vivado 安装路径
set vivado_bin [file dirname [info nameofexecutable]]
set xvlog_exe [file join $vivado_bin "xvlog"]
set xelab_exe [file join $vivado_bin "xelab"]
set xsim_exe  [file join $vivado_bin "xsim"]

puts "INFO: vivado_bin = $vivado_bin"

# 切到 sim 目录
set orig_dir [pwd]
cd $sim_dir
set result_marker [file join $sim_dir "dl5_unit004_regression_result.txt"]
file delete -force $result_marker

# 收集所有需要编译的 verilog 文件（基于 sim_run.log 的成功源文件列表）
set src_files [list]

# IP sim 文件（adcdata_acq 依赖的 IP）
foreach ip_info {
    {div_gen_0 div_gen_0_sim_netlist.v}
    {fifo_generator_1 sim/fifo_generator_1.v}
    {ila_12 sim/ila_12.v}
    {blk_mem_gen_0 sim/blk_mem_gen_0.v}
    {div_gen_4 div_gen_4_sim_netlist.v}
    {fifo_generator_0 sim/fifo_generator_0.v}
} {
    set ip_name [lindex $ip_info 0]
    set ip_path [lindex $ip_info 1]
    set full_path [file join $proj_root "AXI_DDR.gen" "sources_1" "ip" $ip_name $ip_path]
    if {[file exists $full_path]} {
        lappend src_files $full_path
    } else {
        puts "WARNING: IP file not found: $full_path"
    }
}

# RTL 源文件
foreach rtl {adcdata_acq.v row_repeat_module.v sync_module.v} {
    lappend src_files [file join $proj_root "AXI_DDR.srcs" "sources_1" "new" $rtl]
}

# testbench
lappend src_files $tb_file

# glbl
set glbl_file [file join $sim_dir "glbl.v"]
if {![file exists $glbl_file]} {
    file copy [file join $vivado_bin ".." "data" "verilog" "src" "glbl.v"] $glbl_file
}
lappend src_files $glbl_file

puts "INFO: compiling [llength $src_files] files..."

# 写 prj 文件
set prj_file [file join $sim_dir "dl5_unit004_regression.prj"]
set fp [open $prj_file w]
foreach f $src_files {
    puts $fp "verilog xil_defaultlib \"$f\""
}
puts $fp "nosort"
close $fp

# Step 1: xvlog
puts "INFO: === XVLOG ==="
set xvlog_cmd [list $xvlog_exe --relax -prj $prj_file -log [file join $sim_dir "xvlog.log"]]
puts "INFO: $xvlog_cmd"
catch {exec {*}$xvlog_cmd} xvlog_out
puts $xvlog_out

# 检查 xvlog.log 是否有 ERROR
set xvlog_log_content [read [open [file join $sim_dir "xvlog.log"] r]]
if {[string match "*ERROR*" $xvlog_log_content]} {
    puts "ERROR: xvlog failed - see xvlog.log"
    cd $orig_dir
    close_project
    exit 1
}
puts "INFO: xvlog PASS"

# Step 2: xelab
puts "INFO: === XELAB ==="
set xelab_cmd [list $xelab_exe --debug typical --relax --mt 2 \
    -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -L xpm \
    -L fifo_generator_v13_2_5 -L blk_mem_gen_v8_4_4 \
    --snapshot tb_dl5_unit_004_regression_behav \
    xil_defaultlib.tb_dl5_unit_004_regression xil_defaultlib.glbl \
    -log [file join $sim_dir "xelab.log"]]
puts "INFO: $xelab_cmd"
catch {exec {*}$xelab_cmd} xelab_out
puts $xelab_out

# 检查 xelab.log 是否有 snapshot built
set xelab_log_content [read [open [file join $sim_dir "xelab.log"] r]]
if {![string match "*Built simulation snapshot*" $xelab_log_content]} {
    puts "ERROR: xelab failed - see xelab.log"
    cd $orig_dir
    close_project
    exit 1
}
puts "INFO: xelab PASS"

# Step 3: xsim - 使用 Vivado 内置 xsim 命令（避免 init.tcl 加密问题）
puts "INFO: === XSIM ==="
set snapshot_path [file join $sim_dir "xsim.dir" "tb_dl5_unit_004_regression_behav"]
if {![file exists $snapshot_path]} {
    puts "ERROR: snapshot not found at $snapshot_path"
    cd $orig_dir
    close_project
    exit 1
}

# 用 Vivado 内置的 xsim 命令
cd $sim_dir
puts "INFO: xsim snapshot loaded, running..."
xsim tb_dl5_unit_004_regression_behav -log [file join $sim_dir "xsim.log"]
run all
set xsim_out ""
catch {set xsim_out [read [open [file join $sim_dir "xsim.log"] r]]}
puts $xsim_out

# 检查结果。Vivado 2021.1 batch 模式下当前 xsim 输出主要进入
# Vivado transcript，xsim.log 可能为空；因此由 testbench 写标记文件。
set pass 0
if {[string match "*RESULT: PASS*" $xsim_out]} {
    set pass 1
}
if {[file exists $result_marker]} {
    set fp [open $result_marker r]
    set marker_content [string trim [read $fp]]
    close $fp
    puts "INFO: tb result marker = $marker_content"
    if {[string match "PASS*" $marker_content]} {
        set pass 1
    }
}

# 复制输出
foreach f {xvlog.log xelab.log xsim.log dl5_unit004_regression_result.txt} {
    set src [file join $sim_dir $f]
    if {[file exists $src]} {
        file copy -force $src [file join $out_dir $f]
    }
}

set result_file [file join $out_dir "result.txt"]
set fp [open $result_file w]
if {$pass} {
    puts $fp "PASS"
    puts "INFO: result = PASS"
} else {
    puts $fp "FAIL"
    puts "INFO: result = FAIL"
}
close $fp

cd $orig_dir
close_project

if {!$pass} {
    exit 1
}
exit 0

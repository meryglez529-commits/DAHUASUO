# DL5_UNIT_002 仿真：绕过 launch_simulation 的 Broken pipe 问题
# 在 Vivado tcl 内部直接调用 xvlog/xelab/xsim
#
# 用法：vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_manual.tcl

set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set sim_dir [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim"]

file mkdir $out_dir
file mkdir $sim_dir

open_project $xpr

# 确保 tb 在 sim_1 里
set simset [get_filesets sim_1]
set tb_file [file join $proj_root "AXI_DDR.srcs" "sim_1" "new" "tb_dl5_unit_002.v"]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_002.v]
if {$existing_tb eq ""} {
    add_files -fileset sim_1 $tb_file
}
set_property top tb_dl5_unit_002 $simset
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

# 收集所有需要编译的 verilog 文件
set src_files [list]
# IP sim 文件
foreach ip_name {div_gen_2 div_gen_3 fifo_generator_4 ila_1 ila_2} {
    set sim_v [glob -nocomplain [file join $proj_root "AXI_DDR.gen" "sources_1" "ip" $ip_name "sim" "${ip_name}.v"]]
    set netlist_v [glob -nocomplain [file join $proj_root "AXI_DDR.gen" "sources_1" "ip" $ip_name "${ip_name}_sim_netlist.v"]]
    if {[llength $sim_v] > 0} {
        lappend src_files [lindex $sim_v 0]
    } elseif {[llength $netlist_v] > 0} {
        lappend src_files [lindex $netlist_v 0]
    }
}
# RTL 源文件
foreach rtl {dac_output.v dacdata_config.v parameter_dacdata_gen.v sync_module.v} {
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
set prj_file [file join $sim_dir "dl5_unit002.prj"]
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
    -L fifo_generator_v13_2_5 \
    --snapshot tb_dl5_unit_002_behav \
    xil_defaultlib.tb_dl5_unit_002 xil_defaultlib.glbl \
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
set snapshot_path [file join $sim_dir "xsim.dir" "tb_dl5_unit_002_behav"]
if {![file exists $snapshot_path]} {
    puts "ERROR: snapshot not found at $snapshot_path"
    cd $orig_dir
    close_project
    exit 1
}

# 用 Vivado 内置的 xsim 命令
cd $sim_dir
if {[catch {xsim tb_dl5_unit_002_behav -log [file join $sim_dir "xsim.log"]} xsim_err]} {
    puts "ERROR: xsim open failed: $xsim_err"
    cd $orig_dir
    close_project
    exit 1
}
puts "INFO: xsim snapshot loaded, running..."
run all
set xsim_out ""
catch {set xsim_out [read [open [file join $sim_dir "xsim.log"] r]]}
puts $xsim_out

# 检查结果
set pass 0
if {[string match "*PASS*" $xsim_out] && ![string match "*FAIL*" $xsim_out]} {
    set pass 1
}

# 复制输出
foreach f {xvlog.log xelab.log xsim.log waveform.wdb} {
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

# DL5_UNIT_002 集成 testbench 一键回放脚本
# Vivado 项目模式，使用 XSim 跑 tb_dl5_unit_002.v
#
# 用法（在工程根目录跑）：
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_batch.tcl
#
# 输出：
#   AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/result.txt        - PASS / FAIL
#   AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/xsim.log          - 概要
#   AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/xvlog.log         - 编译日志
#   AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/xelab.log         - elab 日志
#   AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/waveform.wdb      - 波形

set script_dir  [file normalize [file dirname [info script]]]
set unit_dir    [file normalize [file join $script_dir ".."]]
set proj_root   [file normalize [file join $script_dir ".." ".." ".." ".." ".."]]
set out_dir     [file normalize [file join $unit_dir "out" "sim"]]
set xpr         [file normalize [file join $proj_root "AXI_DDR.xpr"]]
set wdb         [file normalize [file join $out_dir "waveform.wdb"]]
set result_file [file normalize [file join $out_dir "result.txt"]]
set tb_file     [file normalize [file join $proj_root "AXI_DDR.srcs" "sim_1" "new" "tb_dl5_unit_002.v"]]

file mkdir $out_dir

foreach stale [list \
    [file join $out_dir "xsim.log"] \
    [file join $out_dir "xvlog.log"] \
    [file join $out_dir "xelab.log"] \
    $wdb \
    $result_file] {
    if {[file exists $stale]} {
        file delete -force $stale
    }
}

if {![file exists $xpr]} {
    puts "FAIL: xpr not found: $xpr"
    error "missing project"
}
if {![file exists $tb_file]} {
    puts "FAIL: testbench not found: $tb_file"
    error "missing testbench"
}

puts "INFO: project root = $proj_root"
puts "INFO: output dir   = $out_dir"
puts "INFO: xpr          = $xpr"
puts "INFO: testbench    = $tb_file"

open_project $xpr

set old_target_sim [get_property target_simulator [current_project]]
puts "INFO: previous target_simulator = $old_target_sim"
set_property target_simulator XSim [current_project]

# 把 tb 文件加进 sim_1（如果还没加）
set simset [get_filesets sim_1]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_002.v]
if {$existing_tb eq ""} {
    puts "INFO: adding tb_dl5_unit_002.v to sim_1 fileset"
    add_files -fileset sim_1 $tb_file
} else {
    puts "INFO: tb_dl5_unit_002.v already in sim_1"
}

set old_top [get_property top $simset]
puts "INFO: previous sim_1 top = $old_top"
set old_debug_level ""
set old_log_all_signals ""
set have_old_debug_level [expr {![catch {get_property xsim.elaborate.debug_level $simset} old_debug_level]}]
set have_old_log_all_signals [expr {![catch {get_property xsim.simulate.log_all_signals $simset} old_log_all_signals]}]

set_property top tb_dl5_unit_002 $simset
set_property top_lib xil_defaultlib $simset
catch {set_property xsim.elaborate.debug_level typical $simset}
catch {set_property xsim.simulate.log_all_signals true $simset}
update_compile_order -fileset sim_1

puts "INFO: launching behavioral simulation"
# 先确保所有 IP 的仿真目标已生成
puts "INFO: generating simulation targets for all IPs..."
foreach ip [get_ips -quiet] {
    generate_target Simulation $ip -quiet
}
# 加 fifo_generator 预编译库到 xelab 参数
set_property -name {xsim.elaborate.xelab.more_options} -value {-L fifo_generator_v13_2_5} -objects $simset
launch_simulation -simset sim_1 -mode behavioral

puts "INFO: logging waves and running to finish"
catch {log_wave -r /*}
run all

set sim_errors "UNKNOWN"
if {[catch {get_value -radix unsigned /tb_dl5_unit_002/errors} sim_errors]} {
    catch {examine -radix unsigned /tb_dl5_unit_002/errors} sim_errors
}

set result "UNKNOWN"
set sim_errors_trim [string trim $sim_errors]
if {$sim_errors_trim eq "0" || $sim_errors_trim eq "32'h00000000" || $sim_errors_trim eq "00000000"} {
    set result "PASS"
} elseif {$sim_errors_trim ne "UNKNOWN"} {
    set result "FAIL"
}

set sim_dir [file normalize [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"]]
puts "INFO: Vivado sim dir = $sim_dir"

set compile_log [file join $sim_dir "compile.log"]
if {[file exists $compile_log] && [file size $compile_log] > 0} {
    file copy -force $compile_log [file join $out_dir "xvlog.log"]
}
set elaborate_log [file join $sim_dir "elaborate.log"]
if {[file exists $elaborate_log] && [file size $elaborate_log] > 0} {
    file copy -force $elaborate_log [file join $out_dir "xelab.log"]
}

set wdb_candidates [glob -nocomplain -directory $sim_dir *.wdb]
if {[llength $wdb_candidates] > 0} {
    set latest_wdb [lindex [lsort -dictionary $wdb_candidates] end]
    file copy -force $latest_wdb $wdb
    puts "INFO: copied waveform: $latest_wdb -> $wdb"
} else {
    puts "WARN: no WDB found under $sim_dir"
}

set log_file [file join $out_dir "xsim.log"]
set fp [open $log_file w]
puts $fp "# DL5_UNIT_002 xsim replay summary"
puts $fp "result=$result"
puts $fp "errors=$sim_errors_trim"
puts $fp "testbench=AXI_DDR.srcs/sim_1/new/tb_dl5_unit_002.v"
puts $fp "dut=AXI_DDR.srcs/sources_1/new/dacdata_config.v (with parameter_dacdata_gen + dac_output)"
puts $fp "waveform=AI-work/features/DL5_laser_sync/DL5_UNIT_002/out/sim/waveform.wdb"
close $fp

set fp [open $result_file w]
puts $fp $result
close $fp

puts "INFO: restoring project simulation settings"
catch {set_property top $old_top $simset}
catch {set_property target_simulator $old_target_sim [current_project]}
if {$have_old_debug_level} {
    catch {set_property xsim.elaborate.debug_level $old_debug_level $simset}
}
if {$have_old_log_all_signals} {
    catch {set_property xsim.simulate.log_all_signals $old_log_all_signals $simset}
}

puts "INFO: result = $result"
puts "INFO: xsim log -> $log_file"
puts "INFO: waveform -> $wdb"

if {$result ne "PASS"} {
    puts "FAIL: DL5_UNIT_002 integration simulation did not PASS"
    exit 1
}

exit 0

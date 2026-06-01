# DL5_UNIT_002 仿真准备脚本：生成 IP 仿真目标 + 导出 prj 文件
# 用法：vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/gen_sim_targets.tcl

set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]

open_project $xpr

set simset [get_filesets sim_1]

# 确保 tb 在 sim_1 里
set tb_file [file join $proj_root "AXI_DDR.srcs" "sim_1" "new" "tb_dl5_unit_002.v"]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_002.v]
if {$existing_tb eq ""} {
    add_files -fileset sim_1 $tb_file
    puts "INFO: added tb_dl5_unit_002.v"
}

set_property top tb_dl5_unit_002 $simset
set_property top_lib xil_defaultlib $simset
set_property target_simulator XSim [current_project]
update_compile_order -fileset sim_1

# 生成所有 IP 的仿真目标
puts "INFO: generating simulation targets for IPs..."
foreach ip [get_ips -quiet] {
    set needs [get_property generate_synth_checkpoint $ip]
    generate_target Simulation $ip -quiet
}
puts "INFO: IP simulation targets generated"

# 导出仿真脚本（这会生成完整的 prj 文件和 bat）
puts "INFO: exporting simulation..."
export_simulation -simulator xsim -directory [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"] -force
puts "INFO: export done"

close_project
puts "INFO: DONE - now run compile/elaborate/simulate manually"
exit 0

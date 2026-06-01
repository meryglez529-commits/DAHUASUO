# DL5_UNIT_002 仿真 GUI 模式入口
# 在 Vivado Tcl Console 里 source 本文件即可
#
# 用法：
#   1. 打开 Vivado GUI，打开 AXI_DDR.xpr 工程
#   2. 在 Tcl Console 输入：
#      source AI-work/features/DL5_laser_sync/DL5_UNIT_002/sim/run_gui.tcl
#   3. 等待仿真完成，查看 Tcl Console 输出的 PASS/FAIL
#   4. 波形在 waveform viewer 里自动打开

set simset [get_filesets sim_1]

# 确保 tb 在 sim_1 里
set tb_file [file normalize "AXI_DDR.srcs/sim_1/new/tb_dl5_unit_002.v"]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_002.v]
if {$existing_tb eq ""} {
    add_files -fileset sim_1 $tb_file
    puts "INFO: added tb_dl5_unit_002.v"
}

set_property top tb_dl5_unit_002 $simset
set_property top_lib xil_defaultlib $simset
set_property target_simulator XSim [current_project]
catch {set_property xsim.elaborate.debug_level typical $simset}
catch {set_property xsim.simulate.log_all_signals true $simset}
update_compile_order -fileset sim_1

puts "INFO: launching behavioral simulation..."
launch_simulation -simset sim_1 -mode behavioral

puts "INFO: running simulation to finish..."
run all

puts ""
puts "========================================"
puts "仿真完成。请查看 Tcl Console 输出中的 PASS/FAIL"
puts "波形已自动加载到 Waveform Viewer"
puts "========================================"

# DL5_UNIT_004 仿真：激光模式 ADC 采集点数独立控制（acq_time）
# 在 Vivado tcl 内部直接调用 xvlog/xelab/xsim
#
# 用法：vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/run_manual.tcl

set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set sim_dir [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/sim"]

file mkdir $out_dir
file mkdir $sim_dir

open_project $xpr

# 确保 tb 在 sim_1 里
set simset [get_filesets sim_1]
set tb_file [file join $proj_root "AXI_DDR.srcs" "sim_1" "new" "tb_dl5_unit_004.v"]
set existing_tb [get_files -quiet -of_objects $simset tb_dl5_unit_004.v]
if {$existing_tb eq ""} {
    add_files -fileset sim_1 $tb_file
}
set_property top tb_dl5_unit_004 $simset
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

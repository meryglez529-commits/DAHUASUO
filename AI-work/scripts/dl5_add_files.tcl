# DL5 实现脚本：把新增的 RTL 和 testbench 文件注册到 Vivado 项目。
# 一次性任务，注册完即可走标准 run_synth.tcl 流程。
#
# Usage:
#   & "D:/Xilinx/Vivado/2021.1/bin/vivado.bat" -mode batch `
#       -source AI-work/scripts/dl5_add_files.tcl `
#       -tclargs AXI_DDR.xpr `
#       -log    AI-work/sim_out/dl5_add_files.log `
#       -journal AI-work/sim_out/dl5_add_files.jou

if {[llength $argv] < 1} {
    puts "FAIL: missing argument: <project.xpr>"
    exit 2
}
set xpr [lindex $argv 0]
if {![file exists $xpr]} {
    puts "FAIL: xpr not found: $xpr"
    exit 2
}

open_project $xpr

# 注册 DL5 新 RTL（sources_1）
set src_new "AXI_DDR.srcs/sources_1/new/laser_sync_blanker_ctrl.v"
if {[file exists $src_new]} {
    set existing [get_files -of_objects [get_filesets sources_1] -filter "NAME =~ *laser_sync_blanker_ctrl*"]
    if {[llength $existing] == 0} {
        add_files -fileset sources_1 -norecurse $src_new
        puts "INFO: added to sources_1: $src_new"
    } else {
        puts "INFO: already in sources_1: $src_new"
    }
} else {
    puts "FAIL: source file missing: $src_new"
    close_project
    exit 1
}

# 注册 DL5 testbench（sim_1）
set tb_new "AXI_DDR.srcs/sim_1/new/tb_laser_sync_blanker_ctrl.v"
if {[file exists $tb_new]} {
    set existing [get_files -of_objects [get_filesets sim_1] -filter "NAME =~ *tb_laser_sync_blanker_ctrl*"]
    if {[llength $existing] == 0} {
        add_files -fileset sim_1 -norecurse $tb_new
        puts "INFO: added to sim_1: $tb_new"
    } else {
        puts "INFO: already in sim_1: $tb_new"
    }
} else {
    puts "WARN: testbench file missing: $tb_new"
}

# 刷新编译顺序
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 这里不显式 save_project，因为 Vivado 在 add_files 后会自动 dirty 标记；
# 后续脚本 open_project 时不需要先存盘，直接读 .xpr 就能看到新文件。
# 如果要强制存盘，调用方在自己的脚本里再加 save_project。

puts "INFO: dl5_add_files done. Verifying sources_1 includes new module:"
set found_dl5 [get_files -of_objects [get_filesets sources_1] -filter "NAME =~ *laser_sync_blanker_ctrl*"]
puts "  laser_sync_blanker_ctrl files: $found_dl5"

set found_tb [get_files -of_objects [get_filesets sim_1] -filter "NAME =~ *tb_laser_sync_blanker_ctrl*"]
puts "  tb_laser_sync_blanker_ctrl files: $found_tb"

save_project
close_project
puts "DONE"
exit 0

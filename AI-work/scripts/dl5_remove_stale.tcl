# 一次性脚本：从 .xpr 移除 UNIT_001 残留文件引用
# 用法：vivado -mode batch -source AI-work/scripts/dl5_remove_stale.tcl -tclargs AXI_DDR.xpr

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

puts "INFO: removing UNIT_001 stale file references..."

set f1 [get_files -quiet laser_sync_blanker_ctrl.v]
set f2 [get_files -quiet -of_objects [get_filesets sim_1] tb_laser_sync_blanker_ctrl.v]

puts "INFO: found in sources_1: $f1"
puts "INFO: found in sim_1:     $f2"

if {$f1 ne ""} {
    remove_files $f1
    puts "INFO: removed $f1"
}
if {$f2 ne ""} {
    remove_files -fileset sim_1 $f2
    puts "INFO: removed $f2"
}

close_project
puts "INFO: DONE"
exit 0

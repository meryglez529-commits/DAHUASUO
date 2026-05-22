# DL5 快速 RTL elaboration 检查
# 跑 synth_design -rtl 而不是完整 synth_1，时间 ~1-2 分钟
# 主要 catch：端口连接错误、信号位宽不匹配、未声明信号、模块缺失等
#
# Usage:
#   & "D:/Xilinx/Vivado/2021.1/bin/vivado.bat" -mode batch `
#       -source AI-work/scripts/dl5_elab.tcl `
#       -tclargs AXI_DDR.xpr `
#       -log    AI-work/sim_out/dl5_elab.log `
#       -journal AI-work/sim_out/dl5_elab.jou

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

# 跑 RTL 弹性 elaboration（不优化、不映射）
puts "INFO: starting synth_design -rtl ..."
if {[catch {synth_design -rtl -top ETH_TOP -part xc7k325tffg676-2} err]} {
    puts "FAIL: RTL elaboration failed: $err"
    close_project
    exit 1
}

# 收集 warning/error 数
set msgs [get_msg_config -severity ERROR -count]
set wrns [get_msg_config -severity {CRITICAL WARNING} -count]
puts "INFO: ERROR count = $msgs"
puts "INFO: CRITICAL WARNING count = $wrns"

# 列出 ETH_TOP 的所有 ports（确认 laser_sync_in 已经在顶层）
puts "INFO: ETH_TOP top-level ports:"
foreach p [lsort [get_ports]] {
    puts "  - $p"
}

close_project

if {$msgs > 0} {
    puts "FAIL: $msgs error(s) during RTL elaboration"
    exit 1
}
puts "INFO: RTL elaboration PASS"
exit 0

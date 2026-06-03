# 专门确认 laser_sync_in 是否真的恒0：对 laser_sync_in 上升沿做条件触发
# 命中 => 引脚有信号进来（之前是采样窗口太短）
# 超时 => 引脚确实没信号（硬件/接线/引脚问题）

set proj_root [file normalize [pwd]]
set ltx [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
file mkdir $out_dir
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev
for {set i 0} {$i < 12} {incr i} {
    refresh_hw_device -quiet $dev
    if {[llength [get_hw_ilas -quiet]] > 0} break
    after 1000
}

# 找含 laser_sync_in 的 ILA
set ila ""
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        if {[get_property NAME $p -quiet] eq "U6/laser_sync_in"} { set ila $c }
    }
}
if {$ila eq ""} { puts "ERROR: laser_sync_in probe not found"; exit 1 }
puts "Using ILA: $ila"

set probe [get_hw_probes "U6/laser_sync_in" -of_objects $ila]
set_property CONTROL.TRIGGER_POSITION 128 $ila
set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe
run_hw_ila $ila
puts "Armed on laser_sync_in==1, waiting up to 10s for a rising edge..."

set hit 1
if {[catch {wait_on_hw_ila $ila -timeout 10}]} {
    set hit 0
    puts "RESULT: TIMEOUT - laser_sync_in 在10秒内没有任何高电平 => 引脚没有信号进入FPGA"
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
} else {
    puts "RESULT: TRIGGERED - laser_sync_in 检测到高电平 => 引脚有信号"
}
set data [upload_hw_ila_data $ila]
set tag [expr {$hit ? "HIT" : "TIMEOUT"}]
set csv [file join $out_dir "laser_in_check_${tag}_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "saved: $csv"

close_hw_manager
exit 0

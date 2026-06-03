# 决定性测试: laser_toggle 有没有翻转?
# 对 laser_toggle 上升沿做条件触发,等 15 秒
# - 命中 => 状态机在工作,toggle 在翻转
# - 超时 => 状态机卡死,toggle 恒定

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

# 找含 laser_toggle 的 ILA
set ila ""
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        if {[get_property NAME $p -quiet] eq "U6/laser_toggle"} { set ila $c; break }
    }
    if {$ila ne ""} break
}
if {$ila eq ""} { puts "ERROR: laser_toggle probe not found"; exit 1 }
puts "ILA: $ila"

set_property CONTROL.DATA_DEPTH 1024 $ila
set_property CONTROL.TRIGGER_POSITION 512 $ila
set probe [get_hw_probes "U6/laser_toggle" -of_objects $ila]
set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe
puts "=== Trigger: laser_toggle==1 (rising edge), waiting 15s ==="
run_hw_ila $ila

if {[catch {wait_on_hw_ila $ila -timeout 15}]} {
    puts "\n*** RESULT: TIMEOUT ***"
    puts "laser_toggle 在 15 秒内没有翻转 => 状态机不工作"
    set tag "NOTOGGLE"
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
} else {
    puts "\n*** RESULT: TRIGGERED ***"
    puts "laser_toggle 检测到上升沿 => 状态机在工作!"
    set tag "TOGGLE"
}

set data [upload_hw_ila_data $ila]
set csv [file join $out_dir "toggle_test_${tag}_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "saved: $csv"

close_hw_manager
exit 0

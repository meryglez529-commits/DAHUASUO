# 稳健版:抓取 laser_sync_in 上升沿前后完整波形
# - 触发位置设为 512(buffer 中部),确保能看到触发前后各 512 采样
# - 增加数据深度到 4096,降低空数据风险
# - 前台跑,不用管道,直接看全部输出

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
        if {[get_property NAME $p -quiet] eq "U6/laser_sync_in"} { set ila $c; break }
    }
    if {$ila ne ""} break
}
if {$ila eq ""} { puts "ERROR: laser_sync_in probe not found"; exit 1 }
puts "ILA: $ila"

# 设数据深度和触发位置(最大1024)
set_property CONTROL.DATA_DEPTH 1024 $ila
set_property CONTROL.TRIGGER_POSITION 512 $ila
set probe [get_hw_probes "U6/laser_sync_in" -of_objects $ila]
set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe
puts "Trigger condition: laser_sync_in==1, depth=1024, trigger_pos=512"
run_hw_ila $ila
puts "Armed, waiting up to 12s..."

if {[catch {wait_on_hw_ila $ila -timeout 12}]} {
    puts "TIMEOUT - fallback to trigger_now"
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    set tag "NOTRIG"
} else {
    puts "TRIGGERED!"
    set tag "trig"
}

set data [upload_hw_ila_data $ila]
set csv [file join $out_dir "laser_edge_${tag}_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "saved: $csv"

# 读一下确认数据行数
set f [open $csv r]
set lines [split [read $f] "\n"]
close $f
puts "CSV lines: [llength $lines] (header+radix+data)"

close_hw_manager
exit 0

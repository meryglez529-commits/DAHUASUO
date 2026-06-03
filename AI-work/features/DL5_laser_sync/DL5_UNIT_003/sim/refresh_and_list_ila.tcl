# 重新连接已编程的器件，加载 LTX，等待 debug hub 上线后列出 ILA probe
set proj_root [file normalize [pwd]]
set ltx [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev

# 多次 refresh 直到 debug hub 上线（最多 10 次）
set ila_count 0
for {set i 0} {$i < 10} {incr i} {
    refresh_hw_device -quiet $dev
    set ila_count [llength [get_hw_ilas -quiet]]
    puts "attempt [expr {$i+1}]: ILA count = $ila_count"
    if {$ila_count > 0} break
    after 1000
}

if {$ila_count == 0} {
    puts "ERROR: debug hub still not detected after retries."
    exit 1
}

# 列出每个 ILA 及其 probe，标记 laser 相关
foreach ila [get_hw_ilas] {
    set probes [get_hw_probes -of_objects $ila -quiet]
    puts "\nILA $ila  (probes [llength $probes])"
    foreach probe $probes { puts "   [get_property NAME $probe -quiet]" }
}
close_hw_manager
exit 0

# 决定性测试: 直抓 TRIGGER_IN (IBUF 输出原始值)
# probe0=TRIGGER_IN, probe1=freerun计数, probe2=内部注入脉冲, probe3=预留
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
set n 0
for {set i 0} {$i < 15} {incr i} {
    refresh_hw_device -quiet $dev
    set n [llength [get_hw_ilas -quiet]]
    if {$n > 0} break
    after 1000
}
puts "ILA count: $n"
if {$n == 0} { puts "ERROR: no debug hub"; exit 1 }

# 找抓 TRIGGER_IN 的 ILA (ila_top_trig)
set ila ""
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        set pn [get_property NAME $p -quiet]
        if {$pn eq "TRIGGER_IN" || [string match "*TRIGGER_IN*" $pn]} {
            # 排除 dac/dl5 模块里的同名，确认是顶层 ila_top_trig（带 dbg_top_freerun）
            set ila $c
        }
    }
}
# 更稳妥：用 dbg_top_laser_pulse 这个唯一信号定位
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        if {[string match "*dbg_top_laser_pulse*" [get_property NAME $p -quiet]]} { set ila $c }
    }
}
if {$ila eq ""} { puts "ERROR: ila_top_trig not found"; exit 1 }
puts "Using ILA: $ila"
puts "Probes:"
foreach p [get_hw_probes -of_objects $ila -quiet] { puts "  [get_property NAME $p -quiet]" }

set_property CONTROL.DATA_DEPTH 8192 $ila
set_property CONTROL.TRIGGER_POSITION 0 $ila
puts "trigger_now..."
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
set d [upload_hw_ila_data $ila]
set csv [file join $out_dir "TRIGIN_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $d
puts "saved: $csv"

close_hw_manager
exit 0

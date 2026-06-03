# 抓 hw_ila_17 (dac_output 内部 DAX_DATA/DAY_DATA)
# 普通模式扫描在跑,如果 DAC 数据通路正常,DAX_DATA 应该在变化

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

# 找 DAX_DATA 所在的 ILA
set ila ""
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        if {[get_property NAME $p -quiet] eq "U6/N2/DAX_DATA"} { set ila $c; break }
    }
    if {$ila ne ""} break
}
if {$ila eq ""} { puts "ERROR: DAX_DATA probe not found"; exit 1 }
puts "ILA: $ila"

set_property CONTROL.DATA_DEPTH 1024 $ila
set_property CONTROL.TRIGGER_POSITION 0 $ila
puts "trigger_now (扫描在跑,任意时刻抓一帧)"
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
set data [upload_hw_ila_data $ila]
set csv [file join $out_dir "dac_output_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "saved: $csv"

close_hw_manager
exit 0

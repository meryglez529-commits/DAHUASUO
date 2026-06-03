# 抓 hw_ila_17 (dac_dco 域含 DAX_DATA),用于测 laser → DAX 切换延迟
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

# 抓 hw_ila_17 (DAX_DATA, DAY_DATA, sync1_pixel_tri)
set ila [get_hw_ilas hw_ila_17]
set_property CONTROL.DATA_DEPTH 1024 $ila
set_property CONTROL.TRIGGER_POSITION 0 $ila
puts "=== hw_ila_17: DAX_DATA / DAY_DATA / sync1_pixel_tri (dac_dco域) ==="
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
set d [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file [file join $out_dir "DAC_dax_${ts}.csv"] $d
puts "saved: DAC_dax_${ts}.csv"

close_hw_manager
exit 0

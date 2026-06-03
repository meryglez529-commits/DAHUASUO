# 普通模式下抓状态机和 DAC 链路
# 应该确认: current_state 在动? para_config_wr_en 在动? DAX_DATA 经 FIFO 后到底有没有变?
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

# 抓 hw_ila_20 (含 current_state, scan_state 等)
set ila_st [get_hw_ilas hw_ila_20]
set_property CONTROL.DATA_DEPTH 1024 $ila_st
set_property CONTROL.TRIGGER_POSITION 0 $ila_st
puts "=== hw_ila_20: 抓 current_state ==="
run_hw_ila -trigger_now $ila_st
wait_on_hw_ila $ila_st
set d [upload_hw_ila_data $ila_st]
write_hw_ila_data -force -csv_file [file join $out_dir "normal_state_${ts}.csv"] $d

# 抓 hw_ila_17 (含 DAX_DATA, DAY_DATA, sync1_pixel_tri)
set ila_dac [get_hw_ilas hw_ila_17]
set_property CONTROL.DATA_DEPTH 1024 $ila_dac
set_property CONTROL.TRIGGER_POSITION 0 $ila_dac
puts "=== hw_ila_17: 抓 DAX_DATA ==="
run_hw_ila -trigger_now $ila_dac
wait_on_hw_ila $ila_dac
set d [upload_hw_ila_data $ila_dac]
write_hw_ila_data -force -csv_file [file join $out_dir "normal_dac_${ts}.csv"] $d

puts "saved both CSVs"
close_hw_manager
exit 0

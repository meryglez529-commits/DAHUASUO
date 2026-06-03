# Capture hw_ila_18 immediately and export CSV.

set proj_root [file normalize [pwd]]
set ltx_file [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
file mkdir $out_dir

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
}
refresh_hw_device $dev

set ila [get_hw_ilas hw_ila_18]
puts "Capturing $ila with trigger_now"
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
set data [upload_hw_ila_data $ila]
set csv [file join $out_dir "hw_ila_18_trigger_now.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "Saved: $csv"

close_hw_manager
exit 0

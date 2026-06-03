# Report hw_ila_18 probe properties for configuring a blanker capture.

set proj_root [file normalize [pwd]]
set ltx_file [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]

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
puts "ILA: $ila"
foreach probe [get_hw_probes -of_objects $ila] {
    puts "\nPROBE [get_property NAME $probe]"
    report_property $probe
}

close_hw_manager
exit 0

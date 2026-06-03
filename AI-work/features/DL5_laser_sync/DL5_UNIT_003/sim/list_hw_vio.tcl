# List hardware VIO cores and probes.

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

set vios [get_hw_vios]
puts "VIO count: [llength $vios]"
foreach vio $vios {
    puts "\nVIO: $vio"
    set probes [get_hw_probes -of_objects $vio]
    puts "Probe count: [llength $probes]"
    foreach probe $probes {
        puts "  [get_property NAME $probe]"
    }
}

close_hw_manager
exit 0

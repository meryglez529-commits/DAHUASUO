# List hardware ILA cores and probes for DL5_UNIT_003 board bring-up.
# This script only reads hardware debug metadata.

set proj_root [file normalize [pwd]]
set ltx_file [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]

puts "\n=========================================="
puts "DL5_UNIT_003 Hardware ILA Probe Listing"
puts "=========================================="
puts "LTX: $ltx_file"

open_hw_manager
connect_hw_server

set targets [get_hw_targets]
puts "Targets: $targets"
if {[llength $targets] == 0} {
    puts "ERROR: No hardware target found."
    exit 1
}

open_hw_target [lindex $targets 0]

set devices [get_hw_devices]
puts "Devices: $devices"
if {[llength $devices] == 0} {
    puts "ERROR: No hardware device found."
    exit 1
}

set dev [lindex $devices 0]
current_hw_device $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
}
refresh_hw_device $dev

set ilas [get_hw_ilas]
puts "\nILA count: [llength $ilas]"
foreach ila $ilas {
    puts "\nILA: $ila"
    set probes [get_hw_probes -of_objects $ila]
    puts "Probe count: [llength $probes]"
    foreach probe $probes {
        puts "  [get_property NAME $probe]"
    }
}

close_hw_manager
exit 0

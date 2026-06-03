# DL5_UNIT_003 hardware ILA capture with project hardware context loaded.
#
# This script is read-only for RTL/bitstream: it opens the Vivado project so the
# saved AXI_DDR.hw metadata can restore probe names, then captures selected ILAs.

set proj_root [file normalize [pwd]]
set xpr_file [file join $proj_root "AXI_DDR.xpr"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
set recovered_ltx [file join $out_dir "recovered_from_hwxml.ltx"]
file mkdir $out_dir

puts "\n=========================================="
puts "DL5_UNIT_003 Project-Aware ILA Capture"
puts "=========================================="
puts "Project: $xpr_file"
puts "Output : $out_dir"

open_project $xpr_file
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
if {[file exists $recovered_ltx]} {
    puts "INFO: Using recovered probes file: $recovered_ltx"
    set_property PROBES.FILE $recovered_ltx $dev
    set_property FULL_PROBES.FILE $recovered_ltx $dev
}
refresh_hw_device $dev

puts "PROGRAM.FILE      = [get_property PROGRAM.FILE $dev]"
puts "PROBES.FILE       = [get_property PROBES.FILE $dev]"
puts "FULL_PROBES.FILE  = [get_property FULL_PROBES.FILE $dev]"

set ilas [get_hw_ilas]
puts "\nILA count: [llength $ilas]"
foreach ila $ilas {
    set probes [get_hw_probes -of_objects $ila]
    puts "\nILA: $ila"
    puts "Probe count: [llength $probes]"
    foreach probe $probes {
        puts "  [get_property NAME $probe]"
    }
}

foreach ila_name {hw_ila_18 hw_ila_9} {
    set ila [get_hw_ilas $ila_name]
    if {[llength $ila] == 0} {
        puts "WARN: $ila_name not found, skip capture."
        continue
    }

    puts "\nCapturing $ila_name with trigger_now..."
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    set data [upload_hw_ila_data $ila]
    set csv [file join $out_dir "${ila_name}_project_trigger_now.csv"]
    write_hw_ila_data -force -csv_file $csv $data
    puts "Saved: $csv"
}

close_hw_manager
close_project
exit 0

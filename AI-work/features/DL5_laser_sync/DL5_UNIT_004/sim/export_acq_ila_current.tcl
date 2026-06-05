# Export the current DL5 acquisition-timing ILA buffer without re-arming it.
# Usage:
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/export_acq_ila_current.tcl

set proj_root [pwd]
set out_dir   [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_004" "out" "ila"]
set ltx_file  [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_004" "out" "build" "ETH_TOP_unit004.ltx"]
file mkdir $out_dir

set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set csv_file     [file join $out_dir "acq_timing_current_${ts}.csv"]
set summary_file [file join $out_dir "acq_timing_current_${ts}.txt"]

proc probe_name {probe} {
    return [get_property NAME $probe]
}

proc find_ila_by_probe_glob {pattern} {
    foreach ila [get_hw_ilas -quiet] {
        foreach p [get_hw_probes -of_objects $ila -quiet] {
            if {[string match $pattern [probe_name $p]]} {
                return $ila
            }
        }
    }
    return ""
}

puts "DL5 acquisition ILA export"
puts "ltx=$ltx_file"
puts "csv=$csv_file"

open_hw_manager
catch {connect_hw_server -url localhost:3121 -allow_non_jtag}
open_hw_target
set dev [lindex [get_hw_devices] 0]
if {$dev eq ""} {
    puts "ERROR: no hardware device found"
    exit 1
}
current_hw_device $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE      $ltx_file $dev
    set_property FULL_PROBES.FILE $ltx_file $dev
}
refresh_hw_device -update_hw_probes true $dev

set ila [find_ila_by_probe_glob "*dl5_ila_acq_cfg_1*"]
if {$ila eq ""} {
    puts "ERROR: DL5 acquisition ILA not found"
    foreach candidate [get_hw_ilas -quiet] {
        puts "--- $candidate ---"
        foreach p [get_hw_probes -of_objects $candidate -quiet] {
            puts "  [probe_name $p]"
        }
    }
    exit 1
}

puts "target_ila=$ila"
puts "probes:"
foreach p [get_hw_probes -of_objects $ila -quiet] {
    puts "  [probe_name $p]"
}

set status ""
catch {set status [get_property CONTROL.STATUS $ila]}
set capture_status ""
catch {set capture_status [get_property CONTROL.CAPTURE_STATUS $ila]}
set trigger_status ""
catch {set trigger_status [get_property CONTROL.TRIGGER_STATUS $ila]}

set data [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file $csv_file $data

set fp [open $summary_file w]
puts $fp "target_ila=$ila"
puts $fp "ltx=$ltx_file"
puts $fp "csv=$csv_file"
puts $fp "CONTROL.STATUS=$status"
puts $fp "CONTROL.CAPTURE_STATUS=$capture_status"
puts $fp "CONTROL.TRIGGER_STATUS=$trigger_status"
puts $fp "probes:"
foreach p [get_hw_probes -of_objects $ila -quiet] {
    puts $fp "  [probe_name $p]"
}
close $fp

puts "summary=$summary_file"
puts "DONE"
close_hw_manager
exit 0

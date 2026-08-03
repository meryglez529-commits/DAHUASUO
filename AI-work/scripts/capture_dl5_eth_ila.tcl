set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ".." ".."]]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
set ila_out    [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_005" "out" "ila"]
set work_dir   [file join $ila_out "vivado_hw_work"]
file mkdir $work_dir
cd $work_dir
puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"

proc list_droot_hw_ila_dirs {} {
    return [lsort [glob -nocomplain -type d "D:/hw_ila_data_*"]]
}

proc archive_new_droot_hw_ila_dirs {before archive_dir} {
    file mkdir $archive_dir
    foreach d [list_droot_hw_ila_dirs] {
        if {[lsearch -exact $before $d] >= 0} {
            continue
        }
        set dst [file join $archive_dir [file tail $d]]
        if {[catch {file rename $d $dst} err]} {
            puts "WARN: failed to archive D-root ILA spill $d: $err"
        } else {
            puts "ARCHIVED_DROOT_ILA_SPILL=$d -> $dst"
        }
    }
}
set droot_hw_ila_before [list_droot_hw_ila_dirs]

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t_0] 0]
if {$dev eq ""} {
    set dev [lindex [get_hw_devices] 0]
}
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
refresh_hw_device $dev

set ila [get_hw_ilas hw_ila_20]
if {$ila eq ""} {
    error "Could not find hw_ila_20 / U6 dl5_eth_debug"
}

set trig [get_hw_probes U6/laser_sync_rise_eth -of_objects $ila]
if {$trig eq ""} {
    error "Could not find U6/laser_sync_rise_eth probe"
}

set_property CONTROL.TRIGGER_POSITION 128 $ila
set_property TRIGGER_COMPARE_VALUE {eq1'b1} $trig

run_hw_ila $ila
wait_on_hw_ila $ila
set data [upload_hw_ila_data $ila]

file mkdir $ila_out
set csv_file [file join $ila_out "dl5_eth_debug_capture.csv"]
set vcd_file [file join $ila_out "dl5_eth_debug_capture.vcd"]
write_hw_ila_data -force -csv_file $csv_file $data
write_hw_ila_data -force -vcd_file $vcd_file $data

puts "CAPTURED=$data"
puts "CSV=$csv_file"

archive_new_droot_hw_ila_dirs $droot_hw_ila_before [file join $ila_out "droot_spill"]

close_hw_manager

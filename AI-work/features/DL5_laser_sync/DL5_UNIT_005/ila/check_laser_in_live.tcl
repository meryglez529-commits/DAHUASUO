# Guarded-unit adaptation of the proven DL5_UNIT_003 check_laser_in.tcl.
# Trigger and capture behavior is intentionally unchanged: laser_sync_in == 1.
set script_dir [file dirname [file normalize [info script]]]
set unit_root [file normalize [file join $script_dir ".."]]
set proj_root [file normalize [file join $unit_root ".." ".." ".." ".."]]
set ltx [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
set out_dir [file join $unit_root "out" "ila"]
set work_dir [file join $out_dir "vivado_hw_work"]
file mkdir $out_dir
file mkdir $work_dir
cd $work_dir
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

proc droot_dirs {} { return [lsort [glob -nocomplain -type d "D:/hw_ila_data_*"]] }
proc archive_new_droot_dirs {before dst_root} {
    file mkdir $dst_root
    foreach d [droot_dirs] {
        if {[lsearch -exact $before $d] >= 0} { continue }
        set dst [file join $dst_root [file tail $d]]
        if {[catch {file rename $d $dst} err]} { puts "WARN: spill archive failed: $err" }
    }
}
set before [droot_dirs]
puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx"

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev
refresh_hw_device -quiet -update_hw_probes true $dev

set ila ""
foreach c [get_hw_ilas -quiet] {
    foreach p [get_hw_probes -of_objects $c -quiet] {
        if {[get_property NAME $p -quiet] eq "U6/laser_sync_in"} { set ila $c }
    }
}
if {$ila eq ""} { puts "ERROR: laser_sync_in probe not found"; close_hw_manager; exit 1 }
puts "Using ILA: $ila"
set probe [get_hw_probes "U6/laser_sync_in" -of_objects $ila]
set_property CONTROL.TRIGGER_POSITION 128 $ila
set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe
run_hw_ila $ila
puts "ARMED: laser_sync_in==1; await host DL5 apply/start"

# Kept exactly in the order used by the historical successful diagnostic.
set hit 1
if {[catch {wait_on_hw_ila $ila -timeout 10} err]} {
    set hit 0
    puts "RESULT: TIMEOUT - laser_sync_in no high level: $err"
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
} else {
    puts "RESULT: TRIGGERED - laser_sync_in high level detected"
}
set data [upload_hw_ila_data $ila]
set tag [expr {$hit ? "HIT" : "TIMEOUT"}]
set csv [file join $out_dir "laser_in_check_${tag}_${ts}.csv"]
write_hw_ila_data -force -csv_file $csv $data
puts "SAVED=$csv"
archive_new_droot_dirs $before [file join $out_dir "droot_spill"]
close_hw_manager
exit 0

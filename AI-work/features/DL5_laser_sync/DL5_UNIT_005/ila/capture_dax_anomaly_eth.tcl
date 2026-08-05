# Capture one laser-driven line in the existing eth_clk DL5 debug ILA.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set ila_out    [file join $unit_root "out" "ila"]
set work_dir   [file join $ila_out "vivado_hw_work"]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
set scenario   [lindex $argv 0]
if {$scenario eq ""} { set scenario "laser" }
file mkdir $ila_out
file mkdir $work_dir
cd $work_dir
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

proc find_probe {ila exact_name} {
    foreach probe [get_hw_probes -of_objects $ila -quiet] {
        if {[get_property NAME $probe] eq $exact_name} { return $probe }
    }
    return ""
}

proc find_probe_by_glob {ila pattern} {
    foreach probe [get_hw_probes -of_objects $ila -quiet] {
        if {[string match $pattern [get_property NAME $probe]]} { return $probe }
    }
    return ""
}

puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx_file"
open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
refresh_hw_device -quiet -update_hw_probes true $dev

set ila [lindex [get_hw_ilas hw_ila_21 -quiet] 0]
if {$ila eq ""} { error "hw_ila_21 missing" }
if {$scenario eq "tail"} {
    set trig [find_probe_by_glob $ila "*dl5_dbg_current_state*"]
    set trig_value "eq5'h0c"
} else {
    set trig [find_probe $ila "U6/laser_sync_rise_eth"]
    set trig_value "eq1'b1"
}
if {$trig eq ""} { error "trigger probe missing for scenario=$scenario" }
puts "ILA=$ila"
puts "TRIGGER=$trig"
puts "DEPTH_BEFORE=[get_property CONTROL.DATA_DEPTH $ila]"
catch {set_property CONTROL.DATA_DEPTH 4096 $ila} depth_err
puts "DEPTH_AFTER=[get_property CONTROL.DATA_DEPTH $ila]"
set_property CONTROL.TRIGGER_POSITION 0 $ila
set_property TRIGGER_COMPARE_VALUE $trig_value $trig
run_hw_ila $ila
puts "ARMED: scenario=$scenario, [get_property NAME $trig] $trig_value"
if {[catch {wait_on_hw_ila $ila -timeout 20} err]} { error "capture timeout: $err" }
set data [upload_hw_ila_data $ila]
set base [file join $ila_out "dax_anomaly_eth_${scenario}_TRIG_${ts}"]
write_hw_ila_data -force -csv_file "${base}.csv" $data
catch {write_hw_ila_data -force -vcd_file "${base}.vcd" $data}
puts "CSV=${base}.csv"
close_hw_manager
exit 0

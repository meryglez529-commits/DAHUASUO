# Run only after the user programs ETH_TOP_camera_marker_fix.bit with the
# matching LTX and starts the laser-mode profile.  Launch via the guarded
# PowerShell runner so D-root hw_ila_data_* spill is archived unit-locally.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_ila    [file join $unit_root "out" "ila"]
set work_dir   [file join $out_ila "vivado_hw_work"]
set ltx_file   [file join $unit_root "out" "bitstream" "ETH_TOP_camera_marker_fix.ltx"]
file mkdir $out_ila
file mkdir $work_dir
cd $work_dir

proc find_ila_with_probe {pattern} {
    foreach ila [get_hw_ilas -quiet] {
        foreach probe [get_hw_probes -of_objects $ila -quiet] {
            if {[string match $pattern [get_property NAME $probe]]} { return $ila }
        }
    }
    return ""
}
proc find_probe_by_glob {ila pattern} {
    foreach probe [get_hw_probes -of_objects $ila -quiet] {
        if {[string match $pattern [get_property NAME $probe]]} { return $probe }
    }
    return ""
}
proc export_ila {ila out_ila label tag ts} {
    set data [upload_hw_ila_data $ila]
    set base [file join $out_ila "${label}_${tag}_${ts}"]
    write_hw_ila_data -force -csv_file "${base}.csv" $data
    catch {write_hw_ila_data -force -vcd_file "${base}.vcd" $data}
    puts "CSV=${base}.csv"
}

if {![file exists $ltx_file]} { error "Missing paired LTX: $ltx_file" }
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx_file"
puts "SCENARIO=laser camera marker alignment; trigger DAC FIFO[33]"

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
refresh_hw_device -quiet -update_hw_probes true $dev

set eth_ila [find_ila_with_probe "*dl5_dbg_line_start_accept*"]
set dac_ila [find_ila_with_probe "*camera_line_sync*"]
set acq_ila [find_ila_with_probe "*dl5_ila_acq_counts*"]
if {$eth_ila eq ""} { error "ETH diagnostic ILA not found" }
if {$dac_ila eq ""} { error "DAC/camera ILA not found" }
if {$acq_ila eq ""} { error "Acquisition-timing ILA not found" }

set eth_trig [find_probe_by_glob $eth_ila "*dl5_dbg_line_start_accept*"]
set dac_trig [find_probe_by_glob $dac_ila "*para_config_dout*"]
set acq_trig [find_probe_by_glob $acq_ila "*laser_pulse_ui*"]
if {$eth_trig eq ""} { error "ETH line-start trigger probe not found" }
if {$dac_trig eq ""} { error "DAC FIFO[33] trigger probe not found" }
if {$acq_trig eq ""} { error "Acquisition trigger probe not found" }

foreach {ila depth pos trig} [list \
    $eth_ila 4096 0    $eth_trig \
    $dac_ila 4096 3072 $dac_trig \
    $acq_ila 1024 512  $acq_trig] {
    set_property CONTROL.DATA_DEPTH $depth $ila
    set_property CONTROL.TRIGGER_POSITION $pos $ila
    set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trig
    run_hw_ila $ila
    puts "ARMED: $ila trigger=[get_property NAME $trig] depth=$depth pos=$pos"
}

foreach {label ila} [list eth_full_line $eth_ila dac_camera_alignment $dac_ila acq_timing $acq_ila] {
    if {[catch {wait_on_hw_ila -timeout 12 $ila} err]} {
        error "$label did not trigger within 12 s: $err"
    }
    export_ila $ila $out_ila $label TRIG $ts
}
close_hw_manager
exit 0

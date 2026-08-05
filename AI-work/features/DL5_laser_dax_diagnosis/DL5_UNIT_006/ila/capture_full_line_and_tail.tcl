# Capture the complete evidence set after the user programs the paired bit/LTX
# and runs the continuous laser test profile. All hardware-manager artifacts
# remain under this unit. Run through run_vivado_ila_guarded.ps1 only.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_ila    [file join $unit_root "out" "ila"]
set work_dir   [file join $out_ila "vivado_hw_work"]
set ltx_file   [file join $unit_root "out" "bitstream" "ETH_TOP_dl5_dax_diag.ltx"]
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

proc find_probe_by_name {ila exact_name} {
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

proc export_ila {ila out_ila label ts} {
    set data [upload_hw_ila_data $ila]
    set base [file join $out_ila "${label}_TRIG_${ts}"]
    write_hw_ila_data -force -csv_file "${base}.csv" $data
    catch {write_hw_ila_data -force -vcd_file "${base}.vcd" $data}
    puts "CSV=${base}.csv"
}

if {![file exists $ltx_file]} { error "Missing paired LTX: $ltx_file" }
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx_file"
puts "SCENARIO=continuous laser profile, 16 pixels/line"

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
refresh_hw_device -quiet -update_hw_probes true $dev

# Three complementary ILA instances, located by probe names rather than a
# fragile hw_ila_N index.  All are armed before waiting for the next line.
set eth_ila [find_ila_with_probe "*dl5_dbg_line_start_accept*"]
set dac_ila [find_ila_with_probe "*camera_line_sync*"]
set acq_ila [find_ila_with_probe "*dl5_ila_acq_counts*"]
if {$eth_ila eq ""} { error "ETH diagnostic ILA not found" }
if {$dac_ila eq ""} { error "DAC/camera ILA not found" }
if {$acq_ila eq ""} { error "Acquisition-timing ILA not found" }

set eth_trig [find_probe_by_glob $eth_ila "*dl5_dbg_line_start_accept*"]
set dac_trig [find_probe_by_name $dac_ila {U6/N2/para_config_dout[33]}]
set acq_trig [find_probe_by_glob $acq_ila "*laser_pulse_ui*"]
if {$eth_trig eq ""} { error "ETH line-start trigger probe not found" }
if {$dac_trig eq ""} { error "DAC line-end marker probe not found" }
if {$acq_trig eq ""} { error "Acquisition laser-pulse trigger probe not found" }

foreach ila [list $eth_ila $dac_ila $acq_ila] {
    catch {set_property CONTROL.DATA_DEPTH 4096 $ila}
}
set_property CONTROL.TRIGGER_POSITION 0    $eth_ila
set_property CONTROL.TRIGGER_POSITION 3072 $dac_ila
set_property CONTROL.TRIGGER_POSITION 1024 $acq_ila
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $eth_trig
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $dac_trig
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $acq_trig

puts "ETH_ILA=$eth_ila TRIGGER=[get_property NAME $eth_trig]"
puts "DAC_ILA=$dac_ila TRIGGER=[get_property NAME $dac_trig]"
puts "ACQ_ILA=$acq_ila TRIGGER=[get_property NAME $acq_trig]"
run_hw_ila $eth_ila
run_hw_ila $dac_ila
run_hw_ila $acq_ila
puts "ARMED: all three ILAs; waiting for the next laser scan line"

foreach {label ila} [list eth_full_line $eth_ila dac_tail_camera $dac_ila acq_timing $acq_ila] {
    if {[catch {wait_on_hw_ila $ila -timeout 20} err]} {
        error "Capture timeout for $label: $err"
    }
    export_ila $ila $out_ila $label $ts
}
close_hw_manager
exit 0

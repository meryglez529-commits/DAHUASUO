#######################################################################
# Live laser-mode ILA diagnostic for the bitstream in this unit.
# Capture order: J9 input -> laser UI pulse -> DAC trigger.
#######################################################################

set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set ltx_file   [file join $unit_root "out" "bitstream" "ETH_TOP.ltx"]
set ila_out    [file join $unit_root "out" "ila"]
set work_dir   [file join $ila_out "vivado_hw_work"]
file mkdir $ila_out
file mkdir $work_dir
cd $work_dir

proc list_droot_hw_ila_dirs {} {
    return [lsort [glob -nocomplain -type d "D:/hw_ila_data_*"]]
}

proc archive_new_droot_hw_ila_dirs {before archive_dir} {
    file mkdir $archive_dir
    foreach d [list_droot_hw_ila_dirs] {
        if {[lsearch -exact $before $d] >= 0} { continue }
        set base [file tail $d]
        set dst [file join $archive_dir $base]
        set n 1
        while {[file exists $dst]} { set dst [file join $archive_dir "${base}_${n}"]; incr n }
        if {[catch {file rename $d $dst} err]} {
            puts "WARN: failed to archive D-root ILA spill $d: $err"
        } else {
            puts "ARCHIVED_DROOT_ILA_SPILL=$d -> $dst"
        }
    }
}

set scenario [lindex $argv 0]
if {$scenario eq ""} { set scenario "laser_input_live" }
set timeout_s [lindex $argv 1]
if {$timeout_s eq ""} { set timeout_s 30 }
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set droot_hw_ila_before [list_droot_hw_ila_dirs]

proc probe_name {probe} { return [get_property NAME $probe] }
proc find_probe_by_glob {ila pattern} {
    foreach p [get_hw_probes -of_objects $ila -quiet] {
        if {[string match $pattern [probe_name $p]]} { return $p }
    }
    return ""
}
proc find_ila_by_probe_glob {pattern} {
    foreach ila [get_hw_ilas -quiet] {
        if {[find_probe_by_glob $ila $pattern] ne ""} { return $ila }
    }
    return ""
}
proc arm_high {label ila probe_glob depth pos} {
    if {$ila eq ""} { puts "WARN: $label ILA not found"; return "missing" }
    catch {set_property CONTROL.DATA_DEPTH $depth $ila}
    catch {set_property CONTROL.TRIGGER_POSITION $pos $ila}
    set probe [find_probe_by_glob $ila $probe_glob]
    if {$probe eq ""} { puts "WARN: $label probe $probe_glob not found"; return "missing" }
    puts "ARM $label: [probe_name $probe] == 1"
    set_property TRIGGER_COMPARE_VALUE "eq1'b1" $probe
    run_hw_ila $ila
    return "armed"
}
proc save_ila {label ila mode out_dir scenario ts timeout_s} {
    if {$ila eq "" || $mode ne "armed"} { return "" }
    set tag "TRIG"
    if {[catch {wait_on_hw_ila $ila -timeout $timeout_s} err]} {
        puts "WARN: $label wait failed: $err"
        set tag "NOTRIG"
    }
    set data [upload_hw_ila_data $ila]
    set base [file join $out_dir "${scenario}_${label}_${tag}_${ts}"]
    write_hw_ila_data -force -csv_file "${base}.csv" $data
    catch {write_hw_ila_data -force -vcd_file "${base}.vcd" $data}
    puts "SAVED_${label}=${base}.csv"
    return "${base}.csv"
}

puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx_file"
if {![file exists $ltx_file]} { puts "ERROR: LTX not found"; exit 1 }

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
refresh_hw_device -quiet -update_hw_probes true $dev

set in_ila  [find_ila_by_probe_glob "*laser_sync_in"]
set ui_ila  [find_ila_by_probe_glob "*laser_pulse_ui_1"]
set adc_ila [find_ila_by_probe_glob "*adcdata1_acq/adc_tri_r1*"]
puts "INPUT_ILA=$in_ila"
puts "UI_ILA=$ui_ila"
puts "ADC_ILA=$adc_ila"

set in_mode  [arm_high "INPUT" $in_ila  "*laser_sync_in"          1024 128]
set ui_mode  [arm_high "UI"    $ui_ila  "*laser_pulse_ui_1"        1024 128]
set adc_mode [arm_high "ADC"   $adc_ila "*adcdata1_acq/adc_tri_r1*" 2048 512]

set in_csv  [save_ila "INPUT" $in_ila  $in_mode  $ila_out $scenario $ts $timeout_s]
set ui_csv  [save_ila "UI"    $ui_ila  $ui_mode  $ila_out $scenario $ts $timeout_s]
set adc_csv [save_ila "ADC"   $adc_ila $adc_mode $ila_out $scenario $ts $timeout_s]

set summary [file join $ila_out "${scenario}_summary_${ts}.txt"]
set fp [open $summary w]
puts $fp "scenario=$scenario"
puts $fp "timestamp=$ts"
puts $fp "ltx=$ltx_file"
puts $fp "input_csv=$in_csv"
puts $fp "ui_csv=$ui_csv"
puts $fp "adc_csv=$adc_csv"
close $fp
puts "SUMMARY=$summary"
archive_new_droot_hw_ila_dirs $droot_hw_ila_before [file join $ila_out "droot_spill"]
close_hw_manager
exit 0

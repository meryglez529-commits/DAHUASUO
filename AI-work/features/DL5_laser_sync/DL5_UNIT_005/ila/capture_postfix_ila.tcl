#######################################################################
# DL5_UNIT_005 post-fix ILA capture.
#
# Usage:
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_postfix_ila.tcl
#
# Capture groups:
#   - UI_ACQ  : U6/N2 dl5_acq timing, triggered by laser_pulse_ui_1
#   - ADC_ACQ : U5/adcdata1_acq state/acq_en, triggered by adc_tri_r1
#
# Re-send DL5 host parameters and start scanning after arming this script.
#######################################################################

set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set impl_dir  [file join $proj_root "AXI_DDR.runs" "impl_1"]
set ltx_file  [file join $impl_dir "ETH_TOP.ltx"]
set ila_out   [file join $unit_root "out" "ila"]
set work_dir  [file join $ila_out "vivado_hw_work"]
file mkdir $ila_out
file mkdir $work_dir
cd $work_dir

proc list_droot_hw_ila_dirs {} {
    return [lsort [glob -nocomplain -type d "D:/hw_ila_data_*"]]
}

proc archive_new_droot_hw_ila_dirs {before archive_dir} {
    file mkdir $archive_dir
    foreach d [list_droot_hw_ila_dirs] {
        if {[lsearch -exact $before $d] >= 0} {
            continue
        }
        set base [file tail $d]
        set dst [file join $archive_dir $base]
        set n 1
        while {[file exists $dst]} {
            set dst [file join $archive_dir "${base}_${n}"]
            incr n
        }
        if {[catch {file rename $d $dst} err]} {
            puts "WARN: failed to archive D-root ILA spill $d: $err"
        } else {
            puts "ARCHIVED_DROOT_ILA_SPILL=$d -> $dst"
        }
    }
}

set scenario [lindex $argv 0]
if {$scenario eq ""} { set scenario "postfix_dl5_acq" }
set timeout_s [lindex $argv 1]
if {$timeout_s eq ""} { set timeout_s 120 }
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

puts "============================================================"
puts "DL5_UNIT_005 ILA capture: scenario=$scenario"
puts "project_root=$proj_root"
puts "ltx=$ltx_file"
puts "out=$ila_out"
puts "hw_work_dir=$work_dir"
puts "timeout_s=$timeout_s"
puts "============================================================"

set droot_hw_ila_before [list_droot_hw_ila_dirs]

proc probe_name {probe} {
    return [get_property NAME $probe]
}

proc find_probe_by_glob {ila pattern} {
    foreach p [get_hw_probes -of_objects $ila -quiet] {
        set name [probe_name $p]
        if {[string match $pattern $name]} {
            return $p
        }
    }
    return ""
}

proc find_ila_by_probe_glob {pattern} {
    foreach ila [get_hw_ilas -quiet] {
        set p [find_probe_by_glob $ila $pattern]
        if {$p ne ""} {
            return $ila
        }
    }
    return ""
}

proc print_ila_probes {label ila} {
    if {$ila eq ""} {
        puts "WARN: $label ILA not found"
        return
    }
    puts ">>> $label ILA = $ila"
    foreach p [get_hw_probes -of_objects $ila -quiet] {
        puts "    [probe_name $p]"
    }
}

proc arm_ila_on_high {label ila trigger_glob trigger_pos depth} {
    if {$ila eq ""} {
        puts "WARN: $label: no ILA to arm"
        return "missing"
    }

    catch {set_property CONTROL.DATA_DEPTH $depth $ila}
    catch {set_property CONTROL.TRIGGER_POSITION $trigger_pos $ila}

    set trig [find_probe_by_glob $ila $trigger_glob]
    if {$trig eq ""} {
        puts "WARN: $label: trigger probe '$trigger_glob' not found; using trigger_now"
        run_hw_ila -trigger_now $ila
        return "trigger_now"
    }

    puts ">>> $label: arm on [probe_name $trig] == 1"
    set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trig
    run_hw_ila $ila
    return "armed"
}

proc wait_and_save_ila {label ila arm_mode out_dir scenario ts timeout_s} {
    if {$ila eq ""} {
        return ""
    }

    set tag "TRIG"
    if {$arm_mode eq "armed"} {
        puts ">>> $label: waiting up to ${timeout_s}s"
        if {[catch {wait_on_hw_ila $ila -timeout $timeout_s} err]} {
            puts "WARN: $label: trigger timeout/error: $err"
            puts "WARN: $label: forcing trigger_now for a diagnostic snapshot"
            catch {run_hw_ila -trigger_now $ila}
            catch {wait_on_hw_ila $ila -timeout 5}
            set tag "NOTRIG"
        }
    } else {
        catch {wait_on_hw_ila $ila -timeout 5}
        set tag "NOW"
    }

    set data [upload_hw_ila_data $ila]
    set safe_label $label
    regsub -all {[^A-Za-z0-9_]} $safe_label "_" safe_label
    set base [file join $out_dir "${scenario}_${safe_label}_${tag}_${ts}"]
    set csv "${base}.csv"
    set vcd "${base}.vcd"
    write_hw_ila_data -force -csv_file $csv $data
    catch {write_hw_ila_data -force -vcd_file $vcd $data}
    puts ">>> $label: saved $csv"
    return $csv
}

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]

set dev [lindex [get_hw_devices] 0]
puts ">>> hw_device = $dev"
current_hw_device $dev

set_property PROBES.FILE      $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev

set ila_count 0
for {set i 0} {$i < 12} {incr i} {
    refresh_hw_device -quiet -update_hw_probes true $dev
    set ila_count [llength [get_hw_ilas -quiet]]
    if {$ila_count > 0} {
        break
    }
    after 1000
}
puts ">>> ILA count = $ila_count"
if {$ila_count == 0} {
    puts "ERROR: no ILA cores found"
    exit 1
}

set ui_ila  [find_ila_by_probe_glob "*dl5_ila_acq_cfg*"]
set adc_ila [find_ila_by_probe_glob "*adcdata1_acq/adc_tri_r1*"]

print_ila_probes "UI_ACQ"  $ui_ila
print_ila_probes "ADC_ACQ" $adc_ila

set ui_mode  [arm_ila_on_high "UI_ACQ"  $ui_ila  "*laser_pulse_ui_1*" 128 1024]
set adc_mode [arm_ila_on_high "ADC_ACQ" $adc_ila "*adc_tri_r1*"      512 2048]

set ui_csv  [wait_and_save_ila "UI_ACQ"  $ui_ila  $ui_mode  $ila_out $scenario $ts $timeout_s]
set adc_csv [wait_and_save_ila "ADC_ACQ" $adc_ila $adc_mode $ila_out $scenario $ts $timeout_s]

set summary [file join $ila_out "${scenario}_capture_summary_${ts}.txt"]
set fp [open $summary w]
puts $fp "scenario=$scenario"
puts $fp "timestamp=$ts"
puts $fp "ltx=$ltx_file"
puts $fp "timeout_s=$timeout_s"
puts $fp "ui_ila=$ui_ila"
puts $fp "adc_ila=$adc_ila"
puts $fp "ui_csv=$ui_csv"
puts $fp "adc_csv=$adc_csv"
close $fp
puts ">>> summary saved $summary"

archive_new_droot_hw_ila_dirs $droot_hw_ila_before [file join $ila_out "droot_spill"]

close_hw_manager
exit 0

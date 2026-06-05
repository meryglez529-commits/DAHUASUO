#######################################################################
# DL5_UNIT_004 ILA capture for laser -> acquisition timing.
#
# Usage:
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/capture_ila.tcl -tclargs <scenario>
#
# Captures two domains in one run:
#   1) ui_clk  : laser_pulse_ui -> acq_delay/acq_time state machine -> acq_pulse_ui
#   2) adc_dco : adc_tri_r1 -> acq_en/adc_valid_point/adc_valid_point_cnt
#
# Register setup and external laser pulses are provided by host-app/board setup.
#######################################################################

set proj_root [file normalize [pwd]]
set impl_dir  [file join $proj_root "AXI_DDR.runs" "impl_1"]
set ltx_file  [file join $impl_dir "ETH_TOP.ltx"]
set ila_out   [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_004" "out" "ila"]
file mkdir $ila_out

set scenario [lindex $argv 0]
if {$scenario eq ""} { set scenario "laser_acq" }
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

puts "============================================================"
puts "DL5_UNIT_004 ILA capture: scenario=$scenario"
puts "ltx=$ltx_file"
puts "out=$ila_out"
puts "============================================================"

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
    set csv [file join $out_dir "${scenario}_${safe_label}_${tag}_${ts}.csv"]
    write_hw_ila_data -force -csv_file $csv $data
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
if {$adc_ila eq ""} {
    set adc_ila [find_ila_by_probe_glob "*adc_valid_point*"]
}

print_ila_probes "UI_ACQ"  $ui_ila
print_ila_probes "ADC_ACQ" $adc_ila

# Arm both ILAs before the user/host-app emits laser pulses.
set ui_mode  [arm_ila_on_high "UI_ACQ"  $ui_ila  "*laser_pulse_ui*" 128 1024]
set adc_mode [arm_ila_on_high "ADC_ACQ" $adc_ila "*adc_tri_r1*"     512 2048]

set ui_csv  [wait_and_save_ila "UI_ACQ"  $ui_ila  $ui_mode  $ila_out $scenario $ts 15]
set adc_csv [wait_and_save_ila "ADC_ACQ" $adc_ila $adc_mode $ila_out $scenario $ts 15]

set summary [file join $ila_out "${scenario}_capture_summary_${ts}.txt"]
set fp [open $summary w]
puts $fp "scenario=$scenario"
puts $fp "timestamp=$ts"
puts $fp "ltx=$ltx_file"
puts $fp "ui_ila=$ui_ila"
puts $fp "adc_ila=$adc_ila"
puts $fp "ui_csv=$ui_csv"
puts $fp "adc_csv=$adc_csv"
close $fp
puts ">>> summary saved $summary"

close_hw_manager
exit 0

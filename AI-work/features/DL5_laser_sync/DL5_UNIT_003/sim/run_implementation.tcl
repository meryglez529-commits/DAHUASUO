# DL5_UNIT_003 implementation timing check: run impl_1 through route_design.
#
# Usage:
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_implementation.tcl
#
# This script intentionally stops at routed timing and does not write a bitstream.

set start_time [clock seconds]
set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/impl"]

file mkdir $out_dir

puts "\n=========================================="
puts "DL5_UNIT_003 Implementation Timing Check"
puts "=========================================="
puts "Start: [clock format $start_time -format {%Y-%m-%d %H:%M:%S}]"
puts "Project: $xpr"
puts "Output: $out_dir"
puts ""

puts "INFO: Opening project..."
open_project $xpr

puts "\n--- Step 1: Check synth_1 status ---"
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]
puts "synth_1 STATUS: $synth_status"
puts "synth_1 PROGRESS: $synth_progress"

if {$synth_status ne "synth_design Complete!"} {
    puts "ERROR: synth_1 is not complete. Run run_synthesis.tcl first."
    exit 1
}

puts "\n--- Step 2: Reset impl_1 ---"
reset_run impl_1
puts "INFO: impl_1 reset"

puts "\n--- Step 3: Launch implementation through route_design ---"
puts "INFO: This may take a while for the full design with MIG/SGMII..."
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1

puts "\n--- Step 4: Check implementation status ---"
set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
puts "impl_1 STATUS: $impl_status"
puts "impl_1 PROGRESS: $impl_progress"

if {$impl_status ne "route_design Complete!"} {
    puts "ERROR: Implementation failed or did not reach route_design."
    puts "Check AXI_DDR.runs/impl_1/runme.log for details."
    catch {file copy -force AXI_DDR.runs/impl_1/runme.log [file join $out_dir "impl_runme.log"]}
    exit 1
}

puts "\n--- Step 5: Open routed design ---"
open_run impl_1 -name impl_1

puts "\n--- Step 6: Generate routed utilization report ---"
set util_rpt [file join $out_dir "utilization_routed.rpt"]
report_utilization -file $util_rpt
puts "Saved: $util_rpt"

puts "\n--- Step 7: Generate routed timing summary ---"
set timing_rpt [file join $out_dir "timing_summary_routed.rpt"]
report_timing_summary -file $timing_rpt -max_paths 20 -report_unconstrained -warn_on_violation
puts "Saved: $timing_rpt"

puts "\n=== Routed Timing Summary ==="
set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set hold_path  [get_timing_paths -delay_type min -max_paths 1 -nworst 1]

if {$setup_path ne ""} {
    set setup_slack [get_property SLACK $setup_path]
    puts "Setup WNS: $setup_slack ns"
    if {$setup_slack < 0} {
        puts "WARNING: Routed setup timing violation detected."
    } else {
        puts "INFO: Routed setup timing meets WNS >= 0."
    }
} else {
    puts "INFO: No routed setup timing path found."
}

if {$hold_path ne ""} {
    set hold_slack [get_property SLACK $hold_path]
    puts "Hold WHS: $hold_slack ns"
    if {$hold_slack < 0} {
        puts "WARNING: Routed hold timing violation detected."
    } else {
        puts "INFO: Routed hold timing meets WHS >= 0."
    }
} else {
    puts "INFO: No routed hold timing path found."
}

puts "\n--- Step 8: Generate routed bus skew report ---"
set bus_skew_rpt [file join $out_dir "bus_skew_routed.rpt"]
if {[catch {report_bus_skew -warn_on_violation -file $bus_skew_rpt} bus_skew_err]} {
    puts "WARNING: report_bus_skew failed or no bus skew constraints were found: $bus_skew_err"
} else {
    puts "Saved: $bus_skew_rpt"
}

puts "\n--- Step 9: Generate routed DRC report ---"
set drc_rpt [file join $out_dir "drc_routed.rpt"]
report_drc -file $drc_rpt
puts "Saved: $drc_rpt"

puts "\n--- Step 10: Copy implementation logs ---"
file copy -force AXI_DDR.runs/impl_1/runme.log [file join $out_dir "impl_runme.log"]
if {[file exists AXI_DDR.runs/impl_1/ETH_TOP_timing_summary_routed.rpt]} {
    file copy -force AXI_DDR.runs/impl_1/ETH_TOP_timing_summary_routed.rpt [file join $out_dir "ETH_TOP_timing_summary_routed.rpt"]
}

set end_time [clock seconds]
set elapsed [expr {$end_time - $start_time}]
puts "\n=========================================="
puts "Implementation Timing Check Complete"
puts "=========================================="
puts "Duration: $elapsed seconds ([expr {$elapsed/60}] minutes)"
puts "Reports saved to: $out_dir"
puts ""

close_project
exit 0

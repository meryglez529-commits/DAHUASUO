# Build the one-shot DL5 DAX diagnostic bitstream.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
set out_bit    [file join $unit_root "out" "bitstream"]
file mkdir $out_impl
file mkdir $out_bit
cd $out_impl

puts "PROJECT_ROOT=$proj_root"
puts "UNIT_ROOT=$unit_root"
puts "OUT_IMPL=$out_impl"

open_project [file join $proj_root "AXI_DDR.xpr"]

# This is a debug-IP-only configuration change.  Both depths are required to
# cover a full 16-pixel / 2-us laser line in their native clock domains.
foreach ip_name {ila_1 ila_2} {
    set ip [get_ips $ip_name]
    if {$ip eq ""} { error "Missing IP: $ip_name" }
    set_property CONFIG.C_DATA_DEPTH 4096 $ip
    if {$ip_name eq "ila_2"} {
        # ila_2 had widths stored for probe3..6 but only three active ports.
        set_property CONFIG.C_NUM_OF_PROBES 7 $ip
    }
    reset_target all $ip
    generate_target all $ip
    puts "DEBUG_IP: $ip_name depth=[get_property CONFIG.C_DATA_DEPTH $ip] probes=[get_property CONFIG.C_NUM_OF_PROBES $ip]"
}
# generate_target persists the modified XCI; Vivado 2021.1 has no
# parameterless save_project command for an already-open project.

# The project consumes these ILA cores through their OOC synthesis checkpoints.
# Rebuild those checkpoints before launching the top-level run so it cannot
# resolve the obsolete three-probe ila_2 or a missing post-reset ila_1 stub.
set diag_ip_runs {ila_1_synth_1 ila_2_synth_1}
foreach run_name $diag_ip_runs {
    if {[get_runs -quiet $run_name] eq ""} { error "Missing IP run: $run_name" }
    reset_run $run_name
}
launch_runs $diag_ip_runs -jobs 4
foreach run_name $diag_ip_runs {
    wait_on_run [get_runs $run_name]
    set status [get_property STATUS [get_runs $run_name]]
    puts "IP_RUN_STATUS: $run_name = $status"
    if {$status ne "synth_design Complete!"} {
        error "Diagnostic IP synthesis failed: $run_name = $status"
    }
}
update_compile_order -fileset sources_1

reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl [get_runs impl_1]
set status [get_property STATUS $impl]
puts "IMPL_STATUS=$status"
if {$status ne "write_bitstream Complete!"} {
    error "Diagnostic implementation did not complete: $status"
}

set run_dir [file join $proj_root "AXI_DDR.runs" "impl_1"]
# Project-managed runs execute out of process, so reopen the routed checkpoint
# before querying reports in this batch Tcl.
open_checkpoint [file join $run_dir "ETH_TOP_routed.dcp"]
report_timing_summary -file [file join $out_impl "timing_summary.rpt"]
report_utilization -file [file join $out_impl "utilization.rpt"]
report_drc -file [file join $out_impl "drc.rpt"]

file copy -force [file join $run_dir "ETH_TOP.bit"] [file join $out_bit "ETH_TOP_dl5_dax_diag.bit"]
file copy -force [file join $run_dir "ETH_TOP.ltx"] [file join $out_bit "ETH_TOP_dl5_dax_diag.ltx"]
puts "BITSTREAM=[file join $out_bit "ETH_TOP_dl5_dax_diag.bit"]"
puts "LTX=[file join $out_bit "ETH_TOP_dl5_dax_diag.ltx"]"
close_project
exit 0

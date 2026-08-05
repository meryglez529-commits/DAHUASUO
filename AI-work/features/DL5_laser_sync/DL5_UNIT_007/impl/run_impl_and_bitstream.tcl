set script_dir [file normalize [file dirname [info script]]]
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
update_compile_order -fileset sources_1

# No XCI, XDC, or BD mutation.  Existing ILA cores keep their configured widths
# and depths; only the already-existing probe payload nets are repacked.
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl [get_runs impl_1]
set status [get_property STATUS $impl]
puts "IMPL_STATUS=$status"
if {$status ne "write_bitstream Complete!"} {
    error "Implementation did not complete: $status"
}

set run_dir [file join $proj_root "AXI_DDR.runs" "impl_1"]
open_checkpoint [file join $run_dir "ETH_TOP_routed.dcp"]
report_timing_summary -file [file join $out_impl "timing_summary.rpt"]
report_utilization -file [file join $out_impl "utilization.rpt"]
report_drc -file [file join $out_impl "drc.rpt"]
file copy -force [file join $run_dir "ETH_TOP.bit"] [file join $out_bit "ETH_TOP_dl5_recovery_ack.bit"]
file copy -force [file join $run_dir "ETH_TOP.ltx"] [file join $out_bit "ETH_TOP_dl5_recovery_ack.ltx"]
puts "BITSTREAM=[file join $out_bit ETH_TOP_dl5_recovery_ack.bit]"
puts "LTX=[file join $out_bit ETH_TOP_dl5_recovery_ack.ltx]"
close_project
exit 0

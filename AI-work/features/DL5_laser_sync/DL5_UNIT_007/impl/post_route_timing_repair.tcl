set script_dir [file normalize [file dirname [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
set out_bit    [file join $unit_root "out" "bitstream"]
file mkdir $out_impl
file mkdir $out_bit
cd $out_impl

set routed_dcp [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP_routed.dcp"]
if {![file exists $routed_dcp]} { error "Missing routed checkpoint: $routed_dcp" }
open_checkpoint $routed_dcp

# One qualified repair attempt only: no RTL, IP, XDC, or project-run mutation.
phys_opt_design -directive Explore
route_design -directive Explore

report_timing_summary -file [file join $out_impl "post_route_repair_timing_summary.rpt"]
report_utilization -file [file join $out_impl "post_route_repair_utilization.rpt"]
report_drc -file [file join $out_impl "post_route_repair_drc.rpt"]
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "POST_ROUTE_WNS=$wns"
puts "POST_ROUTE_WHS=$whs"
if {$wns < 0.0 || $whs < 0.0} {
    write_checkpoint -force [file join $out_impl "ETH_TOP_dl5_recovery_unqualified.dcp"]
    error "Timing remains negative: WNS=$wns WHS=$whs"
}

write_checkpoint -force [file join $out_impl "ETH_TOP_dl5_recovery_qualified.dcp"]
write_debug_probes -force [file join $out_bit "ETH_TOP_dl5_recovery_ack_qualified.ltx"]
write_bitstream -force [file join $out_bit "ETH_TOP_dl5_recovery_ack_qualified.bit"]
close_design
exit 0

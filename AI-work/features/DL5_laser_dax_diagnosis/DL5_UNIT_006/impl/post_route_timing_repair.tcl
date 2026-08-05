# One post-route attempt for the diagnostic build. It starts from the routed
# checkpoint, so no RTL/IP is rebuilt and the original checkpoint stays intact.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
set out_bit    [file join $unit_root "out" "bitstream"]
file mkdir $out_impl
file mkdir $out_bit
cd $out_impl

set routed_dcp [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP_routed.dcp"]
if {![file exists $routed_dcp]} { error "Missing routed checkpoint: $routed_dcp" }

puts "PROJECT_ROOT=$proj_root"
puts "UNIT_ROOT=$unit_root"
puts "ROUTED_DCP=$routed_dcp"
open_checkpoint $routed_dcp

# The sole negative path is an unrelated SGMII-to-sys_clk endpoint whose
# data path is 85% routing. Re-optimize and route once without logical edits.
phys_opt_design -directive Explore
route_design -directive Explore

set timing_rpt [file join $out_impl "post_route_repair_timing_summary.rpt"]
report_timing_summary -file $timing_rpt
report_utilization -file [file join $out_impl "post_route_repair_utilization.rpt"]
report_drc -file [file join $out_impl "post_route_repair_drc.rpt"]

set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "POST_ROUTE_WNS=$wns"
puts "POST_ROUTE_WHS=$whs"
if {$wns < 0.0 || $whs < 0.0} {
    write_checkpoint -force [file join $out_impl "ETH_TOP_diag_post_route_unqualified.dcp"]
    error "Post-route repair did not meet timing: WNS=$wns WHS=$whs"
}

write_checkpoint -force [file join $out_impl "ETH_TOP_diag_post_route_qualified.dcp"]
write_debug_probes -force [file join $out_bit "ETH_TOP_dl5_dax_diag.ltx"]
write_bitstream -force [file join $out_bit "ETH_TOP_dl5_dax_diag.bit"]
puts "BITSTREAM=[file join $out_bit "ETH_TOP_dl5_dax_diag.bit"]"
puts "LTX=[file join $out_bit "ETH_TOP_dl5_dax_diag.ltx"]"
close_design
exit 0

# Generate a bitstream only from the routed DL1 implementation.
# No hardware-manager, JTAG, or board operation is performed.
set script_dir [file dirname [file normalize [info script]]]
set unit_root [file dirname $script_dir]
set proj_root [file normalize [file join $unit_root .. .. .. ..]]
set out_dir [file join $unit_root out bitstream]
file mkdir $out_dir
cd $out_dir

set xpr [file join $proj_root AXI_DDR.xpr]
open_project $xpr
set impl_status [get_property STATUS [get_runs impl_1]]
if {$impl_status ne "route_design Complete!" && $impl_status ne "write_bitstream Complete!"} {
    puts "ERROR: impl_1 must be routed before bitstream generation; status=$impl_status"
    close_project
    exit 1
}

if {$impl_status ne "write_bitstream Complete!"} {
    launch_runs impl_1 -to_step write_bitstream -jobs 2
    wait_on_run impl_1
}
set final_status [get_property STATUS [get_runs impl_1]]
set fp [open [file join $out_dir run_status.txt] w]
puts $fp "impl_1=$final_status"
close $fp

foreach source_name {ETH_TOP.bit ETH_TOP.bin ETH_TOP.ltx runme.log ETH_TOP_timing_summary_routed.rpt ETH_TOP_drc_routed.rpt} {
    set source_file [file join $proj_root AXI_DDR.runs impl_1 $source_name]
    if {[file exists $source_file]} { file copy -force $source_file [file join $out_dir $source_name] }
}
close_project
if {$final_status eq "write_bitstream Complete!" && [file exists [file join $out_dir ETH_TOP.bit]]} { exit 0 }
exit 1

# Resume from the fresh current synth_1 and rebuild implementation through route_design.
set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set unit_root [file join $proj_root AI-work features camera_line_sync DL1_UNIT_001]
set out_dir [file join $unit_root out impl]
file mkdir $out_dir
open_project [file join $proj_root AXI_DDR.xpr]
reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
set fp [open [file join $out_dir run_status.txt] w]
puts $fp "impl_1=$impl_status"
close $fp
foreach source_name {runme.log ETH_TOP_timing_summary_routed.rpt ETH_TOP_utilization_placed.rpt ETH_TOP_drc_routed.rpt ETH_TOP_methodology_drc_routed.rpt ETH_TOP_route_status.rpt} {
    set source_file [file join $proj_root AXI_DDR.runs impl_1 $source_name]
    if {[file exists $source_file]} { file copy -force $source_file [file join $out_dir $source_name] }
}
close_project
if {[string match "*route_design Complete*" $impl_status]} { exit 0 }
exit 1

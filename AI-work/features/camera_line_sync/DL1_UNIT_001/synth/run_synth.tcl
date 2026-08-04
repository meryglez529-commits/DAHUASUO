set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set unit_root [file join $proj_root AI-work features camera_line_sync DL1_UNIT_001]
set out_dir [file join $unit_root out synth]
file mkdir $out_dir
open_project [file join $proj_root AXI_DDR.xpr]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
set synth_run [get_runs synth_1]
set status [get_property STATUS $synth_run]
set fp [open [file join $out_dir synth_status.txt] w]
puts $fp $status
close $fp
foreach source_name {runme.log synth_1_utilization_synth.rpt synth_1_timing_summary_routed.rpt} {
    set source_file [file join $proj_root AXI_DDR.runs synth_1 $source_name]
    if {[file exists $source_file]} { file copy -force $source_file [file join $out_dir $source_name] }
}
close_project
if {[string match "*Complete*" $status]} { exit 0 }
exit 1

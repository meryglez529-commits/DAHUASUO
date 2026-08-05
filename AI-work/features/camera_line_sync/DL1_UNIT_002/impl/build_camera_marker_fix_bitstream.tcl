# Fresh implementation for the DL1_UNIT_002 RTL and existing diagnostic ILA IP.
# It intentionally does not reset, regenerate, or modify any XCI/XDC/BD file.
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

# Assert the already-approved diagnostic IP shape, but do not change it.
foreach {ip_name expected_depth expected_probes} {ila_1 1024 7 ila_2 4096 7 ila_dl5_eth 4096 7} {
    set ip [get_ips -quiet $ip_name]
    if {$ip eq ""} { error "Missing required existing ILA IP: $ip_name" }
    set actual_depth [get_property CONFIG.C_DATA_DEPTH $ip]
    set actual_probes [get_property CONFIG.C_NUM_OF_PROBES $ip]
    puts "ILA_IP: $ip_name depth=$actual_depth probes=$actual_probes"
    if {$actual_depth != $expected_depth || $actual_probes != $expected_probes} {
        error "Unexpected $ip_name configuration; refusing to modify XCI automatically"
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
    error "DL1_UNIT_002 implementation did not complete: $status"
}

set run_dir [file join $proj_root "AXI_DDR.runs" "impl_1"]
open_checkpoint [file join $run_dir "ETH_TOP_routed.dcp"]
report_timing_summary -file [file join $out_impl "timing_summary.rpt"]
report_utilization -file [file join $out_impl "utilization.rpt"]
report_drc -file [file join $out_impl "drc.rpt"]
file copy -force [file join $run_dir "ETH_TOP.bit"] [file join $out_bit "ETH_TOP_camera_marker_fix.bit"]
file copy -force [file join $run_dir "ETH_TOP.ltx"] [file join $out_bit "ETH_TOP_camera_marker_fix.ltx"]
foreach filename {runme.log ETH_TOP_timing_summary_routed.rpt ETH_TOP_drc_routed.rpt} {
    set source_file [file join $run_dir $filename]
    if {[file exists $source_file]} {
        file copy -force $source_file [file join $out_impl $filename]
    }
}
puts "BITSTREAM=[file join $out_bit "ETH_TOP_camera_marker_fix.bit"]"
puts "LTX=[file join $out_bit "ETH_TOP_camera_marker_fix.ltx"]"
close_project
exit 0

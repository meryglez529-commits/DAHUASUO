# Read-only inventory of live ILA probes for the DAX scope-anomaly diagnosis.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set ila_out    [file join $unit_root "out" "ila"]
set work_dir   [file join $ila_out "vivado_hw_work"]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
file mkdir $ila_out
file mkdir $work_dir
cd $work_dir
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set report_file [file join $ila_out "dax_anomaly_probe_inventory_${ts}.txt"]

puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"
puts "LTX=$ltx_file"

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -url localhost:3121 -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
refresh_hw_device -quiet -update_hw_probes true $dev

set fp [open $report_file w]
puts $fp "device=$dev"
puts $fp "ltx=$ltx_file"
foreach ila [get_hw_ilas -quiet] {
    puts $fp "ILA=$ila"
    foreach probe [get_hw_probes -of_objects $ila -quiet] {
        puts $fp "  [get_property NAME $probe]"
    }
}
close $fp
puts "PROBE_INVENTORY=$report_file"
close_hw_manager
exit 0

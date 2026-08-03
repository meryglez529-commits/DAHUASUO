set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ".." ".."]]
set out_dir    [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_005" "out" "hw_debug"]
set work_dir   [file join $out_dir "vivado_hw_work"]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
file mkdir $work_dir
cd $work_dir
puts "PROJECT_ROOT=$proj_root"
puts "HW_WORK_DIR=$work_dir"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t_0] 0]
if {$dev eq ""} {
    set dev [lindex [get_hw_devices] 0]
}
current_hw_device $dev
set_property PROBES.FILE $ltx_file $dev
refresh_hw_device $dev

foreach ila [get_hw_ilas] {
    puts "=== $ila ==="
    foreach p {NAME CELL_NAME CORE_REFRESH_RATE CORE_STATUS DATA_DEPTH CONTROL.DATA_DEPTH INPUT_PIPE_STAGES C_CLK_INPUT_FREQ_HZ} {
        if {![catch {set v [get_property $p $ila]}]} {
            puts "$p=$v"
        }
    }
    puts "PROBES=[get_hw_probes -of_objects $ila]"
}

close_hw_manager

#######################################################################
# Probe where Vivado Hardware Manager creates hw_ila_data_* artifacts.
#
# Usage:
#   vivado.bat -mode batch -source AI-work/scripts/probe_ila_workdir_behavior.tcl
#
# This script intentionally avoids exporting CSV/VCD. It only refreshes
# the hardware device after cd'ing into a controlled work directory.
#######################################################################

proc list_hw_ila_dirs {dir} {
    set dirs [glob -nocomplain -type d [file join $dir "hw_ila_data_*"]]
    return [lsort $dirs]
}

proc print_dir_delta {label before after} {
    puts "${label}_BEFORE_COUNT=[llength $before]"
    puts "${label}_AFTER_COUNT=[llength $after]"
    foreach d $after {
        if {[lsearch -exact $before $d] < 0} {
            puts "${label}_NEW=$d"
        }
    }
}

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ".." ".."]]
set out_dir    [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_005" "out" "hw_debug" "ila_workdir_probe"]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]

file mkdir $out_dir

set d_root_before [list_hw_ila_dirs "D:/"]
set appdata_before [list_hw_ila_dirs "C:/Users/Administrator/AppData/Roaming/Xilinx/Vivado"]
set work_before [list_hw_ila_dirs $out_dir]

puts "PWD_INITIAL=[pwd]"
puts "PROJECT_ROOT=$proj_root"
puts "WORK_DIR=$out_dir"
puts "LTX_FILE=$ltx_file"
cd $out_dir
puts "PWD_AFTER_CD=[pwd]"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t_0] 0]
if {$dev eq ""} {
    set dev [lindex [get_hw_devices] 0]
}
if {$dev eq ""} {
    error "No hardware device found"
}

current_hw_device $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
    catch {set_property FULL_PROBES.FILE $ltx_file $dev}
}
refresh_hw_device -quiet -update_hw_probes true $dev
puts "ILA_COUNT=[llength [get_hw_ilas -quiet]]"

close_hw_manager

set d_root_after [list_hw_ila_dirs "D:/"]
set appdata_after [list_hw_ila_dirs "C:/Users/Administrator/AppData/Roaming/Xilinx/Vivado"]
set work_after [list_hw_ila_dirs $out_dir]

print_dir_delta "D_ROOT" $d_root_before $d_root_after
print_dir_delta "APPDATA" $appdata_before $appdata_after
print_dir_delta "WORK_DIR" $work_before $work_after

# DL5_UNIT_007 GUI replay entry. In Vivado GUI Tcl Console, run:
# source AI-work/features/DL5_laser_sync/DL5_UNIT_007/sim/run_gui.tcl
# This builds the same isolated behavioral testbench as run_batch.tcl and
# opens XSim. It does not change the project or generate FPGA output files.
set script_dir [file normalize [file dirname [info script]]]
set unit_root [file normalize [file join $script_dir ".."]]
set proj_root [file normalize [file join $unit_root ".." ".." ".." ".."]]
set sim_dir [file join $unit_root "out" "sim" "gui_work"]
file mkdir $sim_dir

set vivado_bin [file dirname [info nameofexecutable]]
set xvlog_exe [file join $vivado_bin "xvlog"]
set xelab_exe [file join $vivado_bin "xelab"]
set prj_file [file join $sim_dir "dl5_unit007_gui.prj"]
set fp [open $prj_file w]
foreach f [list \
    [file join $unit_root "sim" "dl5_unit_007_stubs.v"] \
    [file join $proj_root "AXI_DDR.srcs" "sources_1" "new" "parameter_dacdata_gen.v"] \
    [file join $proj_root "AXI_DDR.srcs" "sources_1" "new" "dac_output.v"] \
    [file join $unit_root "sim" "tb_dl5_unit_007.v"]] {
    puts $fp "verilog xil_defaultlib \"$f\""
}
puts $fp "nosort"
close $fp

set old_pwd [pwd]
cd $sim_dir
if {[catch {exec $xvlog_exe --relax -sv -prj $prj_file -log xvlog_gui.log} err]} { error $err }
if {[catch {exec $xelab_exe --debug typical --relax --snapshot tb_dl5_unit_007_gui xil_defaultlib.tb_dl5_unit_007 -log xelab_gui.log} err]} { error $err }
cd $old_pwd
xsim tb_dl5_unit_007_gui -gui

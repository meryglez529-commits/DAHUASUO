# DL5_UNIT_005 simulation runner.
# Follows AI-work/guide/VIVADO_SIM_SOP.md:
#   exec xvlog/xelab, then use Vivado Tcl built-in xsim.

set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set sim_dir [file join $proj_root "AXI_DDR.sim" "sim_1" "behav" "xsim"]
set unit_root [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_005"]
set out_dir [file join $unit_root "out" "sim"]
set result_file [file join $out_dir "result.txt"]
set tb_result_file [file join $sim_dir "dl5_unit005_tb_result.txt"]

file mkdir $out_dir
file mkdir $sim_dir

open_project $xpr
set_property target_simulator XSim [current_project]

set vivado_bin [file dirname [info nameofexecutable]]
set xvlog_exe [file join $vivado_bin "xvlog"]
set xelab_exe [file join $vivado_bin "xelab"]

set src_files [list]
lappend src_files [file join $unit_root "sim" "dl5_unit_005_stubs.v"]
lappend src_files [file join $proj_root "AXI_DDR.srcs" "sources_1" "new" "adcdata_acq.v"]
lappend src_files [file join $unit_root "sim" "tb_dl5_unit_005_adc_trigger_wait.v"]

set glbl_file [file join $sim_dir "glbl.v"]
if {![file exists $glbl_file]} {
    file copy [file join $vivado_bin ".." "data" "verilog" "src" "glbl.v"] $glbl_file
}
lappend src_files $glbl_file

set orig_dir [pwd]
cd $sim_dir
file delete -force $tb_result_file

set prj_file [file join $sim_dir "dl5_unit005.prj"]
set fp [open $prj_file w]
foreach f $src_files {
    puts $fp "verilog xil_defaultlib \"$f\""
}
puts $fp "nosort"
close $fp

puts "INFO: === XVLOG ==="
set xvlog_cmd [list $xvlog_exe --relax -sv -prj $prj_file -log [file join $sim_dir "xvlog_unit005.log"]]
puts "INFO: $xvlog_cmd"
catch {exec {*}$xvlog_cmd} xvlog_out
puts $xvlog_out
set fp [open [file join $sim_dir "xvlog_unit005.log"] r]
set xvlog_log [read $fp]
close $fp
if {[string match "*ERROR*" $xvlog_log]} {
    set fp [open $result_file w]
    puts $fp "FAIL: xvlog error"
    close $fp
    cd $orig_dir
    close_project
    exit 1
}
puts "INFO: xvlog PASS"

puts "INFO: === XELAB ==="
set xelab_cmd [list $xelab_exe --debug typical --relax --mt 2 \
    -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -L xpm \
    --snapshot tb_dl5_unit_005_adc_trigger_wait_behav \
    xil_defaultlib.tb_dl5_unit_005_adc_trigger_wait xil_defaultlib.glbl \
    -log [file join $sim_dir "xelab_unit005.log"]]
puts "INFO: $xelab_cmd"
catch {exec {*}$xelab_cmd} xelab_out
puts $xelab_out
set fp [open [file join $sim_dir "xelab_unit005.log"] r]
set xelab_log [read $fp]
close $fp
if {![string match "*Built simulation snapshot*" $xelab_log]} {
    set fp [open $result_file w]
    puts $fp "FAIL: xelab did not build snapshot"
    close $fp
    cd $orig_dir
    close_project
    exit 1
}
puts "INFO: xelab PASS"

puts "INFO: === XSIM ==="
set snapshot_path [file join $sim_dir "xsim.dir" "tb_dl5_unit_005_adc_trigger_wait_behav"]
if {![file exists $snapshot_path]} {
    set fp [open $result_file w]
    puts $fp "FAIL: snapshot not found"
    close $fp
    cd $orig_dir
    close_project
    exit 1
}

xsim tb_dl5_unit_005_adc_trigger_wait_behav -log [file join $sim_dir "xsim_unit005.log"]
run 200 us
catch {close_sim}

set xsim_log ""
catch {
    set fp [open [file join $sim_dir "xsim_unit005.log"] r]
    set xsim_log [read $fp]
    close $fp
}
puts $xsim_log

foreach f {xvlog_unit005.log xelab_unit005.log xsim_unit005.log tb_dl5_unit_005_adc_trigger_wait_behav.wdb dl5_unit005_tb_result.txt} {
    set src [file join $sim_dir $f]
    if {[file exists $src]} {
        file copy -force $src [file join $out_dir $f]
    }
}

set pass 0
set tb_result ""
if {[file exists $tb_result_file]} {
    set fp [open $tb_result_file r]
    set tb_result [string trim [read $fp]]
    close $fp
}
if {$tb_result eq "PASS"} {
    set pass 1
}

set fp [open $result_file w]
if {$pass} {
    puts $fp "PASS"
    puts "INFO: result = PASS"
} else {
    puts $fp "FAIL"
    puts "INFO: result = FAIL ($tb_result)"
}
close $fp

cd $orig_dir
close_project

if {!$pass} {
    exit 1
}
exit 0

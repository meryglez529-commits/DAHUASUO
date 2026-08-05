set script_dir [file normalize [file dirname [info script]]]
set unit_root [file normalize [file join $script_dir ".."]]
set proj_root [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_dir [file join $unit_root "out" "sim"]
set sim_dir [file join $out_dir "work"]
file mkdir $sim_dir
file mkdir $out_dir

set vivado_bin [file dirname [info nameofexecutable]]
set xvlog_exe [file join $vivado_bin "xvlog"]
set xelab_exe [file join $vivado_bin "xelab"]
set prj_file [file join $sim_dir "dl5_unit007.prj"]
set result_file [file join $out_dir "result.txt"]
set tb_result [file join $sim_dir "dl5_unit007_tb_result.txt"]
file delete -force $result_file $tb_result

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

set orig_dir [pwd]
cd $sim_dir
catch {exec $xvlog_exe --relax -sv -prj $prj_file -log xvlog.log}
set log [read [open "xvlog.log" r]]
if {[string match "*ERROR*" $log]} { puts [open $result_file w] "FAIL: xvlog"; exit 1 }
catch {exec $xelab_exe --debug typical --relax --mt 2 --snapshot tb_dl5_unit_007_behav xil_defaultlib.tb_dl5_unit_007 -log xelab.log}
set log [read [open "xelab.log" r]]
if {![string match "*Built simulation snapshot*" $log]} { puts [open $result_file w] "FAIL: xelab"; exit 1 }
xsim tb_dl5_unit_007_behav -log xsim.log
run 100 us
catch {close_sim}
foreach f {xvlog.log xelab.log xsim.log dl5_unit007_tb_result.txt tb_dl5_unit_007_behav.wdb} {
    if {[file exists $f]} { file copy -force $f [file join $out_dir $f] }
}
set pass 0
if {[file exists $tb_result] && [string trim [read [open $tb_result r]]] eq "PASS"} { set pass 1 }
set fp [open $result_file w]
if {$pass} { puts $fp "PASS" } else { puts $fp "FAIL" }
close $fp
cd $orig_dir
if {!$pass} { exit 1 }
exit 0

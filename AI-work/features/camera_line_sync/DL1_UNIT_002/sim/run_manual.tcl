# Vivado Tcl-hosted xsim flow required by AI-work/guide/VIVADO_SIM_SOP.md.
set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set unit_root [file join $proj_root AI-work features camera_line_sync DL1_UNIT_002]
set out_dir [file join $unit_root out sim]
set work_dir [file join $out_dir work]
set result_file [file join $out_dir result.txt]
file mkdir $work_dir
open_project [file join $proj_root AXI_DDR.xpr]
set vivado_bin [file dirname [info nameofexecutable]]
set src_files [list \
    [file join $unit_root sim dl1_unit_002_stubs.v] \
    [file join $proj_root AXI_DDR.srcs sources_1 new parameter_dacdata_gen.v] \
    [file join $proj_root AXI_DDR.srcs sources_1 new dac_output.v] \
    [file join $unit_root sim tb_dl1_unit_002_marker_alignment.v]]
set glbl_file [file join $work_dir glbl.v]
file copy -force {D:/Xilinx/Vivado/2021.1/data/verilog/src/glbl.v} $glbl_file
lappend src_files $glbl_file
set original_dir [pwd]
cd $work_dir
set prj_file [file join $work_dir dl1_unit_002.prj]
set fp [open $prj_file w]
foreach f $src_files {
    puts $fp "verilog xil_defaultlib \"$f\""
}
puts $fp nosort
close $fp

catch {exec [file join $vivado_bin xvlog] --relax -prj $prj_file -log [file join $out_dir xvlog.log]}
set fp [open [file join $out_dir xvlog.log] r]
set xvlog_log [read $fp]
close $fp
if {[string match "*ERROR*" $xvlog_log]} {
    set fp [open $result_file w]; puts $fp "FAIL: xvlog"; close $fp
    cd $original_dir; close_project; exit 1
}

catch {exec [file join $vivado_bin xelab] --debug typical --relax --mt 2 \
    -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -L xpm \
    --snapshot tb_dl1_unit_002_marker_alignment_behav \
    xil_defaultlib.tb_dl1_unit_002_marker_alignment xil_defaultlib.glbl \
    -log [file join $out_dir xelab.log]}
set fp [open [file join $out_dir xelab.log] r]
set xelab_log [read $fp]
close $fp
if {![string match "*Built simulation snapshot*" $xelab_log]} {
    set fp [open $result_file w]; puts $fp "FAIL: xelab"; close $fp
    cd $original_dir; close_project; exit 1
}

xsim tb_dl1_unit_002_marker_alignment_behav -log [file join $out_dir xsim.log]
run all
catch {close_sim}
set fp [open [file join $out_dir xsim.log] r]
set xsim_log [read $fp]
close $fp
set fp [open $result_file w]
if {[string match "*PASS: DL1_UNIT_002*" $xsim_log] && ![string match "*FAIL:*" $xsim_log]} {
    puts $fp PASS
    close $fp
    cd $original_dir
    close_project
    exit 0
}
puts $fp FAIL
close $fp
cd $original_dir
close_project
exit 1

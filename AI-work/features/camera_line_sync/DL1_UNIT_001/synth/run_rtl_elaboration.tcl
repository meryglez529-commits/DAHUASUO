set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set out_dir [file join $proj_root AI-work features camera_line_sync DL1_UNIT_001 out synth]
file mkdir $out_dir
open_project [file join $proj_root AXI_DDR.xpr]
synth_design -rtl -top ETH_TOP -part xc7k325tffg676-2
report_property [current_design] -file [file join $out_dir rtl_elaboration_properties.rpt]
close_project
exit

set proj_root [file normalize {D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj}]
set unit_root [file join $proj_root AI-work features camera_line_sync DL1_UNIT_001]
set simset [get_filesets sim_1]
add_files -fileset $simset [file join $unit_root sim dl1_unit_001_stubs.v]
add_files -fileset $simset [file join $unit_root sim tb_dl1_unit_001_camera_line_sync.v]
set_property top tb_dl1_unit_001_camera_line_sync $simset
set_property top_lib xil_defaultlib $simset
update_compile_order -fileset sim_1
launch_simulation

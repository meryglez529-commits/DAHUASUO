# 验证 DL5 新文件是否已经在 Vivado 项目里
open_project [lindex $argv 0]
set found [get_files -of_objects [get_filesets sources_1] -filter "NAME =~ *laser_sync_blanker_ctrl*"]
puts "VERIFY: laser_sync_blanker_ctrl in sources_1: $found"
set found_tb [get_files -of_objects [get_filesets sim_1] -filter "NAME =~ *tb_laser_sync_blanker_ctrl*"]
puts "VERIFY: tb_laser_sync_blanker_ctrl in sim_1: $found_tb"
close_project
exit 0

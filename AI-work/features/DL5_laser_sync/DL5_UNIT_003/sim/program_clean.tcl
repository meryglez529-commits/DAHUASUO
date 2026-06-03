# 烧录干净(pre-DL5)工程的 bit + ltx,作为对照实验
set bit "D:/SGSC_SEM_dahuasuo_325T_V3_173/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj/AXI_DDR.runs/impl_1/ETH_TOP.bit"
set ltx "D:/SGSC_SEM_dahuasuo_325T_V3_173/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj/AXI_DDR.runs/impl_1/ETH_TOP.ltx"

puts "=== Programming clean (pre-DL5) bitstream for control experiment ==="
puts "BIT: $bit"
puts "LTX: $ltx"

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev
program_hw_devices $dev
puts "PROGRAMMED. Disconnecting JTAG so host-app can use ethernet freely."
close_hw_manager
exit 0

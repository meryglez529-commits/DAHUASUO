# 烧录新生成的 DL5 bitstream，并用配套 LTX 验证 ILA probe 名字可解析
set proj_root [file normalize [pwd]]
set bit [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.bit"]
set ltx [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]

puts "\n=== Program FPGA with fresh DL5 bitstream ==="
puts "BIT: $bit"
puts "LTX: $ltx"

open_hw_manager
connect_hw_server
set targets [get_hw_targets]
if {[llength $targets] == 0} { puts "ERROR: no hw target"; exit 1 }
open_hw_target [lindex $targets 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev

set_property PROGRAM.FILE $bit $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev

puts "\nProgramming device..."
program_hw_devices $dev
refresh_hw_device $dev

puts "\n=== Verify ILA probes resolve correctly ==="
set ilas [get_hw_ilas]
puts "ILA count: [llength $ilas]"
set matched 0
foreach ila $ilas {
    set probes [get_hw_probes -of_objects $ila -quiet]
    if {[llength $probes] > 0} {
        incr matched
        puts "\nILA $ila  (probe count [llength $probes])"
        foreach probe $probes { puts "   [get_property NAME $probe -quiet]" }
    }
}
puts "\nILAs with resolved probes: $matched / [llength $ilas]"
if {$matched == 0} {
    puts "ERROR: no probes resolved -- LTX/bitstream mismatch."
    exit 1
}

close_hw_manager
puts "\n=== Programmed and verified. ==="
exit 0

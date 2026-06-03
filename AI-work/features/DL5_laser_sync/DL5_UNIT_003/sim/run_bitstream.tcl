# DL5_UNIT_003 bitstream generation.
#
# Usage:
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_bitstream.tcl
#
# Prerequisite:
#   impl_1 should already have reached route_design Complete!.

set start_time [clock seconds]
set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/bitstream"]

file mkdir $out_dir

puts "\n=========================================="
puts "DL5_UNIT_003 Bitstream Generation"
puts "=========================================="
puts "Start: [clock format $start_time -format {%Y-%m-%d %H:%M:%S}]"
puts "Project: $xpr"
puts "Output: $out_dir"
puts ""

puts "INFO: Opening project..."
open_project $xpr

puts "\n--- Step 1: Check impl_1 status ---"
set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
puts "impl_1 STATUS: $impl_status"
puts "impl_1 PROGRESS: $impl_progress"

if {$impl_status ne "route_design Complete!" && $impl_status ne "write_bitstream Complete!"} {
    puts "ERROR: impl_1 is not routed yet. Run run_implementation.tcl first."
    puts "Current STATUS: $impl_status"
    exit 1
}

puts "\n--- Step 2: Launch write_bitstream ---"
if {$impl_status eq "write_bitstream Complete!"} {
    puts "INFO: write_bitstream already complete; skip launching impl_1."
} else {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
}

puts "\n--- Step 3: Check write_bitstream status ---"
set final_status [get_property STATUS [get_runs impl_1]]
set final_progress [get_property PROGRESS [get_runs impl_1]]
puts "impl_1 STATUS: $final_status"
puts "impl_1 PROGRESS: $final_progress"

if {$final_status ne "write_bitstream Complete!"} {
    puts "ERROR: write_bitstream did not complete."
    catch {file copy -force AXI_DDR.runs/impl_1/runme.log [file join $out_dir "bitstream_runme.log"]}
    exit 1
}

puts "\n--- Step 4: Archive bitstream output ---"
set bit_src [file normalize "AXI_DDR.runs/impl_1/ETH_TOP.bit"]
set bit_dst [file join $out_dir "ETH_TOP_unit003.bit"]

if {![file exists $bit_src]} {
    puts "ERROR: Bitstream not found: $bit_src"
    exit 1
}

file copy -force $bit_src $bit_dst
puts "Saved: $bit_dst"

set ltx_src [file normalize "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]
if {[file exists $ltx_src]} {
    set ltx_dst [file join $out_dir "ETH_TOP_unit003.ltx"]
    file copy -force $ltx_src $ltx_dst
    puts "Saved: $ltx_dst"
}

catch {file copy -force AXI_DDR.runs/impl_1/runme.log [file join $out_dir "bitstream_runme.log"]}

set end_time [clock seconds]
set elapsed [expr {$end_time - $start_time}]
puts "\n=========================================="
puts "Bitstream Generation Complete"
puts "=========================================="
puts "Duration: $elapsed seconds ([expr {$elapsed/60}] minutes)"
puts "Bitstream: $bit_dst"
puts ""

close_project
exit 0

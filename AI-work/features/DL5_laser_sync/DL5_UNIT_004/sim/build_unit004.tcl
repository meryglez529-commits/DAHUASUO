#######################################################################
# DL5_UNIT_004 重新构建脚本
# 目的：用当前源码（含 UNIT_004 改动 + 已回退 dac_output.v）重新生成 bit
#
# 背景：现有 ETH_TOP.bit 是 2026-06-04 18:56 生成的，早于 UNIT_004 源码
#       改动（20:23~21:46），且含已回退的越界 ILA。必须重新构建。
#
# 用法：
#   vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/build_unit004.tcl
#######################################################################

set proj_root [pwd]
set out_dir "$proj_root/AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/build"
file mkdir $out_dir

puts "============================================================"
puts "DL5_UNIT_004 REBUILD START"
puts "proj_root = $proj_root"
puts "============================================================"

# 1. 打开工程
open_project AXI_DDR.xpr

# 2. 确认顶层和源文件已是最新（Vivado 会按 mtime 判断 out-of-date）
update_compile_order -fileset sources_1

# 3. 复位旧的 synth/impl run（强制重新综合，避免用旧网表）
puts ">>> reset_run synth_1 / impl_1"
reset_run impl_1
reset_run synth_1

# 4. 综合
puts ">>> launch synth_1"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synth_1 failed"
    exit 1
}
puts ">>> synth_1 done"

# 5. 实现 + 生成 bitstream
puts ">>> launch impl_1 (to bitstream)"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: impl_1 failed"
    exit 1
}
puts ">>> impl_1 + bitstream done"

# 6. 拷贝时序摘要和 bit/ltx 到 UNIT_004 输出目录
set impl_dir "$proj_root/AXI_DDR.runs/impl_1"
if {[file exists "$impl_dir/ETH_TOP.bit"]} {
    file copy -force "$impl_dir/ETH_TOP.bit" "$out_dir/ETH_TOP_unit004.bit"
    puts ">>> bit copied to $out_dir/ETH_TOP_unit004.bit"
}
if {[file exists "$impl_dir/ETH_TOP.ltx"]} {
    file copy -force "$impl_dir/ETH_TOP.ltx" "$out_dir/ETH_TOP_unit004.ltx"
    puts ">>> ltx copied to $out_dir/ETH_TOP_unit004.ltx"
}

# 7. 打开实现后的设计，导出时序摘要
open_run impl_1
set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
puts "============================================================"
puts "TIMING: WNS = $wns ns,  WHS = $whs ns"
puts "============================================================"
report_timing_summary -file "$out_dir/timing_summary_unit004.rpt"
report_utilization     -file "$out_dir/utilization_unit004.rpt"

# 8. 写一个简单的构建结果标记
set fp [open "$out_dir/build_result.txt" w]
if {$wns >= 0 && $whs >= 0} {
    puts $fp "BUILD PASS"
    puts $fp "WNS=$wns WHS=$whs"
    puts ">>> BUILD PASS (WNS=$wns WHS=$whs)"
} else {
    puts $fp "BUILD TIMING FAIL"
    puts $fp "WNS=$wns WHS=$whs"
    puts ">>> BUILD TIMING FAIL (WNS=$wns WHS=$whs)"
}
close $fp

puts "============================================================"
puts "DL5_UNIT_004 REBUILD COMPLETE"
puts "============================================================"

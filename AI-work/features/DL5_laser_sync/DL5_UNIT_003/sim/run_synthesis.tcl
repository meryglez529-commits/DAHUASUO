# DL5_UNIT_003 综合验证：batch 模式重跑 synth_1 + 提取 timing/utilization 报告
#
# 用法：vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/run_synthesis.tcl
#
# 改动内容：
# - fifo_generator_4 IP 阈值 20→2（已在 GUI 改并 generate_target，本脚本重综合该 IP）
# - parameter_dacdata_gen.v State 2 + State 13（C3-lite）
# - 新增 s2_write_cnt (2-bit) + s13_wait_cnt (1-bit) 寄存器

set start_time [clock seconds]
set proj_root [file normalize [pwd]]
set xpr [file join $proj_root "AXI_DDR.xpr"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/synth"]

file mkdir $out_dir

puts "\n=========================================="
puts "DL5_UNIT_003 Synthesis Verification"
puts "=========================================="
puts "Start: [clock format $start_time -format {%Y-%m-%d %H:%M:%S}]"
puts "Project: $xpr"
puts "Output: $out_dir"
puts ""

# 打开工程
puts "INFO: Opening project..."
open_project $xpr

# 1. 重置 fifo_generator_4_synth_1（IP 配置改了，必须重综合）
puts "\n--- Step 1: Reset fifo_generator_4_synth_1 (IP config changed) ---"
set ip_run [get_runs fifo_generator_4_synth_1]
if {$ip_run ne ""} {
    reset_run $ip_run
    puts "INFO: fifo_generator_4_synth_1 reset"
} else {
    puts "WARNING: fifo_generator_4_synth_1 not found, skipping"
}

# 2. 重置 synth_1（顶层 RTL 改了）
puts "\n--- Step 2: Reset synth_1 (RTL changed) ---"
reset_run synth_1
puts "INFO: synth_1 reset"

# 3. 启动综合（会自动先跑 fifo_generator_4_synth_1）
puts "\n--- Step 3: Launch synthesis (with upstream IP) ---"
puts "INFO: This may take 20-40 minutes for full design with MIG/SGMII..."
puts "INFO: Launching synth_1..."

launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 4. 检查综合状态
puts "\n--- Step 4: Check synthesis status ---"
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]
puts "synth_1 STATUS: $synth_status"
puts "synth_1 PROGRESS: $synth_progress"

if {$synth_status ne "synth_design Complete!"} {
    puts "ERROR: Synthesis failed or incomplete"
    puts "Check AXI_DDR.runs/synth_1/runme.log for details"
    exit 1
}

# 5. 打开综合后的 checkpoint
puts "\n--- Step 5: Open synthesized design ---"
open_run synth_1 -name synth_1

# 6. 生成 utilization 报告
puts "\n--- Step 6: Generate utilization report ---"
set util_rpt [file join $out_dir "utilization.rpt"]
report_utilization -file $util_rpt
puts "Saved: $util_rpt"

# 提取关键资源数字到日志
puts "\n=== Resource Utilization Summary ==="
set lut_used [get_property LUT_LOGIC [get_cells -hierarchical -filter {IS_PRIMITIVE==1 && REF_NAME=~LUT*}] -quiet]
set ff_used [llength [get_cells -hierarchical -filter {IS_PRIMITIVE==1 && REF_NAME=~FD*}]]
puts "LUTs (approx): [llength $lut_used]"
puts "FFs (approx): $ff_used"

# 7. 生成 timing summary 报告
puts "\n--- Step 7: Generate timing summary ---"
set timing_rpt [file join $out_dir "timing_summary.rpt"]
report_timing_summary -file $timing_rpt -max_paths 10 -report_unconstrained -warn_on_violation
puts "Saved: $timing_rpt"

# 8. 提取 WNS/TNS
puts "\n=== Timing Summary ==="
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1]]
if {$wns ne ""} {
    puts "WNS (Worst Negative Slack): $wns ns"
    if {$wns < 0} {
        puts "WARNING: Timing violation detected! WNS < 0"
    } else {
        puts "INFO: Timing closure OK (WNS >= 0)"
    }
} else {
    puts "INFO: No constrained paths found or timing analysis incomplete"
}

# 9. 生成 DRC 报告（可选，快速检查明显错误）
puts "\n--- Step 8: Run DRC (quick check) ---"
set drc_rpt [file join $out_dir "drc.rpt"]
report_drc -file $drc_rpt
puts "Saved: $drc_rpt"

# 10. 保存日志
puts "\n--- Step 9: Copy synthesis logs ---"
file copy -force AXI_DDR.runs/synth_1/runme.log [file join $out_dir "synth_runme.log"]
file copy -force AXI_DDR.runs/synth_1/ETH_TOP_utilization_synth.rpt [file join $out_dir "ETH_TOP_utilization_synth.rpt"]

# 完成
set end_time [clock seconds]
set elapsed [expr {$end_time - $start_time}]
puts "\n=========================================="
puts "Synthesis Verification Complete"
puts "=========================================="
puts "Duration: $elapsed seconds ([expr {$elapsed/60}] minutes)"
puts "Reports saved to: $out_dir"
puts ""

close_project
exit 0

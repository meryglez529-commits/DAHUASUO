# DL5_UNIT_003: 改 fifo_generator_4 IP 的 prog_empty 阈值 20 → 2
#
# ⚠️ 在 Vivado GUI 已经打开 AXI_DDR.xpr 工程的情况下，
#    把本文件内容【一段一段】粘进 Tcl Console 执行（避免一次粘整段）。
#
# 第 1 步：读当前值（确认是 20）
# 第 2 步：改 Assert Value 到 2（Negate Value 不用动，IP 内部最小有效值 = Assert+1 = 3）
# 第 3 步：触发 IP 重新生成 output products（Synthesis 子步骤）
# 第 4 步：复查改动后值

# ============ 第 1 步：读当前值 ============
set ip_obj [get_ips fifo_generator_4]
puts "当前 Empty_Threshold_Assert_Value = [get_property CONFIG.Empty_Threshold_Assert_Value $ip_obj]"
puts "当前 Empty_Threshold_Negate_Value = [get_property CONFIG.Empty_Threshold_Negate_Value $ip_obj]"

# ============ 第 2 步：改成 2 ============
set_property -dict [list \
    CONFIG.Empty_Threshold_Assert_Value 2 \
    CONFIG.Empty_Threshold_Negate_Value 3 \
] $ip_obj

# ============ 第 3 步：复查（应当 = 2 / 3）============
puts "改后 Empty_Threshold_Assert_Value = [get_property CONFIG.Empty_Threshold_Assert_Value $ip_obj]"
puts "改后 Empty_Threshold_Negate_Value = [get_property CONFIG.Empty_Threshold_Negate_Value $ip_obj]"

# ============ 第 4 步：重新生成 IP 输出产物（约 3~5 分钟） ============
# 这一步会让 Vivado 重新跑 IP 综合和仿真 netlist 生成。
# 完成后 .gen/sources_1/ip/fifo_generator_4/ 下的 .v 文件会用新阈值。
generate_target {synthesis simulation} [get_files fifo_generator_4.xci]

puts "fifo_generator_4 阈值改动完成。可以开始仿真了。"

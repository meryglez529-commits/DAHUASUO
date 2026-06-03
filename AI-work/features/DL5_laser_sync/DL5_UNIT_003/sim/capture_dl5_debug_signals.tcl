# DL5_UNIT_003 ILA capture for laser sync debugging
# Target: capture laser_sync_in → laser_toggle → blanker/acq chain
#
# 使用说明：
# 1. 确保FPGA已烧录最新bitstream (ETH_TOP.bit)
# 2. 确保已配置laser_mode_en=1 (0x0205)
# 3. 确保laser_sync_in有输入信号（示波器确认）
# 4. 执行：vivado.bat -mode batch -source <this_script>

set proj_root [file normalize [pwd]]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
file mkdir $out_dir

puts "\n=========================================="
puts "DL5 Laser Sync Debug - ILA Capture"
puts "=========================================="
puts "Output directory: $out_dir"

# 打开硬件管理器
open_hw_manager
connect_hw_server

set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware target found. Check JTAG connection."
    exit 1
}
puts "Hardware targets: $targets"

open_hw_target [lindex $targets 0]
set devices [get_hw_devices]
if {[llength $devices] == 0} {
    puts "ERROR: No hardware device found."
    exit 1
}
puts "Hardware devices: $devices"

set dev [lindex $devices 0]
current_hw_device $dev

# 尝试加载probe文件（如果存在）
set ltx_paths [list \
    [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"] \
    [file join $out_dir "recovered_from_hwxml.ltx"] \
]

set ltx_loaded 0
foreach ltx $ltx_paths {
    if {[file exists $ltx]} {
        puts "INFO: Loading probes file: $ltx"
        set_property PROBES.FILE $ltx $dev
        set_property FULL_PROBES.FILE $ltx $dev
        set ltx_loaded 1
        break
    }
}

if {!$ltx_loaded} {
    puts "WARN: No LTX file found. Probe names will be generic (hw_probe_X)."
}

refresh_hw_device $dev

# 列出所有ILA
set ilas [get_hw_ilas]
puts "\nDetected ILA cores: [llength $ilas]"
if {[llength $ilas] == 0} {
    puts "ERROR: No ILA cores found. Check if bitstream has ILA enabled."
    exit 1
}

# 列出每个ILA的探测点
foreach ila $ilas {
    puts "\n----------------------------------------"
    puts "ILA: $ila"
    set probes [get_hw_probes -of_objects $ila -quiet]
    puts "Probe count: [llength $probes]"
    if {[llength $probes] > 0} {
        foreach probe $probes {
            set pname [get_property NAME $probe -quiet]
            set pwidth [get_property BUS_WIDTH $probe -quiet]
            puts "  $pname \[$pwidth\]"
        }
    }
}

# 重点关注的ILA：
# - hw_ila_1 或 ila_1: dacdata_config.v中的dl5_eth_debug，监测eth_clk域的laser_sync_in
# - hw_ila_9/18: 可能是dac_output.v中的sync1/sync2测试ILA

puts "\n=========================================="
puts "开始抓取ILA数据..."
puts "=========================================="

# 策略1: 先尝试trigger_now立即抓取（适合连续信号）
set capture_list [list]
foreach ila_name {hw_ila_1 hw_ila_18 hw_ila_9} {
    set ila [get_hw_ilas $ila_name -quiet]
    if {[llength $ila] > 0} {
        lappend capture_list $ila
    }
}

if {[llength $capture_list] == 0} {
    puts "WARN: Target ILAs (hw_ila_1/9/18) not found. Try capturing first available ILA."
    set capture_list [lrange $ilas 0 2]
}

foreach ila $capture_list {
    set ila_name [lindex [split $ila "/"] end]
    puts "\n>>> Capturing $ila_name with trigger_now..."

    # 配置触发模式为立即触发
    set_property CONTROL.TRIGGER_POSITION 512 $ila

    # 启动ILA
    run_hw_ila -trigger_now $ila

    # 等待ILA完成采集
    puts "    Waiting for ILA capture..."
    if {[catch {wait_on_hw_ila $ila -timeout 10} err]} {
        puts "    ERROR: ILA capture timeout: $err"
        continue
    }

    # 上传数据
    puts "    Uploading data..."
    set data [upload_hw_ila_data $ila]

    # 导出CSV
    set timestamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set csv [file join $out_dir "${ila_name}_${timestamp}.csv"]
    write_hw_ila_data -force -csv_file $csv $data
    puts "    ✓ Saved: $csv"

    # 同时保存波形文件
    set wdb [file join $out_dir "${ila_name}_${timestamp}.wdb"]
    write_hw_ila_data -force -wdb_file $wdb $data
    puts "    ✓ Saved: $wdb"
}

puts "\n=========================================="
puts "ILA Capture Complete!"
puts "=========================================="
puts "Output files in: $out_dir"
puts "\n下一步分析："
puts "1. 打开CSV文件，查找以下信号："
puts "   - laser_sync_in: 是否有跳变？"
puts "   - laser_sync_rise_eth: CDC后的上升沿检测是否工作？"
puts "   - laser_toggle: 是否跟随laser_sync_in翻转？"
puts "   - laser_mode_en: 是否=1？"
puts "   - dl5_dbg_current_state: parameter_dacdata_gen状态机状态"
puts ""
puts "2. 如果laser_sync_in一直是0:"
puts "   → 检查引脚约束和物理接线"
puts ""
puts "3. 如果laser_sync_in有信号但laser_toggle不变:"
puts "   → CDC链路或上升沿检测有问题"
puts ""
puts "4. 如果需要条件触发（而不是trigger_now），请手动配置:"
puts "   - 在Hardware Manager GUI中打开ILA"
puts "   - 设置trigger条件（如laser_sync_rise_eth == 1'b1）"
puts "   - 手动arm并等待触发"

close_hw_manager
exit 0

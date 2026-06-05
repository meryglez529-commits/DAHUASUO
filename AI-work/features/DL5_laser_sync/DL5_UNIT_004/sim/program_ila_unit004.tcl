#######################################################################
# DL5_UNIT_004 烧录 + ILA 抓波形脚本
#
# 用法（先烧录，只需一次）：
#   vivado.bat -mode batch -source program_ila_unit004.tcl -tclargs program
#
# 用法（抓某个场景的波形，可重复，配合 host-app 配寄存器）：
#   vivado.bat -mode batch -source program_ila_unit004.tcl -tclargs arm <scenario_name>
#
# 注意：寄存器配置与扫描触发由 host-app(UDP) 完成，本脚本只管 JTAG/ILA。
#######################################################################

set proj_root [pwd]
set impl_dir  "$proj_root/AXI_DDR.runs/impl_1"
set bit_file  "$impl_dir/ETH_TOP.bit"
set ltx_file  "$impl_dir/ETH_TOP.ltx"
set ila_out   "$proj_root/AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/ila"
file mkdir $ila_out

# 解析参数
set mode [lindex $argv 0]
if {$mode == ""} { set mode "program" }
set scenario [lindex $argv 1]
if {$scenario == ""} { set scenario "capture" }

puts "============================================================"
puts "ILA script: mode=$mode scenario=$scenario"
puts "bit=$bit_file"
puts "ltx=$ltx_file"
puts "============================================================"

# ---- 连接 hw_server ----
open_hw_manager
# 若 hw_server 已在本机运行，connect 到 localhost；否则 Vivado 会本地拉起
catch {connect_hw_server -url localhost:3121 -allow_non_jtag}
open_hw_target

set dev [lindex [get_hw_devices] 0]
puts ">>> hw_device = $dev"
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

# 关联 probe(ltx) 文件
set_property PROBES.FILE      $ltx_file $dev
set_property FULL_PROBES.FILE $ltx_file $dev
set_property PROGRAM.FILE     $bit_file $dev

if {$mode == "program"} {
    puts ">>> programming device ..."
    program_hw_devices $dev
    refresh_hw_device $dev
    puts ">>> program done. ILA cores:"
    foreach ila [get_hw_ilas] { puts "    $ila" }
    puts ">>> 现在用 host-app 配置寄存器，然后用 mode=arm 抓波形"
    exit 0
}

if {$mode == "arm"} {
    refresh_hw_device -update_hw_probes false $dev
    # 找到 adcdata_acq 里的 ila_12（探针名 adc_tri_r1 / state / adc_valid_point ...）
    # 通过探针名匹配定位正确的 ILA，避免 hw_ila_1 索引不确定
    set target_ila ""
    foreach ila [get_hw_ilas] {
        set probes [get_hw_probes -of_objects $ila -quiet]
        foreach p $probes {
            if {[string match "*adc_valid_point*" $p] || [string match "*adc_tri_r1*" $p]} {
                set target_ila $ila
                break
            }
        }
        if {$target_ila != ""} break
    }
    if {$target_ila == ""} {
        puts "WARN: 未按探针名定位到 adcdata_acq ILA，回退用第一个 ILA"
        set target_ila [lindex [get_hw_ilas] 0]
    }
    puts ">>> target_ila = $target_ila"
    puts ">>> 该 ILA 探针列表："
    foreach p [get_hw_probes -of_objects $target_ila -quiet] { puts "    $p" }

    # 触发设置：probe0 = adc_tri_r1 上升沿
    set tri_probe ""
    foreach p [get_hw_probes -of_objects $target_ila -quiet] {
        if {[string match "*adc_tri_r1*" $p]} { set tri_probe $p; break }
    }
    set_property CONTROL.TRIGGER_POSITION 64 $target_ila
    if {$tri_probe != ""} {
        puts ">>> trigger on $tri_probe rising edge (R)"
        set_property TRIGGER_COMPARE_VALUE eq1'bR [get_hw_probes $tri_probe -of_objects $target_ila]
    } else {
        puts "WARN: 没找到 adc_tri_r1 探针，用 basic_only/立即触发"
    }

    # 启动 ILA，等待触发
    run_hw_ila $target_ila
    puts ">>> ILA armed, 等待触发（请确保 host-app 已发起扫描/激光脉冲）..."
    # 最多等 30 秒
    catch {wait_on_hw_ila -timeout 30 $target_ila}

    upload_hw_ila_data $target_ila
    set csv "$ila_out/ila_${scenario}.csv"
    write_hw_ila_data -force -csv_file $csv [current_hw_ila_data]
    puts ">>> 波形已导出: $csv"
    exit 0
}

puts "ERROR: 未知 mode=$mode (应为 program 或 arm)"
exit 1

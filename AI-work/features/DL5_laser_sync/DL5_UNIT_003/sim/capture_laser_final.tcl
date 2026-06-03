# DL5 laser-sync 最终诊断抓取
# hw_ila_20: eth_clk 输入链路, 触发条件 laser_sync_rise_eth==1 (laser 脉冲到来时刻)
# hw_ila_18: ui_clk  输出整形器, 触发条件 laser_pulse_ui==1
# 同时各做一次 trigger_now 兜底（万一根本没脉冲，条件触发会等不到）

set proj_root [file normalize [pwd]]
set ltx [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"]
set out_dir [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
file mkdir $out_dir
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets] 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROBES.FILE $ltx $dev
set_property FULL_PROBES.FILE $ltx $dev

set ila_count 0
for {set i 0} {$i < 10} {incr i} {
    refresh_hw_device -quiet $dev
    set ila_count [llength [get_hw_ilas -quiet]]
    if {$ila_count > 0} break
    after 1000
}
puts "ILA count: $ila_count"
if {$ila_count == 0} { puts "ERROR: no ILA"; exit 1 }

# ---- 通用：条件触发抓取一个 probe 的上升沿 ----
proc capture_on_rise {dev ila_name probe_name out_dir ts} {
    set ila [get_hw_ilas $ila_name -quiet]
    if {[llength $ila] == 0} { puts "WARN: $ila_name not found"; return }
    set probe [get_hw_probes $probe_name -of_objects $ila -quiet]
    if {[llength $probe] == 0} {
        puts "WARN: probe $probe_name not on $ila_name; fallback trigger_now"
        run_hw_ila -trigger_now $ila
    } else {
        # 设触发位置靠前，多看触发后的演化
        set_property CONTROL.TRIGGER_POSITION 64 $ila
        set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe
        run_hw_ila $ila
    }
    puts "  $ila_name armed on $probe_name, waiting up to 8s..."
    if {[catch {wait_on_hw_ila $ila -timeout 8} err]} {
        puts "  $ila_name: TRIGGER TIMEOUT ($err) -> forcing trigger_now"
        run_hw_ila -trigger_now $ila
        wait_on_hw_ila $ila
        set tag "NOTRIG"
    } else {
        set tag "trig"
    }
    set data [upload_hw_ila_data $ila]
    regsub -all {[/<> ]} "${ila_name}_${tag}_${ts}" "_" fname
    set csv [file join $out_dir "${fname}.csv"]
    write_hw_ila_data -force -csv_file $csv $data
    puts "  saved: $csv"
}

puts "\n--- hw_ila_20: eth_clk input chain, trigger on laser_sync_rise_eth ---"
capture_on_rise $dev hw_ila_20 "U6/laser_sync_rise_eth" $out_dir $ts

puts "\n--- hw_ila_18: ui_clk blanker shaper, trigger on laser_pulse_ui ---"
capture_on_rise $dev hw_ila_18 "U6/N2/laser_pulse_ui" $out_dir $ts

close_hw_manager
puts "\n=== capture done ==="
exit 0

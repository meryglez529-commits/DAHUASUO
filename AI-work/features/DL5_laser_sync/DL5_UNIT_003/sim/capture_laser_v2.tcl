# DL5 laser-sync 诊断抓取 v2 — 稳健版
#   - 用 trigger_now 立即抓取（不等条件，避免卡死）
#   - 对 hw_ila_20(输入链路) 和 hw_ila_18(blanker整形器) 各抓一次
#   - 用每个 ILA 自己的 probe 名按编号确认，再导出 CSV
#   - 不依赖 shell timeout，Vivado 跑完自然退出

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

# refresh 直到 debug hub 上线
set n 0
for {set i 0} {$i < 12} {incr i} {
    refresh_hw_device -quiet $dev
    set n [llength [get_hw_ilas -quiet]]
    if {$n > 0} break
    after 1000
}
puts "ILA count: $n"
if {$n == 0} { puts "ERROR: no debug hub"; exit 1 }

# 通过 probe 名字找到正确的 ILA（不靠编号硬编码）
proc find_ila_by_probe {probe_glob} {
    foreach ila [get_hw_ilas -quiet] {
        foreach p [get_hw_probes -of_objects $ila -quiet] {
            if {[string match $probe_glob [get_property NAME $p -quiet]]} { return $ila }
        }
    }
    return ""
}

proc grab {dev ila out_dir ts label} {
    if {$ila eq ""} { puts "WARN: $label ILA not found"; return }
    set name [lindex [split $ila "/"] end]
    puts "\n=== $label ($name) trigger_now ==="
    set_property CONTROL.TRIGGER_POSITION 0 $ila
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    set data [upload_hw_ila_data $ila]
    set csv [file join $out_dir "${label}_${name}_${ts}.csv"]
    write_hw_ila_data -force -csv_file $csv $data
    puts "saved: $csv"
}

set ila_in    [find_ila_by_probe "U6/laser_toggle"]
set ila_blank [find_ila_by_probe "U6/N2/laser_pulse_ui"]

grab $dev $ila_in    $out_dir $ts "INPUT"
grab $dev $ila_blank $out_dir $ts "BLANKER"

close_hw_manager
puts "\n=== done ==="
exit 0

# 抓 DL5_UNIT_003 诊断 ILA (dl5_dac_diag, ila_4, dac_dco域, 深度8192)
# 同时抓 hw_ila_18(blanker整形器) 和 hw_ila_20(状态机输入链路)
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
set n 0
for {set i 0} {$i < 15} {incr i} {
    refresh_hw_device -quiet $dev
    set n [llength [get_hw_ilas -quiet]]
    if {$n > 0} break
    after 1000
}
puts "ILA count: $n"
if {$n == 0} { puts "ERROR: no debug hub"; exit 1 }

proc find_ila {probe_name} {
    foreach ila [get_hw_ilas -quiet] {
        foreach p [get_hw_probes -of_objects $ila -quiet] {
            if {[get_property NAME $p -quiet] eq $probe_name} { return $ila }
        }
    }
    return ""
}

proc grab {ila out_dir ts label depth} {
    if {$ila eq ""} { puts "WARN: $label not found"; return }
    set name [lindex [split $ila "/"] end]
    set_property CONTROL.DATA_DEPTH $depth $ila
    set_property CONTROL.TRIGGER_POSITION 0 $ila
    puts "=== $label ($name) depth=$depth trigger_now ==="
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    set d [upload_hw_ila_data $ila]
    set csv [file join $out_dir "${label}_${name}_${ts}.csv"]
    write_hw_ila_data -force -csv_file $csv $d
    puts "saved: $csv"
}

# 诊断 ILA：用 prog_empty 探针名定位 dl5_dac_diag (ila_4)
set ila_diag [find_ila "N2/para_config_prog_empty"]
if {$ila_diag eq ""} { set ila_diag [find_ila "U6/N2/para_config_prog_empty"] }
grab $ila_diag $out_dir $ts "DIAG" 8192

# 配套：blanker 整形器 + 状态机输入
grab [find_ila "U6/N2/laser_pulse_ui"] $out_dir $ts "BLANKER" 1024
grab [find_ila "U6/laser_toggle"]      $out_dir $ts "INPUT"   1024

close_hw_manager
puts "=== done ==="
exit 0

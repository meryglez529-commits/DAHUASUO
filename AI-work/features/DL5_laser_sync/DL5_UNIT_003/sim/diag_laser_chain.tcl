# DL5 laser-sync 链路诊断：自动匹配 LTX、定位 laser 相关 ILA、抓取并导出 CSV
#
# 目标：一次性抓到下面两组信号，判断 laser_toggle 是否翻转、blanker 整形器是否动作
#   eth_clk 域 (dl5_eth_debug): laser_sync_in / laser_sync_rise_eth / laser_toggle / scan_state / current_state
#   ui_clk  域 (sync1_test):    laser_pulse_ui / sync1_state / sync1_trig_used / sync_pixel_tri1

set proj_root [file normalize [pwd]]
set out_dir   [file normalize "AI-work/features/DL5_laser_sync/DL5_UNIT_003/out/hw_debug"]
file mkdir $out_dir

set ltx_candidates [list \
    [file join $proj_root "AXI_DDR.runs/impl_1/ETH_TOP.ltx"] \
    [file join $out_dir "recovered_from_hwxml.ltx"] \
]

puts "\n=== DL5 laser-sync chain ILA diagnosis ==="

open_hw_manager
connect_hw_server
set targets [get_hw_targets]
if {[llength $targets] == 0} { puts "ERROR: no hw target"; exit 1 }
open_hw_target [lindex $targets 0]
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev

set ltx_used ""
foreach ltx $ltx_candidates {
    if {[file exists $ltx]} {
        set_property PROBES.FILE $ltx $dev
        set_property FULL_PROBES.FILE $ltx $dev
        set ltx_used $ltx
        break
    }
}
puts "LTX: $ltx_used"
refresh_hw_device $dev

set ilas [get_hw_ilas]
puts "ILA count: [llength $ilas]"

# 找出 probe 名里带 laser / sync1 关键字的 ILA
set laser_ilas [list]
foreach ila $ilas {
    set probes [get_hw_probes -of_objects $ila -quiet]
    set hit 0
    foreach probe $probes {
        set pn [string tolower [get_property NAME $probe -quiet]]
        if {[string match *laser* $pn] || [string match *sync1_state* $pn] \
            || [string match *sync_pixel_tri1* $pn] || [string match *current_state* $pn]} {
            set hit 1
        }
    }
    if {$hit} {
        lappend laser_ilas $ila
        puts "\n>> MATCH $ila"
        foreach probe $probes { puts "     [get_property NAME $probe -quiet]" }
    }
}

if {[llength $laser_ilas] == 0} {
    puts "\nWARN: no laser-related probe names matched. Listing all ILAs for manual pick:"
    foreach ila $ilas {
        puts "\nILA $ila"
        foreach probe [get_hw_probes -of_objects $ila -quiet] {
            puts "   [get_property NAME $probe -quiet]"
        }
    }
    close_hw_manager
    exit 0
}

# 对匹配到的 ILA 立即抓取
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
foreach ila $laser_ilas {
    set name [lindex [split $ila "/"] end]
    puts "\n=== Capturing $name (trigger_now) ==="
    catch {set_property CONTROL.TRIGGER_POSITION 16 $ila}
    run_hw_ila -trigger_now $ila
    if {[catch {wait_on_hw_ila $ila} err]} {
        puts "   capture error: $err"; continue
    }
    set data [upload_hw_ila_data $ila]
    set csv [file join $out_dir "diag_${name}_${ts}.csv"]
    write_hw_ila_data -force -csv_file $csv $data
    puts "   saved: $csv"
}

close_hw_manager
puts "\n=== done ==="
exit 0

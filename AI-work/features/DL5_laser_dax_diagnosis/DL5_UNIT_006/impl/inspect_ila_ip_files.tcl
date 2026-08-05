set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
file mkdir $out_impl
cd $out_impl
open_project [file join $proj_root "AXI_DDR.xpr"]
set fp [open [file join $out_impl "ila_ip_files.txt"] w]
foreach ip_name {ila_1 ila_2} {
    set ip [get_ips $ip_name]
    puts $fp "IP=$ip_name"
    puts $fp "  depth=[get_property CONFIG.C_DATA_DEPTH $ip]"
    puts $fp "  probes=[get_property CONFIG.C_NUM_OF_PROBES $ip]"
    foreach f [get_files -of_objects $ip] {
        puts $fp "  FILE=$f TYPE=[get_property FILE_TYPE $f] USED=[get_property USED_IN $f]"
    }
}
close $fp
close_project
exit 0

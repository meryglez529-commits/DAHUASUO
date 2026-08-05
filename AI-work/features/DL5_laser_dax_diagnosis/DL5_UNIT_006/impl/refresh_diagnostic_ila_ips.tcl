# Regenerate ILA targets before the full diagnostic build, preventing Vivado
# from using the obsolete three-probe ila_2 stub.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
file mkdir $out_impl
cd $out_impl
open_project [file join $proj_root "AXI_DDR.xpr"]
foreach ip_name {ila_1 ila_2} {
    set ip [get_ips $ip_name]
    set_property CONFIG.C_DATA_DEPTH 4096 $ip
    if {$ip_name eq "ila_2"} { set_property CONFIG.C_NUM_OF_PROBES 7 $ip }
    reset_target all $ip
    generate_target all $ip
    puts "REFRESHED: $ip_name depth=[get_property CONFIG.C_DATA_DEPTH $ip] probes=[get_property CONFIG.C_NUM_OF_PROBES $ip]"
}
close_project
exit 0

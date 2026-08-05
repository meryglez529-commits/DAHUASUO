# Create the dedicated 4096-sample eth_clk ILA. This keeps the three existing
# ila_1 instances at 1024 samples and prevents a debug-only BRAM overflow.
set script_dir [file dirname [file normalize [info script]]]
set unit_root  [file normalize [file join $script_dir ".."]]
set proj_root  [file normalize [file join $unit_root ".." ".." ".." ".."]]
set out_impl   [file join $unit_root "out" "impl"]
file mkdir $out_impl
cd $out_impl

open_project [file join $proj_root "AXI_DDR.xpr"]
set ip_name ila_dl5_eth
if {[get_ips -quiet $ip_name] eq ""} {
    create_ip -name ila -vendor xilinx.com -library ip -module_name $ip_name \
        -dir [file join $proj_root "AXI_DDR.srcs" "sources_1" "ip"]
}
set ip [get_ips $ip_name]
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_NUM_OF_PROBES {7} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE2_WIDTH {4} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {16} \
    CONFIG.C_PROBE6_WIDTH {1}] $ip
generate_target all $ip
if {[get_runs -quiet ${ip_name}_synth_1] eq ""} {
    create_ip_run $ip
}
puts "ISOLATED_ETH_ILA=$ip"
puts "DEPTH=[get_property CONFIG.C_DATA_DEPTH $ip]"
puts "PROBES=[get_property CONFIG.C_NUM_OF_PROBES $ip]"
puts "IP_RUN=[get_runs -quiet ${ip_name}_synth_1]"
close_project
exit 0

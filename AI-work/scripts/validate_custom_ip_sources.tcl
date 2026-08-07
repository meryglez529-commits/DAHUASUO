# Rebuilds the two unique custom-IP HDL cores in an in-memory project.
# Run only from an isolated worktree; output is written under AI-work/reports/.
set out_dir [file normalize "AI-work/reports/baseline/dcp-rebuild-source"]
file mkdir $out_dir
set fh [open [file join $out_dir "RESULTS.tsv"] w]
puts $fh "core\tresult\tcheckpoint\tdetail"

proc build_core {name sources out_dir fh} {
    create_project -in_memory -part xc7a100tfgg484-2
    set result PASS
    set detail ""
    set checkpoint [file join $out_dir "$name.dcp"]
    if {[catch {
        read_verilog $sources
        synth_design -top $name -part xc7a100tfgg484-2 -mode out_of_context
        write_checkpoint -force $checkpoint
    } err]} {
        set result FAIL
        set detail [string map {"\t" " " "\n" " " "\r" " "} $err]
    }
    puts $fh "$name\t$result\t$checkpoint\t$detail"
    close_project
}

build_core MSXBO_OVSensorRGB565 [list "AXI_DDR.srcs/sources_1/ip/MSXBO_OVSensorRGB565_0/MSXBO_OVSensorRGB565.v"] $out_dir $fh
build_core OV5640IIC [list "AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/src/I2C_OV5640_RGB565_Config.v" "AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/src/i2c_timing_ctrl.v" "AXI_DDR.srcs/sources_1/ip/OV5640IIC_0/src/OV5640IIC.v"] $out_dir $fh
close $fh
exit

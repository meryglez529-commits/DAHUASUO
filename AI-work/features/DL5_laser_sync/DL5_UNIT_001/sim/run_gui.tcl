# DL5_UNIT_001 waveform opener for Vivado GUI Tcl Console.
# Usage from Vivado Tcl Console:
#   cd D:/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_dahuasuo_325T_V3_172/SGSC_SEM_325T_V3_171/fpga_prj
#   source AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/run_gui.tcl

set script_dir [file normalize [file dirname [info script]]]
set unit_dir   [file normalize [file join $script_dir ".."]]
set out_dir    [file normalize [file join $unit_dir "out" "sim"]]
set wdb        [file normalize [file join $out_dir "waveform.wdb"]]
set wcfg       [file normalize [file join $script_dir "waves.wcfg"]]

puts "INFO: DL5_UNIT_001 wave database = $wdb"

if {![file exists $wdb]} {
    puts "WARN: waveform.wdb not found."
    puts "WARN: Run this first from PowerShell:"
    puts {  vivado.bat -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_001/sim/run_batch.tcl}
} else {
    if {[catch {open_wave_database $wdb} msg]} {
        puts "WARN: open_wave_database failed: $msg"
    }

    if {[file exists $wcfg]} {
        if {[catch {open_wave_config $wcfg} msg]} {
            puts "WARN: open_wave_config failed, adding signals by Tcl instead: $msg"
        }
    }

    set wave_signals {
        /tb_laser_sync_blanker_ctrl/ui_clk
        /tb_laser_sync_blanker_ctrl/rstn
        /tb_laser_sync_blanker_ctrl/laser_mode_en
        /tb_laser_sync_blanker_ctrl/scan_state
        /tb_laser_sync_blanker_ctrl/laser_sync_in
        /tb_laser_sync_blanker_ctrl/blanker_delay_time
        /tb_laser_sync_blanker_ctrl/blanker_time
        /tb_laser_sync_blanker_ctrl/acq_data_delay_time
        /tb_laser_sync_blanker_ctrl/acq_time
        /tb_laser_sync_blanker_ctrl/laser_period
        /tb_laser_sync_blanker_ctrl/blanker_pulse
        /tb_laser_sync_blanker_ctrl/laser_acq_pulse
        /tb_laser_sync_blanker_ctrl/laser_event_busy
        /tb_laser_sync_blanker_ctrl/pixel_done_pulse_ui
        /tb_laser_sync_blanker_ctrl/blanker_cnt
        /tb_laser_sync_blanker_ctrl/acq_cnt
        /tb_laser_sync_blanker_ctrl/busy_cnt
        /tb_laser_sync_blanker_ctrl/pixel_done_cnt
        /tb_laser_sync_blanker_ctrl/errors
        /tb_laser_sync_blanker_ctrl/dut/current_state
        /tb_laser_sync_blanker_ctrl/dut/t_cnt
        /tb_laser_sync_blanker_ctrl/dut/laser_pulse_edge
        /tb_laser_sync_blanker_ctrl/dut/blanker_start_5ns
        /tb_laser_sync_blanker_ctrl/dut/blanker_end_5ns
        /tb_laser_sync_blanker_ctrl/dut/acq_start_5ns
        /tb_laser_sync_blanker_ctrl/dut/acq_end_5ns
    }

    foreach sig $wave_signals {
        catch {add_wave $sig}
    }

    puts "INFO: key DL5 waves added. If any signal is missing, rerun run_batch.tcl to regenerate waveform.wdb with log_wave enabled."
}

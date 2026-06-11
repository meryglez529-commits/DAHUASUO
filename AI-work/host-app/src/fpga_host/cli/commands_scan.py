"""Scan command handlers."""

from __future__ import annotations

from fpga_host.core.control.device import FpgaDevice
from fpga_host.core.control.scan import ScanConfig


def scan_config_from_args(args) -> ScanConfig:
    return ScanConfig(
        rows=args.rows,
        cols=args.cols,
        adc_sample=args.adc_sample,
        dac_sample=args.dac_sample,
        adc_channel=args.adc_channel,
        adc_len_single=args.adc_len_single,
        adc_interval=args.adc_interval,
        scan_mode=args.scan_mode,
        clk_sel=args.clk_sel,
        adc1_gain=args.adc1_gain,
        adc2_gain=args.adc2_gain,
        adc3_gain=args.adc3_gain,
        adc4_gain=args.adc4_gain,
        dacx_gain=args.dacx_gain,
        dacy_gain=args.dacy_gain,
        dacx_strat_level=args.dacx_start,
        dacx_end_level=args.dacx_end,
        dacx_recovery_time=args.dacx_recovery_us,
        dacy_strat_level=args.dacy_start,
        dacy_end_level=args.dacy_end,
        frame_waiting_time=args.frame_wait_words,
        dax_fall_time=args.dax_fall_us,
        row_repeat=args.row_repeat,
        row_m=args.row_m,
        row_n=args.row_n,
        dacx_tk_point=args.dacx_tk_point,
    )


def cmd_start(device: FpgaDevice, args):
    return device.start_scan(adc_interval=args.adc_interval, scan_mode=args.scan_mode, dry_run=args.dry_run)


def cmd_stop(device: FpgaDevice, args):
    return device.stop_scan(adc_interval=args.adc_interval, scan_mode=args.scan_mode, dry_run=args.dry_run)


def cmd_scan_apply(device: FpgaDevice, args):
    return device.apply_scan_config(scan_config_from_args(args), dry_run=args.dry_run)

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
    )


def cmd_start(device: FpgaDevice, args):
    return device.start_scan(adc_interval=args.adc_interval, scan_mode=args.scan_mode, dry_run=args.dry_run)


def cmd_stop(device: FpgaDevice, args):
    return device.stop_scan(adc_interval=args.adc_interval, scan_mode=args.scan_mode, dry_run=args.dry_run)


def cmd_scan_apply(device: FpgaDevice, args):
    return device.apply_scan_config(scan_config_from_args(args), dry_run=args.dry_run)

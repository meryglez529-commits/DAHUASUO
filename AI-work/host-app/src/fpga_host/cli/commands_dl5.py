"""DL5 command handlers."""

from __future__ import annotations

from fpga_host.core.control.device import FpgaDevice
from fpga_host.core.control.dl5 import Dl5Config


def dl5_config_from_args(args) -> Dl5Config:
    return Dl5Config(
        laser_mode=args.laser_mode,
        scan_delay=args.scan_delay,
        blanker_delay=args.blanker_delay,
        blanker_time=args.blanker_time,
        acq_delay=args.acq_delay,
        acq_time=args.acq_time,
    )


def cmd_dl5_apply(device: FpgaDevice, args):
    return device.apply_dl5_config(
        dl5_config_from_args(args),
        stop_before_apply=not args.no_stop,
        start_after_apply=args.start_after,
        dry_run=args.dry_run,
    )

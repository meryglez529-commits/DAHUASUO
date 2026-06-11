"""CLI entry point."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from fpga_host.cli.commands_dl5 import cmd_dl5_apply, dl5_config_from_args
from fpga_host.cli.commands_register import (
    cmd_dump,
    cmd_read,
    cmd_version,
    cmd_write,
    cmd_write_checked,
)
from fpga_host.cli.commands_scan import cmd_scan_apply, cmd_start, cmd_stop, scan_config_from_args
from fpga_host.cli.output import emit, emit_error
from fpga_host.core.config import ConnectionConfig
from fpga_host.core.control.device import FpgaDevice
from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.core.control.modes import LaserModeConfig, NormalModeConfig, UltrafastModeConfig
from fpga_host.core.control.register_client import RegisterClient
from fpga_host.core.control.register_map import DUMP_RANGES
from fpga_host.core.control.scan import ScanConfig
from fpga_host.core.data.dl2_receiver_stub import MockDl2Receiver
from fpga_host.core.errors import HostAppError, UnsafeOperationError
from fpga_host.core.transport.mock_transport import MockTransport
from fpga_host.core.transport.udp_transport import UdpTransport


def parse_int(text: str) -> int:
    return int(text, 0)


def make_device(args) -> FpgaDevice:
    config = ConnectionConfig(
        host_ip=args.host_ip,
        fpga_ip=args.fpga_ip,
        local_port=args.local_port,
        remote_port=args.remote_port,
        timeout_ms=args.timeout_ms,
        retries=args.retries,
        mock=args.mock,
    )
    transport = MockTransport() if args.mock else UdpTransport(config)
    return FpgaDevice(RegisterClient(transport))


def ensure_safe(args) -> None:
    if getattr(args, "dry_run", False):
        return
    if getattr(args, "mock", False):
        return
    if getattr(args, "requires_yes", False) and not getattr(args, "yes", False):
        raise UnsafeOperationError("real hardware write requires --yes")


def result_exit_code(result) -> int:
    if isinstance(result, list):
        return 0
    if hasattr(result, "success"):
        if result.success:
            return 0
        if result.error == "ReadbackMismatch":
            return 11
        return 1
    return 0


def add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--mock", action="store_true", help="Use virtual FPGA registers")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON")
    parser.add_argument("--host-ip", default="0.0.0.0", help="Local bind IP")
    parser.add_argument("--fpga-ip", default="192.168.1.8", help="FPGA IP")
    parser.add_argument("--local-port", type=int, default=32000, help="Local UDP port")
    parser.add_argument("--remote-port", type=int, default=32000, help="FPGA UDP port")
    parser.add_argument("--timeout-ms", type=int, default=500, help="UDP timeout")
    parser.add_argument("--retries", type=int, default=1, help="Read retry count")


def add_yes(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--yes", action="store_true", help="Confirm hardware-changing operation")


def add_dry_run(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--dry-run", action="store_true", help="Show write plan without sending")


def add_scan_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--rows", type=parse_int, default=1024)
    parser.add_argument("--cols", type=parse_int, default=1024)
    parser.add_argument("--adc-sample", type=parse_int, default=20, help="ADC average count, raw sample points")
    parser.add_argument("--dac-sample", type=parse_int, default=20, help="DAC pixel dwell count, raw FIFO words")
    parser.add_argument("--adc-channel", type=parse_int, default=4)
    parser.add_argument("--adc-len-single", type=parse_int)
    parser.add_argument("--adc-interval", type=parse_int, default=0, help="ADC DCO cycles, about 20 ns/step at 50 MHz")
    parser.add_argument("--scan-mode", type=parse_int, default=1)
    parser.add_argument("--clk-sel", type=parse_int, choices=[0, 1], help="0=free run, 1=wait TRIGGER_IN before each line")
    parser.add_argument("--dacx-start", type=parse_int, default=0x1999, help="DAC X start code")
    parser.add_argument("--dacx-end", type=parse_int, default=0xE665, help="DAC X end code")
    parser.add_argument("--dacx-tk-point", type=parse_int, help="X points per line; omitted means follow --cols")
    parser.add_argument("--dacx-recovery-us", type=parse_int, default=50, help="line-head recovery in us; FPGA multiplies by 50")
    parser.add_argument("--dacy-start", type=parse_int, default=0x3BBB, help="DAC Y start code")
    parser.add_argument("--dacy-end", type=parse_int, default=0xC443, help="DAC Y end code")
    parser.add_argument("--dax-fall-us", type=parse_int, default=20, help="X fall time in us; FPGA multiplies by 50")
    parser.add_argument("--frame-wait-words", type=parse_int, default=0, help="Frame wait FIFO words, about 20 ns/word")
    parser.add_argument("--adc1-gain", type=parse_int, choices=range(4), default=2)
    parser.add_argument("--adc2-gain", type=parse_int, choices=range(4), default=2)
    parser.add_argument("--adc3-gain", type=parse_int, choices=range(4), default=2)
    parser.add_argument("--adc4-gain", type=parse_int, choices=range(4), default=2)
    parser.add_argument("--dacx-gain", type=parse_int, choices=range(4), default=3)
    parser.add_argument("--dacy-gain", type=parse_int, choices=range(4), default=3)
    parser.add_argument("--row-repeat", type=parse_int, default=1, help="Repeated scans per row; must be >=1")
    parser.add_argument("--row-m", type=parse_int, default=0, help="Interleaved scan skipped-row group m")
    parser.add_argument("--row-n", type=parse_int, default=1, help="Interleaved scan active-row group n; must be >=1")


def add_dl5_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--laser-mode", type=parse_int, choices=[0, 1], default=1)
    parser.add_argument("--scan-delay", type=parse_int, required=True, help="eth_clk cycles, 8 ns/step")
    parser.add_argument("--blanker-delay", type=parse_int, required=True, help="ui_clk cycles, 5 ns/step")
    parser.add_argument("--blanker-time", type=parse_int, required=True, help="ui_clk cycles, 5 ns/step")
    parser.add_argument("--acq-delay", type=parse_int, required=True, help="20 ns steps; FPGA shifts left by 2 to ui_clk")
    parser.add_argument("--acq-time", type=parse_int, required=True, help="ADC sample count / 20 ns steps; >=2 when laser is enabled")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fpga-host")
    sub = parser.add_subparsers(dest="command", required=True)

    version = sub.add_parser("version", help="Read FPGA version register")
    add_common_options(version)
    version.set_defaults(handler=cmd_version)

    read = sub.add_parser("read", help="Read one 32-bit register")
    add_common_options(read)
    read.add_argument("address", type=parse_int)
    read.set_defaults(handler=cmd_read)

    write = sub.add_parser("write", help="Write one 32-bit register")
    add_common_options(write)
    add_yes(write)
    write.add_argument("address", type=parse_int)
    write.add_argument("value", type=parse_int)
    write.set_defaults(handler=cmd_write, requires_yes=True)

    write_checked = sub.add_parser("write-checked", help="Write one register and read it back")
    add_common_options(write_checked)
    add_yes(write_checked)
    write_checked.add_argument("address", type=parse_int)
    write_checked.add_argument("value", type=parse_int)
    write_checked.set_defaults(handler=cmd_write_checked, requires_yes=True)

    dump = sub.add_parser("dump", help="Dump readable register range")
    add_common_options(dump)
    dump.add_argument("--range", choices=sorted(DUMP_RANGES), default="basic")
    dump.set_defaults(handler=cmd_dump)

    start = sub.add_parser("start", help="Start scan")
    add_common_options(start)
    add_yes(start)
    add_dry_run(start)
    start.add_argument("--adc-interval", type=int)
    start.add_argument("--scan-mode", type=int)
    start.set_defaults(handler=cmd_start, requires_yes=True)

    stop = sub.add_parser("stop", help="Stop scan")
    add_common_options(stop)
    add_yes(stop)
    add_dry_run(stop)
    stop.add_argument("--adc-interval", type=int)
    stop.add_argument("--scan-mode", type=int)
    stop.set_defaults(handler=cmd_stop, requires_yes=True)

    scan = sub.add_parser("scan", help="Scan parameter commands")
    scan_sub = scan.add_subparsers(dest="scan_command", required=True)
    scan_apply = scan_sub.add_parser("apply", help="Apply scan config")
    add_common_options(scan_apply)
    add_yes(scan_apply)
    add_dry_run(scan_apply)
    add_scan_options(scan_apply)
    scan_apply.set_defaults(handler=cmd_scan_apply, requires_yes=True)

    dl5 = sub.add_parser("dl5", help="DL5 laser-sync commands")
    dl5_sub = dl5.add_subparsers(dest="dl5_command", required=True)
    dl5_apply = dl5_sub.add_parser("apply", help="Apply DL5 config")
    add_common_options(dl5_apply)
    add_yes(dl5_apply)
    add_dry_run(dl5_apply)
    add_dl5_options(dl5_apply)
    dl5_apply.add_argument("--no-stop", action="store_true", help="Do not stop scan before applying")
    dl5_apply.add_argument("--start-after", action="store_true", help="Start scan after applying")
    dl5_apply.set_defaults(handler=cmd_dl5_apply, requires_yes=True)

    profile = sub.add_parser("profile", help="Profile file commands")
    profile_sub = profile.add_subparsers(dest="profile_command", required=True)
    profile_load = profile_sub.add_parser("load", help="Load scan/DL5 JSON profile")
    add_common_options(profile_load)
    add_yes(profile_load)
    add_dry_run(profile_load)
    profile_load.add_argument("path")
    profile_load.set_defaults(handler=cmd_profile_load, requires_yes=True)

    mode = sub.add_parser("mode", help="Human-oriented work modes")
    mode_sub = mode.add_subparsers(dest="mode_name", required=True)

    normal = mode_sub.add_parser("normal", help="Normal scan mode")
    normal_sub = normal.add_subparsers(dest="mode_command", required=True)
    normal_apply = normal_sub.add_parser("apply", help="Apply normal scan mode")
    add_common_options(normal_apply)
    add_yes(normal_apply)
    add_dry_run(normal_apply)
    add_scan_options(normal_apply)
    normal_apply.add_argument("--start-after", action="store_true")
    normal_apply.set_defaults(handler=cmd_mode_normal_apply, requires_yes=True)

    ultrafast = mode_sub.add_parser("ultrafast", help="Ultrafast scan mode")
    ultrafast_sub = ultrafast.add_subparsers(dest="mode_command", required=True)
    ultrafast_apply = ultrafast_sub.add_parser("apply", help="Apply ultrafast scan mode")
    add_common_options(ultrafast_apply)
    add_yes(ultrafast_apply)
    add_dry_run(ultrafast_apply)
    add_scan_options(ultrafast_apply)
    ultrafast_apply.add_argument("--ultrafast-line-rec", type=parse_int, default=0, help="line recovery in us; FPGA multiplies by 50")
    ultrafast_apply.add_argument("--adc-acq-delay", type=parse_int, default=0, help="ADC DCO cycles, about 20 ns/step")
    ultrafast_apply.add_argument("--acq-dead-time", type=parse_int, default=0, help="ADC DCO cycles, about 20 ns/step")
    ultrafast_apply.add_argument("--sync-delay1", type=parse_int, default=0, help="ui_clk cycles, 5 ns/step")
    ultrafast_apply.add_argument("--sync-delay2", type=parse_int, default=0, help="ui_clk cycles, 5 ns/step")
    ultrafast_apply.add_argument("--sync1-width", type=parse_int, default=0, help="20 ns steps; FPGA shifts left by 2 to ui_clk")
    ultrafast_apply.add_argument("--sync2-width", type=parse_int, default=0, help="20 ns steps; FPGA shifts left by 2 to ui_clk")
    ultrafast_apply.add_argument("--start-after", action="store_true")
    ultrafast_apply.set_defaults(handler=cmd_mode_ultrafast_apply, requires_yes=True)

    laser = mode_sub.add_parser("laser", help="Laser sync mode")
    laser_sub = laser.add_subparsers(dest="mode_command", required=True)
    laser_apply = laser_sub.add_parser("apply", help="Apply laser sync mode")
    add_common_options(laser_apply)
    add_yes(laser_apply)
    add_dry_run(laser_apply)
    add_scan_options(laser_apply)
    add_dl5_options(laser_apply)
    laser_apply.add_argument("--start-after", action="store_true")
    laser_apply.set_defaults(handler=cmd_mode_laser_apply, requires_yes=True)

    data = sub.add_parser("data", help="DL2 data-plane placeholder commands")
    data_sub = data.add_subparsers(dest="data_command", required=True)
    mock_frame = data_sub.add_parser("mock-frame", help="Generate one mock DL2 frame summary")
    add_common_options(mock_frame)
    mock_frame.add_argument("--rows", type=int, default=16)
    mock_frame.add_argument("--cols", type=int, default=16)
    mock_frame.add_argument("--channels", type=int, default=4)
    mock_frame.set_defaults(handler=cmd_data_mock_frame)

    return parser


def cmd_profile_load(device: FpgaDevice, args):
    data = json.loads(Path(args.path).read_text(encoding="utf-8"))
    results = []
    if "scan" in data:
        results.append(device.apply_scan_config(ScanConfig.from_dict(data["scan"]), dry_run=args.dry_run).to_dict())
    if "dl5" in data:
        results.append(device.apply_dl5_config(Dl5Config.from_dict(data["dl5"]), dry_run=args.dry_run).to_dict())
    return {"success": all(item["success"] for item in results), "results": results}


def cmd_mode_normal_apply(device: FpgaDevice, args):
    config = NormalModeConfig(scan=scan_config_from_args(args))
    return device.apply_mode_config(config, start_after_apply=args.start_after, dry_run=args.dry_run)


def cmd_mode_ultrafast_apply(device: FpgaDevice, args):
    config = UltrafastModeConfig(
        scan=scan_config_from_args(args),
        ultrafast_line_rec=args.ultrafast_line_rec,
        adc_acq_delay=args.adc_acq_delay,
        acq_dead_time=args.acq_dead_time,
        sync_delay1=args.sync_delay1,
        sync_delay2=args.sync_delay2,
        sync1_width=args.sync1_width,
        sync2_width=args.sync2_width,
    )
    return device.apply_mode_config(config, start_after_apply=args.start_after, dry_run=args.dry_run)


def cmd_mode_laser_apply(device: FpgaDevice, args):
    config = LaserModeConfig(
        scan=scan_config_from_args(args),
        dl5=dl5_config_from_args(args),
    )
    return device.apply_mode_config(config, start_after_apply=args.start_after, dry_run=args.dry_run)


def cmd_data_mock_frame(_device: FpgaDevice, args):
    receiver = MockDl2Receiver(rows=args.rows, cols=args.cols, channels=args.channels)
    receiver.start()
    frame = receiver.get_frame()
    receiver.stop()
    return frame.to_dict() if frame is not None else {"success": False, "error": "no frame"}


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        ensure_safe(args)
        device = make_device(args)
        result = args.handler(device, args)
        if hasattr(result, "to_dict"):
            emit(result.to_dict() if args.json else result, json_mode=args.json)
        else:
            emit(result, json_mode=args.json)
        return result_exit_code(result)
    except HostAppError as exc:
        emit_error(str(exc), exc.code, json_mode=getattr(args, "json", False))
        return exc.code
    except Exception as exc:
        emit_error(str(exc), 1, json_mode=getattr(args, "json", False))
        return 1


if __name__ == "__main__":
    sys.exit(main())

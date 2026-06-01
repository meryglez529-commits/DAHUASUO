"""Register command handlers."""

from __future__ import annotations

from fpga_host.core.control.device import FpgaDevice


def cmd_version(device: FpgaDevice, _args):
    return device.version()


def cmd_read(device: FpgaDevice, args):
    return device.read_register(args.address)


def cmd_write(device: FpgaDevice, args):
    return device.write_register(args.address, args.value, checked=False)


def cmd_write_checked(device: FpgaDevice, args):
    return device.write_register(args.address, args.value, checked=True)


def cmd_dump(device: FpgaDevice, args):
    return [value.to_dict() for value in device.client.dump(args.range)]

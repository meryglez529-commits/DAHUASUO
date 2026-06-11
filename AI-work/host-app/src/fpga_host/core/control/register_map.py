"""Register map for the DL4 control plane."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RegisterSpec:
    address: int
    name: str
    readable: bool = True
    writable: bool = True
    default: int = 0
    description: str = ""


DEFAULT_UNKNOWN_READ_VALUE = 0x11223344
VERSION_VALUE = 0x000300AC


REGISTER_SPECS: dict[int, RegisterSpec] = {
    0x0000: RegisterSpec(0x0000, "clk_sel", default=0),
    0x0001: RegisterSpec(0x0001, "adc_len_channel", default=(1024 * 1024 << 4) | 4),
    0x0002: RegisterSpec(0x0002, "sample", default=50),
    0x0003: RegisterSpec(0x0003, "gain", default=0x00000FAA),
    0x0004: RegisterSpec(0x0004, "image_size", default=(1024 << 16) | 1024),
    0x0005: RegisterSpec(0x0005, "dacx_range", default=0x80008000),
    0x0006: RegisterSpec(0x0006, "dacx_point_recovery", default=(128 << 16) | 1),
    0x0007: RegisterSpec(0x0007, "dacy_range", default=0x80008000),
    0x0008: RegisterSpec(0x0008, "frame_waiting_time", default=0),
    0x0009: RegisterSpec(0x0009, "scan_control", default=0x00001310),
    0x000A: RegisterSpec(0x000A, "version", readable=True, writable=False, default=VERSION_VALUE),
    0x000B: RegisterSpec(0x000B, "remote_result", readable=True, writable=False, default=0),
    0x000C: RegisterSpec(0x000C, "remote_rstn", default=1),
    0x000D: RegisterSpec(0x000D, "heart_beat", default=0),
    0x000E: RegisterSpec(0x000E, "pc_ack", readable=False, writable=True, default=0),
    0x000F: RegisterSpec(0x000F, "dax_fall_time_us", default=20),
    0x0010: RegisterSpec(0x0010, "offset_adc1_adc2", default=0),
    0x0011: RegisterSpec(0x0011, "offset_adc3_adc4", default=0),
    0x0012: RegisterSpec(0x0012, "offset_dacx_dacy", default=0),
    0x0013: RegisterSpec(0x0013, "row_repeat", default=1),
    0x0014: RegisterSpec(0x0014, "row_m_n", default=0x00000001),
    0x0200: RegisterSpec(0x0200, "sync1_pixel_tri_width", default=1),
    0x0201: RegisterSpec(0x0201, "adc_acq_delay", default=0),
    0x0202: RegisterSpec(0x0202, "ultrafast", default=2),
    0x0203: RegisterSpec(0x0203, "sync_signal_delay", default=0),
    0x0204: RegisterSpec(0x0204, "acq_dead_time", default=0),
    0x0205: RegisterSpec(0x0205, "sync2_pixel_tri_width", default=1),
    0x0206: RegisterSpec(0x0206, "scan_delay_time", default=0),
    0x0207: RegisterSpec(0x0207, "blanker_delay_time", default=0),
    0x0208: RegisterSpec(0x0208, "blanker_time", default=0),
    0x0209: RegisterSpec(0x0209, "acq_data_delay_time", default=0),
    0x020A: RegisterSpec(0x020A, "acq_time", default=0),
    0x020B: RegisterSpec(0x020B, "laser_mode_en", default=0),
}

DUMP_RANGES: dict[str, list[int]] = {
    "basic": [0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0008, 0x0009, 0x000A],
    "dl5": [0x0206, 0x0207, 0x0208, 0x0209, 0x020A, 0x020B],
    "sync": [0x0200, 0x0201, 0x0202, 0x0203, 0x0204, 0x0205],
}
DUMP_RANGES["all"] = sorted(REGISTER_SPECS)


def get_register(address: int) -> RegisterSpec:
    if address in REGISTER_SPECS:
        return REGISTER_SPECS[address]
    return RegisterSpec(address, f"unknown_0x{address:04X}", readable=True, writable=True)


def register_name(address: int) -> str:
    return get_register(address).name

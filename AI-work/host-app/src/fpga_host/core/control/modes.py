"""Human-oriented work modes for the host app.

The GUI should expose these modes instead of raw register addresses.
Each mode still compiles down to a DL4 register write plan.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.core.control.scan import ScanConfig
from fpga_host.core.errors import ConfigError
from fpga_host.core.models import hex16, hex32


@dataclass(frozen=True)
class WritePlanItem:
    address: int
    value: int
    label: str
    checked: bool = True
    note: str = ""

    def to_tuple(self) -> tuple[int, int]:
        return self.address, self.value

    def to_dict(self) -> dict:
        return {
            "address": hex16(self.address),
            "value": hex32(self.value),
            "label": self.label,
            "checked": self.checked,
            "note": self.note,
        }


@dataclass(frozen=True)
class ModeApplyPlan:
    mode: str
    items: list[WritePlanItem] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "mode": self.mode,
            "items": [item.to_dict() for item in self.items],
            "warnings": self.warnings,
        }


class ModeConfig(Protocol):
    mode_name: str

    def to_plan(self) -> ModeApplyPlan:
        ...


def _scan_items(scan: ScanConfig, scan_state: int = 0) -> list[WritePlanItem]:
    return [
        WritePlanItem(addr, value, label=_scan_label(addr), checked=True)
        for addr, value in scan.to_registers(scan_state=scan_state)
    ]


def _scan_label(address: int) -> str:
    return {
        0x0001: "ADC length/channel",
        0x0002: "Sample count",
        0x0004: "Image size",
        0x0009: "Scan control",
    }.get(address, f"Register {hex16(address)}")


@dataclass(frozen=True)
class NormalModeConfig:
    scan: ScanConfig
    mode_name: str = "normal"

    def to_plan(self) -> ModeApplyPlan:
        items = [
            WritePlanItem(0x0009, self.scan.to_registers(scan_state=0)[-1][1], "Stop scan", checked=True),
            WritePlanItem(0x0205, 0, "Disable laser mode", checked=True),
            WritePlanItem(
                0x0202,
                0,
                "Disable ultrafast mode",
                checked=False,
                note="0x0202 is not readable in current RTL",
            ),
        ]
        items.extend(_scan_items(self.scan, scan_state=0))
        return ModeApplyPlan(
            mode=self.mode_name,
            items=items,
            warnings=["Ultrafast register 0x0202 is write-only; GUI can only confirm send."],
        )


@dataclass(frozen=True)
class UltrafastModeConfig:
    scan: ScanConfig
    ultrafast_line_rec: int = 0
    adc_acq_delay: int = 0
    acq_dead_time: int = 0
    sync_delay1: int = 0
    sync_delay2: int = 0
    sync1_width: int = 0
    mode_name: str = "ultrafast"

    def validate(self) -> None:
        self.scan.validate()
        for name, value in (
            ("ultrafast_line_rec", self.ultrafast_line_rec),
            ("adc_acq_delay", self.adc_acq_delay),
            ("acq_dead_time", self.acq_dead_time),
            ("sync_delay1", self.sync_delay1),
            ("sync_delay2", self.sync_delay2),
            ("sync1_width", self.sync1_width),
        ):
            if not 0 <= value <= 0xFFFFFFFF:
                raise ConfigError(f"{name} must fit in 32 bits")

    def to_plan(self) -> ModeApplyPlan:
        self.validate()
        ultrafast_value = ((self.ultrafast_line_rec & 0x7FFFFFFF) << 1) | 1
        items = [
            WritePlanItem(0x0009, self.scan.to_registers(scan_state=0)[-1][1], "Stop scan", checked=True),
            WritePlanItem(0x0205, 0, "Disable laser mode", checked=True),
        ]
        items.extend(_scan_items(self.scan, scan_state=0))
        items.extend(
            [
                WritePlanItem(0x0200, self.sync1_width & 0xFFFF, "Sync1 width", checked=False, note="write-only"),
                WritePlanItem(0x0201, self.adc_acq_delay, "ADC acq delay", checked=False, note="write-only"),
                WritePlanItem(0x0203, ((self.sync_delay1 & 0xFFFF) << 16) | (self.sync_delay2 & 0xFFFF), "Sync delay", checked=False, note="write-only"),
                WritePlanItem(0x0204, self.acq_dead_time, "Acq dead time", checked=False, note="write-only"),
                WritePlanItem(0x0202, ultrafast_value, "Enable ultrafast mode", checked=False, note="write-only"),
            ]
        )
        return ModeApplyPlan(
            mode=self.mode_name,
            items=items,
            warnings=["0x0200~0x0204 are not readable in current RTL; readback is not available."],
        )


@dataclass(frozen=True)
class LaserModeConfig:
    scan: ScanConfig
    dl5: Dl5Config
    mode_name: str = "laser"

    def to_plan(self) -> ModeApplyPlan:
        self.scan.validate()
        self.dl5.validate()
        items = [
            WritePlanItem(0x0009, self.scan.to_registers(scan_state=0)[-1][1], "Stop scan", checked=True),
            WritePlanItem(0x0202, 0, "Disable ultrafast mode", checked=False, note="0x0202 is write-only"),
        ]
        items.extend(_scan_items(self.scan, scan_state=0))
        items.append(WritePlanItem(0x0205, 0, "Close laser before applying timing", checked=True))
        for addr, value in self.dl5.to_registers():
            if addr == 0x0205:
                continue
            items.append(WritePlanItem(addr, value, label=_dl5_label(addr), checked=True))
        items.append(WritePlanItem(0x0205, self.dl5.laser_mode, "Enable laser mode", checked=True))
        return ModeApplyPlan(
            mode=self.mode_name,
            items=items,
            warnings=["Laser mode is applied while scan is stopped, then can be started explicitly."],
        )


def _dl5_label(address: int) -> str:
    return {
        0x0206: "Scan delay",
        0x0207: "Blanker delay",
        0x0208: "Blanker time",
        0x0209: "Acq delay",
        0x020A: "Acq time",
    }.get(address, f"DL5 {hex16(address)}")

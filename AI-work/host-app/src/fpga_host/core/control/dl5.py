"""DL5 laser-sync parameter model."""

from __future__ import annotations

from dataclasses import dataclass

from fpga_host.core.errors import ConfigError


LASER_MODE_REGISTER = 0x020B


def _u16(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFF:
        raise ConfigError(f"{name} must fit in 16 bits")
    return value


@dataclass(frozen=True)
class Dl5Config:
    laser_mode: int = 0
    # Register values are raw hardware steps:
    # scan_delay: eth_clk cycles, 8 ns/step.
    # blanker_delay/blanker_time: ui_clk cycles, 5 ns/step.
    # acq_delay/acq_time: 20 ns steps; acq_time is also the laser ADC sample count.
    scan_delay: int = 0
    blanker_delay: int = 0
    blanker_time: int = 0
    acq_delay: int = 0
    acq_time: int = 0

    def validate(self) -> None:
        if self.laser_mode not in (0, 1):
            raise ConfigError("laser_mode must be 0 or 1")
        _u16("scan_delay", self.scan_delay)
        _u16("blanker_delay", self.blanker_delay)
        _u16("blanker_time", self.blanker_time)
        _u16("acq_delay", self.acq_delay)
        _u16("acq_time", self.acq_time)
        if self.laser_mode and self.acq_time < 2:
            raise ConfigError("acq_time must be >= 2 when laser mode is enabled")

    def to_registers(self) -> list[tuple[int, int]]:
        self.validate()
        return [
            (LASER_MODE_REGISTER, self.laser_mode),
            (0x0206, self.scan_delay),
            (0x0207, self.blanker_delay),
            (0x0208, self.blanker_time),
            (0x0209, self.acq_delay),
            (0x020A, self.acq_time),
        ]

    def to_safe_apply_registers(self) -> list[tuple[int, int]]:
        self.validate()
        writes = [(LASER_MODE_REGISTER, 0)]
        writes.extend((addr, value) for addr, value in self.to_registers() if addr != LASER_MODE_REGISTER)
        writes.append((LASER_MODE_REGISTER, self.laser_mode))
        return writes

    @classmethod
    def from_dict(cls, data: dict) -> "Dl5Config":
        return cls(
            laser_mode=int(data.get("laser_mode", data.get("laser_mode_en", 0))),
            scan_delay=int(data.get("scan_delay", data.get("scan_delay_time", 0))),
            blanker_delay=int(data.get("blanker_delay", data.get("blanker_delay_time", 0))),
            blanker_time=int(data.get("blanker_time", 0)),
            acq_delay=int(data.get("acq_delay", data.get("acq_data_delay_time", 0))),
            acq_time=int(data.get("acq_time", 0)),
        )

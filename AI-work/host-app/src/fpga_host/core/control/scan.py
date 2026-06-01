"""Scan parameter model and register-write plan."""

from __future__ import annotations

from dataclasses import dataclass

from fpga_host.core.errors import ConfigError


def _u16(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFF:
        raise ConfigError(f"{name} must fit in 16 bits")
    return value


def _u24(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFFFF:
        raise ConfigError(f"{name} must fit in 24 bits")
    return value


@dataclass(frozen=True)
class ScanConfig:
    rows: int = 1024
    cols: int = 1024
    adc_sample: int = 20
    dac_sample: int = 20
    adc_channel: int = 4
    adc_len_single: int | None = None
    adc_interval: int = 0
    scan_mode: int = 1

    def validate(self) -> None:
        _u16("rows", self.rows)
        _u16("cols", self.cols)
        if self.rows == 0 or self.cols == 0:
            raise ConfigError("rows and cols must be non-zero")
        if self.adc_sample != self.dac_sample:
            raise ConfigError("FPGA register 0x0002 ties adc_sample and dac_sample together")
        if self.adc_channel not in (1, 2, 4):
            raise ConfigError("adc_channel must be 1, 2, or 4")
        _u24("adc_interval", self.adc_interval)
        if not 0 <= self.scan_mode <= 0xF:
            raise ConfigError("scan_mode must fit in 4 bits")
        adc_len = self.effective_adc_len_single()
        if not 0 <= adc_len <= 0x1FFFFF:
            raise ConfigError("adc_len_single must fit in 21 bits")

    def effective_adc_len_single(self) -> int:
        if self.adc_len_single is not None:
            return self.adc_len_single
        return self.rows * self.cols

    def to_registers(self, scan_state: int = 0) -> list[tuple[int, int]]:
        self.validate()
        if not 0 <= scan_state <= 0xF:
            raise ConfigError("scan_state must fit in 4 bits")
        adc_cfg = (self.effective_adc_len_single() << 4) | self.adc_channel
        sample = self.adc_sample
        image_size = (self.rows << 16) | self.cols
        scan_control = (self.adc_interval << 8) | (self.scan_mode << 4) | scan_state
        return [
            (0x0001, adc_cfg),
            (0x0002, sample),
            (0x0004, image_size),
            (0x0009, scan_control),
        ]

    @classmethod
    def from_dict(cls, data: dict) -> "ScanConfig":
        return cls(
            rows=int(data.get("rows", 1024)),
            cols=int(data.get("cols", 1024)),
            adc_sample=int(data.get("adc_sample", data.get("sample", 20))),
            dac_sample=int(data.get("dac_sample", data.get("sample", data.get("adc_sample", 20)))),
            adc_channel=int(data.get("adc_channel", 4)),
            adc_len_single=(
                None if data.get("adc_len_single") is None else int(data["adc_len_single"])
            ),
            adc_interval=int(data.get("adc_interval", 0)),
            scan_mode=int(data.get("scan_mode", 1)),
        )

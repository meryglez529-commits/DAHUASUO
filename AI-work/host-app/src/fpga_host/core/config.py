"""Configuration models and JSON loading helpers."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class ConnectionConfig:
    host_ip: str = "0.0.0.0"
    fpga_ip: str = "192.168.1.8"
    local_port: int = 32000
    remote_port: int = 32000
    timeout_ms: int = 500
    retries: int = 1
    mock: bool = False


@dataclass(frozen=True)
class BoardProfile:
    name: str = "SGSC_SEM_325T_V3_172"
    fpga_ip: str = "192.168.1.8"
    host_ip: str = "0.0.0.0"
    local_port: int = 32000
    remote_port: int = 32000
    timeout_ms: int = 500
    retries: int = 1
    expected_version: int = 0x000300AC

    def to_connection(self, mock: bool = False) -> ConnectionConfig:
        return ConnectionConfig(
            host_ip=self.host_ip,
            fpga_ip=self.fpga_ip,
            local_port=self.local_port,
            remote_port=self.remote_port,
            timeout_ms=self.timeout_ms,
            retries=self.retries,
            mock=mock,
        )


def parse_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 0)
    raise TypeError(f"cannot parse int from {value!r}")


def load_board_profile(path: str | Path) -> BoardProfile:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    return BoardProfile(
        name=data.get("name", "SGSC_SEM_325T_V3_172"),
        fpga_ip=data.get("fpga_ip", "192.168.1.8"),
        host_ip=data.get("host_ip", "0.0.0.0"),
        local_port=int(data.get("local_port", 32000)),
        remote_port=int(data.get("remote_port", 32000)),
        timeout_ms=int(data.get("timeout_ms", 500)),
        retries=int(data.get("retries", 1)),
        expected_version=parse_int(data.get("expected_version", "0x000300AC")),
    )

"""Small structured log events for GUI and CLI output."""

from __future__ import annotations

from dataclasses import dataclass, field
import time
from typing import Any

from fpga_host.core.models import hex16, hex32


@dataclass(frozen=True)
class LogEvent:
    kind: str
    message: str
    address: int | None = None
    value: int | None = None
    payload: bytes | None = None
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "message": self.message,
            "address": hex16(self.address),
            "value": hex32(self.value),
            "payload": self.payload.hex(" ") if self.payload is not None else None,
            "timestamp": self.timestamp,
        }

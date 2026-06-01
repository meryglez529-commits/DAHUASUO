"""Small data models shared across core, CLI, and GUI."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08X}"


def hex16(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFF:04X}"


@dataclass(frozen=True)
class RegisterValue:
    address: int
    value: int
    name: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "address": hex16(self.address),
            "value": hex32(self.value),
            "name": self.name,
        }


@dataclass
class OperationResult:
    success: bool
    operation: str
    message: str = ""
    address: int | None = None
    value: int | None = None
    readback: int | None = None
    error: str | None = None
    elapsed_ms: float = 0.0
    dry_run: bool = False
    data: dict[str, Any] = field(default_factory=dict)
    events: list[dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "success": self.success,
            "operation": self.operation,
            "message": self.message,
            "address": hex16(self.address),
            "value": hex32(self.value),
            "readback": hex32(self.readback),
            "error": self.error,
            "elapsed_ms": round(self.elapsed_ms, 3),
            "dry_run": self.dry_run,
            "data": self.data,
            "events": self.events,
        }

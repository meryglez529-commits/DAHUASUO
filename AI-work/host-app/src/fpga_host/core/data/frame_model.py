"""Frame model reserved for DL2 ADC data."""

from __future__ import annotations

from dataclasses import dataclass, field
import time


@dataclass(frozen=True)
class FrameModel:
    rows: int
    cols: int
    channels: int
    sample_bits: int = 16
    payload: bytes = b""
    timestamp: float = field(default_factory=time.time)
    source: str = "mock"

    @property
    def expected_samples(self) -> int:
        return self.rows * self.cols * self.channels

    @property
    def expected_bytes(self) -> int:
        return self.expected_samples * (self.sample_bits // 8)

    def to_dict(self) -> dict:
        return {
            "rows": self.rows,
            "cols": self.cols,
            "channels": self.channels,
            "sample_bits": self.sample_bits,
            "payload_bytes": len(self.payload),
            "expected_bytes": self.expected_bytes,
            "timestamp": self.timestamp,
            "source": self.source,
        }

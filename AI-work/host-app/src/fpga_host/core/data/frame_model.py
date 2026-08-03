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
    sequence_start: int | None = None
    sequence_end: int | None = None
    dropped_packets: int = 0

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
            "sequence_start": self.sequence_start,
            "sequence_end": self.sequence_end,
            "dropped_packets": self.dropped_packets,
        }

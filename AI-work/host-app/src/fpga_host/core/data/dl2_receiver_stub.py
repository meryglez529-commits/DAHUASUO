"""DL2 receiver placeholders.

The real DL2 packet/frame parser still depends on a dedicated DL2 deep read.
This module gives GUI/CLI/tests a stable boundary today.
"""

from __future__ import annotations

from fpga_host.core.data.frame_model import FrameModel
from fpga_host.core.data.receiver_base import DataReceiver


class Dl2ReceiverStub(DataReceiver):
    def __init__(self, rows: int = 1024, cols: int = 1024, channels: int = 4):
        self.rows = rows
        self.cols = cols
        self.channels = channels
        self.running = False

    def start(self) -> None:
        self.running = True

    def stop(self) -> None:
        self.running = False

    def get_frame(self, timeout_ms: int | None = None) -> FrameModel | None:
        if not self.running:
            return None
        return FrameModel(
            rows=self.rows,
            cols=self.cols,
            channels=self.channels,
            payload=b"",
            source="dl2_stub",
        )


class MockDl2Receiver(Dl2ReceiverStub):
    def get_frame(self, timeout_ms: int | None = None) -> FrameModel | None:
        if not self.running:
            return None
        sample_count = self.rows * self.cols * self.channels
        payload = bytearray()
        for index in range(sample_count):
            pixel = index // self.channels
            channel = index % self.channels
            value = (pixel * 257 + channel * 4096) & 0xFFFF
            payload.extend(value.to_bytes(2, "little"))
        return FrameModel(
            rows=self.rows,
            cols=self.cols,
            channels=self.channels,
            payload=bytes(payload),
            source="mock_dl2",
        )

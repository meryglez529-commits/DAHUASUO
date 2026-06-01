"""Abstract DL2 data receiver boundary."""

from __future__ import annotations

from abc import ABC, abstractmethod

from fpga_host.core.data.frame_model import FrameModel


class DataReceiver(ABC):
    @abstractmethod
    def start(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def stop(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def get_frame(self, timeout_ms: int | None = None) -> FrameModel | None:
        raise NotImplementedError

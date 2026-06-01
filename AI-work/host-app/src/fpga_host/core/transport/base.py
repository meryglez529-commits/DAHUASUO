"""Transport interface."""

from __future__ import annotations

from abc import ABC, abstractmethod


class Transport(ABC):
    @abstractmethod
    def open(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def close(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def transact(self, payload: bytes, expect_response: bool) -> bytes | None:
        raise NotImplementedError

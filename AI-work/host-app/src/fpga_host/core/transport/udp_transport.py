"""Real UDP transport for the FPGA DL4 control plane."""

from __future__ import annotations

import socket

from fpga_host.core.config import ConnectionConfig
from fpga_host.core.errors import TransportError, TransportTimeout
from fpga_host.core.transport.base import Transport


class UdpTransport(Transport):
    def __init__(self, config: ConnectionConfig):
        self.config = config
        self._socket: socket.socket | None = None

    def open(self) -> None:
        if self._socket is not None:
            return
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.settimeout(self.config.timeout_ms / 1000.0)
        try:
            sock.bind((self.config.host_ip, self.config.local_port))
        except OSError as exc:
            sock.close()
            raise TransportError(
                f"failed to bind UDP {self.config.host_ip}:{self.config.local_port}: {exc}"
            ) from exc
        self._socket = sock

    def close(self) -> None:
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def transact(self, payload: bytes, expect_response: bool) -> bytes | None:
        self.open()
        assert self._socket is not None
        remote = (self.config.fpga_ip, self.config.remote_port)
        attempts = 1 + max(0, self.config.retries if expect_response else 0)
        last_timeout: socket.timeout | None = None
        for _ in range(attempts):
            self._socket.sendto(payload, remote)
            if not expect_response:
                return None
            try:
                response, _addr = self._socket.recvfrom(2048)
                return response
            except socket.timeout as exc:
                last_timeout = exc
        raise TransportTimeout(
            f"UDP timeout waiting for {remote[0]}:{remote[1]} after {attempts} attempt(s)"
        ) from last_timeout

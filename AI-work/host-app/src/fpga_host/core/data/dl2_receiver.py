"""Real UDP receiver for the FPGA DL2 ADC data plane."""

from __future__ import annotations

import socket

from fpga_host.core.data.dl2_protocol import (
    Dl2FrameAssembler,
    Dl2FrameStats,
    Dl2ProtocolError,
    parse_dl2_packet,
)
from fpga_host.core.data.frame_model import FrameModel
from fpga_host.core.data.receiver_base import DataReceiver


DEFAULT_DL2_DATA_PORT = 32001


class Dl2UdpReceiver(DataReceiver):
    def __init__(
        self,
        host_ip: str = "0.0.0.0",
        port: int = DEFAULT_DL2_DATA_PORT,
        rows: int = 1024,
        cols: int = 1024,
        channels: int = 4,
        timeout_ms: int = 100,
    ):
        self.host_ip = host_ip
        self.port = port
        self.timeout_ms = timeout_ms
        self._socket: socket.socket | None = None
        self._assembler = Dl2FrameAssembler(rows=rows, cols=cols, channel_count=channels)
        self.last_error: str | None = None

    @property
    def stats(self) -> Dl2FrameStats:
        return self._assembler.stats

    def start(self) -> None:
        if self._socket is not None:
            return
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.settimeout(self.timeout_ms / 1000.0)
        sock.bind((self.host_ip, self.port))
        self._socket = sock

    def stop(self) -> None:
        if self._socket is not None:
            self._socket.close()
            self._socket = None
        self._assembler.reset()

    def get_frame(self, timeout_ms: int | None = None) -> FrameModel | None:
        self.start()
        assert self._socket is not None
        old_timeout = self._socket.gettimeout()
        if timeout_ms is not None:
            self._socket.settimeout(timeout_ms / 1000.0)
        try:
            while True:
                try:
                    datagram, _addr = self._socket.recvfrom(65535)
                except socket.timeout:
                    return None
                try:
                    packet = parse_dl2_packet(datagram)
                    frame = self._assembler.add_packet(packet)
                    if frame is not None:
                        return frame
                except Dl2ProtocolError as exc:
                    self.last_error = str(exc)
                    self._assembler.stats.bad_packets += 1
        finally:
            if timeout_ms is not None:
                self._socket.settimeout(old_timeout)

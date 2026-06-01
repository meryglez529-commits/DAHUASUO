"""Mock transport that behaves like a small virtual FPGA register file."""

from __future__ import annotations

from fpga_host.core.control import protocol
from fpga_host.core.control.register_map import (
    DEFAULT_UNKNOWN_READ_VALUE,
    REGISTER_SPECS,
    get_register,
)
from fpga_host.core.errors import ProtocolError, RegisterAccessError, TransportTimeout
from fpga_host.core.transport.base import Transport


class MockTransport(Transport):
    def __init__(self):
        self.registers = {addr: spec.default for addr, spec in REGISTER_SPECS.items()}
        self.is_open = False
        self.fail_next_timeout = False
        self.mismatch_addresses: set[int] = set()

    def open(self) -> None:
        self.is_open = True

    def close(self) -> None:
        self.is_open = False

    def transact(self, payload: bytes, expect_response: bool) -> bytes | None:
        self.open()
        if self.fail_next_timeout:
            self.fail_next_timeout = False
            raise TransportTimeout("mock timeout")
        packet = protocol.decode_payload(payload)
        if packet.command == protocol.CMD_WRITE:
            if packet.value is None:
                raise ProtocolError("write packet missing value")
            spec = get_register(packet.address)
            if not spec.writable:
                raise RegisterAccessError(f"{spec.name} is not writable")
            self.registers[packet.address] = packet.value & 0xFFFFFFFF
            return None
        if packet.command == protocol.CMD_READ:
            spec = get_register(packet.address)
            if not spec.readable:
                raise RegisterAccessError(f"{spec.name} is not readable")
            value = self.registers.get(packet.address, DEFAULT_UNKNOWN_READ_VALUE)
            if packet.address in self.mismatch_addresses:
                value ^= 1
            return protocol.encode_read_response(packet.address, value)
        raise ProtocolError(f"mock cannot handle command 0x{packet.command:04X}")

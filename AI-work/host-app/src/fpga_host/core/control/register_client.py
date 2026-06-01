"""Register read/write API on top of a transport."""

from __future__ import annotations

import time

from fpga_host.core.control import protocol
from fpga_host.core.control.register_map import DUMP_RANGES, get_register
from fpga_host.core.errors import ProtocolError, ReadbackMismatch, RegisterAccessError
from fpga_host.core.models import OperationResult, RegisterValue, hex16, hex32
from fpga_host.core.transport.base import Transport


class RegisterClient:
    def __init__(self, transport: Transport):
        self.transport = transport

    def read32(self, address: int) -> int:
        spec = get_register(address)
        if not spec.readable:
            raise RegisterAccessError(f"{spec.name} ({hex16(address)}) is not readable")
        payload = protocol.encode_read(address)
        response = self.transport.transact(payload, expect_response=True)
        if response is None:
            raise ProtocolError("read expected a response")
        resp_addr, value = protocol.decode_read_response(response)
        if resp_addr != address:
            raise ProtocolError(f"response address {hex16(resp_addr)} != request {hex16(address)}")
        return value

    def write32(self, address: int, value: int) -> OperationResult:
        spec = get_register(address)
        if not spec.writable:
            raise RegisterAccessError(f"{spec.name} ({hex16(address)}) is not writable")
        start = time.perf_counter()
        payload = protocol.encode_write(address, value)
        self.transport.transact(payload, expect_response=False)
        return OperationResult(
            success=True,
            operation="write32",
            message=f"sent {hex16(address)}={hex32(value)}",
            address=address,
            value=value,
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
        )

    def write_checked(self, address: int, value: int) -> OperationResult:
        spec = get_register(address)
        if not spec.readable:
            raise RegisterAccessError(f"{spec.name} ({hex16(address)}) is not readable for check")
        start = time.perf_counter()
        self.write32(address, value)
        readback = self.read32(address)
        elapsed = (time.perf_counter() - start) * 1000.0
        if readback != (value & 0xFFFFFFFF):
            return OperationResult(
                success=False,
                operation="write_checked",
                message="readback mismatch",
                address=address,
                value=value,
                readback=readback,
                error=ReadbackMismatch.__name__,
                elapsed_ms=elapsed,
            )
        return OperationResult(
            success=True,
            operation="write_checked",
            message=f"verified {hex16(address)}={hex32(value)}",
            address=address,
            value=value,
            readback=readback,
            elapsed_ms=elapsed,
        )

    def dump(self, range_name: str = "basic") -> list[RegisterValue]:
        if range_name not in DUMP_RANGES:
            raise RegisterAccessError(f"unknown dump range: {range_name}")
        values: list[RegisterValue] = []
        for address in DUMP_RANGES[range_name]:
            spec = get_register(address)
            if spec.readable:
                values.append(RegisterValue(address=address, value=self.read32(address), name=spec.name))
        return values

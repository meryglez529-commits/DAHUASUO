"""DL4 UDP payload encoder/decoder."""

from __future__ import annotations

from dataclasses import dataclass
import struct

from fpga_host.core.errors import ProtocolError

MAGIC = b"\x55\x55\xAA\xAA"
CMD_WRITE = 0x0001
CMD_READ = 0x0002
CMD_READ_RESPONSE = 0x0003
LEN_READ = 0x0002
LEN_WRITE_OR_RESPONSE = 0x0006


@dataclass(frozen=True)
class Dl4Packet:
    command: int
    length: int
    address: int
    value: int | None = None


def _check_u16(name: str, value: int) -> None:
    if not 0 <= value <= 0xFFFF:
        raise ProtocolError(f"{name} out of u16 range: {value!r}")


def _check_u32(name: str, value: int) -> None:
    if not 0 <= value <= 0xFFFFFFFF:
        raise ProtocolError(f"{name} out of u32 range: {value!r}")


def encode_write(address: int, value: int) -> bytes:
    _check_u16("address", address)
    _check_u32("value", value)
    return struct.pack(">4sHHHI", MAGIC, CMD_WRITE, LEN_WRITE_OR_RESPONSE, address, value)


def encode_read(address: int) -> bytes:
    _check_u16("address", address)
    return struct.pack(">4sHHH", MAGIC, CMD_READ, LEN_READ, address)


def encode_read_response(address: int, value: int) -> bytes:
    _check_u16("address", address)
    _check_u32("value", value)
    return struct.pack(">4sHHHI", MAGIC, CMD_READ_RESPONSE, LEN_WRITE_OR_RESPONSE, address, value)


def decode_payload(payload: bytes) -> Dl4Packet:
    if len(payload) < 10:
        raise ProtocolError(f"payload too short: {len(payload)}")
    magic, command, length = struct.unpack(">4sHH", payload[:8])
    if magic != MAGIC:
        raise ProtocolError(f"bad magic: {magic.hex(' ')}")
    if length != len(payload) - 8:
        raise ProtocolError(f"bad length field {length}, actual {len(payload) - 8}")
    if command == CMD_READ:
        if length != LEN_READ or len(payload) != 10:
            raise ProtocolError("bad read packet length")
        (address,) = struct.unpack(">H", payload[8:10])
        return Dl4Packet(command=command, length=length, address=address)
    if command in (CMD_WRITE, CMD_READ_RESPONSE):
        if length != LEN_WRITE_OR_RESPONSE or len(payload) != 14:
            raise ProtocolError("bad write/response packet length")
        address, value = struct.unpack(">HI", payload[8:14])
        return Dl4Packet(command=command, length=length, address=address, value=value)
    raise ProtocolError(f"unsupported command: 0x{command:04X}")


def decode_read_response(payload: bytes) -> tuple[int, int]:
    packet = decode_payload(payload)
    if packet.command != CMD_READ_RESPONSE or packet.value is None:
        raise ProtocolError("payload is not a read response")
    return packet.address, packet.value

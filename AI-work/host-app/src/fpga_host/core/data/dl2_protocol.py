"""DL2 ADC UDP packet parsing and frame assembly."""

from __future__ import annotations

from dataclasses import dataclass

from fpga_host.core.data.frame_model import FrameModel


AA55_MAGIC = b"\xAA\x55\xAA\x55"
CC55_MAGIC = b"\xCC\x55\xCC\x55"
DL2_HEADER_BYTES = 12


class Dl2ProtocolError(ValueError):
    """Raised when a DL2 UDP payload does not match the FPGA packet format."""


@dataclass(frozen=True)
class Dl2Packet:
    kind: str
    sequence: int | None
    payload: bytes
    payload_length: int


@dataclass
class Dl2FrameStats:
    packets: int = 0
    frames: int = 0
    lost_packets: int = 0
    bad_packets: int = 0
    ignored_packets: int = 0
    bytes_in_frame: int = 0
    expected_bytes: int = 0
    last_sequence: int | None = None


def channel_count_to_mask(channel_count: int) -> int:
    """Map the user-facing channel count to the RTL adc_channel bitmask."""

    mapping = {1: 0x1, 2: 0x3, 4: 0xF}
    try:
        return mapping[channel_count]
    except KeyError as exc:
        raise ValueError("channel_count must be 1, 2, or 4") from exc


def parse_dl2_packet(datagram: bytes) -> Dl2Packet:
    if len(datagram) < DL2_HEADER_BYTES:
        raise Dl2ProtocolError("DL2 packet is shorter than the 12-byte header")

    magic = datagram[:4]
    if magic == AA55_MAGIC:
        sequence = _decode_sequence(datagram[4:10])
        payload_length = int.from_bytes(datagram[10:12], "little")
        actual = len(datagram) - DL2_HEADER_BYTES
        if actual != payload_length:
            raise Dl2ProtocolError(
                f"AA55 payload length mismatch: header={payload_length}, actual={actual}"
            )
        return Dl2Packet(
            kind="adc",
            sequence=sequence,
            payload=datagram[DL2_HEADER_BYTES:],
            payload_length=payload_length,
        )

    if magic == CC55_MAGIC:
        payload = datagram[DL2_HEADER_BYTES:]
        return Dl2Packet(
            kind="line",
            sequence=None,
            payload=payload,
            payload_length=len(payload),
        )

    raise Dl2ProtocolError(f"unknown DL2 magic 0x{magic.hex().upper()}")


def build_aa55_packet(sequence: int, payload: bytes) -> bytes:
    if not 0 <= sequence <= 0xFFFFFFFFFFFF:
        raise ValueError("sequence must fit in 48 bits")
    if len(payload) > 0xFFFF:
        raise ValueError("payload is too large for one DL2 packet")
    return AA55_MAGIC + _encode_sequence(sequence) + len(payload).to_bytes(2, "little") + payload


class Dl2FrameAssembler:
    def __init__(self, rows: int, cols: int, channel_count: int):
        if rows <= 0 or cols <= 0:
            raise ValueError("rows and cols must be positive")
        channel_count_to_mask(channel_count)
        self.rows = rows
        self.cols = cols
        self.channel_count = channel_count
        self.expected_bytes = rows * cols * channel_count * 2
        self._buffer = bytearray()
        self._first_sequence: int | None = None
        self._expected_sequence: int | None = None
        self.stats = Dl2FrameStats(expected_bytes=self.expected_bytes)

    def reset(self) -> None:
        self._buffer.clear()
        self._first_sequence = None
        self._expected_sequence = None
        self.stats.bytes_in_frame = 0

    def add_packet(self, packet: Dl2Packet) -> FrameModel | None:
        if packet.kind != "adc":
            self.stats.ignored_packets += 1
            return None

        self.stats.packets += 1
        self.stats.last_sequence = packet.sequence

        if self._expected_sequence is not None and packet.sequence != self._expected_sequence:
            self.stats.lost_packets += 1
            self._buffer.clear()
            self._first_sequence = packet.sequence

        if self._first_sequence is None:
            self._first_sequence = packet.sequence

        if packet.sequence is not None:
            self._expected_sequence = (packet.sequence + 1) & 0xFFFFFFFFFFFF

        if len(self._buffer) + packet.payload_length > self.expected_bytes:
            self.stats.bad_packets += 1
            self._buffer.clear()
            self._first_sequence = packet.sequence

        self._buffer.extend(packet.payload)
        self.stats.bytes_in_frame = len(self._buffer)

        if len(self._buffer) != self.expected_bytes:
            return None

        payload = bytes(self._buffer)
        frame = FrameModel(
            rows=self.rows,
            cols=self.cols,
            channels=self.channel_count,
            payload=payload,
            source="dl2_udp",
            sequence_start=self._first_sequence,
            sequence_end=packet.sequence,
            dropped_packets=self.stats.lost_packets,
        )
        self.stats.frames += 1
        self._buffer.clear()
        self._first_sequence = None
        self.stats.bytes_in_frame = 0
        return frame


def _decode_sequence(raw: bytes) -> int:
    if len(raw) != 6:
        raise Dl2ProtocolError("sequence field must be 6 bytes")
    return (
        (raw[1] << 40)
        | (raw[0] << 32)
        | (raw[5] << 24)
        | (raw[4] << 16)
        | (raw[3] << 8)
        | raw[2]
    )


def _encode_sequence(sequence: int) -> bytes:
    return bytes(
        [
            (sequence >> 32) & 0xFF,
            (sequence >> 40) & 0xFF,
            sequence & 0xFF,
            (sequence >> 8) & 0xFF,
            (sequence >> 16) & 0xFF,
            (sequence >> 24) & 0xFF,
        ]
    )

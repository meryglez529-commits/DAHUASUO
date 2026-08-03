from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.data.dl2_protocol import (
    Dl2FrameAssembler,
    Dl2ProtocolError,
    build_aa55_packet,
    channel_count_to_mask,
    parse_dl2_packet,
)


class Dl2ProtocolTests(unittest.TestCase):
    def test_channel_count_to_mask(self):
        self.assertEqual(channel_count_to_mask(1), 0x1)
        self.assertEqual(channel_count_to_mask(2), 0x3)
        self.assertEqual(channel_count_to_mask(4), 0xF)
        with self.assertRaises(ValueError):
            channel_count_to_mask(3)

    def test_parse_aa55_packet(self):
        payload = b"\x01\x02\x03\x04"
        packet = parse_dl2_packet(build_aa55_packet(0x010203040506, payload))
        self.assertEqual(packet.kind, "adc")
        self.assertEqual(packet.sequence, 0x010203040506)
        self.assertEqual(packet.payload_length, len(payload))
        self.assertEqual(packet.payload, payload)

    def test_reject_length_mismatch(self):
        packet = bytearray(build_aa55_packet(1, b"\x00\x01"))
        packet[10:12] = (3).to_bytes(2, "little")
        with self.assertRaises(Dl2ProtocolError):
            parse_dl2_packet(bytes(packet))

    def test_frame_assembler(self):
        assembler = Dl2FrameAssembler(rows=2, cols=2, channel_count=2)
        payload = bytes(range(16))
        frame = None
        frame = assembler.add_packet(parse_dl2_packet(build_aa55_packet(1, payload[:8])))
        self.assertIsNone(frame)
        frame = assembler.add_packet(parse_dl2_packet(build_aa55_packet(2, payload[8:])))
        self.assertIsNotNone(frame)
        self.assertEqual(frame.rows, 2)
        self.assertEqual(frame.cols, 2)
        self.assertEqual(frame.channels, 2)
        self.assertEqual(frame.payload, payload)
        self.assertEqual(frame.sequence_start, 1)
        self.assertEqual(frame.sequence_end, 2)

    def test_sequence_gap_drops_partial_frame(self):
        assembler = Dl2FrameAssembler(rows=2, cols=2, channel_count=1)
        assembler.add_packet(parse_dl2_packet(build_aa55_packet(1, b"\x00\x01")))
        frame = assembler.add_packet(parse_dl2_packet(build_aa55_packet(3, bytes(range(8)))))
        self.assertIsNotNone(frame)
        self.assertEqual(assembler.stats.lost_packets, 1)


if __name__ == "__main__":
    unittest.main()

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control import protocol
from fpga_host.core.errors import ProtocolError


class ProtocolTests(unittest.TestCase):
    def test_encode_write(self):
        self.assertEqual(
            protocol.encode_write(0x0205, 1).hex(" "),
            "55 55 aa aa 00 01 00 06 02 05 00 00 00 01",
        )

    def test_encode_read(self):
        self.assertEqual(
            protocol.encode_read(0x000A).hex(" "),
            "55 55 aa aa 00 02 00 02 00 0a",
        )

    def test_decode_response(self):
        payload = protocol.encode_read_response(0x000A, 0x000300AC)
        self.assertEqual(protocol.decode_read_response(payload), (0x000A, 0x000300AC))

    def test_bad_magic(self):
        with self.assertRaises(ProtocolError):
            protocol.decode_payload(b"\x00" * 10)


if __name__ == "__main__":
    unittest.main()

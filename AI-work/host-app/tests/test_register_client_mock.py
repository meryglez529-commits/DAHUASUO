from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control.register_client import RegisterClient
from fpga_host.core.transport.mock_transport import MockTransport


class RegisterClientMockTests(unittest.TestCase):
    def setUp(self):
        self.client = RegisterClient(MockTransport())

    def test_version_read(self):
        self.assertEqual(self.client.read32(0x000A), 0x000300AC)

    def test_write_checked_dl5(self):
        result = self.client.write_checked(0x0205, 1)
        self.assertTrue(result.success)
        self.assertEqual(result.readback, 1)

    def test_write_checked_mismatch(self):
        transport = MockTransport()
        transport.mismatch_addresses.add(0x0205)
        client = RegisterClient(transport)
        result = client.write_checked(0x0205, 1)
        self.assertFalse(result.success)


if __name__ == "__main__":
    unittest.main()

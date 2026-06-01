from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control.register_map import VERSION_VALUE, get_register


class RegisterMapTests(unittest.TestCase):
    def test_version_is_read_only(self):
        spec = get_register(0x000A)
        self.assertTrue(spec.readable)
        self.assertFalse(spec.writable)
        self.assertEqual(spec.default, VERSION_VALUE)

    def test_dl5_registers_are_read_write(self):
        for addr in range(0x0205, 0x020B):
            spec = get_register(addr)
            self.assertTrue(spec.readable)
            self.assertTrue(spec.writable)

    def test_0200_is_write_only_risk(self):
        spec = get_register(0x0200)
        self.assertFalse(spec.readable)
        self.assertTrue(spec.writable)


if __name__ == "__main__":
    unittest.main()

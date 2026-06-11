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

    def test_dl5_timing_registers_are_read_write(self):
        for addr in range(0x0206, 0x020B):
            spec = get_register(addr)
            self.assertTrue(spec.readable)
            self.assertTrue(spec.writable)

    def test_current_rtl_readback_address_split(self):
        sync2 = get_register(0x0205)
        laser = get_register(0x020B)
        self.assertEqual(sync2.name, "sync2_pixel_tri_width")
        self.assertTrue(sync2.readable)
        self.assertTrue(sync2.writable)
        self.assertEqual(laser.name, "laser_mode_en")
        self.assertTrue(laser.readable)
        self.assertTrue(laser.writable)

    def test_sync_registers_are_read_write(self):
        for addr in range(0x0200, 0x0206):
            spec = get_register(addr)
            self.assertTrue(spec.readable)
            self.assertTrue(spec.writable)


if __name__ == "__main__":
    unittest.main()

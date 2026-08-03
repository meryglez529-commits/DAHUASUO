from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control.scan import ScanConfig
from fpga_host.core.errors import ConfigError


class ScanPlanTests(unittest.TestCase):
    def test_scan_register_plan(self):
        plan = dict(
            ScanConfig(
                rows=1024,
                cols=1024,
                adc_sample=20,
                dac_sample=20,
                adc_channel=4,
                adc_interval=19,
                scan_mode=1,
            ).to_registers(scan_state=0)
        )
        self.assertEqual(plan[0x0004], 0x04000400)
        self.assertEqual(plan[0x0001], (1024 * 1024 << 4) | 0xF)
        self.assertEqual(plan[0x0002], 20)
        self.assertEqual(plan[0x0003], 0x00000FAA)
        self.assertEqual(plan[0x0008], 0)
        self.assertEqual(plan[0x0013], 1)
        self.assertEqual(plan[0x0014], 1)
        self.assertEqual(plan[0x0009], (19 << 8) | (1 << 4))

    def test_adc_channel_count_maps_to_rtl_bitmask(self):
        self.assertEqual(dict(ScanConfig(adc_channel=1).to_registers())[0x0001] & 0xF, 0x1)
        self.assertEqual(dict(ScanConfig(adc_channel=2).to_registers())[0x0001] & 0xF, 0x3)
        self.assertEqual(dict(ScanConfig(adc_channel=4).to_registers())[0x0001] & 0xF, 0xF)

    def test_sample_must_match(self):
        with self.assertRaises(ConfigError):
            ScanConfig(adc_sample=20, dac_sample=21).to_registers()

    def test_units_are_raw_hardware_steps(self):
        plan = dict(
            ScanConfig(
                dacx_recovery_time=50,
                dax_fall_time=20,
                frame_waiting_time=7,
                row_repeat=2,
                row_n=1,
            ).to_registers()
        )
        self.assertEqual(plan[0x0006] & 0xFFFF, 50)
        self.assertEqual(plan[0x000F], 20)
        self.assertEqual(plan[0x0008], 7)
        self.assertEqual(plan[0x0013], 2)


if __name__ == "__main__":
    unittest.main()

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
        self.assertEqual(plan[0x0002], 20)
        self.assertEqual(plan[0x0009], (19 << 8) | (1 << 4))

    def test_sample_must_match(self):
        with self.assertRaises(ConfigError):
            ScanConfig(adc_sample=20, dac_sample=21).to_registers()


if __name__ == "__main__":
    unittest.main()

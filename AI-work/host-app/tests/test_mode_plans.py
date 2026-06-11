from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.core.control.modes import LaserModeConfig, NormalModeConfig, UltrafastModeConfig
from fpga_host.core.control.scan import ScanConfig


class ModePlanTests(unittest.TestCase):
    def scan(self):
        return ScanConfig(rows=1024, cols=1024, adc_sample=20, dac_sample=20, adc_channel=4)

    def test_normal_disables_extensions(self):
        plan = NormalModeConfig(scan=self.scan()).to_plan()
        writes = [(item.address, item.value, item.checked) for item in plan.items]
        self.assertIn((0x020B, 0, True), writes)
        self.assertIn((0x0202, 0, True), writes)
        self.assertEqual(plan.mode, "normal")

    def test_ultrafast_uses_checked_extension_regs(self):
        plan = UltrafastModeConfig(
            scan=self.scan(),
            ultrafast_line_rec=7,
            adc_acq_delay=3,
            acq_dead_time=5,
            sync2_width=5,
        ).to_plan()
        values = {item.address: item for item in plan.items}
        self.assertEqual(values[0x0202].value, (7 << 1) | 1)
        self.assertTrue(values[0x0201].checked)
        self.assertEqual(values[0x0205].value, 5)
        self.assertTrue(values[0x0205].checked)
        self.assertFalse(plan.warnings)

    def test_laser_sequence_closes_then_enables(self):
        plan = LaserModeConfig(
            scan=self.scan(),
            dl5=Dl5Config(laser_mode=1, scan_delay=100, blanker_delay=20, blanker_time=80, acq_delay=30, acq_time=60),
        ).to_plan()
        laser_writes = [item.value for item in plan.items if item.address == 0x020B]
        self.assertEqual(laser_writes, [0, 1])
        self.assertTrue(all(item.checked for item in plan.items if item.address == 0x020B))
        self.assertIn(0x020A, {item.address for item in plan.items})


if __name__ == "__main__":
    unittest.main()

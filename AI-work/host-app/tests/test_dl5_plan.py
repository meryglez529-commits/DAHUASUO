from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.core.control.dl5 import Dl5Config


class Dl5PlanTests(unittest.TestCase):
    def test_dl5_register_plan(self):
        config = Dl5Config(
            laser_mode=1,
            scan_delay=100,
            blanker_delay=20,
            blanker_time=80,
            acq_delay=30,
            acq_time=60,
        )
        self.assertEqual(
            config.to_registers(),
            [
                (0x0205, 1),
                (0x0206, 100),
                (0x0207, 20),
                (0x0208, 80),
                (0x0209, 30),
                (0x020A, 60),
            ],
        )

    def test_safe_apply_disables_then_enables(self):
        plan = Dl5Config(laser_mode=1).to_safe_apply_registers()
        self.assertEqual(plan[0], (0x0205, 0))
        self.assertEqual(plan[-1], (0x0205, 1))


if __name__ == "__main__":
    unittest.main()

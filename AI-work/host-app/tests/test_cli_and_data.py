from pathlib import Path
from contextlib import redirect_stderr, redirect_stdout
import io
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from fpga_host.cli.main import main
from fpga_host.core.data.dl2_receiver_stub import MockDl2Receiver


class CliAndDataTests(unittest.TestCase):
    def test_cli_version_mock(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(main(["version", "--mock", "--json"]), 0)

    def test_cli_blocks_real_write_without_yes(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(main(["write", "0x0205", "1"]), 20)

    def test_cli_mode_laser_dry_run(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = main([
                "mode",
                "laser",
                "apply",
                "--mock",
                "--dry-run",
                "--json",
                "--laser-mode",
                "1",
                "--scan-delay",
                "100",
                "--blanker-delay",
                "20",
                "--blanker-time",
                "80",
                "--acq-delay",
                "30",
                "--acq-time",
                "60",
            ])
        self.assertEqual(code, 0)
        self.assertIn('"mode": "laser"', out.getvalue())

    def test_mock_dl2_frame(self):
        receiver = MockDl2Receiver(rows=4, cols=4, channels=2)
        receiver.start()
        frame = receiver.get_frame()
        receiver.stop()
        self.assertIsNotNone(frame)
        self.assertEqual(frame.rows, 4)
        self.assertEqual(frame.channels, 2)
        self.assertGreater(len(frame.payload), 0)


if __name__ == "__main__":
    unittest.main()

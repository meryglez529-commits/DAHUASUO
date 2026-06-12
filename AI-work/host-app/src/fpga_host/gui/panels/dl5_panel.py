"""DL5 configuration panel."""

from __future__ import annotations

from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.gui.qt_compat import QtWidgets


class Dl5Panel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        layout = QtWidgets.QFormLayout(self)
        self.laser_mode = QtWidgets.QCheckBox()
        self.scan_delay = self._spin(0)
        self.blanker_delay = self._spin(0)
        self.blanker_time = self._spin(0)
        self.acq_delay = self._spin(0)
        self.acq_time = self._spin(0)
        self.dry_run = QtWidgets.QCheckBox()
        self.start_after = QtWidgets.QCheckBox()
        self.apply_btn = QtWidgets.QPushButton("Apply DL5")
        self.result = QtWidgets.QLabel("-")
        layout.addRow("Laser mode", self.laser_mode)
        layout.addRow("Scan delay", self.scan_delay)
        layout.addRow("Blanker delay", self.blanker_delay)
        layout.addRow("Blanker time", self.blanker_time)
        layout.addRow("Acq delay", self.acq_delay)
        layout.addRow("Acq time", self.acq_time)
        layout.addRow("Dry run", self.dry_run)
        layout.addRow("Start after apply", self.start_after)
        layout.addRow(self.apply_btn)
        layout.addRow("Result", self.result)
        self.apply_btn.clicked.connect(self.apply_dl5)

    def _spin(self, value: int):
        box = QtWidgets.QSpinBox()
        box.setRange(0, 0xFFFF)
        box.setValue(value)
        buttons = getattr(QtWidgets.QAbstractSpinBox, "ButtonSymbols", QtWidgets.QAbstractSpinBox)
        box.setButtonSymbols(buttons.NoButtons)
        return box

    def _config(self) -> Dl5Config:
        return Dl5Config(
            laser_mode=1 if self.laser_mode.isChecked() else 0,
            scan_delay=self.scan_delay.value(),
            blanker_delay=self.blanker_delay.value(),
            blanker_time=self.blanker_time.value(),
            acq_delay=self.acq_delay.value(),
            acq_time=self.acq_time.value(),
        )

    def apply_dl5(self) -> None:
        try:
            result = self.main_window.device.apply_dl5_config(
                self._config(),
                stop_before_apply=True,
                start_after_apply=self.start_after.isChecked(),
                dry_run=self.dry_run.isChecked(),
            )
            self.result.setText(result.message)
            self.main_window.log(result.message)
        except Exception as exc:
            self.result.setText(str(exc))
            self.main_window.log(f"apply dl5 failed: {exc}")

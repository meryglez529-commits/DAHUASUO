"""Scan configuration panel."""

from __future__ import annotations

from fpga_host.core.control.scan import ScanConfig
from fpga_host.gui.qt_compat import QtWidgets


class ScanPanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        layout = QtWidgets.QFormLayout(self)
        self.rows = self._spin(1, 65535, 1024)
        self.cols = self._spin(1, 65535, 1024)
        self.sample = self._spin(1, 0xFFFFFFFF, 20)
        self.adc_channel = self._spin(1, 4, 4)
        self.adc_interval = self._spin(0, 0xFFFFFF, 0)
        self.scan_mode = self._spin(0, 15, 1)
        self.dry_run = QtWidgets.QCheckBox()
        self.apply_btn = QtWidgets.QPushButton("Apply Scan")
        self.start_btn = QtWidgets.QPushButton("Start")
        self.stop_btn = QtWidgets.QPushButton("Stop")
        self.result = QtWidgets.QLabel("-")
        layout.addRow("Rows", self.rows)
        layout.addRow("Cols", self.cols)
        layout.addRow("Sample / dwell points", self.sample)
        layout.addRow("ADC channel", self.adc_channel)
        layout.addRow("ADC interval (ADC cycles, ~20ns/step)", self.adc_interval)
        layout.addRow("Scan mode", self.scan_mode)
        layout.addRow("Dry run", self.dry_run)
        layout.addRow(self.apply_btn)
        layout.addRow(self.start_btn)
        layout.addRow(self.stop_btn)
        layout.addRow("Result", self.result)
        self.apply_btn.clicked.connect(self.apply_scan)
        self.start_btn.clicked.connect(self.start_scan)
        self.stop_btn.clicked.connect(self.stop_scan)

    def _spin(self, minimum: int, maximum: int, value: int):
        box = QtWidgets.QSpinBox()
        box.setRange(minimum, min(maximum, 2147483647))
        box.setValue(value)
        buttons = getattr(QtWidgets.QAbstractSpinBox, "ButtonSymbols", QtWidgets.QAbstractSpinBox)
        box.setButtonSymbols(buttons.NoButtons)
        return box

    def _config(self) -> ScanConfig:
        return ScanConfig(
            rows=self.rows.value(),
            cols=self.cols.value(),
            adc_sample=self.sample.value(),
            dac_sample=self.sample.value(),
            adc_channel=self.adc_channel.value(),
            adc_interval=self.adc_interval.value(),
            scan_mode=self.scan_mode.value(),
        )

    def _show(self, text: str) -> None:
        self.result.setText(text)
        self.main_window.log(text)

    def apply_scan(self) -> None:
        try:
            result = self.main_window.device.apply_scan_config(self._config(), dry_run=self.dry_run.isChecked())
            self._show(result.message)
        except Exception as exc:
            self._show(f"apply scan failed: {exc}")

    def start_scan(self) -> None:
        try:
            result = self.main_window.device.start_scan(
                adc_interval=self.adc_interval.value(), scan_mode=self.scan_mode.value(), dry_run=self.dry_run.isChecked()
            )
            self._show(result.message)
        except Exception as exc:
            self._show(f"start failed: {exc}")

    def stop_scan(self) -> None:
        try:
            result = self.main_window.device.stop_scan(
                adc_interval=self.adc_interval.value(), scan_mode=self.scan_mode.value(), dry_run=self.dry_run.isChecked()
            )
            self._show(result.message)
        except Exception as exc:
            self._show(f"stop failed: {exc}")

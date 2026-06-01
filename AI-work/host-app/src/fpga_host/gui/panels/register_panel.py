"""Raw register console panel."""

from __future__ import annotations

from fpga_host.gui.qt_compat import QtWidgets


def parse_int(text: str) -> int:
    return int(text.strip(), 0)


class RegisterPanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        layout = QtWidgets.QFormLayout(self)
        self.address = QtWidgets.QLineEdit("0x000A")
        self.value = QtWidgets.QLineEdit("0x00000000")
        self.read_btn = QtWidgets.QPushButton("Read32")
        self.write_btn = QtWidgets.QPushButton("Write32")
        self.write_checked_btn = QtWidgets.QPushButton("Write Checked")
        self.result = QtWidgets.QLabel("-")
        layout.addRow("Address", self.address)
        layout.addRow("Value", self.value)
        layout.addRow(self.read_btn)
        layout.addRow(self.write_btn)
        layout.addRow(self.write_checked_btn)
        layout.addRow("Result", self.result)
        self.read_btn.clicked.connect(self.read32)
        self.write_btn.clicked.connect(self.write32)
        self.write_checked_btn.clicked.connect(self.write_checked)

    def _show(self, text: str) -> None:
        self.result.setText(text)
        self.main_window.log(text)

    def read32(self) -> None:
        try:
            result = self.main_window.device.read_register(parse_int(self.address.text()))
            self._show(result.message)
        except Exception as exc:
            self._show(f"read failed: {exc}")

    def write32(self) -> None:
        try:
            result = self.main_window.device.write_register(
                parse_int(self.address.text()), parse_int(self.value.text()), checked=False
            )
            self._show(result.message)
        except Exception as exc:
            self._show(f"write failed: {exc}")

    def write_checked(self) -> None:
        try:
            result = self.main_window.device.write_register(
                parse_int(self.address.text()), parse_int(self.value.text()), checked=True
            )
            self._show(result.message)
        except Exception as exc:
            self._show(f"write checked failed: {exc}")

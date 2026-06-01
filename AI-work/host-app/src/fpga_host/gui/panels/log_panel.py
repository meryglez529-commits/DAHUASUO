"""Log panel."""

from __future__ import annotations

from fpga_host.gui.qt_compat import QtWidgets


class LogPanel(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        layout = QtWidgets.QVBoxLayout(self)
        self.text = QtWidgets.QTextEdit()
        self.text.setReadOnly(True)
        layout.addWidget(self.text)

    def append(self, message: str) -> None:
        self.text.append(message)

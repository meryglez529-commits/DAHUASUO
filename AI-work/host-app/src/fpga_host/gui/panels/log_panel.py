"""Collapsible log panel."""

from __future__ import annotations

from fpga_host.gui.qt_compat import QtWidgets


class LogPanel(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.error_count = 0
        self.warning_count = 0
        self.info_count = 0

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self.toggle = QtWidgets.QToolButton()
        self.toggle.setCheckable(True)
        self.toggle.setChecked(False)
        self.toggle.clicked.connect(self._refresh)

        self.text = QtWidgets.QTextEdit()
        self.text.setReadOnly(True)
        self.text.setMinimumHeight(120)
        self.text.setVisible(False)

        layout.addWidget(self.toggle)
        layout.addWidget(self.text)
        self._refresh()

    def append(self, message: str) -> None:
        lower = message.lower()
        if "failed" in lower or "error" in lower or "mismatch" in lower:
            self.error_count += 1
            self.toggle.setChecked(True)
        elif "warning" in lower or "warn" in lower:
            self.warning_count += 1
        else:
            self.info_count += 1
        self.text.append(message)
        self._refresh()

    def _refresh(self) -> None:
        expanded = self.toggle.isChecked()
        prefix = "v" if expanded else ">"
        self.toggle.setText(
            f"{prefix} 日志  {self.error_count} error / "
            f"{self.warning_count} warning / {self.info_count} info"
        )
        self.text.setVisible(expanded)

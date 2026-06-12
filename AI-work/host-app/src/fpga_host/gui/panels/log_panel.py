"""Collapsible log panel."""

from __future__ import annotations

from fpga_host.gui.qt_compat import QtWidgets


class LogPanel(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.error_count = 0
        self.warning_count = 0
        self.info_count = 0
        self.max_lines = 500
        self._levels: list[str] = []

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        header = QtWidgets.QWidget()
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(6)

        self.toggle = QtWidgets.QToolButton()
        self.toggle.setCheckable(True)
        self.toggle.setChecked(False)
        self.toggle.clicked.connect(self._refresh)

        self.clear_btn = QtWidgets.QPushButton("清除")
        self.clear_btn.setMaximumWidth(72)
        self.clear_btn.clicked.connect(self.clear)

        self.text = QtWidgets.QTextEdit()
        self.text.setReadOnly(True)
        self.text.setMinimumHeight(120)
        self.text.setVisible(False)
        self.text.document().setMaximumBlockCount(self.max_lines)

        header_layout.addWidget(self.toggle)
        header_layout.addStretch(1)
        header_layout.addWidget(self.clear_btn)

        layout.addWidget(header)
        layout.addWidget(self.text)
        self._refresh()

    def append(self, message: str) -> None:
        lower = message.lower()
        if "failed" in lower or "error" in lower or "mismatch" in lower:
            level = "error"
            self.toggle.setChecked(True)
        elif "warning" in lower or "warn" in lower:
            level = "warning"
        else:
            level = "info"
        if len(self._levels) >= self.max_lines:
            self._decrement_count(self._levels.pop(0))
        self._levels.append(level)
        self._increment_count(level)
        self.text.append(message)
        self._refresh()

    def clear(self) -> None:
        self.error_count = 0
        self.warning_count = 0
        self.info_count = 0
        self._levels.clear()
        self.text.clear()
        self._refresh()

    def _increment_count(self, level: str) -> None:
        if level == "error":
            self.error_count += 1
        elif level == "warning":
            self.warning_count += 1
        else:
            self.info_count += 1

    def _decrement_count(self, level: str) -> None:
        if level == "error":
            self.error_count = max(0, self.error_count - 1)
        elif level == "warning":
            self.warning_count = max(0, self.warning_count - 1)
        else:
            self.info_count = max(0, self.info_count - 1)

    def _refresh(self) -> None:
        expanded = self.toggle.isChecked()
        prefix = "v" if expanded else ">"
        self.toggle.setText(
            f"{prefix} 日志  {self.error_count} error / "
            f"{self.warning_count} warning / {self.info_count} info"
        )
        self.text.setVisible(expanded)

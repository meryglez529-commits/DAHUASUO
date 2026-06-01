"""GUI application entry point."""

from __future__ import annotations

import sys

from fpga_host.gui.main_window import MainWindow
from fpga_host.gui.qt_compat import QtWidgets


def main(argv: list[str] | None = None) -> int:
    app = QtWidgets.QApplication(argv or sys.argv)
    window = MainWindow()
    window.resize(1100, 720)
    window.show()
    if hasattr(app, "exec"):
        return app.exec()
    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())

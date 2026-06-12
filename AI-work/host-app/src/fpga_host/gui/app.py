"""GUI application entry point."""

from __future__ import annotations

import sys

from fpga_host.gui.main_window import MainWindow
from fpga_host.gui.qt_compat import QtWidgets


def _apply_style(app: QtWidgets.QApplication) -> None:
    if hasattr(QtWidgets, "QStyleFactory"):
        app.setStyle("Fusion")
    app.setStyleSheet(
        """
        QWidget {
            background: #f3f4f6;
            color: #111827;
            font-size: 9pt;
        }
        QMainWindow, QTabWidget::pane {
            background: #f3f4f6;
        }
        QTabWidget::pane {
            border: 1px solid #c9ced6;
        }
        QTabBar::tab {
            background: #e5e7eb;
            border: 1px solid #c9ced6;
            padding: 4px 10px;
            margin-right: 2px;
        }
        QTabBar::tab:selected {
            background: #ffffff;
            border-bottom: 2px solid #2563eb;
        }
        QFrame[frameShape="6"],
        QGroupBox {
            background: #f9fafb;
            border: 1px solid #cfd5dd;
            border-radius: 3px;
        }
        QGroupBox {
            margin-top: 10px;
            font-weight: 600;
            padding-top: 7px;
        }
        QGroupBox::title {
            subcontrol-origin: margin;
            left: 8px;
            padding: 0 4px;
            color: #374151;
            background: #f3f4f6;
        }
        QLineEdit, QSpinBox, QComboBox, QTextEdit, QTableWidget {
            background: #ffffff;
            border: 1px solid #b8c2d1;
            border-radius: 2px;
            padding: 1px 3px;
        }
        QLineEdit:focus, QSpinBox:focus, QComboBox:focus {
            border: 1px solid #2563eb;
        }
        QPushButton, QToolButton {
            background: #edf2f7;
            border: 1px solid #aeb8c6;
            border-radius: 3px;
            padding: 3px 10px;
        }
        QPushButton:hover, QToolButton:hover {
            background: #e2e8f0;
        }
        QPushButton:default {
            background: #eff6ff;
            border: 1px solid #2563eb;
            color: #1d4ed8;
            font-weight: 600;
        }
        QPushButton#ApplyButton {
            background: #eff6ff;
            border: 1px solid #2563eb;
            color: #1d4ed8;
            font-weight: 600;
        }
        QPushButton#StartButton {
            background: #ecfdf5;
            border: 1px solid #059669;
            color: #047857;
            font-weight: 600;
        }
        QPushButton#StopButton {
            background: #fff7ed;
            border: 1px solid #f97316;
            color: #c2410c;
        }
        QPushButton:disabled {
            color: #94a3b8;
            background: #e5e7eb;
            border-color: #cbd5e1;
        }
        QScrollArea, QScrollArea > QWidget > QWidget {
            background: #f3f4f6;
        }
        QFrame#ParamRow {
            background: transparent;
            border: 0;
        }
        """
    )


def main(argv: list[str] | None = None) -> int:
    app = QtWidgets.QApplication(argv or sys.argv)
    _apply_style(app)
    window = MainWindow()
    window.resize(1100, 720)
    window.show()
    if hasattr(app, "exec"):
        return app.exec()
    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())

"""Qt binding compatibility helper."""

from __future__ import annotations

QT_API = ""

try:
    from PySide6 import QtCore, QtGui, QtWidgets

    QT_API = "PySide6"
except ImportError:
    try:
        from PyQt6 import QtCore, QtGui, QtWidgets

        QT_API = "PyQt6"
        QtCore.Signal = QtCore.pyqtSignal
        QtCore.Slot = QtCore.pyqtSlot
    except ImportError:
        try:
            from PyQt5 import QtCore, QtGui, QtWidgets

            QT_API = "PyQt5"
            QtCore.Signal = QtCore.pyqtSignal
            QtCore.Slot = QtCore.pyqtSlot
        except ImportError as exc:
            raise RuntimeError("No Qt binding found. Install PySide6 first.") from exc

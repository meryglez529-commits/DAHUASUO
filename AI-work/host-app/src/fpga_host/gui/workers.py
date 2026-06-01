"""Worker scaffolding for future real UDP and DL2 background tasks."""

from __future__ import annotations

from fpga_host.gui.qt_compat import QtCore


class ControlWorker(QtCore.QObject):
    finished = QtCore.Signal(object)
    failed = QtCore.Signal(str)

    def __init__(self, func, *args, **kwargs):
        super().__init__()
        self.func = func
        self.args = args
        self.kwargs = kwargs

    @QtCore.Slot()
    def run(self):
        try:
            self.finished.emit(self.func(*self.args, **self.kwargs))
        except Exception as exc:
            self.failed.emit(str(exc))

"""Connection panel."""

from __future__ import annotations

from fpga_host.core.config import ConnectionConfig
from fpga_host.gui.qt_compat import QtWidgets


class ConnectionPanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        layout = QtWidgets.QFormLayout(self)
        self.mock = QtWidgets.QCheckBox()
        self.mock.setChecked(True)
        self.host_ip = QtWidgets.QLineEdit("0.0.0.0")
        self.fpga_ip = QtWidgets.QLineEdit("192.168.1.8")
        self.local_port = QtWidgets.QSpinBox()
        self.local_port.setRange(1, 65535)
        self.local_port.setValue(32000)
        self.remote_port = QtWidgets.QSpinBox()
        self.remote_port.setRange(1, 65535)
        self.remote_port.setValue(32000)
        self.timeout_ms = QtWidgets.QSpinBox()
        self.timeout_ms.setRange(1, 10000)
        self.timeout_ms.setValue(500)
        self.apply_btn = QtWidgets.QPushButton("Apply Connection")
        self.version_btn = QtWidgets.QPushButton("Read Version")
        self.result = QtWidgets.QLabel("-")

        layout.addRow("Mock mode", self.mock)
        layout.addRow("Host IP", self.host_ip)
        layout.addRow("FPGA IP", self.fpga_ip)
        layout.addRow("Local port", self.local_port)
        layout.addRow("Remote port", self.remote_port)
        layout.addRow("Timeout ms", self.timeout_ms)
        layout.addRow(self.apply_btn)
        layout.addRow(self.version_btn)
        layout.addRow("Result", self.result)

        self.apply_btn.clicked.connect(self.apply_connection)
        self.version_btn.clicked.connect(self.read_version)

    def apply_connection(self) -> None:
        config = ConnectionConfig(
            host_ip=self.host_ip.text().strip(),
            fpga_ip=self.fpga_ip.text().strip(),
            local_port=self.local_port.value(),
            remote_port=self.remote_port.value(),
            timeout_ms=self.timeout_ms.value(),
            mock=self.mock.isChecked(),
        )
        self.main_window.update_connection(config)

    def read_version(self) -> None:
        try:
            result = self.main_window.device.version()
            self.result.setText(result.message)
            self.main_window.log(result.message)
        except Exception as exc:
            self.result.setText(str(exc))
            self.main_window.log(f"version failed: {exc}")

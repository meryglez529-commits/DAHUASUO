"""Compact connection bar for the main GUI."""

from __future__ import annotations

from fpga_host.core.config import ConnectionConfig
from fpga_host.gui.qt_compat import QtCore, QtWidgets


class ConnectionBar(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(8, 6, 8, 6)

        self.badge = QtWidgets.QLabel("MOCK")
        self.badge.setMinimumWidth(64)
        self.badge.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)

        self.mock = QtWidgets.QCheckBox("Mock")
        self.mock.setChecked(True)

        self.fpga_ip = QtWidgets.QLineEdit("192.168.1.8")
        self.fpga_ip.setMaximumWidth(130)
        self.host_ip = QtWidgets.QLineEdit("0.0.0.0")
        self.host_ip.setMaximumWidth(110)

        self.local_port = QtWidgets.QSpinBox()
        self.local_port.setRange(1, 65535)
        self.local_port.setValue(32000)
        self.local_port.setMaximumWidth(86)

        self.remote_port = QtWidgets.QSpinBox()
        self.remote_port.setRange(1, 65535)
        self.remote_port.setValue(32000)
        self.remote_port.setMaximumWidth(86)

        self.apply_btn = QtWidgets.QPushButton("连接")
        self.version_btn = QtWidgets.QPushButton("读版本")
        self.diagnose_btn = QtWidgets.QPushButton("网络诊断")
        self.version_label = QtWidgets.QLabel("version: -")
        self.version_label.setMinimumWidth(150)

        layout.addWidget(self.badge)
        layout.addSpacing(8)
        layout.addWidget(self.mock)
        layout.addWidget(QtWidgets.QLabel("FPGA IP"))
        layout.addWidget(self.fpga_ip)
        layout.addWidget(QtWidgets.QLabel("本机 IP"))
        layout.addWidget(self.host_ip)
        layout.addWidget(QtWidgets.QLabel("本机端口"))
        layout.addWidget(self.local_port)
        layout.addWidget(QtWidgets.QLabel("FPGA 端口"))
        layout.addWidget(self.remote_port)
        layout.addWidget(self.apply_btn)
        layout.addWidget(self.version_btn)
        layout.addWidget(self.diagnose_btn)
        layout.addWidget(self.version_label)
        layout.addStretch(1)

        self.apply_btn.clicked.connect(self.apply_connection)
        self.version_btn.clicked.connect(self.read_version)
        self.diagnose_btn.clicked.connect(self.diagnose_network)
        self.mock.toggled.connect(self._refresh_badge)
        self._refresh_badge()

    def _refresh_badge(self) -> None:
        if self.mock.isChecked():
            self.badge.setText("MOCK")
            self.badge.setStyleSheet(
                "QLabel { background: #eef2ff; color: #3730a3; border: 1px solid #c7d2fe; padding: 4px; }"
            )
        else:
            self.badge.setText("REAL")
            self.badge.setStyleSheet(
                "QLabel { background: #fff7ed; color: #9a3412; border: 1px solid #fed7aa; padding: 4px; }"
            )

    def apply_connection(self) -> None:
        config = ConnectionConfig(
            host_ip=self.host_ip.text().strip(),
            fpga_ip=self.fpga_ip.text().strip(),
            local_port=self.local_port.value(),
            remote_port=self.remote_port.value(),
            mock=self.mock.isChecked(),
        )
        self.main_window.update_connection(config)
        self._refresh_badge()

    def set_config(self, config: ConnectionConfig) -> None:
        self.mock.setChecked(config.mock)
        self.fpga_ip.setText(config.fpga_ip)
        self.host_ip.setText(config.host_ip)
        self.local_port.setValue(config.local_port)
        self.remote_port.setValue(config.remote_port)
        self._refresh_badge()

    def read_version(self) -> None:
        try:
            result = self.main_window.device.version()
            self.version_label.setText(result.message)
            self.main_window.log(result.message)
        except Exception as exc:
            self.version_label.setText("version failed")
            self.main_window.log(f"version failed: {exc}; endpoints: {self._endpoint_summary()}")

    def diagnose_network(self) -> None:
        self.main_window.log(f"diagnose: {self._endpoint_summary()}")
        self.read_version()
        try:
            scan = self.main_window.device.read_register(0x0009)
            self.main_window.log(f"diagnose scan_control: {scan.message}")
        except Exception as exc:
            self.main_window.log(f"diagnose scan_control failed: {exc}")
        if hasattr(self.main_window, "mode_panel"):
            self.main_window.mode_panel.refresh_scan_status(log_failures=False)

    def _endpoint_summary(self) -> str:
        config = self.main_window.config
        mode = "mock" if config.mock else "real"
        return (
            f"mode={mode}, host={config.host_ip}:{config.local_port}, "
            f"fpga={config.fpga_ip}:{config.remote_port}, timeout={config.timeout_ms}ms"
        )

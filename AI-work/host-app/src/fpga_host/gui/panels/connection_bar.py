"""Connection and device identity bar for the main GUI."""

from __future__ import annotations

from fpga_host.core.config import ConnectionConfig
from fpga_host.gui.qt_compat import QtCore, QtWidgets


class ConnectionBar(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(10, 6, 10, 6)
        layout.setSpacing(10)

        self.mode_chip = QtWidgets.QLabel("MOCK")
        self.mode_chip.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        self.mode_chip.setMinimumWidth(58)

        self.transport_mode = QtWidgets.QComboBox()
        self.transport_mode.addItem("Mock", True)
        self.transport_mode.addItem("Real", False)
        self.transport_mode.setMaximumWidth(92)
        self.transport_mode.setToolTip("选择使用本地 mock 传输，或连接真实 FPGA。")

        self.host_ip = self._line_edit("0.0.0.0", 118)
        self.host_ip.setToolTip("0.0.0.0 表示自动绑定所有本机网卡，不是未配置。")
        self.fpga_ip = self._line_edit("192.168.1.8", 128)
        self.local_port = self._port_spin()
        self.remote_port = self._port_spin()

        self.apply_btn = QtWidgets.QPushButton("连接")
        self.apply_btn.setDefault(True)
        self.version_btn = QtWidgets.QPushButton("读版本")
        self.diagnose_btn = QtWidgets.QPushButton("诊断")
        self.diagnose_btn.setToolTip("读取版本和 scan_control，用于快速确认 UDP 控制链路。")
        self.version_label = QtWidgets.QLabel("version: -")
        self.version_label.setMinimumWidth(150)

        layout.addWidget(self.mode_chip)
        layout.addWidget(self.transport_mode)
        layout.addSpacing(4)
        layout.addWidget(QtWidgets.QLabel("本机 IP"))
        layout.addWidget(self.host_ip)
        layout.addWidget(QtWidgets.QLabel("本机端口"))
        layout.addWidget(self.local_port)
        layout.addSpacing(6)
        layout.addWidget(QtWidgets.QLabel("FPGA IP"))
        layout.addWidget(self.fpga_ip)
        layout.addWidget(QtWidgets.QLabel("FPGA 端口"))
        layout.addWidget(self.remote_port)
        layout.addSpacing(8)
        layout.addWidget(self.apply_btn)
        layout.addWidget(self.version_btn)
        layout.addWidget(self.version_label)
        layout.addWidget(self.diagnose_btn)
        layout.addStretch(1)

        self.apply_btn.clicked.connect(self.apply_connection)
        self.version_btn.clicked.connect(self.read_version)
        self.diagnose_btn.clicked.connect(self.diagnose_network)
        self.transport_mode.currentIndexChanged.connect(lambda _index: self._refresh_badge())
        self.host_ip.textChanged.connect(lambda _text: self._refresh_host_hint())
        self._refresh_badge()
        self._refresh_host_hint()

    def _line_edit(self, text: str, width: int):
        edit = QtWidgets.QLineEdit(text)
        edit.setMaximumWidth(width)
        edit.setMinimumWidth(width)
        return edit

    def _port_spin(self):
        box = QtWidgets.QSpinBox()
        box.setRange(1, 65535)
        box.setValue(32000)
        box.setMaximumWidth(82)
        return box

    def _is_mock_selected(self) -> bool:
        return bool(self.transport_mode.currentData())

    def _refresh_badge(self) -> None:
        if self._is_mock_selected():
            self.mode_chip.setText("MOCK")
            self.mode_chip.setStyleSheet(
                "QLabel { background: #eef2ff; color: #3730a3; "
                "border: 1px solid #c7d2fe; padding: 4px 8px; }"
            )
        else:
            self.mode_chip.setText("REAL")
            self.mode_chip.setStyleSheet(
                "QLabel { background: #fffbeb; color: #92400e; "
                "border: 1px solid #fcd34d; padding: 4px 8px; }"
            )

    def _refresh_host_hint(self) -> None:
        host = self.host_ip.text().strip()
        if host == "0.0.0.0":
            self.host_ip.setPlaceholderText("自动绑定")
            self.host_ip.setToolTip("自动绑定所有本机网卡。真实硬件连接失败时，可改成指定网卡 IP。")
        else:
            self.host_ip.setToolTip("本机 UDP 绑定地址。")

    def apply_connection(self) -> None:
        config = ConnectionConfig(
            host_ip=self.host_ip.text().strip(),
            fpga_ip=self.fpga_ip.text().strip(),
            local_port=self.local_port.value(),
            remote_port=self.remote_port.value(),
            mock=self._is_mock_selected(),
        )
        self.main_window.update_connection(config)
        self._refresh_badge()
        self._refresh_host_hint()

    def set_config(self, config: ConnectionConfig) -> None:
        self.transport_mode.setCurrentIndex(0 if config.mock else 1)
        self.fpga_ip.setText(config.fpga_ip)
        self.host_ip.setText(config.host_ip)
        self.local_port.setValue(config.local_port)
        self.remote_port.setValue(config.remote_port)
        self._refresh_badge()
        self._refresh_host_hint()

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
        host = "auto(0.0.0.0)" if config.host_ip == "0.0.0.0" else config.host_ip
        return (
            f"mode={mode}, host={host}:{config.local_port}, "
            f"fpga={config.fpga_ip}:{config.remote_port}, timeout={config.timeout_ms}ms"
        )

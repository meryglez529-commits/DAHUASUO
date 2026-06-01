"""Main Qt window."""

from __future__ import annotations

from fpga_host.core.config import ConnectionConfig
from fpga_host.core.control.device import FpgaDevice
from fpga_host.core.control.register_client import RegisterClient
from fpga_host.core.transport.mock_transport import MockTransport
from fpga_host.core.transport.udp_transport import UdpTransport
from fpga_host.gui.panels.connection_bar import ConnectionBar
from fpga_host.gui.panels.connection_panel import ConnectionPanel
from fpga_host.gui.panels.log_panel import LogPanel
from fpga_host.gui.panels.mode_workbench_panel import ModeWorkbenchPanel
from fpga_host.gui.panels.register_panel import RegisterPanel
from fpga_host.gui.qt_compat import QT_API, QtCore, QtWidgets


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"FPGA Host Console ({QT_API})")
        self.setMinimumSize(1120, 720)
        self.config = ConnectionConfig(mock=True)
        self.device = self._make_device()
        self.log_panel = LogPanel()

        root = QtWidgets.QWidget()
        root_layout = QtWidgets.QVBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        self.connection_bar = ConnectionBar(self)
        tabs = QtWidgets.QTabWidget()
        self.connection_panel = ConnectionPanel(self)
        self.register_panel = RegisterPanel(self)
        self.mode_panel = ModeWorkbenchPanel(self)

        advanced_panel = QtWidgets.QWidget()
        advanced_layout = QtWidgets.QHBoxLayout(advanced_panel)
        advanced_layout.addWidget(self.register_panel, 1)
        advanced_layout.addWidget(self.connection_panel, 1)

        tabs.addTab(self.mode_panel, "模式控制")
        tabs.addTab(advanced_panel, "高级调试")

        splitter = QtWidgets.QSplitter(QtCore.Qt.Orientation.Vertical)
        splitter.addWidget(tabs)
        splitter.addWidget(self.log_panel)
        splitter.setStretchFactor(0, 4)
        splitter.setStretchFactor(1, 1)

        root_layout.addWidget(self.connection_bar)
        root_layout.addWidget(splitter, 1)
        self.setCentralWidget(root)
        self.statusBar().showMessage("mock mode")

    def _make_device(self) -> FpgaDevice:
        transport = MockTransport() if self.config.mock else UdpTransport(self.config)
        return FpgaDevice(RegisterClient(transport))

    def update_connection(self, config: ConnectionConfig) -> None:
        self.config = config
        self.device = self._make_device()
        if hasattr(self, "connection_bar"):
            self.connection_bar.set_config(config)
        if hasattr(self, "mode_panel"):
            self.mode_panel.on_connection_updated()
        mode = "mock" if config.mock else f"real {config.fpga_ip}:{config.remote_port}"
        self.statusBar().showMessage(mode)
        self.log(f"connection updated: {mode}")

    def log(self, message: str) -> None:
        self.log_panel.append(message)

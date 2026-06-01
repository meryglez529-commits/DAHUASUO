"""Human-oriented mode workbench for scan control."""

from __future__ import annotations

from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.core.control.modes import LaserModeConfig, NormalModeConfig, UltrafastModeConfig
from fpga_host.core.control.scan import ScanConfig
from fpga_host.core.models import hex16, hex32
from fpga_host.gui.qt_compat import QtCore, QtWidgets


MODE_LABELS = {
    "normal": "普通扫描",
    "ultrafast": "超快扫描",
    "laser": "激光同步",
}


class ModeWorkbenchPanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        self.current_mode = "normal"
        self.scan_running = False
        self.parameters_dirty = True
        self.block_start_reason: str | None = "参数尚未应用"
        self.last_plan_items = []

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(10, 10, 10, 10)
        root.setSpacing(10)

        body = QtWidgets.QSplitter(QtCore.Qt.Orientation.Horizontal)
        body.addWidget(self._build_mode_selector())
        body.addWidget(self._build_parameter_area())
        body.addWidget(self._build_action_area())
        body.setStretchFactor(0, 0)
        body.setStretchFactor(1, 2)
        body.setStretchFactor(2, 1)

        self.plan_table = QtWidgets.QTableWidget(0, 4)
        self.plan_table.verticalHeader().setVisible(False)
        self.plan_table.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.plan_table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectionBehavior.SelectRows)
        self.plan_table.horizontalHeader().setStretchLastSection(True)
        self.plan_table.setMinimumHeight(150)

        root.addWidget(body, 1)
        root.addWidget(self.plan_table, 0)

        self._connect_dirty_signals()
        self._set_mode("normal")
        self.preview_plan(log_message=False)
        self.refresh_scan_status(log_failures=False)
        self._refresh_start_guard()

    def _build_mode_selector(self):
        panel = QtWidgets.QGroupBox("工作模式")
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setSpacing(8)

        self.mode_buttons = {}
        for mode, label in MODE_LABELS.items():
            button = QtWidgets.QRadioButton(label)
            button.setMinimumHeight(34)
            button.toggled.connect(lambda checked, name=mode: checked and self._set_mode(name))
            self.mode_buttons[mode] = button
            layout.addWidget(button)
        self.mode_buttons["normal"].setChecked(True)
        layout.addStretch(1)
        return panel

    def _build_parameter_area(self):
        panel = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        scan_group = QtWidgets.QGroupBox("扫描参数")
        scan_form = QtWidgets.QFormLayout(scan_group)
        self.rows = self._spin(1, 65535, 1024)
        self.cols = self._spin(1, 65535, 1024)
        self.sample = self._spin(0, 0x7FFFFFFF, 20)
        self.adc_channel = QtWidgets.QComboBox()
        for channel in (1, 2, 4):
            self.adc_channel.addItem(str(channel), channel)
        self.adc_channel.setCurrentIndex(2)
        self.adc_interval = self._spin(0, 0xFFFFFF, 0)
        self.scan_mode = self._spin(0, 15, 1)
        scan_form.addRow("图像行数", self.rows)
        scan_form.addRow("图像列数", self.cols)
        scan_form.addRow("每点采样", self.sample)
        scan_form.addRow("ADC 通道", self.adc_channel)
        scan_form.addRow("ADC 间隔", self.adc_interval)
        scan_form.addRow("扫描模式", self.scan_mode)

        self.mode_stack = QtWidgets.QStackedWidget()
        self.mode_stack.addWidget(self._build_normal_extra())
        self.mode_stack.addWidget(self._build_ultrafast_extra())
        self.mode_stack.addWidget(self._build_laser_extra())

        layout.addWidget(scan_group)
        layout.addWidget(self.mode_stack)
        layout.addStretch(1)
        return panel

    def _build_normal_extra(self):
        group = QtWidgets.QGroupBox("普通扫描")
        layout = QtWidgets.QVBoxLayout(group)
        self.normal_state = QtWidgets.QLabel("将关闭超快和激光同步扩展")
        layout.addWidget(self.normal_state)
        return group

    def _build_ultrafast_extra(self):
        group = QtWidgets.QGroupBox("超快参数")
        form = QtWidgets.QFormLayout(group)
        self.ultrafast_line_rec = self._spin(0, 0x3FFFFFFF, 0)
        self.adc_acq_delay = self._spin(0, 0x7FFFFFFF, 0)
        self.acq_dead_time = self._spin(0, 0x7FFFFFFF, 0)
        self.sync_delay1 = self._spin(0, 0xFFFF, 0)
        self.sync_delay2 = self._spin(0, 0xFFFF, 0)
        self.sync1_width = self._spin(0, 0xFFFF, 0)
        form.addRow("行记录参数", self.ultrafast_line_rec)
        form.addRow("采集延时", self.adc_acq_delay)
        form.addRow("采集死区", self.acq_dead_time)
        form.addRow("Sync1 延时", self.sync_delay1)
        form.addRow("Sync2 延时", self.sync_delay2)
        form.addRow("Sync1 宽度", self.sync1_width)
        return group

    def _build_laser_extra(self):
        group = QtWidgets.QGroupBox("激光同步参数")
        form = QtWidgets.QFormLayout(group)
        self.laser_enable = QtWidgets.QCheckBox("启用")
        self.laser_enable.setChecked(True)
        self.scan_delay = self._spin(0, 0xFFFF, 0)
        self.blanker_delay = self._spin(0, 0xFFFF, 0)
        self.blanker_time = self._spin(0, 0xFFFF, 0)
        self.acq_delay = self._spin(0, 0xFFFF, 0)
        self.acq_time = self._spin(0, 0xFFFF, 0)
        form.addRow("激光模式", self.laser_enable)
        form.addRow("Scan Delay", self.scan_delay)
        form.addRow("Blanker Delay", self.blanker_delay)
        form.addRow("Blanker Time", self.blanker_time)
        form.addRow("Acq Delay", self.acq_delay)
        form.addRow("Acq Time", self.acq_time)
        return group

    def _build_action_area(self):
        group = QtWidgets.QGroupBox("运行")
        layout = QtWidgets.QVBoxLayout(group)
        self.mode_label = QtWidgets.QLabel("-")
        self.state_label = QtWidgets.QLabel("扫描状态: unknown")
        self.param_state_label = QtWidgets.QLabel("参数状态: 未应用")
        self.result_label = QtWidgets.QLabel("-")
        self.result_label.setWordWrap(True)

        self.show_register_details = QtWidgets.QCheckBox("显示底层地址")
        self.preview_btn = QtWidgets.QPushButton("预览写入计划")
        self.apply_btn = QtWidgets.QPushButton("应用参数")
        self.refresh_btn = QtWidgets.QPushButton("刷新扫描状态")
        self.start_btn = QtWidgets.QPushButton("开始扫描")
        self.stop_btn = QtWidgets.QPushButton("停止扫描")

        self.apply_btn.setMinimumHeight(40)
        self.start_btn.setMinimumHeight(40)
        self.stop_btn.setMinimumHeight(40)

        layout.addWidget(self.mode_label)
        layout.addWidget(self.state_label)
        layout.addWidget(self.param_state_label)
        layout.addSpacing(8)
        layout.addWidget(self.show_register_details)
        layout.addWidget(self.preview_btn)
        layout.addWidget(self.apply_btn)
        layout.addWidget(self.refresh_btn)
        layout.addWidget(self.start_btn)
        layout.addWidget(self.stop_btn)
        layout.addSpacing(8)
        layout.addWidget(self.result_label)
        layout.addStretch(1)

        self.show_register_details.toggled.connect(lambda _checked: self._fill_plan_table(self.last_plan_items))
        self.preview_btn.clicked.connect(self.preview_plan)
        self.apply_btn.clicked.connect(self.apply_parameters)
        self.refresh_btn.clicked.connect(self.refresh_scan_status)
        self.start_btn.clicked.connect(self.start_scan)
        self.stop_btn.clicked.connect(self.stop_scan)
        return group

    def _spin(self, minimum: int, maximum: int, value: int):
        box = QtWidgets.QSpinBox()
        box.setRange(minimum, min(maximum, 2147483647))
        box.setValue(value)
        return box

    def _connect_dirty_signals(self) -> None:
        for spin in (
            self.rows,
            self.cols,
            self.sample,
            self.adc_interval,
            self.scan_mode,
            self.ultrafast_line_rec,
            self.adc_acq_delay,
            self.acq_dead_time,
            self.sync_delay1,
            self.sync_delay2,
            self.sync1_width,
            self.scan_delay,
            self.blanker_delay,
            self.blanker_time,
            self.acq_delay,
            self.acq_time,
        ):
            spin.valueChanged.connect(self._mark_dirty)
        self.adc_channel.currentIndexChanged.connect(self._mark_dirty)
        self.laser_enable.toggled.connect(self._mark_dirty)

    def _scan_config(self) -> ScanConfig:
        sample = self.sample.value()
        return ScanConfig(
            rows=self.rows.value(),
            cols=self.cols.value(),
            adc_sample=sample,
            dac_sample=sample,
            adc_channel=int(self.adc_channel.currentData()),
            adc_interval=self.adc_interval.value(),
            scan_mode=self.scan_mode.value(),
        )

    def _mode_config(self):
        scan = self._scan_config()
        if self.current_mode == "normal":
            return NormalModeConfig(scan=scan)
        if self.current_mode == "ultrafast":
            return UltrafastModeConfig(
                scan=scan,
                ultrafast_line_rec=self.ultrafast_line_rec.value(),
                adc_acq_delay=self.adc_acq_delay.value(),
                acq_dead_time=self.acq_dead_time.value(),
                sync_delay1=self.sync_delay1.value(),
                sync_delay2=self.sync_delay2.value(),
                sync1_width=self.sync1_width.value(),
            )
        return LaserModeConfig(
            scan=scan,
            dl5=Dl5Config(
                laser_mode=1 if self.laser_enable.isChecked() else 0,
                scan_delay=self.scan_delay.value(),
                blanker_delay=self.blanker_delay.value(),
                blanker_time=self.blanker_time.value(),
                acq_delay=self.acq_delay.value(),
                acq_time=self.acq_time.value(),
            ),
        )

    def _set_mode(self, mode: str) -> None:
        old_mode = self.current_mode
        self.current_mode = mode
        stack_index = {"normal": 0, "ultrafast": 1, "laser": 2}[mode]
        if hasattr(self, "mode_stack"):
            self.mode_stack.setCurrentIndex(stack_index)
        if hasattr(self, "mode_label"):
            self.mode_label.setText(f"当前模式: {MODE_LABELS[mode]}")
        if hasattr(self.main_window, "statusBar"):
            self.main_window.statusBar().showMessage(f"mode: {MODE_LABELS[mode]}")
        if old_mode != mode and hasattr(self, "param_state_label"):
            self._mark_dirty()
            self.preview_plan(log_message=False)

    def preview_plan(self, log_message: bool = True) -> None:
        try:
            plan = self._mode_config().to_plan()
            self._fill_plan_table(plan.items)
            if plan.warnings:
                self._show("; ".join(plan.warnings), log=log_message)
            else:
                self._show(f"{MODE_LABELS[self.current_mode]} 写入计划已生成", log=log_message)
        except Exception as exc:
            self._show(f"预览失败: {exc}")

    def apply_parameters(self) -> None:
        if not self._confirm_real_action("应用参数"):
            return
        try:
            self.main_window.log(f"CLI: {self._mode_apply_cli_command()}")
            result = self.main_window.device.apply_mode_config(self._mode_config())
            if result.success:
                self.parameters_dirty = False
                self.block_start_reason = None
                self._show(result.message)
                self.refresh_scan_status(log_failures=True)
            else:
                self.parameters_dirty = True
                self.block_start_reason = "上次应用失败，请重新应用参数"
                self._show(result.message or "应用失败")
            self.preview_plan(log_message=False)
            self._refresh_start_guard()
        except Exception as exc:
            self.parameters_dirty = True
            self.block_start_reason = "应用异常，请检查连接后重新应用"
            self._refresh_start_guard()
            self._show(f"应用失败: {exc}")

    def start_scan(self) -> None:
        if not self._can_start():
            self._show(self.block_start_reason or "当前状态不允许开始扫描")
            return
        if not self._confirm_real_action("开始扫描"):
            return
        try:
            self.main_window.log(f"CLI: {self._start_stop_cli_command('start')}")
            result = self.main_window.device.start_scan(
                adc_interval=self.adc_interval.value(),
                scan_mode=self.scan_mode.value(),
            )
            if result.success:
                self.block_start_reason = None
                self._show(result.message)
                self.refresh_scan_status(log_failures=True)
            else:
                self.block_start_reason = "上次开始扫描失败，请先停止扫描或重新应用参数"
                self._show(result.message or "开始失败")
            self._refresh_start_guard()
        except Exception as exc:
            self.block_start_reason = "开始扫描异常，请先停止扫描或检查连接"
            self._refresh_start_guard()
            self._show(f"开始失败: {exc}")

    def stop_scan(self) -> None:
        try:
            self.main_window.log(f"CLI: {self._start_stop_cli_command('stop')}")
            result = self.main_window.device.stop_scan(
                adc_interval=self.adc_interval.value(),
                scan_mode=self.scan_mode.value(),
            )
            if result.success:
                self.block_start_reason = None if not self.parameters_dirty else "参数已修改但尚未应用"
                self._show(result.message)
                self.refresh_scan_status(log_failures=True)
            else:
                self._show(result.message or "停止失败")
            self._refresh_start_guard()
        except Exception as exc:
            self.scan_running = False
            self._refresh_state()
            self._show(f"停止失败: {exc}")

    def refresh_scan_status(self, log_failures: bool = True) -> None:
        try:
            result = self.main_window.device.read_register(0x0009)
            value = result.value or 0
            scan_state = value & 0xF
            self.scan_running = scan_state != 0
            state = "running" if self.scan_running else "stopped"
            self.state_label.setText(f"扫描状态: {state} ({hex32(value)})")
            if log_failures:
                self.main_window.log(f"scan status: {state}, 0x0009={hex32(value)}")
        except Exception as exc:
            self.scan_running = False
            self.state_label.setText("扫描状态: unknown")
            if log_failures:
                self.main_window.log(f"scan status failed: {exc}")

    def on_connection_updated(self) -> None:
        self.parameters_dirty = True
        self.block_start_reason = "连接已切换，请重新应用参数"
        self.refresh_scan_status(log_failures=False)
        self._refresh_start_guard()

    def _fill_plan_table(self, items) -> None:
        self.last_plan_items = list(items)
        show_details = self.show_register_details.isChecked()
        headers = ["步骤", "动作", "寄存器", "写入值", "确认"] if show_details else ["步骤", "动作", "写入值", "确认"]
        self.plan_table.clear()
        self.plan_table.setColumnCount(len(headers))
        self.plan_table.setHorizontalHeaderLabels(headers)
        self.plan_table.setRowCount(len(self.last_plan_items))
        for row, item in enumerate(self.last_plan_items):
            confirm = "写后读回" if item.checked else "仅发送"
            values = [str(row + 1), item.label, hex16(item.address), hex32(item.value) or "-", confirm]
            if not show_details:
                values = [values[0], values[1], values[3], values[4]]
            for column, value in enumerate(values):
                cell = QtWidgets.QTableWidgetItem(value)
                tooltip = item.note
                if not show_details:
                    tooltip = f"{hex16(item.address)} {tooltip}".strip()
                if tooltip:
                    cell.setToolTip(tooltip)
                self.plan_table.setItem(row, column, cell)
        self.plan_table.resizeColumnsToContents()
        self.plan_table.horizontalHeader().setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeMode.Stretch)

    def _mark_dirty(self, *_args) -> None:
        self.parameters_dirty = True
        self.block_start_reason = "参数已修改但尚未应用"
        self._refresh_start_guard()

    def _can_start(self) -> bool:
        return not self.parameters_dirty and self.block_start_reason is None

    def _refresh_start_guard(self) -> None:
        can_start = self._can_start()
        self.start_btn.setEnabled(can_start)
        if self.parameters_dirty:
            text = "参数状态: 未应用"
            style = "QLabel { color: #92400e; }"
        elif self.block_start_reason:
            text = "参数状态: 需处理"
            style = "QLabel { color: #991b1b; }"
        else:
            text = "参数状态: 已应用"
            style = "QLabel { color: #166534; }"
        self.param_state_label.setText(text)
        self.param_state_label.setStyleSheet(style)
        if not can_start and self.block_start_reason:
            self.start_btn.setToolTip(self.block_start_reason)
        else:
            self.start_btn.setToolTip("")

    def _refresh_state(self) -> None:
        state = "running" if self.scan_running else "stopped"
        self.state_label.setText(f"扫描状态: {state}")

    def _show(self, message: str, log: bool = True) -> None:
        self.result_label.setText(message)
        if log:
            self.main_window.log(message)

    def _confirm_real_action(self, action: str) -> bool:
        if self.main_window.config.mock:
            return True
        buttons = getattr(QtWidgets.QMessageBox, "StandardButton", QtWidgets.QMessageBox)
        answer = QtWidgets.QMessageBox.question(
            self,
            "确认真实硬件操作",
            f"当前是 REAL 模式，将对 FPGA 执行“{action}”。确认继续？",
            buttons.Yes | buttons.No,
            buttons.No,
        )
        return answer == buttons.Yes

    def _mode_apply_cli_command(self) -> str:
        args = ["fpga-host", "mode", self.current_mode, "apply"]
        args.extend(self._common_cli_args(write=True))
        args.extend(self._scan_cli_args())
        if self.current_mode == "ultrafast":
            args.extend(
                [
                    "--ultrafast-line-rec",
                    str(self.ultrafast_line_rec.value()),
                    "--adc-acq-delay",
                    str(self.adc_acq_delay.value()),
                    "--acq-dead-time",
                    str(self.acq_dead_time.value()),
                    "--sync-delay1",
                    str(self.sync_delay1.value()),
                    "--sync-delay2",
                    str(self.sync_delay2.value()),
                    "--sync1-width",
                    str(self.sync1_width.value()),
                ]
            )
        elif self.current_mode == "laser":
            args.extend(
                [
                    "--laser-mode",
                    "1" if self.laser_enable.isChecked() else "0",
                    "--scan-delay",
                    str(self.scan_delay.value()),
                    "--blanker-delay",
                    str(self.blanker_delay.value()),
                    "--blanker-time",
                    str(self.blanker_time.value()),
                    "--acq-delay",
                    str(self.acq_delay.value()),
                    "--acq-time",
                    str(self.acq_time.value()),
                ]
            )
        return self._format_cli(args)

    def _start_stop_cli_command(self, command: str) -> str:
        args = ["fpga-host", command]
        args.extend(self._common_cli_args(write=True))
        args.extend(["--adc-interval", str(self.adc_interval.value()), "--scan-mode", str(self.scan_mode.value())])
        return self._format_cli(args)

    def _common_cli_args(self, write: bool = False) -> list[str]:
        config = self.main_window.config
        if config.mock:
            return ["--mock"]
        args = [
            "--host-ip",
            config.host_ip,
            "--fpga-ip",
            config.fpga_ip,
            "--local-port",
            str(config.local_port),
            "--remote-port",
            str(config.remote_port),
            "--timeout-ms",
            str(config.timeout_ms),
            "--retries",
            str(config.retries),
        ]
        if write:
            args.append("--yes")
        return args

    def _scan_cli_args(self) -> list[str]:
        scan = self._scan_config()
        return [
            "--rows",
            str(scan.rows),
            "--cols",
            str(scan.cols),
            "--adc-sample",
            str(scan.adc_sample),
            "--dac-sample",
            str(scan.dac_sample),
            "--adc-channel",
            str(scan.adc_channel),
            "--adc-interval",
            str(scan.adc_interval),
            "--scan-mode",
            str(scan.scan_mode),
        ]

    def _format_cli(self, args: list[str]) -> str:
        return " ".join(self._quote_cli_arg(arg) for arg in args)

    def _quote_cli_arg(self, arg: str) -> str:
        if any(char.isspace() for char in arg):
            return f'"{arg}"'
        return arg

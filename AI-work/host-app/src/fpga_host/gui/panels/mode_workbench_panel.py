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

# ADC mapping combines ETH_TOP.v relay logic with sem-scsg2450-afea-v10 AFEA schematic:
# relay state RL1/RL2 00=+/-5V, 01=+/-2.5V, 1x=+/-1.25V.
ADC_GAIN_LABELS = ("+/-1.25 V", "+/-2.5 V", "+/-5 V", "+/-2.5 V (same)")
DAC_GAIN_LABELS = ("1.25 V", "2.5 V", "5 V", "10 V")

ADC_GAIN_TOOLTIP = "code->relay->range: 0->10->+/-1.25V, 1->01->+/-2.5V, 2->00->+/-5V, 3->01->+/-2.5V"
DAC_GAIN_TOOLTIP = "RTL: AOUTx_CON selects 1.25/2.5V vs 5/10V group; AD9747 gain bit selects 12.5/25mA"


class CollapsibleSection(QtWidgets.QWidget):
    def __init__(self, title: str, content: QtWidgets.QWidget, expanded: bool = False):
        super().__init__()
        self._title = title
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        header = QtWidgets.QWidget()
        self.header_layout = QtWidgets.QHBoxLayout(header)
        self.header_layout.setContentsMargins(0, 0, 0, 0)
        self.header_layout.setSpacing(8)

        self.toggle = QtWidgets.QToolButton()
        self.toggle.setCheckable(True)
        self.toggle.setChecked(expanded)
        self.toggle.clicked.connect(self._refresh)
        self.header_layout.addWidget(self.toggle)
        self.header_layout.addStretch(1)

        self.content = content
        layout.addWidget(header)
        layout.addWidget(content)
        self._refresh()

    def set_title(self, title: str) -> None:
        self._title = title
        self._refresh()

    def _refresh(self) -> None:
        expanded = self.toggle.isChecked()
        prefix = "v" if expanded else ">"
        self.toggle.setText(f"{prefix} {self._title}")
        self.content.setVisible(expanded)


class ModeWorkbenchPanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        self.current_mode = "normal"
        self.scan_running = False
        self.parameters_dirty = True
        self.block_start_reason: str | None = "参数尚未应用"
        self.last_plan_items = []
        self.last_plan_results = []
        self.field_rows: dict[int, QtWidgets.QFrame] = {}
        self.hint_labels: dict[QtWidgets.QWidget, QtWidgets.QLabel] = {}
        self.hint_formatters = []

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(10, 10, 10, 10)
        root.setSpacing(8)

        root.addWidget(self._build_work_toolbar(), 0)
        root.addWidget(self._build_parameter_area(), 1)
        root.addWidget(self._build_plan_section(), 0)

        self._set_mode("laser", update_selector=True)
        self.preview_plan(log_message=False)
        self.refresh_scan_status(log_failures=False)
        self._refresh_start_guard()
        self._refresh_equivalents()

    def _build_work_toolbar(self):
        bar = QtWidgets.QFrame()
        bar.setFrameShape(QtWidgets.QFrame.Shape.StyledPanel)
        layout = QtWidgets.QHBoxLayout(bar)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(8)

        self.mode_selector = QtWidgets.QComboBox()
        for mode, label in MODE_LABELS.items():
            self.mode_selector.addItem(label, mode)
        self.mode_selector.setMinimumWidth(128)
        self.mode_selector.currentIndexChanged.connect(lambda _index: self._set_mode(str(self.mode_selector.currentData())))

        self.scan_state_chip = QtWidgets.QLabel("扫描: unknown")
        self.param_state_chip = QtWidgets.QLabel("参数: 未应用")
        self.start_reason_label = QtWidgets.QLabel("先应用参数")
        self.start_reason_label.setMinimumWidth(160)

        self.preview_btn = QtWidgets.QPushButton("预览")
        self.apply_btn = QtWidgets.QPushButton("应用参数")
        self.refresh_btn = QtWidgets.QPushButton("刷新状态")
        self.start_btn = QtWidgets.QPushButton("开始扫描")
        self.stop_btn = QtWidgets.QPushButton("停止扫描")
        self.apply_btn.setObjectName("ApplyButton")
        self.start_btn.setObjectName("StartButton")
        self.stop_btn.setObjectName("StopButton")
        self.apply_btn.setMinimumWidth(92)
        self.start_btn.setMinimumWidth(92)
        self.stop_btn.setMinimumWidth(92)

        self.message_label = QtWidgets.QLabel("-")
        self.message_label.setWordWrap(False)

        layout.addWidget(QtWidgets.QLabel("模式"))
        layout.addWidget(self.mode_selector)
        layout.addSpacing(10)
        layout.addWidget(self.scan_state_chip)
        layout.addWidget(self.param_state_chip)
        layout.addWidget(self.start_reason_label)
        layout.addStretch(1)
        layout.addWidget(self.preview_btn)
        layout.addWidget(self.apply_btn)
        layout.addWidget(self.refresh_btn)
        layout.addWidget(self.start_btn)
        layout.addWidget(self.stop_btn)

        self.preview_btn.clicked.connect(self.preview_plan)
        self.apply_btn.clicked.connect(self.apply_parameters)
        self.refresh_btn.clicked.connect(self.refresh_scan_status)
        self.start_btn.clicked.connect(self.start_scan)
        self.stop_btn.clicked.connect(self.stop_scan)
        return bar

    def _build_parameter_area(self):
        panel = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(6)

        page = QtWidgets.QWidget()
        page_layout = QtWidgets.QVBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(10)
        page_layout.addWidget(self._build_common_parameters_tab(), 0)

        self.mode_stack = QtWidgets.QStackedWidget()
        self.mode_stack.setSizePolicy(
            QtWidgets.QSizePolicy.Policy.Expanding,
            QtWidgets.QSizePolicy.Policy.Maximum,
        )
        self.mode_stack.addWidget(self._build_normal_extra())
        self.mode_stack.addWidget(self._build_ultrafast_extra())
        self.mode_stack.addWidget(self._build_laser_extra())
        page_layout.addWidget(self.mode_stack, 0)
        page_layout.addStretch(1)

        layout.addWidget(self._scroll(page))
        return panel

    def _build_plan_section(self):
        self.show_register_details = QtWidgets.QCheckBox("显示底层地址")
        self.plan_table = QtWidgets.QTableWidget(0, 5)
        self.plan_table.verticalHeader().setVisible(False)
        self.plan_table.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.plan_table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectionBehavior.SelectRows)
        self.plan_table.horizontalHeader().setStretchLastSection(True)
        self.plan_table.setMinimumHeight(132)

        self.plan_section = CollapsibleSection("写入计划", self.plan_table, expanded=False)
        self.plan_section.header_layout.insertWidget(1, self.show_register_details)
        self.show_register_details.toggled.connect(lambda _checked: self._fill_plan_table(self.last_plan_items, self.last_plan_results))
        return self.plan_section

    def _build_common_parameters_tab(self):
        page = QtWidgets.QWidget()
        grid = QtWidgets.QGridLayout(page)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(8)

        image_group, image_grid = self._group("图像 / 采样")
        self.rows = self._spin(1, 65535, 6, width=96)
        self.cols = self._spin(1, 65535, 8, width=96)
        self.sample = self._spin(1, 0x7FFFFFFF, 20, width=110)
        self.adc_channel = QtWidgets.QComboBox()
        for channel in (1, 2, 4):
            self.adc_channel.addItem(f"{channel} 通道", channel)
        self.adc_channel.setCurrentIndex(0)
        self._add_param(image_grid, 0, "行数", self.rows, "rows", "1..65535", "写入 0x0004[31:16]")
        self._add_param(image_grid, 1, "列数", self.cols, "cols", "1..65535", "写入 0x0004[15:0]")
        self._add_param(image_grid, 2, "每点采样", self.sample, "points", "ADC/DAC 共用保持点数", "写入 0x0002")
        self._add_param(image_grid, 3, "ADC 通道", self.adc_channel, "count", "1->ADC1, 2->ADC1/2, 4->ADC1..4", "写入 0x0001[3:0] bitmask")

        region_group, region_grid = self._group("扫描区域")
        self.dacx_start = self._spin(0, 7, 0, width=96)
        self.dacx_end = self._spin(0, 7, 7, width=96)
        self.dacy_start = self._spin(0, 5, 0, width=96)
        self.dacy_end = self._spin(0, 5, 5, width=96)
        self.dacx_tk_follow_cols = QtWidgets.QCheckBox("跟随列数")
        self.dacx_tk_follow_cols.setChecked(True)
        self.dacx_tk_point = self._spin(1, 0xFFFF, 1024, width=96)
        self.dacx_tk_point.setEnabled(False)
        self._add_param(
            region_grid,
            0,
            "X 起点",
            self.dacx_start,
            "0..cols-1",
            "raw 0x0000",
            "人类坐标，GUI 内部换算为 0x0005[31:16] 的 16-bit DAC code",
        )
        self._add_param(
            region_grid,
            1,
            "X 终点",
            self.dacx_end,
            "0..cols-1",
            "raw 0xFFFF",
            "人类坐标，GUI 内部换算为 0x0005[15:0] 的 16-bit DAC code",
        )
        self._add_param(
            region_grid,
            2,
            "Y 起点",
            self.dacy_start,
            "0..rows-1",
            "raw 0x0000",
            "人类坐标，GUI 内部换算为 0x0007[31:16] 的 16-bit DAC code",
        )
        self._add_param(
            region_grid,
            3,
            "Y 终点",
            self.dacy_end,
            "0..rows-1",
            "raw 0xFFFF",
            "人类坐标，GUI 内部换算为 0x0007[15:0] 的 16-bit DAC code",
        )
        self._add_param(region_grid, 4, "X 点数", self.dacx_tk_follow_cols, "policy", "跟随 cols", "关闭后启用 X 点数覆盖，写入 0x0006[31:16]")
        self._add_param(region_grid, 5, "X 点数覆盖", self.dacx_tk_point, "pixels", "仅覆盖模式生效", "必须非 0，FPGA 用它计算 dacx_step")

        timing_group, timing_grid = self._group("扫描时序")
        self.dacx_recovery_us = self._spin(0, 0xFFFF, 1, width=96)
        self.dax_fall_us = self._spin(0, 0x7FFFFFFF, 1, width=110)
        self.frame_wait_words = self._spin(0, 0x7FFFFFFF, 0, width=118)
        self._add_param(timing_grid, 0, "X 线首恢复", self.dacx_recovery_us, "us", "1 us -> 50 words", "写入 0x0006[15:0]，RTL 内部 x50")
        self._add_param(timing_grid, 1, "X 回扫下降", self.dax_fall_us, "us", "1 us -> 50 words", "写入 0x000F，RTL 内部 x50")
        self._add_param(timing_grid, 2, "帧间等待", self.frame_wait_words, "FIFO words", "0 words ~= 0 ns", "写入 0x0008，约 20ns/word")

        gain_group, gain_grid = self._group("增益 / 行帧")
        self.adc1_gain = self._gain_combo(2, ADC_GAIN_LABELS)
        self.adc2_gain = self._gain_combo(2, ADC_GAIN_LABELS)
        self.adc3_gain = self._gain_combo(2, ADC_GAIN_LABELS)
        self.adc4_gain = self._gain_combo(2, ADC_GAIN_LABELS)
        self.dacx_gain = self._gain_combo(3, DAC_GAIN_LABELS)
        self.dacy_gain = self._gain_combo(3, DAC_GAIN_LABELS)
        self._add_param(gain_grid, 0, "ADC1", self.adc1_gain, "range", "0x0003[1:0]", f"写入 0x0003[1:0]；{ADC_GAIN_TOOLTIP}")
        self._add_param(gain_grid, 1, "ADC2", self.adc2_gain, "range", "0x0003[3:2]", f"写入 0x0003[3:2]；{ADC_GAIN_TOOLTIP}")
        self._add_param(gain_grid, 2, "ADC3", self.adc3_gain, "range", "0x0003[5:4]", f"写入 0x0003[5:4]；{ADC_GAIN_TOOLTIP}")
        self._add_param(gain_grid, 3, "ADC4", self.adc4_gain, "range", "0x0003[7:6]", f"写入 0x0003[7:6]；{ADC_GAIN_TOOLTIP}")
        self._add_param(gain_grid, 4, "DAC X", self.dacx_gain, "range", "0x0003[9:8]", f"写入 0x0003[9:8]；{DAC_GAIN_TOOLTIP}")
        self._add_param(gain_grid, 5, "DAC Y", self.dacy_gain, "range", "0x0003[11:10]", f"写入 0x0003[11:10]；{DAC_GAIN_TOOLTIP}")
        self.row_repeat = self._spin(1, 0xFFFF, 1, width=96)
        self.row_m = self._spin(0, 0xFFFF, 0, width=96)
        self.row_n = self._spin(1, 0xFFFF, 1, width=96)
        self._add_param(gain_grid, 6, "行重复", self.row_repeat, "count", ">= 1", "写入 0x0013；同一行重复采样并平均")
        self._add_param(gain_grid, 7, "交错 row_m", self.row_m, "skip rows", "0 = 不跳行", "交错扫描：每扫 row_n 行后跳过 row_m 行")
        self._add_param(gain_grid, 8, "交错 row_n", self.row_n, "scan rows", "1 = 逐行", "交错扫描：每组连续扫描 row_n 行；写入 0x0014[15:0]")

        grid.addWidget(image_group, 0, 0)
        grid.addWidget(timing_group, 1, 0)
        grid.addWidget(region_group, 0, 1, 2, 1)
        grid.addWidget(gain_group, 0, 2, 2, 1)
        grid.setColumnStretch(0, 1)
        grid.setColumnStretch(1, 1)
        grid.setColumnStretch(2, 1)

        self.dacx_tk_follow_cols.toggled.connect(self._toggle_dacx_tk_point)
        self.rows.valueChanged.connect(lambda _value: self._update_axis_ranges())
        self.cols.valueChanged.connect(lambda _value: self._update_axis_ranges())
        self._update_axis_ranges()
        return page

    def _build_normal_extra(self):
        page = QtWidgets.QWidget()
        grid = QtWidgets.QGridLayout(page)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(10)

        adc_group, adc_grid = self._group("普通模式 ADC")
        self.adc_interval = self._spin(0, 0xFFFFFF, 0, width=110)
        self.normal_trigger_source = QtWidgets.QComboBox()
        self.normal_trigger_source.addItem("自由运行", 0)
        self.normal_trigger_source.addItem("等待 TRIGGER_IN", 1)
        self.normal_trigger_source.setMaximumWidth(150)
        self._add_param(adc_grid, 0, "采集延时", self.adc_interval, "ADC cycles", "0 cycles ~= 0 ns", "普通模式触发后等待；写入 0x0009[31:8]")
        self._add_param(adc_grid, 1, "行触发源", self.normal_trigger_source, "clk_sel", "自由运行", "写入 0x0000[0]；激光模式不使用")

        note = QtWidgets.QLabel("扫描模式固定为参数扫描 code 1，GUI 不再开放修改。")
        note.setStyleSheet("QLabel { color: #64748b; }")
        note.setWordWrap(True)
        grid.addWidget(adc_group, 0, 0)
        grid.addWidget(note, 1, 0)
        grid.setColumnStretch(0, 1)
        return page

    def _build_ultrafast_extra(self):
        page = QtWidgets.QWidget()
        grid = QtWidgets.QGridLayout(page)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(10)

        sync_group, sync_grid = self._group("Sync 输出")
        self.sync1_width = self._spin(0, 0xFFFF, 0, width=96)
        self.sync2_width = self._spin(0, 0xFFFF, 0, width=96)
        self.sync_delay1 = self._spin(0, 0xFFFF, 0, width=96)
        self.sync_delay2 = self._spin(0, 0xFFFF, 0, width=96)
        self._add_param(sync_grid, 0, "Sync1 宽度", self.sync1_width, "20ns steps", "0 steps ~= 0 ns", "写入 0x0200，RTL 内部 <<2 到 ui_clk")
        self._add_param(sync_grid, 1, "Sync2 宽度", self.sync2_width, "20ns steps", "0 steps ~= 0 ns", "写入 0x0205，RTL 内部 <<2 到 ui_clk")
        self._add_param(sync_grid, 2, "Sync1 延时", self.sync_delay1, "ui_clk cycles", "0 cycles ~= 0 ns", "写入 0x0203[31:16]，5ns/step")
        self._add_param(sync_grid, 3, "Sync2 延时", self.sync_delay2, "ui_clk cycles", "0 cycles ~= 0 ns", "写入 0x0203[15:0]，5ns/step")

        adc_group, adc_grid = self._group("超快 ADC")
        self.ultrafast_trigger_source = QtWidgets.QComboBox()
        self.ultrafast_trigger_source.addItem("自由运行", 0)
        self.ultrafast_trigger_source.addItem("等待 TRIGGER_IN", 1)
        self.ultrafast_trigger_source.setMaximumWidth(150)
        self.ultrafast_line_rec = self._spin(0, 0x3FFFFFFF, 0, width=118)
        self.adc_acq_delay = self._spin(0, 0x7FFFFFFF, 0, width=118)
        self.acq_dead_time = self._spin(0, 0x7FFFFFFF, 0, width=118)
        self._add_param(adc_grid, 0, "行触发源", self.ultrafast_trigger_source, "clk_sel", "自由运行", "写入 0x0000[0]；激光模式不使用")
        self._add_param(adc_grid, 1, "行恢复", self.ultrafast_line_rec, "us", "0 us -> 0 words", "写入 0x0202[31:1]，RTL 内部 x50")
        self._add_param(adc_grid, 2, "采集延时", self.adc_acq_delay, "ADC cycles", "0 cycles ~= 0 ns", "写入 0x0201")
        self._add_param(adc_grid, 3, "采集死区", self.acq_dead_time, "ADC cycles", "0 cycles ~= 0 ns", "写入 0x0204")

        grid.addWidget(sync_group, 0, 0)
        grid.addWidget(adc_group, 0, 1)
        grid.setColumnStretch(0, 1)
        grid.setColumnStretch(1, 1)
        return page

    def _build_laser_extra(self):
        page = QtWidgets.QWidget()
        grid = QtWidgets.QGridLayout(page)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(10)

        timing_group, timing_grid = self._group("激光同步 / 时序")
        self.laser_enable = QtWidgets.QCheckBox("应用后启用激光同步")
        self.laser_enable.setChecked(True)
        self.scan_delay = self._spin(0, 0xFFFF, 10, width=96)
        self.blanker_delay = self._spin(0, 0xFFFF, 10, width=96)
        self.blanker_time = self._spin(0, 0xFFFF, 10, width=96)
        self.acq_delay = self._spin(0, 0xFFFF, 10, width=96)
        self.acq_time = self._spin(0, 0xFFFF, 10, width=96)
        self._add_param(timing_grid, 0, "激光同步", self.laser_enable, "0x020B", "checked write", "写入 0x020B[0]")
        self._add_param(timing_grid, 1, "Scan Delay", self.scan_delay, "eth_clk cycles", "0 cycles ~= 0 ns", "写入 0x0206，8ns/step")
        self._add_param(timing_grid, 2, "Blanker Delay", self.blanker_delay, "ui_clk cycles", "0 cycles ~= 0 ns", "写入 0x0207，5ns/step")
        self._add_param(timing_grid, 3, "Blanker Time", self.blanker_time, "ui_clk cycles", "0 cycles ~= 0 ns", "写入 0x0208，5ns/step")
        self._add_param(timing_grid, 4, "Acq Delay", self.acq_delay, "20ns steps", "0 steps ~= 0 ns", "写入 0x0209，RTL 内部 <<2")
        self._add_param(timing_grid, 5, "Acq Time", self.acq_time, "samples / 20ns", "2 samples ~= 40 ns", "写入 0x020A；laser enable 时必须 >= 2")

        grid.addWidget(timing_group, 0, 0)
        grid.setColumnStretch(0, 1)
        return page

    def _group(self, title: str):
        group = QtWidgets.QGroupBox(title)
        tones = {
            "图像 / 采样": "blue",
            "扫描时序": "amber",
            "扫描区域": "green",
            "增益 / 行帧": "violet",
            "普通模式 ADC": "slate",
            "Sync 输出": "cyan",
            "超快 ADC": "orange",
            "激光同步 / 时序": "cyan",
        }
        group.setProperty("tone", tones.get(title, "neutral"))
        group.setSizePolicy(
            QtWidgets.QSizePolicy.Policy.Expanding,
            QtWidgets.QSizePolicy.Policy.Maximum,
        )
        grid = QtWidgets.QGridLayout(group)
        grid.setContentsMargins(8, 8, 8, 8)
        grid.setHorizontalSpacing(6)
        grid.setVerticalSpacing(4)
        return group, grid

    def _scroll(self, widget):
        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        scroll.setWidget(widget)
        return scroll

    def _add_param(self, grid, row: int, label: str, widget, unit: str, hint: str, tooltip: str):
        frame = QtWidgets.QFrame()
        frame.setObjectName("ParamRow")
        layout = QtWidgets.QHBoxLayout(frame)
        layout.setContentsMargins(2, 1, 2, 1)
        layout.setSpacing(5)

        name = QtWidgets.QLabel(label)
        name.setMinimumWidth(74)
        name.setMaximumWidth(92)
        unit_label = QtWidgets.QLabel(unit)
        unit_label.setMinimumWidth(54)
        unit_label.setMaximumWidth(86)
        unit_label.setStyleSheet("QLabel { color: #475569; }")
        hint_label = QtWidgets.QLabel(hint)
        hint_label.setMinimumWidth(80)
        hint_label.setMaximumWidth(148)
        hint_label.setWordWrap(True)
        hint_label.setStyleSheet("QLabel { color: #64748b; }")

        for control in (frame, name, widget, unit_label, hint_label):
            control.setToolTip(tooltip)

        layout.addWidget(name)
        layout.addWidget(widget)
        layout.addWidget(unit_label)
        layout.addWidget(hint_label, 1)
        grid.addWidget(frame, row, 0)

        self.field_rows[id(widget)] = frame
        self.hint_labels[widget] = hint_label
        self._watch_widget(widget)
        return hint_label

    def _spin(self, minimum: int, maximum: int, value: int, width: int = 96):
        box = QtWidgets.QSpinBox()
        box.setRange(minimum, min(maximum, 2147483647))
        box.setValue(value)
        buttons = getattr(QtWidgets.QAbstractSpinBox, "ButtonSymbols", QtWidgets.QAbstractSpinBox)
        box.setButtonSymbols(buttons.NoButtons)
        box.setMaximumWidth(width)
        box.setMinimumWidth(width)
        box.setKeyboardTracking(False)
        return box

    def _hex_spin(self, minimum: int, maximum: int, value: int):
        box = self._spin(minimum, maximum, value, width=110)
        box.setDisplayIntegerBase(16)
        box.setPrefix("0x")
        return box

    def _axis_position_to_code(self, value: int, points: int) -> int:
        if points <= 1:
            return 0
        return max(0, min(0xFFFF, round(value * 0xFFFF / (points - 1))))

    def _axis_position_from_code(self, code: int, points: int) -> int:
        if points <= 1:
            return 0
        return max(0, min(points - 1, round(code * (points - 1) / 0xFFFF)))

    def _update_axis_ranges(self) -> None:
        if not all(hasattr(self, name) for name in ("rows", "cols", "dacx_start", "dacx_end", "dacy_start", "dacy_end")):
            return
        pairs = (
            (self.dacx_start, max(0, self.cols.value() - 1)),
            (self.dacx_end, max(0, self.cols.value() - 1)),
            (self.dacy_start, max(0, self.rows.value() - 1)),
            (self.dacy_end, max(0, self.rows.value() - 1)),
        )
        for widget, maximum in pairs:
            current = min(widget.value(), maximum)
            widget.blockSignals(True)
            widget.setRange(0, maximum)
            widget.setValue(current)
            widget.blockSignals(False)
        self._refresh_equivalents()

    def _gain_combo(self, value: int, labels: tuple[str, ...]):
        combo = QtWidgets.QComboBox()
        for code, label in enumerate(labels):
            combo.addItem(label, code)
            combo.setItemData(code, f"code {code}: {label}", QtCore.Qt.ItemDataRole.ToolTipRole)
        combo.setCurrentIndex(value)
        combo.setMinimumWidth(96)
        combo.setMaximumWidth(118)
        return combo

    def _watch_widget(self, widget) -> None:
        if isinstance(widget, QtWidgets.QSpinBox):
            widget.valueChanged.connect(lambda _value, watched=widget: self._mark_dirty(watched))
            self._register_equivalent(widget)
        elif isinstance(widget, QtWidgets.QComboBox):
            widget.currentIndexChanged.connect(lambda _index, watched=widget: self._mark_dirty(watched))
        elif isinstance(widget, QtWidgets.QCheckBox):
            widget.toggled.connect(lambda _checked, watched=widget: self._mark_dirty(watched))

    def _register_equivalent(self, widget) -> None:
        adc_cycle_widgets = (
            getattr(self, "adc_interval", None),
            getattr(self, "adc_acq_delay", None),
            getattr(self, "acq_dead_time", None),
        )
        twenty_ns_widgets = (
            getattr(self, "sync1_width", None),
            getattr(self, "sync2_width", None),
            getattr(self, "acq_delay", None),
            getattr(self, "acq_time", None),
        )
        ui_clk_widgets = (
            getattr(self, "sync_delay1", None),
            getattr(self, "sync_delay2", None),
            getattr(self, "blanker_delay", None),
            getattr(self, "blanker_time", None),
        )
        us_x50_widgets = (
            getattr(self, "dacx_recovery_us", None),
            getattr(self, "dax_fall_us", None),
            getattr(self, "ultrafast_line_rec", None),
        )
        if widget in adc_cycle_widgets:
            self.hint_formatters.append((widget, lambda value: f"{value} cycles ~= {value * 20} ns"))
        elif widget in twenty_ns_widgets:
            self.hint_formatters.append((widget, lambda value: f"{value} steps ~= {value * 20} ns"))
        elif widget in ui_clk_widgets:
            self.hint_formatters.append((widget, lambda value: f"{value} cycles ~= {value * 5} ns"))
        elif widget is getattr(self, "scan_delay", None):
            self.hint_formatters.append((widget, lambda value: f"{value} cycles ~= {value * 8} ns"))
        elif widget in us_x50_widgets:
            self.hint_formatters.append((widget, lambda value: f"{value} us -> {value * 50} words"))
        elif widget is getattr(self, "frame_wait_words", None):
            self.hint_formatters.append((widget, lambda value: f"{value} words ~= {value * 20} ns"))
        elif widget is getattr(self, "dacx_start", None):
            self.hint_formatters.append((widget, lambda value: f"raw {hex16(self._axis_position_to_code(value, self.cols.value()))}"))
        elif widget is getattr(self, "dacx_end", None):
            self.hint_formatters.append((widget, lambda value: f"raw {hex16(self._axis_position_to_code(value, self.cols.value()))}"))
        elif widget is getattr(self, "dacy_start", None):
            self.hint_formatters.append((widget, lambda value: f"raw {hex16(self._axis_position_to_code(value, self.rows.value()))}"))
        elif widget is getattr(self, "dacy_end", None):
            self.hint_formatters.append((widget, lambda value: f"raw {hex16(self._axis_position_to_code(value, self.rows.value()))}"))

    def _toggle_dacx_tk_point(self, checked: bool) -> None:
        self.dacx_tk_point.setEnabled(not checked)
        row = self.field_rows.get(id(self.dacx_tk_point))
        if row is not None:
            row.setEnabled(not checked)
        self._mark_dirty(self.dacx_tk_follow_cols)

    def _value_of(self, widget) -> int:
        if isinstance(widget, QtWidgets.QComboBox):
            return int(widget.currentData())
        if isinstance(widget, QtWidgets.QCheckBox):
            return 1 if widget.isChecked() else 0
        return int(widget.value())

    def _scan_mode_value(self) -> int:
        return 1

    def _trigger_value(self) -> int:
        if self.current_mode == "laser":
            return 0
        if self.current_mode == "ultrafast":
            return int(self.ultrafast_trigger_source.currentData())
        return int(self.normal_trigger_source.currentData())

    def _gain_value(self, combo) -> int:
        return int(combo.currentData())

    def _scan_config(self) -> ScanConfig:
        sample = self.sample.value()
        adc_interval = self.adc_interval.value() if self.current_mode == "normal" else 0
        return ScanConfig(
            rows=self.rows.value(),
            cols=self.cols.value(),
            adc_sample=sample,
            dac_sample=sample,
            adc_channel=int(self.adc_channel.currentData()),
            adc_interval=adc_interval,
            scan_mode=self._scan_mode_value(),
            clk_sel=self._trigger_value(),
            adc1_gain=self._gain_value(self.adc1_gain),
            adc2_gain=self._gain_value(self.adc2_gain),
            adc3_gain=self._gain_value(self.adc3_gain),
            adc4_gain=self._gain_value(self.adc4_gain),
            dacx_gain=self._gain_value(self.dacx_gain),
            dacy_gain=self._gain_value(self.dacy_gain),
            dacx_strat_level=self._axis_position_to_code(self.dacx_start.value(), self.cols.value()),
            dacx_end_level=self._axis_position_to_code(self.dacx_end.value(), self.cols.value()),
            dacx_tk_point=None if self.dacx_tk_follow_cols.isChecked() else self.dacx_tk_point.value(),
            dacx_recovery_time=self.dacx_recovery_us.value(),
            dacy_strat_level=self._axis_position_to_code(self.dacy_start.value(), self.rows.value()),
            dacy_end_level=self._axis_position_to_code(self.dacy_end.value(), self.rows.value()),
            frame_waiting_time=self.frame_wait_words.value(),
            dax_fall_time=self.dax_fall_us.value(),
            row_repeat=self.row_repeat.value(),
            row_m=self.row_m.value(),
            row_n=self.row_n.value(),
        )

    def current_scan_config(self) -> ScanConfig:
        return self._scan_config()

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
                sync2_width=self.sync2_width.value(),
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

    def _set_mode(self, mode: str, update_selector: bool = False) -> None:
        if mode not in MODE_LABELS:
            return
        old_mode = self.current_mode
        self.current_mode = mode
        if update_selector:
            index = self.mode_selector.findData(mode)
            if index >= 0 and self.mode_selector.currentIndex() != index:
                self.mode_selector.blockSignals(True)
                self.mode_selector.setCurrentIndex(index)
                self.mode_selector.blockSignals(False)
        self._update_special_tab()
        if old_mode != mode:
            self._mark_dirty()
            self.preview_plan(log_message=False)

    def _update_special_tab(self) -> None:
        self.mode_stack.setCurrentIndex({"normal": 0, "ultrafast": 1, "laser": 2}[self.current_mode])

    def preview_plan(self, log_message: bool = True) -> None:
        try:
            plan = self._mode_config().to_plan()
            self.last_plan_results = []
            self._fill_plan_table(plan.items, [])
            if plan.warnings:
                self._show("; ".join(plan.warnings), log=log_message)
            else:
                self._show(f"{MODE_LABELS[self.current_mode]} 写入计划已生成", log=log_message)
        except Exception as exc:
            self._show(f"预览失败: {exc}")

    def apply_parameters(self) -> None:
        try:
            plan = self._mode_config().to_plan()
            self.main_window.log(f"CLI: {self._mode_apply_cli_command()}")
            result = self.main_window.device.apply_mode_config(self._mode_config())
            results = (result.data or {}).get("results", []) if result.data else []
            if result.success:
                self.parameters_dirty = False
                self.block_start_reason = None
                self._clear_field_dirty()
                self._show(result.message)
                self.refresh_scan_status(log_failures=True)
            else:
                self.parameters_dirty = True
                self.block_start_reason = "上次应用失败，请重新应用参数"
                self._show(result.message or "应用失败")
            self._fill_plan_table(plan.items, results)
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
        try:
            self.main_window.log(f"CLI: {self._start_stop_cli_command('start')}")
            scan = self._scan_config()
            result = self.main_window.device.start_scan(
                adc_interval=scan.adc_interval,
                scan_mode=scan.scan_mode,
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
            scan = self._scan_config()
            result = self.main_window.device.stop_scan(
                adc_interval=scan.adc_interval,
                scan_mode=scan.scan_mode,
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
            self.scan_state_chip.setText(f"扫描: {state} ({hex32(value)})")
            self.scan_state_chip.setStyleSheet(
                "QLabel { color: #166534; }" if self.scan_running else "QLabel { color: #334155; }"
            )
            if log_failures:
                self.main_window.log(f"scan status: {state}, 0x0009={hex32(value)}")
        except Exception as exc:
            self.scan_running = False
            self.scan_state_chip.setText("扫描: unknown")
            self.scan_state_chip.setStyleSheet("QLabel { color: #991b1b; }")
            if log_failures:
                self.main_window.log(f"scan status failed: {exc}")

    def on_connection_updated(self) -> None:
        self.parameters_dirty = True
        self.block_start_reason = "连接已切换，请重新应用参数"
        self.refresh_scan_status(log_failures=False)
        self._refresh_start_guard()

    def _fill_plan_table(self, items, results=None) -> None:
        self.last_plan_items = list(items)
        self.last_plan_results = list(results or [])
        show_details = self.show_register_details.isChecked()
        headers = ["步骤", "动作", "寄存器", "计划值", "确认策略", "结果"] if show_details else ["步骤", "动作", "计划值", "确认策略", "结果"]
        self.plan_table.clear()
        self.plan_table.setColumnCount(len(headers))
        self.plan_table.setHorizontalHeaderLabels(headers)
        self.plan_table.setRowCount(len(self.last_plan_items))
        checked_count = 0
        send_only_count = 0
        for row, item in enumerate(self.last_plan_items):
            checked_count += 1 if item.checked else 0
            send_only_count += 0 if item.checked else 1
            strategy = "write_checked" if item.checked else "send only"
            status = self._plan_result_text(row)
            values = [str(row + 1), item.label, hex16(item.address), hex32(item.value) or "-", strategy, status]
            if not show_details:
                values = [values[0], values[1], values[3], values[4], values[5]]
            for column, value in enumerate(values):
                cell = QtWidgets.QTableWidgetItem(value)
                tooltip = item.note
                if not show_details:
                    tooltip = f"{hex16(item.address)} {tooltip}".strip()
                if tooltip:
                    cell.setToolTip(tooltip)
                self.plan_table.setItem(row, column, cell)
        self.plan_table.resizeColumnsToContents()
        if self.plan_table.columnCount() > 1:
            self.plan_table.horizontalHeader().setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeMode.Stretch)
        self.plan_section.set_title(
            f"写入计划  {len(self.last_plan_items)} steps / {checked_count} checked / {send_only_count} sent-only"
        )

    def _plan_result_text(self, row: int) -> str:
        if row >= len(self.last_plan_results):
            return "未执行"
        result = self.last_plan_results[row]
        if result.get("success"):
            return "OK"
        error = result.get("error") or result.get("message") or "failed"
        return str(error)

    def _mark_dirty(self, widget=None) -> None:
        self.parameters_dirty = True
        self.block_start_reason = "参数已修改但尚未应用"
        if widget is not None:
            row = self.field_rows.get(id(widget))
            if row is not None:
                row.setStyleSheet("QFrame#ParamRow { border-left: 3px solid #d97706; }")
        self._refresh_equivalents()
        self._refresh_start_guard()

    def _clear_field_dirty(self) -> None:
        for row in self.field_rows.values():
            row.setStyleSheet("")

    def _refresh_equivalents(self) -> None:
        for widget, formatter in self.hint_formatters:
            label = self.hint_labels.get(widget)
            if label is not None:
                label.setText(formatter(widget.value()))

    def _can_start(self) -> bool:
        return not self.parameters_dirty and self.block_start_reason is None

    def _refresh_start_guard(self) -> None:
        can_start = self._can_start()
        self.start_btn.setEnabled(can_start)
        if self.parameters_dirty:
            text = "参数: 未应用"
            style = "QLabel { color: #92400e; font-weight: 600; }"
        elif self.block_start_reason:
            text = "参数: 需处理"
            style = "QLabel { color: #991b1b; font-weight: 600; }"
        else:
            text = "参数: 已应用"
            style = "QLabel { color: #166534; font-weight: 600; }"
        self.param_state_chip.setText(text)
        self.param_state_chip.setStyleSheet(style)
        self.start_reason_label.setText("" if can_start else (self.block_start_reason or "当前不能开始"))
        self.start_reason_label.setStyleSheet("QLabel { color: #92400e; }" if not can_start else "QLabel { color: #64748b; }")
        self.start_btn.setToolTip("" if can_start else (self.block_start_reason or "当前不能开始"))

    def _refresh_state(self) -> None:
        state = "running" if self.scan_running else "stopped"
        self.scan_state_chip.setText(f"扫描: {state}")

    def _show(self, message: str, log: bool = True) -> None:
        self.message_label.setText(message)
        self.main_window.statusBar().showMessage(message)
        if log:
            self.main_window.log(message)

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
                    "--sync2-width",
                    str(self.sync2_width.value()),
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
        scan = self._scan_config()
        args.extend(["--adc-interval", str(scan.adc_interval), "--scan-mode", str(scan.scan_mode)])
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
        args = [
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
            "--clk-sel",
            str(scan.clk_sel or 0),
            "--dacx-start",
            str(scan.dacx_strat_level),
            "--dacx-end",
            str(scan.dacx_end_level),
            "--dacx-recovery-us",
            str(scan.dacx_recovery_time),
            "--dacy-start",
            str(scan.dacy_strat_level),
            "--dacy-end",
            str(scan.dacy_end_level),
            "--dax-fall-us",
            str(scan.dax_fall_time),
            "--frame-wait-words",
            str(scan.frame_waiting_time),
            "--adc1-gain",
            str(scan.adc1_gain),
            "--adc2-gain",
            str(scan.adc2_gain),
            "--adc3-gain",
            str(scan.adc3_gain),
            "--adc4-gain",
            str(scan.adc4_gain),
            "--dacx-gain",
            str(scan.dacx_gain),
            "--dacy-gain",
            str(scan.dacy_gain),
            "--row-repeat",
            str(scan.row_repeat),
            "--row-m",
            str(scan.row_m),
            "--row-n",
            str(scan.row_n),
        ]
        if scan.dacx_tk_point is not None:
            args.extend(["--dacx-tk-point", str(scan.dacx_tk_point)])
        return args

    def _format_cli(self, args: list[str]) -> str:
        return " ".join(self._quote_cli_arg(arg) for arg in args)

    def _quote_cli_arg(self, arg: str) -> str:
        if any(char.isspace() for char in arg):
            return f'"{arg}"'
        return arg

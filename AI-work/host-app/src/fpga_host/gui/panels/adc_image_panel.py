"""ADC image receiver and display panel."""

from __future__ import annotations

from array import array
import time

from fpga_host.core.data.dl2_receiver import DEFAULT_DL2_DATA_PORT, Dl2UdpReceiver
from fpga_host.core.data.dl2_receiver_stub import MockDl2Receiver
from fpga_host.core.data.frame_model import FrameModel
from fpga_host.gui.qt_compat import QtCore, QtGui, QtWidgets


def _qt_enum(owner, enum_name: str, value_name: str):
    enum = getattr(owner, enum_name, owner)
    return getattr(enum, value_name)


class AdcImageWorker(QtCore.QObject):
    frame_ready = QtCore.Signal(object)
    stats_ready = QtCore.Signal(object)
    status = QtCore.Signal(str)
    failed = QtCore.Signal(str)
    finished = QtCore.Signal()

    def __init__(self, receiver, mock: bool = False):
        super().__init__()
        self.receiver = receiver
        self.mock = mock
        self._stop = False

    @QtCore.Slot()
    def run(self) -> None:
        try:
            self.receiver.start()
            self.status.emit("receiving")
            while not self._stop:
                frame = self.receiver.get_frame(timeout_ms=100)
                stats = getattr(self.receiver, "stats", None)
                if stats is not None:
                    self.stats_ready.emit(stats)
                if frame is not None:
                    self.frame_ready.emit(frame)
                if self.mock:
                    time.sleep(0.2)
        except Exception as exc:
            self.failed.emit(str(exc))
        finally:
            try:
                self.receiver.stop()
            finally:
                self.finished.emit()

    def request_stop(self) -> None:
        self._stop = True


class AdcImagePanel(QtWidgets.QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        self._thread: QtCore.QThread | None = None
        self._worker: AdcImageWorker | None = None
        self._last_frame: FrameModel | None = None
        self._last_qimage: QtGui.QImage | None = None
        self._last_image_bytes: bytes | None = None
        self._frame_count = 0
        self._started_at = 0.0

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(10, 10, 10, 10)
        root.setSpacing(8)
        root.addWidget(self._build_toolbar(), 0)

        body = QtWidgets.QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(8)
        body.addWidget(self._build_image_area(), 1)
        body.addWidget(self._build_side_panel(), 0)
        root.addLayout(body, 1)
        self._refresh_config_labels()
        self._set_receiving(False)

    def _build_toolbar(self) -> QtWidgets.QWidget:
        bar = QtWidgets.QFrame()
        bar.setFrameShape(QtWidgets.QFrame.Shape.StyledPanel)
        layout = QtWidgets.QHBoxLayout(bar)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(8)

        self.receive_btn = QtWidgets.QPushButton("Start receive")
        self.stop_receive_btn = QtWidgets.QPushButton("Stop receive")
        self.receive_start_btn = QtWidgets.QPushButton("Receive + start scan")
        self.stop_all_btn = QtWidgets.QPushButton("Stop scan + receive")
        self.receive_btn.setObjectName("StartButton")
        self.stop_receive_btn.setObjectName("StopButton")
        self.receive_start_btn.setObjectName("StartButton")
        self.stop_all_btn.setObjectName("StopButton")

        self.status_label = QtWidgets.QLabel("stopped")
        self.status_label.setMinimumWidth(160)
        self.port_label = QtWidgets.QLabel(f"data UDP: {DEFAULT_DL2_DATA_PORT}")

        layout.addWidget(self.receive_btn)
        layout.addWidget(self.stop_receive_btn)
        layout.addWidget(self.receive_start_btn)
        layout.addWidget(self.stop_all_btn)
        layout.addSpacing(12)
        layout.addWidget(self.status_label)
        layout.addStretch(1)
        layout.addWidget(self.port_label)

        self.receive_btn.clicked.connect(self.start_receiving)
        self.stop_receive_btn.clicked.connect(self.stop_receiving)
        self.receive_start_btn.clicked.connect(self.receive_and_start_scan)
        self.stop_all_btn.clicked.connect(self.stop_scan_and_receive)
        return bar

    def _build_image_area(self) -> QtWidgets.QWidget:
        frame = QtWidgets.QFrame()
        frame.setFrameShape(QtWidgets.QFrame.Shape.StyledPanel)
        layout = QtWidgets.QVBoxLayout(frame)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(6)

        self.image_label = QtWidgets.QLabel("No ADC frame")
        self.image_label.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        self.image_label.setMinimumSize(520, 420)
        self.image_label.setStyleSheet("QLabel { background: #111827; color: #e5e7eb; }")
        layout.addWidget(self.image_label, 1)
        return frame

    def _build_side_panel(self) -> QtWidgets.QWidget:
        panel = QtWidgets.QFrame()
        panel.setFrameShape(QtWidgets.QFrame.Shape.StyledPanel)
        panel.setMaximumWidth(260)
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(8)

        self.config_label = QtWidgets.QLabel("-")
        self.config_label.setWordWrap(True)
        self.channel_combo = QtWidgets.QComboBox()
        self.channel_combo.currentIndexChanged.connect(lambda _index: self._render_last_frame())
        self.auto_stretch = QtWidgets.QCheckBox("Auto gray stretch")
        self.auto_stretch.setChecked(True)
        self.auto_stretch.toggled.connect(lambda _checked: self._render_last_frame())

        self.frame_label = QtWidgets.QLabel("frames: 0")
        self.fps_label = QtWidgets.QLabel("fps: 0.0")
        self.packet_label = QtWidgets.QLabel("packets: 0")
        self.lost_label = QtWidgets.QLabel("lost: 0")
        self.bytes_label = QtWidgets.QLabel("frame bytes: 0 / 0")
        self.seq_label = QtWidgets.QLabel("seq: -")
        for label in (
            self.frame_label,
            self.fps_label,
            self.packet_label,
            self.lost_label,
            self.bytes_label,
            self.seq_label,
        ):
            label.setTextInteractionFlags(QtCore.Qt.TextInteractionFlag.TextSelectableByMouse)

        self.save_raw_btn = QtWidgets.QPushButton("Save raw")
        self.save_png_btn = QtWidgets.QPushButton("Save image")
        self.save_raw_btn.clicked.connect(self.save_raw)
        self.save_png_btn.clicked.connect(self.save_image)

        layout.addWidget(QtWidgets.QLabel("Current config"))
        layout.addWidget(self.config_label)
        layout.addSpacing(8)
        layout.addWidget(QtWidgets.QLabel("Display channel"))
        layout.addWidget(self.channel_combo)
        layout.addWidget(self.auto_stretch)
        layout.addSpacing(8)
        layout.addWidget(self.frame_label)
        layout.addWidget(self.fps_label)
        layout.addWidget(self.packet_label)
        layout.addWidget(self.lost_label)
        layout.addWidget(self.bytes_label)
        layout.addWidget(self.seq_label)
        layout.addStretch(1)
        layout.addWidget(self.save_raw_btn)
        layout.addWidget(self.save_png_btn)
        return panel

    def start_receiving(self) -> bool:
        if self._thread is not None:
            return True
        try:
            scan = self.main_window.mode_panel.current_scan_config()
        except Exception as exc:
            self._set_status(f"config error: {exc}", error=True)
            return False
        self._refresh_config_labels(scan)
        self._populate_channel_combo(scan.adc_channel)
        receiver = self._make_receiver(scan)
        self._worker = AdcImageWorker(receiver, mock=self.main_window.config.mock)
        self._thread = QtCore.QThread(self)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.frame_ready.connect(self._on_frame)
        self._worker.stats_ready.connect(self._on_stats)
        self._worker.status.connect(lambda text: self._set_status(text))
        self._worker.failed.connect(lambda text: self._set_status(text, error=True))
        self._worker.finished.connect(self._on_worker_finished)
        self._worker.finished.connect(self._thread.quit)
        self._worker.finished.connect(self._worker.deleteLater)
        self._thread.finished.connect(self._thread.deleteLater)
        self._frame_count = 0
        self._started_at = time.perf_counter()
        self._set_receiving(True)
        self._thread.start()
        self.main_window.log(
            f"ADC receive started: host={self.main_window.config.host_ip}:{DEFAULT_DL2_DATA_PORT} "
            f"frame={scan.rows}x{scan.cols}x{scan.adc_channel}"
        )
        return True

    def stop_receiving(self) -> None:
        if self._worker is not None:
            self._worker.request_stop()
            self._set_status("stopping")
        else:
            self._set_receiving(False)

    def receive_and_start_scan(self) -> None:
        if self.start_receiving():
            self.main_window.mode_panel.start_scan()

    def stop_scan_and_receive(self) -> None:
        self.main_window.mode_panel.stop_scan()
        self.stop_receiving()

    def on_connection_updated(self) -> None:
        if self._thread is not None:
            self.stop_receiving()
        self._refresh_config_labels()

    def save_raw(self) -> None:
        if self._last_frame is None:
            return
        path, _filter = QtWidgets.QFileDialog.getSaveFileName(
            self,
            "Save raw ADC frame",
            "adc_frame.raw",
            "Raw ADC frame (*.raw);;All files (*)",
        )
        if not path:
            return
        with open(path, "wb") as file:
            file.write(self._last_frame.payload)
        self.main_window.log(f"ADC raw saved: {path}")

    def save_image(self) -> None:
        if self._last_qimage is None:
            return
        path, _filter = QtWidgets.QFileDialog.getSaveFileName(
            self,
            "Save ADC image",
            "adc_frame.png",
            "PNG image (*.png);;BMP image (*.bmp);;All files (*)",
        )
        if not path:
            return
        self._last_qimage.save(path)
        self.main_window.log(f"ADC image saved: {path}")

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._update_scaled_pixmap()

    def _make_receiver(self, scan):
        if self.main_window.config.mock:
            return MockDl2Receiver(rows=scan.rows, cols=scan.cols, channels=scan.adc_channel)
        return Dl2UdpReceiver(
            host_ip=self.main_window.config.host_ip,
            port=DEFAULT_DL2_DATA_PORT,
            rows=scan.rows,
            cols=scan.cols,
            channels=scan.adc_channel,
            timeout_ms=100,
        )

    def _on_frame(self, frame: FrameModel) -> None:
        self._last_frame = frame
        self._frame_count += 1
        elapsed = max(0.001, time.perf_counter() - self._started_at)
        self.frame_label.setText(f"frames: {self._frame_count}")
        self.fps_label.setText(f"fps: {self._frame_count / elapsed:.1f}")
        self.seq_label.setText(f"seq: {frame.sequence_start}..{frame.sequence_end}")
        self._render_last_frame()
        self._set_receiving(True)

    def _on_stats(self, stats) -> None:
        self.packet_label.setText(f"packets: {stats.packets}")
        self.lost_label.setText(f"lost: {stats.lost_packets}")
        self.bytes_label.setText(f"frame bytes: {stats.bytes_in_frame} / {stats.expected_bytes}")

    def _on_worker_finished(self) -> None:
        self._worker = None
        self._thread = None
        self._set_receiving(False)
        self._set_status("stopped")
        self.main_window.log("ADC receive stopped")

    def _render_last_frame(self) -> None:
        frame = self._last_frame
        if frame is None:
            return
        channel = max(0, int(self.channel_combo.currentData() or 0))
        try:
            image_bytes = _frame_channel_to_grayscale(frame, channel, self.auto_stretch.isChecked())
        except ValueError as exc:
            self.image_label.setText(str(exc))
            return
        image_format = _qt_enum(QtGui.QImage, "Format", "Format_Grayscale8")
        qimage = QtGui.QImage(image_bytes, frame.cols, frame.rows, frame.cols, image_format).copy()
        self._last_image_bytes = image_bytes
        self._last_qimage = qimage
        self._update_scaled_pixmap()

    def _update_scaled_pixmap(self) -> None:
        if self._last_qimage is None:
            return
        pixmap = QtGui.QPixmap.fromImage(self._last_qimage)
        keep_aspect = _qt_enum(QtCore.Qt, "AspectRatioMode", "KeepAspectRatio")
        smooth = _qt_enum(QtCore.Qt, "TransformationMode", "SmoothTransformation")
        scaled = pixmap.scaled(self.image_label.size(), keep_aspect, smooth)
        self.image_label.setPixmap(scaled)

    def _populate_channel_combo(self, channels: int) -> None:
        current = self.channel_combo.currentData()
        self.channel_combo.blockSignals(True)
        self.channel_combo.clear()
        for channel in range(channels):
            self.channel_combo.addItem(f"ADC{channel + 1}", channel)
        index = self.channel_combo.findData(current)
        self.channel_combo.setCurrentIndex(index if index >= 0 else 0)
        self.channel_combo.blockSignals(False)

    def _refresh_config_labels(self, scan=None) -> None:
        if scan is None:
            try:
                scan = self.main_window.mode_panel.current_scan_config()
            except Exception:
                self.config_label.setText("-")
                return
        dirty = "dirty" if self.main_window.mode_panel.parameters_dirty else "applied"
        self.config_label.setText(
            f"{scan.rows} x {scan.cols}\n"
            f"{scan.adc_channel} channel(s)\n"
            f"sample={scan.adc_sample}\n"
            f"params={dirty}"
        )

    def _set_status(self, text: str, error: bool = False) -> None:
        self.status_label.setText(text)
        color = "#b91c1c" if error else ("#047857" if text == "receiving" else "#334155")
        self.status_label.setStyleSheet(f"QLabel {{ color: {color}; font-weight: 600; }}")
        if error:
            self.main_window.log(f"ADC receive error: {text}")

    def _set_receiving(self, receiving: bool) -> None:
        self.receive_btn.setEnabled(not receiving)
        self.receive_start_btn.setEnabled(not receiving)
        self.stop_receive_btn.setEnabled(receiving)
        self.stop_all_btn.setEnabled(receiving)
        self.save_raw_btn.setEnabled(self._last_frame is not None)
        self.save_png_btn.setEnabled(self._last_qimage is not None)


def _frame_channel_to_grayscale(frame: FrameModel, channel: int, auto_stretch: bool) -> bytes:
    expected = frame.expected_bytes
    if len(frame.payload) < expected:
        raise ValueError(f"Frame payload too short: {len(frame.payload)} / {expected}")
    if not 0 <= channel < frame.channels:
        raise ValueError("Display channel is outside this frame")

    samples = array("H")
    samples.frombytes(frame.payload[:expected])
    if samples.itemsize != 2:
        raise ValueError("This Python build does not use 16-bit array('H') samples")
    if frame.channels > 1:
        values = samples[channel::frame.channels]
    else:
        values = samples
    if len(values) != frame.rows * frame.cols:
        raise ValueError("Frame dimensions do not match payload")

    if auto_stretch:
        minimum = min(values)
        maximum = max(values)
    else:
        minimum = 0
        maximum = 0xFFFF
    span = max(1, maximum - minimum)
    output = bytearray(len(values))
    for index, value in enumerate(values):
        if value <= minimum:
            output[index] = 0
        elif value >= maximum:
            output[index] = 255
        else:
            output[index] = ((value - minimum) * 255) // span
    return bytes(output)

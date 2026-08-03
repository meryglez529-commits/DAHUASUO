"""Scan parameter model and register-write plan."""

from __future__ import annotations

from dataclasses import dataclass

from fpga_host.core.data.dl2_protocol import channel_count_to_mask
from fpga_host.core.errors import ConfigError


def _u16(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFF:
        raise ConfigError(f"{name} must fit in 16 bits")
    return value


def _u2(name: str, value: int) -> int:
    if not 0 <= value <= 0x3:
        raise ConfigError(f"{name} must fit in 2 bits")
    return value


def _u24(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFFFF:
        raise ConfigError(f"{name} must fit in 24 bits")
    return value


def _u32(name: str, value: int) -> int:
    if not 0 <= value <= 0xFFFFFFFF:
        raise ConfigError(f"{name} must fit in 32 bits")
    return value


@dataclass(frozen=True)
class ScanConfig:
    rows: int = 1024
    cols: int = 1024
    adc_sample: int = 20
    dac_sample: int = 20
    adc_channel: int = 4
    adc_len_single: int | None = None
    adc_interval: int = 0
    scan_mode: int = 1
    clk_sel: int | None = None
    adc1_gain: int = 2
    adc2_gain: int = 2
    adc3_gain: int = 2
    adc4_gain: int = 2
    dacx_gain: int = 3
    dacy_gain: int = 3
    # DAC 扫描几何（必须写，否则 FPGA 不会计算 dacx_step，DAC 输出恒为中点）。
    # 默认值取自已验证可正常出波形的板上配置（10%~90% 量程）。
    # 注意：写 0x0006 是触发 dacx_step 除法器的唯一时机，绝不能省略。
    dacx_strat_level: int = 0x1999
    dacx_end_level: int = 0xE665
    dacx_recovery_time: int = 50
    dacy_strat_level: int = 0x3BBB
    dacy_end_level: int = 0xC443
    frame_waiting_time: int = 0
    dax_fall_time: int = 20
    row_repeat: int = 1
    row_m: int = 0
    row_n: int = 1
    # dacx_tk_point（每行像素数）默认跟随 cols；显式设置可覆盖。
    dacx_tk_point: int | None = None

    def validate(self) -> None:
        _u16("rows", self.rows)
        _u16("cols", self.cols)
        if self.rows == 0 or self.cols == 0:
            raise ConfigError("rows and cols must be non-zero")
        if self.adc_sample != self.dac_sample:
            raise ConfigError("FPGA register 0x0002 ties adc_sample and dac_sample together")
        if self.adc_sample <= 0:
            raise ConfigError("sample count must be non-zero")
        if self.adc_channel not in (1, 2, 4):
            raise ConfigError("adc_channel must be 1, 2, or 4")
        _u24("adc_interval", self.adc_interval)
        if not 0 <= self.scan_mode <= 0xF:
            raise ConfigError("scan_mode must fit in 4 bits")
        if self.clk_sel is not None and self.clk_sel not in (0, 1):
            raise ConfigError("clk_sel must be 0, 1, or omitted")
        for name, value in (
            ("adc1_gain", self.adc1_gain),
            ("adc2_gain", self.adc2_gain),
            ("adc3_gain", self.adc3_gain),
            ("adc4_gain", self.adc4_gain),
            ("dacx_gain", self.dacx_gain),
            ("dacy_gain", self.dacy_gain),
        ):
            _u2(name, value)
        adc_len = self.effective_adc_len_single()
        if not 0 <= adc_len <= 0x1FFFFF:
            raise ConfigError("adc_len_single must fit in 21 bits")
        # DAC 扫描几何校验
        _u16("dacx_strat_level", self.dacx_strat_level)
        _u16("dacx_end_level", self.dacx_end_level)
        _u16("dacx_recovery_time", self.dacx_recovery_time)
        _u16("dacy_strat_level", self.dacy_strat_level)
        _u16("dacy_end_level", self.dacy_end_level)
        _u32("frame_waiting_time", self.frame_waiting_time)
        _u32("dax_fall_time", self.dax_fall_time)
        _u16("row_repeat", self.row_repeat)
        _u16("row_m", self.row_m)
        _u16("row_n", self.row_n)
        if self.row_repeat == 0:
            raise ConfigError("row_repeat must be >= 1")
        if self.row_n == 0:
            raise ConfigError("row_n must be >= 1")
        tk_point = self.effective_dacx_tk_point()
        _u16("dacx_tk_point", tk_point)
        if tk_point == 0:
            raise ConfigError("dacx_tk_point must be non-zero (FPGA divides by it for dacx_step)")
        if self.dacx_strat_level == self.dacx_end_level:
            raise ConfigError(
                "dacx_strat_level == dacx_end_level gives dacx_step=0 (DAC X will not sweep)"
            )

    def effective_adc_len_single(self) -> int:
        if self.adc_len_single is not None:
            return self.adc_len_single
        return self.rows * self.cols

    def adc_channel_mask(self) -> int:
        try:
            return channel_count_to_mask(self.adc_channel)
        except ValueError as exc:
            raise ConfigError(str(exc)) from exc

    def effective_dacx_tk_point(self) -> int:
        if self.dacx_tk_point is not None:
            return self.dacx_tk_point
        return self.cols

    def to_registers(self, scan_state: int = 0) -> list[tuple[int, int]]:
        self.validate()
        if not 0 <= scan_state <= 0xF:
            raise ConfigError("scan_state must fit in 4 bits")
        adc_cfg = (self.effective_adc_len_single() << 4) | self.adc_channel_mask()
        sample = self.adc_sample
        gain_cfg = (
            self.adc1_gain
            | (self.adc2_gain << 2)
            | (self.adc3_gain << 4)
            | (self.adc4_gain << 6)
            | (self.dacx_gain << 8)
            | (self.dacy_gain << 10)
        )
        image_size = (self.rows << 16) | self.cols
        scan_control = (self.adc_interval << 8) | (self.scan_mode << 4) | scan_state
        dacx_range = (self.dacx_strat_level << 16) | self.dacx_end_level
        # 0x0006 写入会脉冲 dacx_step_flag，触发 FPGA 重算 dacx_step；必须写。
        dacx_point_recovery = (self.effective_dacx_tk_point() << 16) | self.dacx_recovery_time
        dacy_range = (self.dacy_strat_level << 16) | self.dacy_end_level
        registers = []
        if self.clk_sel is not None:
            registers.append((0x0000, self.clk_sel))
        registers.extend(
            [
                (0x0001, adc_cfg),
                (0x0002, sample),
                (0x0003, gain_cfg),
                (0x0004, image_size),
                (0x0005, dacx_range),
                (0x0006, dacx_point_recovery),
                (0x0007, dacy_range),
                (0x0008, self.frame_waiting_time),
                (0x000F, self.dax_fall_time),
                (0x0013, self.row_repeat),
                (0x0014, (self.row_m << 16) | self.row_n),
                (0x0009, scan_control),
            ]
        )
        return registers

    @classmethod
    def from_dict(cls, data: dict) -> "ScanConfig":
        return cls(
            rows=int(data.get("rows", 1024)),
            cols=int(data.get("cols", 1024)),
            adc_sample=int(data.get("adc_sample", data.get("sample", 20))),
            dac_sample=int(data.get("dac_sample", data.get("sample", data.get("adc_sample", 20)))),
            adc_channel=int(data.get("adc_channel", 4)),
            adc_len_single=(
                None if data.get("adc_len_single") is None else int(data["adc_len_single"])
            ),
            adc_interval=int(data.get("adc_interval", 0)),
            scan_mode=int(data.get("scan_mode", 1)),
            clk_sel=(None if data.get("clk_sel") is None else int(data["clk_sel"])),
            adc1_gain=int(data.get("adc1_gain", 2)),
            adc2_gain=int(data.get("adc2_gain", 2)),
            adc3_gain=int(data.get("adc3_gain", 2)),
            adc4_gain=int(data.get("adc4_gain", 2)),
            dacx_gain=int(data.get("dacx_gain", 3)),
            dacy_gain=int(data.get("dacy_gain", 3)),
            dacx_strat_level=int(data.get("dacx_strat_level", 0x1999)),
            dacx_end_level=int(data.get("dacx_end_level", 0xE665)),
            dacx_recovery_time=int(data.get("dacx_recovery_time", data.get("dacx_recovery_us", 50))),
            dacy_strat_level=int(data.get("dacy_strat_level", 0x3BBB)),
            dacy_end_level=int(data.get("dacy_end_level", 0xC443)),
            frame_waiting_time=int(data.get("frame_waiting_time", data.get("frame_wait_words", 0))),
            dax_fall_time=int(data.get("dax_fall_time", data.get("dax_fall_us", 20))),
            row_repeat=int(data.get("row_repeat", 1)),
            row_m=int(data.get("row_m", 0)),
            row_n=int(data.get("row_n", 1)),
            dacx_tk_point=(
                None if data.get("dacx_tk_point") is None else int(data["dacx_tk_point"])
            ),
        )

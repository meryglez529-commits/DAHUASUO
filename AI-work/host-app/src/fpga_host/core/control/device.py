"""High-level FPGA device API shared by GUI and CLI."""

from __future__ import annotations

import time

from fpga_host.core.control.dl5 import Dl5Config
from fpga_host.core.control.modes import ModeApplyPlan, ModeConfig, WritePlanItem
from fpga_host.core.control.register_client import RegisterClient
from fpga_host.core.control.scan import ScanConfig
from fpga_host.core.models import OperationResult, hex16, hex32


def _plan_to_dict(plan: list[tuple[int, int]]) -> list[dict[str, str]]:
    return [{"address": hex16(addr), "value": hex32(value)} for addr, value in plan]


def _write_plan_to_dict(plan: list[WritePlanItem]) -> list[dict]:
    return [item.to_dict() for item in plan]


class FpgaDevice:
    def __init__(self, client: RegisterClient):
        self.client = client

    def version(self) -> OperationResult:
        start = time.perf_counter()
        value = self.client.read32(0x000A)
        return OperationResult(
            success=True,
            operation="version",
            message=f"version={hex32(value)}",
            address=0x000A,
            value=value,
            readback=value,
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
        )

    def read_register(self, address: int) -> OperationResult:
        start = time.perf_counter()
        value = self.client.read32(address)
        return OperationResult(
            success=True,
            operation="read32",
            message=f"{hex16(address)}={hex32(value)}",
            address=address,
            value=value,
            readback=value,
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
        )

    def write_register(self, address: int, value: int, checked: bool = False) -> OperationResult:
        if checked:
            return self.client.write_checked(address, value)
        return self.client.write32(address, value)

    def _scan_control_value(
        self,
        scan_state: int,
        adc_interval: int | None = None,
        scan_mode: int | None = None,
    ) -> int:
        current = 0x00000010
        try:
            current = self.client.read32(0x0009)
        except Exception:
            pass
        if adc_interval is None:
            adc_interval = (current >> 8) & 0xFFFFFF
        if scan_mode is None:
            scan_mode = (current >> 4) & 0xF
        return (adc_interval << 8) | (scan_mode << 4) | (scan_state & 0xF)

    def stop_scan(
        self,
        adc_interval: int | None = None,
        scan_mode: int | None = None,
        dry_run: bool = False,
    ) -> OperationResult:
        value = self._scan_control_value(scan_state=0, adc_interval=adc_interval, scan_mode=scan_mode)
        if dry_run:
            return OperationResult(
                success=True,
                operation="stop_scan",
                message="dry-run stop scan",
                dry_run=True,
                data={"plan": _plan_to_dict([(0x0009, value)])},
            )
        return self.client.write_checked(0x0009, value)

    def start_scan(
        self,
        adc_interval: int | None = None,
        scan_mode: int | None = None,
        dry_run: bool = False,
    ) -> OperationResult:
        value = self._scan_control_value(scan_state=1, adc_interval=adc_interval, scan_mode=scan_mode)
        if dry_run:
            return OperationResult(
                success=True,
                operation="start_scan",
                message="dry-run start scan",
                dry_run=True,
                data={"plan": _plan_to_dict([(0x0009, value)])},
            )
        return self.client.write_checked(0x0009, value)

    def apply_scan_config(self, config: ScanConfig, dry_run: bool = False) -> OperationResult:
        plan = config.to_registers(scan_state=0)
        if dry_run:
            return OperationResult(
                success=True,
                operation="apply_scan_config",
                message="dry-run scan config",
                dry_run=True,
                data={"plan": _plan_to_dict(plan)},
            )
        start = time.perf_counter()
        results = [self.client.write_checked(addr, value).to_dict() for addr, value in plan]
        success = all(item["success"] for item in results)
        return OperationResult(
            success=success,
            operation="apply_scan_config",
            message="scan config applied" if success else "scan config failed",
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
            data={"results": results},
        )

    def apply_dl5_config(
        self,
        config: Dl5Config,
        stop_before_apply: bool = True,
        start_after_apply: bool = False,
        dry_run: bool = False,
    ) -> OperationResult:
        plan: list[tuple[int, int]] = []
        if stop_before_apply:
            plan.append((0x0009, self._scan_control_value(scan_state=0)))
        plan.extend(config.to_safe_apply_registers())
        if start_after_apply:
            plan.append((0x0009, self._scan_control_value(scan_state=1)))
        if dry_run:
            return OperationResult(
                success=True,
                operation="apply_dl5_config",
                message="dry-run dl5 config",
                dry_run=True,
                data={"plan": _plan_to_dict(plan)},
            )
        start = time.perf_counter()
        results = [self.client.write_checked(addr, value).to_dict() for addr, value in plan]
        success = all(item["success"] for item in results)
        return OperationResult(
            success=success,
            operation="apply_dl5_config",
            message="dl5 config applied" if success else "dl5 config failed",
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
            data={"results": results},
        )

    def apply_mode_config(
        self,
        config: ModeConfig,
        start_after_apply: bool = False,
        dry_run: bool = False,
    ) -> OperationResult:
        plan = config.to_plan()
        if start_after_apply:
            last_scan_control = _find_last_scan_control(plan)
            plan.items.append(
                WritePlanItem(
                    0x0009,
                    (last_scan_control & 0xFFFFFFF0) | 1,
                    "Start scan after apply",
                    checked=True,
                )
            )
        return self.apply_mode_plan(plan, dry_run=dry_run)

    def apply_mode_plan(self, plan: ModeApplyPlan, dry_run: bool = False) -> OperationResult:
        if dry_run:
            return OperationResult(
                success=True,
                operation=f"apply_mode_{plan.mode}",
                message=f"dry-run {plan.mode} mode",
                dry_run=True,
                data=plan.to_dict(),
            )
        start = time.perf_counter()
        results = []
        for item in plan.items:
            result = (
                self.client.write_checked(item.address, item.value)
                if item.checked
                else self.client.write32(item.address, item.value)
            )
            result_dict = result.to_dict()
            result_dict["label"] = item.label
            result_dict["checked"] = item.checked
            result_dict["note"] = item.note
            results.append(result_dict)
        success = all(item["success"] for item in results)
        return OperationResult(
            success=success,
            operation=f"apply_mode_{plan.mode}",
            message=f"{plan.mode} mode applied" if success else f"{plan.mode} mode failed",
            elapsed_ms=(time.perf_counter() - start) * 1000.0,
            data={
                "mode": plan.mode,
                "results": results,
                "warnings": plan.warnings,
            },
        )


def _find_last_scan_control(plan: ModeApplyPlan) -> int:
    for item in reversed(plan.items):
        if item.address == 0x0009:
            return item.value
    return 0x00000010

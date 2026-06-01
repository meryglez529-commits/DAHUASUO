"""CLI output helpers."""

from __future__ import annotations

import json
import sys
from typing import Any

from fpga_host.core.models import OperationResult


def emit(data: Any, json_mode: bool = False) -> None:
    if json_mode:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return
    if isinstance(data, OperationResult):
        status = "OK" if data.success else "FAIL"
        print(f"{status}: {data.message}")
        if data.address is not None:
            print(f"address={data.to_dict()['address']}")
        if data.value is not None:
            print(f"value={data.to_dict()['value']}")
        if data.readback is not None:
            print(f"readback={data.to_dict()['readback']}")
        if data.data:
            print(json.dumps(data.data, ensure_ascii=False, indent=2))
        return
    if isinstance(data, list):
        for item in data:
            print(item)
        return
    print(data)


def emit_error(message: str, code: int, json_mode: bool = False) -> None:
    if json_mode:
        print(json.dumps({"success": False, "error": message, "code": code}, ensure_ascii=False, indent=2))
    else:
        print(f"ERROR: {message}", file=sys.stderr)

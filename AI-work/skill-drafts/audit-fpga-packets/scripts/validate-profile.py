from __future__ import annotations

import argparse
from pathlib import Path

from packet_audit_lib import load_json, validate_profile


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an FPGA packet protocol profile")
    parser.add_argument("profile", type=Path)
    args = parser.parse_args()
    errors = validate_profile(load_json(args.profile))
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(f"VALID: {args.profile}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

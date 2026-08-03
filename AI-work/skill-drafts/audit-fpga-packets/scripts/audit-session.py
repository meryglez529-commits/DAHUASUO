from __future__ import annotations

import argparse
from pathlib import Path

from packet_audit_lib import audit_packets, load_expected_plan, load_json, load_profile, write_json


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply deterministic FPGA packet audit rules")
    parser.add_argument("--packets", type=Path, required=True)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--expected-plan", type=Path)
    parser.add_argument("--require-readback", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--updated-packets", type=Path)
    args = parser.parse_args()
    packets = load_json(args.packets)
    profile = load_profile(args.profile)
    expected = load_expected_plan(args.expected_plan)
    audit = audit_packets(packets, profile, expected, args.require_readback)
    write_json(args.output, audit)
    if args.updated_packets:
        write_json(args.updated_packets, packets)
    print(f"findings={len(audit['findings'])} output={args.output}")
    counts = audit["summary"]["finding_counts"]
    return 2 if counts["FAIL"] else (1 if counts["WARN"] else 0)


if __name__ == "__main__":
    raise SystemExit(main())

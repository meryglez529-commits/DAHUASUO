from __future__ import annotations

import argparse
from pathlib import Path

from packet_audit_lib import extract_udp_packets, write_json


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract exact UDP payloads from pcap/pcapng")
    parser.add_argument("input", type=Path)
    parser.add_argument("--fpga-ip")
    parser.add_argument("--port", type=int, action="append", default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    packets = extract_udp_packets(args.input, args.fpga_ip, set(args.port) or None)
    serializable = []
    for packet in packets:
        item = dict(packet)
        payload = item.pop("payload")
        item["payload_hex"] = payload.hex().upper()
        serializable.append(item)
    write_json(args.output, serializable)
    print(f"packets={len(serializable)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

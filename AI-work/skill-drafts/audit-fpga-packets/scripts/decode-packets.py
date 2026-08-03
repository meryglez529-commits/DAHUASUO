from __future__ import annotations

import argparse
from pathlib import Path

from packet_audit_lib import decode_packets, load_json, load_profile, packet_from_hex, write_json


def main() -> int:
    parser = argparse.ArgumentParser(description="Decode extracted FPGA UDP payloads")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--hex", action="append", default=[])
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--fpga-ip")
    parser.add_argument("--port", type=int, default=32000)
    parser.add_argument("--direction", default="PC -> FPGA")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    profile = load_profile(args.profile)
    packets = []
    if args.input:
        for index, item in enumerate(load_json(args.input), 1):
            packet = dict(item)
            packet["number"] = packet.get("number", index)
            packet["payload"] = bytes.fromhex(packet.pop("payload_hex"))
            packets.append(packet)
    for index, text in enumerate(args.hex, len(packets) + 1):
        packets.append(packet_from_hex(text, index, args.port, args.direction))
    decoded = decode_packets(packets, profile, args.fpga_ip)
    write_json(args.output, decoded)
    print(f"packets={len(decoded)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

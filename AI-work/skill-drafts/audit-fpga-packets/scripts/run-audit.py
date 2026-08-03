from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import shutil
import sys

from packet_audit_lib import (
    audit_packets,
    decode_packets,
    extract_udp_packets,
    load_expected_plan,
    load_json,
    load_profile,
    packet_from_hex,
    render_html,
    render_markdown,
    sha256_file,
    write_json,
    write_packets_csv,
)


SKILL_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PROFILE = SKILL_ROOT / "assets" / "profiles" / "sgsc-325t-v3-172.json"
DEFAULT_TEMPLATE = SKILL_ROOT / "assets" / "report-template.html"


def _packets_from_json(path: Path) -> list[dict]:
    raw = load_json(path)
    if isinstance(raw, dict):
        raw = raw.get("packets", raw.get("items", []))
    if not isinstance(raw, list):
        raise ValueError("JSON packet input must be a list or contain a packets list")
    packets = []
    for index, item in enumerate(raw, 1):
        if "_source" in item:
            layers = item.get("_source", {}).get("layers", {})
            udp = layers.get("udp", {})
            ip = layers.get("ip", layers.get("ipv6", {}))
            frame = layers.get("frame", {})
            payload_hex = udp.get("udp.payload", "").replace(":", "")
            if not payload_hex:
                continue
            packets.append(
                {
                    "number": int(frame.get("frame.number", index)),
                    "timestamp_epoch": float(frame.get("frame.time_epoch", 0)) or None,
                    "src_ip": ip.get("ip.src", ip.get("ipv6.src")),
                    "dst_ip": ip.get("ip.dst", ip.get("ipv6.dst")),
                    "src_port": int(udp.get("udp.srcport", 0)),
                    "dst_port": int(udp.get("udp.dstport", 0)),
                    "payload": bytes.fromhex(payload_hex),
                }
            )
            continue
        payload_hex = item.get("payload_hex") or item.get("udp_payload")
        if payload_hex is None:
            raise ValueError(f"JSON packet {index} has no payload_hex")
        packet = dict(item)
        packet["number"] = packet.get("number", index)
        packet["payload"] = bytes.fromhex(str(payload_hex).replace(":", "").replace(" ", ""))
        packets.append(packet)
    return packets


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Decode and audit FPGA Ethernet packets")
    parser.add_argument("--input", type=Path, help="pcap, pcapng, tshark JSON, or extracted packet JSON")
    parser.add_argument("--hex", action="append", default=[], help="one UDP payload as hexadecimal text")
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--expected-plan", type=Path)
    parser.add_argument("--fpga-ip")
    parser.add_argument("--port", type=int, action="append", default=[])
    parser.add_argument("--direction", choices=["PC -> FPGA", "FPGA -> PC", "UNKNOWN"], default="PC -> FPGA")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--session-name", default="fpga-packet-audit")
    parser.add_argument("--require-readback", action="store_true")
    parser.add_argument("--copy-capture", action="store_true", help="copy source capture into the report directory")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.input is None and not args.hex:
        raise SystemExit("provide --input or at least one --hex payload")
    profile_path = args.profile.resolve()
    profile = load_profile(profile_path)
    fpga_ip = args.fpga_ip or profile.get("default_fpga_ip")
    control_port = int(profile.get("ports", {}).get("control", 32000))
    ports = set(args.port) if args.port else {control_port}
    raw_packets: list[dict] = []
    source_hash = None
    source_label = "hex input"
    if args.input:
        source = args.input.resolve()
        if not source.exists():
            raise SystemExit(f"input does not exist: {source}")
        source_label = str(source)
        source_hash = sha256_file(source)
        if source.suffix.lower() in (".pcap", ".pcapng", ".cap"):
            raw_packets.extend(extract_udp_packets(source, fpga_ip=fpga_ip, ports=ports))
        elif source.suffix.lower() == ".json":
            raw_packets.extend(_packets_from_json(source))
        else:
            raise SystemExit("unsupported input type; use pcap, pcapng, cap, or JSON")
    first_number = max((packet.get("number", 0) for packet in raw_packets), default=0) + 1
    for offset, payload_text in enumerate(args.hex):
        raw_packets.append(packet_from_hex(payload_text, first_number + offset, control_port, args.direction))
    packets = decode_packets(raw_packets, profile, fpga_ip=fpga_ip)
    expected = load_expected_plan(args.expected_plan)
    audit = audit_packets(packets, profile, expected, require_readback=args.require_readback)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output = (args.output or Path.cwd() / f"{timestamp}-{args.session_name}").resolve()
    output.mkdir(parents=True, exist_ok=True)
    session = {
        "created_at": datetime.now().astimezone().isoformat(),
        "profile_id": profile["id"],
        "profile_path": str(profile_path),
        "profile_sha256": sha256_file(profile_path),
        "source": source_label,
        "source_sha256": source_hash,
        "fpga_ip": fpga_ip,
        "ports": sorted(ports),
        "expected_plan": str(args.expected_plan.resolve()) if args.expected_plan else None,
        "command": " ".join(sys.argv),
    }
    if args.copy_capture and args.input and args.input.suffix.lower() in (".pcap", ".pcapng", ".cap"):
        capture_name = "capture" + args.input.suffix.lower()
        destination = output / capture_name
        if args.input.resolve() != destination:
            shutil.copy2(args.input, destination)
        session["capture_copy"] = str(destination)
    write_json(output / "session.json", session)
    write_json(output / "packets.json", packets)
    write_packets_csv(output / "packets.csv", packets)
    write_json(output / "audit.json", audit)
    markdown = render_markdown(session, packets, audit)
    (output / "REPORT.md").write_text(markdown, encoding="utf-8")
    template = DEFAULT_TEMPLATE.read_text(encoding="utf-8")
    (output / "report.html").write_text(render_html(template, session, packets, audit), encoding="utf-8")
    counts = audit["summary"]["verdict_counts"]
    finding_counts = audit["summary"]["finding_counts"]
    print(
        f"packets={len(packets)} PASS={counts['PASS']} WARN={counts['WARN']} "
        f"FAIL={counts['FAIL']} INFO={counts['INFO']}"
    )
    print(f"report={output / 'REPORT.md'}")
    print(f"html={output / 'report.html'}")
    return 2 if finding_counts["FAIL"] else (1 if finding_counts["WARN"] else 0)


if __name__ == "__main__":
    raise SystemExit(main())

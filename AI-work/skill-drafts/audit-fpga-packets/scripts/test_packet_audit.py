from __future__ import annotations

import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

from packet_audit_lib import (
    audit_packets,
    decode_packets,
    extract_udp_packets,
    format_byte_map,
    load_profile,
    packet_from_hex,
    render_html,
)


ROOT = Path(__file__).resolve().parent.parent
PROFILE_PATH = ROOT / "assets" / "profiles" / "sgsc-325t-v3-172.json"
TEMPLATE_PATH = ROOT / "assets" / "report-template.html"


def ipv4_udp_frame(payload: bytes, src_ip=(192, 168, 1, 10), dst_ip=(192, 168, 1, 8), src_port=49152, dst_port=32000) -> bytes:
    udp_length = 8 + len(payload)
    udp = struct.pack(">HHHH", src_port, dst_port, udp_length, 0) + payload
    total_length = 20 + len(udp)
    ip = bytes([0x45, 0]) + struct.pack(">H", total_length) + b"\x00\x01\x00\x00\x40\x11\x00\x00" + bytes(src_ip) + bytes(dst_ip)
    ethernet = bytes.fromhex("DA0102030405 001122334455 0800")
    return ethernet + ip + udp


def write_pcap(path: Path, frame: bytes) -> None:
    global_header = struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 65535, 1)
    packet_header = struct.pack("<IIII", 1, 500000, len(frame), len(frame))
    path.write_bytes(global_header + packet_header + frame)


def block(block_type: int, body: bytes) -> bytes:
    padding = b"\x00" * ((4 - len(body) % 4) % 4)
    length = 12 + len(body) + len(padding)
    return struct.pack("<II", block_type, length) + body + padding + struct.pack("<I", length)


def write_pcapng(path: Path, frame: bytes) -> None:
    section = block(0x0A0D0D0A, struct.pack("<IHHq", 0x1A2B3C4D, 1, 0, -1))
    interface = block(1, struct.pack("<HHI", 1, 0, 65535))
    timestamp = 1_500_000
    enhanced = block(6, struct.pack("<IIIII", 0, timestamp >> 32, timestamp & 0xFFFFFFFF, len(frame), len(frame)) + frame)
    path.write_bytes(section + interface + enhanced)


class PacketAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = load_profile(PROFILE_PATH)

    def decode_hex(self, text: str):
        packet = packet_from_hex(text, 1, 32000, "PC -> FPGA")
        return decode_packets([packet], self.profile)[0]

    def test_control_write_byte_truth(self):
        packet = self.decode_hex("55 55 AA AA 00 01 00 06 02 07 00 00 00 0A")
        self.assertEqual(packet["command"], "WRITE")
        self.assertEqual(packet["address"], "0x0207")
        self.assertEqual(packet["register_name"], "blanker_delay")
        self.assertEqual(packet["register_fields"][0]["display"], "50 ns (raw 10)")
        byte_map = format_byte_map(packet)
        self.assertIn("55 55 AA AA", byte_map)
        self.assertIn("02 07", byte_map)
        self.assertIn("00 00 00 0A", byte_map)

    def test_malformed_declared_length_fails(self):
        packet = self.decode_hex("55 55 AA AA 00 01 00 02 02 07 00 00 00 0A")
        audit = audit_packets([packet], self.profile)
        self.assertEqual(audit["summary"]["verdict_counts"]["FAIL"], 1)
        self.assertTrue(any("declared length" in error for error in packet["errors"]))

    def test_old_laser_address_is_caught_by_expected_plan(self):
        packet = self.decode_hex("55 55 AA AA 00 01 00 06 02 05 00 00 00 01")
        expected = [{"index": 0, "address": "0x020B", "value": 1, "checked": False, "label": "laser"}]
        audit = audit_packets([packet], self.profile, expected)
        titles = {finding["title"] for finding in audit["findings"]}
        self.assertIn("Missing expected write", titles)
        self.assertIn("Additional writes outside expected plan", titles)
        self.assertEqual(audit["summary"]["finding_counts"]["FAIL"], 1)

    def test_pcap_and_pcapng_extract_same_payload(self):
        payload = bytes.fromhex("5555AAAA0001000602070000000A")
        frame = ipv4_udp_frame(payload)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pcap, pcapng = root / "sample.pcap", root / "sample.pcapng"
            write_pcap(pcap, frame)
            write_pcapng(pcapng, frame)
            for capture in (pcap, pcapng):
                packets = extract_udp_packets(capture, "192.168.1.8", {32000})
                self.assertEqual(len(packets), 1)
                self.assertEqual(packets[0]["payload"], payload)

    def test_html_is_self_contained_and_contains_raw_payload(self):
        packet = self.decode_hex("5555AAAA0001000602070000000A")
        audit = audit_packets([packet], self.profile)
        session = {"profile_id": self.profile["id"], "source": "unit-test"}
        output = render_html(TEMPLATE_PATH.read_text(encoding="utf-8"), session, [packet], audit)
        self.assertIn("5555AAAA0001000602070000000A", output)
        self.assertNotIn("__AUDIT_DATA__", output)
        self.assertNotIn("https://", output)

    def test_run_audit_end_to_end(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            result = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "run-audit.py"),
                    "--hex",
                    "5555AAAA0001000602070000000A",
                    "--profile",
                    str(PROFILE_PATH),
                    "--output",
                    str(output),
                ],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            for name in ("session.json", "packets.json", "packets.csv", "audit.json", "REPORT.md", "report.html"):
                self.assertTrue((output / name).exists(), name)
            packets = json.loads((output / "packets.json").read_text(encoding="utf-8"))
            self.assertEqual(packets[0]["payload_hex"], "5555AAAA0001000602070000000A")


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import csv
import hashlib
import html
import ipaddress
import json
from pathlib import Path
import re
import struct
from typing import Any, Iterable


SEVERITY_RANK = {"INFO": 0, "PASS": 1, "WARN": 2, "FAIL": 3}
HEX_RE = re.compile(r"^[0-9A-Fa-f]+$")


def parse_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if value is None:
        raise ValueError("integer value is missing")
    return int(str(value), 0)


def hex16(value: int) -> str:
    return f"0x{value & 0xFFFF:04X}"


def hex32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_profile(path: Path) -> dict[str, Any]:
    profile = load_json(path)
    errors = validate_profile(profile)
    if errors:
        raise ValueError("invalid profile: " + "; ".join(errors))
    return profile


def validate_profile(profile: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for key in ("schema_version", "id", "control", "registers"):
        if key not in profile:
            errors.append(f"missing {key}")
    control = profile.get("control", {})
    magic = control.get("magic", "")
    if len(magic) != 8 or not HEX_RE.fullmatch(magic):
        errors.append("control.magic must be four hexadecimal bytes")
    commands = control.get("commands", {})
    if not commands:
        errors.append("control.commands is empty")
    for command_key, command in commands.items():
        try:
            parse_int(command_key)
        except ValueError:
            errors.append(f"bad command key {command_key!r}")
        if "name" not in command or "payload_length" not in command:
            errors.append(f"command {command_key} is incomplete")
    for address, register in profile.get("registers", {}).items():
        try:
            numeric_address = parse_int(address)
            if not 0 <= numeric_address <= 0xFFFF:
                errors.append(f"register address out of range: {address}")
        except ValueError:
            errors.append(f"bad register address {address!r}")
            continue
        if not register.get("name"):
            errors.append(f"register {address} has no name")
        occupied = 0
        for field in register.get("fields", []):
            lsb = field.get("lsb")
            width = field.get("width")
            if not isinstance(lsb, int) or not isinstance(width, int) or lsb < 0 or width <= 0:
                errors.append(f"register {address} has invalid field bounds")
                continue
            if lsb + width > 32:
                errors.append(f"register {address} field {field.get('name')} exceeds 32 bits")
            mask = ((1 << width) - 1) << lsb
            if occupied & mask:
                errors.append(f"register {address} has overlapping field {field.get('name')}")
            occupied |= mask
    return errors


def normalize_hex_payload(text: str) -> bytes:
    compact = re.sub(r"(?i)0x", "", text)
    compact = re.sub(r"[^0-9A-Fa-f]", "", compact)
    if not compact:
        raise ValueError("hexadecimal payload is empty")
    if len(compact) % 2:
        raise ValueError("hexadecimal payload has an odd number of digits")
    return bytes.fromhex(compact)


def _read_pcap(path: Path) -> list[dict[str, Any]]:
    data = path.read_bytes()
    if len(data) < 24:
        raise ValueError("pcap file is shorter than the global header")
    magic = data[:4]
    variants = {
        b"\xd4\xc3\xb2\xa1": ("<", 1_000_000),
        b"\xa1\xb2\xc3\xd4": (">", 1_000_000),
        b"\x4d\x3c\xb2\xa1": ("<", 1_000_000_000),
        b"\xa1\xb2\x3c\x4d": (">", 1_000_000_000),
    }
    if magic not in variants:
        raise ValueError("unsupported pcap magic")
    endian, fraction_scale = variants[magic]
    linktype = struct.unpack_from(endian + "I", data, 20)[0]
    offset = 24
    frames: list[dict[str, Any]] = []
    number = 1
    while offset + 16 <= len(data):
        seconds, fraction, captured_len, original_len = struct.unpack_from(endian + "IIII", data, offset)
        offset += 16
        if captured_len > len(data) - offset:
            raise ValueError(f"pcap packet {number} is truncated")
        packet = data[offset : offset + captured_len]
        offset += captured_len
        frames.append(
            {
                "number": number,
                "timestamp_epoch": seconds + fraction / fraction_scale,
                "linktype": linktype,
                "captured_length": captured_len,
                "original_length": original_len,
                "frame_bytes": packet,
            }
        )
        number += 1
    return frames


def _parse_pcapng_options(body: bytes, start: int, endian: str) -> dict[int, list[bytes]]:
    result: dict[int, list[bytes]] = {}
    offset = start
    while offset + 4 <= len(body):
        code, length = struct.unpack_from(endian + "HH", body, offset)
        offset += 4
        if code == 0:
            break
        value = body[offset : offset + length]
        result.setdefault(code, []).append(value)
        offset += (length + 3) & ~3
    return result


def _read_pcapng(path: Path) -> list[dict[str, Any]]:
    data = path.read_bytes()
    offset = 0
    endian = "<"
    interfaces: list[dict[str, Any]] = []
    frames: list[dict[str, Any]] = []
    number = 1
    while offset + 12 <= len(data):
        raw_type = data[offset : offset + 4]
        if raw_type == b"\x0a\x0d\x0d\x0a":
            if offset + 12 > len(data):
                raise ValueError("truncated pcapng section header")
            bom = data[offset + 8 : offset + 12]
            if bom == b"\x4d\x3c\x2b\x1a":
                endian = "<"
            elif bom == b"\x1a\x2b\x3c\x4d":
                endian = ">"
            else:
                raise ValueError("invalid pcapng byte-order magic")
            block_length = struct.unpack_from(endian + "I", data, offset + 4)[0]
            interfaces = []
        else:
            block_type, block_length = struct.unpack_from(endian + "II", data, offset)
            if block_length < 12 or offset + block_length > len(data):
                raise ValueError("invalid pcapng block length")
            body = data[offset + 8 : offset + block_length - 4]
            if block_type == 1 and len(body) >= 8:
                linktype = struct.unpack_from(endian + "H", body, 0)[0]
                options = _parse_pcapng_options(body, 8, endian)
                ts_resolution = 1_000_000
                if 9 in options and options[9] and options[9][0]:
                    raw = options[9][0][0]
                    ts_resolution = (2 ** (raw & 0x7F)) if raw & 0x80 else (10 ** raw)
                interfaces.append({"linktype": linktype, "ts_resolution": ts_resolution})
            elif block_type == 6 and len(body) >= 20:
                interface_id, ts_high, ts_low, captured_len, original_len = struct.unpack_from(
                    endian + "IIIII", body, 0
                )
                if interface_id >= len(interfaces):
                    raise ValueError("pcapng packet refers to an unknown interface")
                packet = body[20 : 20 + captured_len]
                if len(packet) != captured_len:
                    raise ValueError("truncated pcapng enhanced packet")
                raw_ts = (ts_high << 32) | ts_low
                interface = interfaces[interface_id]
                frames.append(
                    {
                        "number": number,
                        "timestamp_epoch": raw_ts / interface["ts_resolution"],
                        "linktype": interface["linktype"],
                        "captured_length": captured_len,
                        "original_length": original_len,
                        "frame_bytes": packet,
                    }
                )
                number += 1
            elif block_type == 3 and len(body) >= 4 and interfaces:
                original_len = struct.unpack_from(endian + "I", body, 0)[0]
                packet = body[4 : 4 + min(original_len, len(body) - 4)]
                frames.append(
                    {
                        "number": number,
                        "timestamp_epoch": None,
                        "linktype": interfaces[0]["linktype"],
                        "captured_length": len(packet),
                        "original_length": original_len,
                        "frame_bytes": packet,
                    }
                )
                number += 1
        if block_length < 12 or offset + block_length > len(data):
            raise ValueError("invalid pcapng section length")
        trailing = struct.unpack_from(endian + "I", data, offset + block_length - 4)[0]
        if trailing != block_length:
            raise ValueError("pcapng block length trailer mismatch")
        offset += block_length
    return frames


def read_capture(path: Path) -> list[dict[str, Any]]:
    signature = path.read_bytes()[:4]
    if signature == b"\x0a\x0d\x0d\x0a":
        return _read_pcapng(path)
    return _read_pcap(path)


def _format_mac(raw: bytes) -> str:
    return ":".join(f"{value:02X}" for value in raw)


def _parse_network_frame(frame: dict[str, Any]) -> dict[str, Any] | None:
    data: bytes = frame["frame_bytes"]
    linktype = frame["linktype"]
    src_mac = dst_mac = None
    ethertype = None
    if linktype == 1:
        if len(data) < 14:
            return None
        dst_mac, src_mac = _format_mac(data[:6]), _format_mac(data[6:12])
        ethertype = int.from_bytes(data[12:14], "big")
        offset = 14
        while ethertype in (0x8100, 0x88A8, 0x9100):
            if len(data) < offset + 4:
                return None
            ethertype = int.from_bytes(data[offset + 2 : offset + 4], "big")
            offset += 4
        network = data[offset:]
    elif linktype == 101:
        network = data
        ethertype = 0x0800 if data and data[0] >> 4 == 4 else 0x86DD
    elif linktype == 113:
        if len(data) < 16:
            return None
        ethertype = int.from_bytes(data[14:16], "big")
        network = data[16:]
    elif linktype == 276:
        if len(data) < 20:
            return None
        ethertype = int.from_bytes(data[:2], "big")
        network = data[20:]
    elif linktype == 0:
        if len(data) < 4:
            return None
        network = data[4:]
        ethertype = 0x0800 if network and network[0] >> 4 == 4 else 0x86DD
    else:
        return None

    src_ip = dst_ip = None
    udp = None
    if ethertype == 0x0800:
        if len(network) < 20 or network[0] >> 4 != 4:
            return None
        ihl = (network[0] & 0x0F) * 4
        if ihl < 20 or len(network) < ihl:
            return None
        total_len = int.from_bytes(network[2:4], "big")
        protocol = network[9]
        src_ip = str(ipaddress.ip_address(network[12:16]))
        dst_ip = str(ipaddress.ip_address(network[16:20]))
        fragment = int.from_bytes(network[6:8], "big")
        if protocol != 17 or (fragment & 0x1FFF):
            return None
        udp = network[ihl : min(len(network), total_len or len(network))]
    elif ethertype == 0x86DD:
        if len(network) < 40 or network[0] >> 4 != 6 or network[6] != 17:
            return None
        src_ip = str(ipaddress.ip_address(network[8:24]))
        dst_ip = str(ipaddress.ip_address(network[24:40]))
        udp = network[40:]
    if udp is None or len(udp) < 8:
        return None
    src_port = int.from_bytes(udp[:2], "big")
    dst_port = int.from_bytes(udp[2:4], "big")
    udp_length = int.from_bytes(udp[4:6], "big")
    payload_end = min(len(udp), udp_length) if udp_length >= 8 else len(udp)
    payload = udp[8:payload_end]
    return {
        "number": frame["number"],
        "timestamp_epoch": frame.get("timestamp_epoch"),
        "src_mac": src_mac,
        "dst_mac": dst_mac,
        "src_ip": src_ip,
        "dst_ip": dst_ip,
        "src_port": src_port,
        "dst_port": dst_port,
        "udp_length": udp_length,
        "payload": payload,
        "payload_length": len(payload),
        "frame_captured_length": frame["captured_length"],
        "frame_original_length": frame["original_length"],
    }


def extract_udp_packets(
    path: Path,
    fpga_ip: str | None = None,
    ports: set[int] | None = None,
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for frame in read_capture(path):
        packet = _parse_network_frame(frame)
        if packet is None:
            continue
        if fpga_ip and fpga_ip not in (packet["src_ip"], packet["dst_ip"]):
            continue
        if ports and not ({packet["src_port"], packet["dst_port"]} & ports):
            continue
        result.append(packet)
    return result


def _direction(packet: dict[str, Any], fpga_ip: str | None, control_port: int) -> str:
    if fpga_ip:
        if packet.get("dst_ip") == fpga_ip:
            return "PC -> FPGA"
        if packet.get("src_ip") == fpga_ip:
            return "FPGA -> PC"
    if packet.get("dst_port") == control_port and packet.get("src_port") != control_port:
        return "PC -> FPGA"
    if packet.get("src_port") == control_port:
        return "FPGA -> PC"
    return packet.get("direction") or "UNKNOWN"


def _decode_register(value: int, register: dict[str, Any]) -> dict[str, Any]:
    decoded_fields: list[dict[str, Any]] = []
    warnings: list[str] = []
    reserved_mask = parse_int(register["reserved_mask"]) if register.get("reserved_mask") else 0
    if reserved_mask and value & reserved_mask:
        warnings.append(f"reserved bits are non-zero: {hex32(value & reserved_mask)}")
    for field in register.get("fields", []):
        width = field["width"]
        raw = (value >> field["lsb"]) & ((1 << width) - 1)
        numeric = raw
        if field.get("signed") and raw & (1 << (width - 1)):
            numeric = raw - (1 << width)
        enum_name = field.get("enum", {}).get(str(raw))
        if enum_name is not None:
            display = f"{enum_name} ({raw})"
        elif field.get("format") == "hex":
            digits = max(1, (width + 3) // 4)
            display = f"0x{raw:0{digits}X}"
        elif "unit" in field:
            physical = numeric * field.get("scale", 1)
            display = f"{physical:g} {field['unit']} (raw {numeric})"
        else:
            display = str(numeric)
        if "min" in field and numeric < field["min"]:
            warnings.append(f"{field['name']}={numeric} is below minimum {field['min']}")
        if "max" in field and numeric > field["max"]:
            warnings.append(f"{field['name']}={numeric} exceeds maximum {field['max']}")
        decoded_fields.append(
            {
                "name": field["name"],
                "lsb": field["lsb"],
                "width": width,
                "raw": raw,
                "numeric": numeric,
                "display": display,
                "unit": field.get("unit"),
                "provenance": register.get("provenance"),
            }
        )
    return {"fields": decoded_fields, "warnings": warnings}


def _sgsc_sequence(raw: bytes) -> int:
    if len(raw) != 6:
        raise ValueError("SGSC sequence must be six bytes")
    return (raw[1] << 40) | (raw[0] << 32) | (raw[5] << 24) | (raw[4] << 16) | (raw[3] << 8) | raw[2]


def _base_record(packet: dict[str, Any], payload: bytes, direction: str) -> dict[str, Any]:
    return {
        "number": packet.get("number"),
        "timestamp_epoch": packet.get("timestamp_epoch"),
        "src_mac": packet.get("src_mac"),
        "dst_mac": packet.get("dst_mac"),
        "src_ip": packet.get("src_ip"),
        "dst_ip": packet.get("dst_ip"),
        "src_port": packet.get("src_port"),
        "dst_port": packet.get("dst_port"),
        "direction": direction,
        "payload_length": len(payload),
        "payload_hex": payload.hex().upper(),
        "payload_sha256": sha256_bytes(payload),
        "protocol": "UNKNOWN",
        "decode_status": "unknown",
        "errors": [],
        "warnings": [],
        "byte_fields": [],
        "verdict": "INFO",
    }


def decode_packet(packet: dict[str, Any], profile: dict[str, Any], fpga_ip: str | None = None) -> dict[str, Any]:
    payload: bytes = packet["payload"]
    control_port = int(profile.get("ports", {}).get("control", 32000))
    direction = _direction(packet, fpga_ip or profile.get("default_fpga_ip"), control_port)
    record = _base_record(packet, payload, direction)
    control = profile["control"]
    magic = bytes.fromhex(control["magic"])
    ports = {packet.get("src_port"), packet.get("dst_port")}
    if control_port in ports or payload.startswith(magic):
        record["protocol"] = "CONTROL"
        record["byte_fields"].append({"name": "frame header", "start": 0, "length": min(4, len(payload)), "decode": "0x" + payload[:4].hex().upper(), "meaning": "protocol key"})
        if len(payload) < 8:
            record["errors"].append("control payload is shorter than the 8-byte fixed header")
            record["decode_status"] = "error"
            return record
        if payload[:4] != magic:
            record["errors"].append(f"bad control magic 0x{payload[:4].hex().upper()}")
        command_code = int.from_bytes(payload[4:6], "big")
        declared_length = int.from_bytes(payload[6:8], "big")
        command_key = f"0x{command_code:04X}"
        command = control.get("commands", {}).get(command_key)
        record.update(
            {
                "command_code": command_key,
                "command": command.get("name") if command else "UNKNOWN_COMMAND",
                "declared_length": declared_length,
                "captured_data_length": len(payload) - 8,
            }
        )
        record["byte_fields"].extend(
            [
                {"name": "command", "start": 4, "length": 2, "decode": record["command"], "meaning": command_key},
                {"name": "length", "start": 6, "length": 2, "decode": f"{declared_length} B", "meaning": f"captured {len(payload) - 8} B"},
            ]
        )
        if command is None:
            record["errors"].append(f"unsupported command {command_key}")
        else:
            if command.get("payload_length") != len(payload):
                record["errors"].append(
                    f"payload length {len(payload)} does not match {command['payload_length']} for {command['name']}"
                )
            if command.get("declared_length") != declared_length:
                record["errors"].append(
                    f"declared length {declared_length} does not match {command['declared_length']} for {command['name']}"
                )
        if declared_length != len(payload) - 8:
            record["errors"].append(
                f"declared data length {declared_length} differs from captured {len(payload) - 8}"
            )
        if len(payload) >= 10:
            address = int.from_bytes(payload[8:10], "big")
            address_key = hex16(address)
            register = profile.get("registers", {}).get(address_key)
            record["address"] = address_key
            record["register_name"] = register.get("name") if register else "UNKNOWN_REGISTER"
            record["register_provenance"] = register.get("provenance") if register else "unknown"
            record["byte_fields"].append(
                {"name": "address", "start": 8, "length": 2, "decode": address_key, "meaning": record["register_name"]}
            )
            if register is None:
                record["warnings"].append(f"register {address_key} is not present in profile {profile['id']}")
            elif register.get("provenance") in ("document-only", "conflict"):
                record["warnings"].append(
                    f"register meaning provenance is {register.get('provenance')}: {register.get('note', '')}".strip()
                )
            if record["command"] == "WRITE" and register and register.get("access") == "r":
                record["errors"].append(f"write sent to read-only register {address_key}")
            if record["command"] in ("READ", "READ_RESPONSE") and register and register.get("access") == "w":
                record["warnings"].append(f"read used with write-only register {address_key}")
        if len(payload) >= 14 and record["command"] in ("WRITE", "READ_RESPONSE"):
            value = int.from_bytes(payload[10:14], "big")
            record["value"] = value
            record["value_hex"] = hex32(value)
            register = profile.get("registers", {}).get(record.get("address"))
            meaning = record.get("register_name", "register value")
            record["byte_fields"].append(
                {"name": "value", "start": 10, "length": 4, "decode": str(value), "meaning": meaning}
            )
            if register:
                decoded = _decode_register(value, register)
                record["register_fields"] = decoded["fields"]
                record["warnings"].extend(decoded["warnings"])
                if decoded["fields"]:
                    record["byte_fields"][-1]["meaning"] = ", ".join(
                        f"{field['name']}={field['display']}" for field in decoded["fields"]
                    )
        record["decode_status"] = "error" if record["errors"] else "ok"
        return record

    for protocol in profile.get("data_protocols", []):
        protocol_port = int(protocol["port"])
        protocol_magic = bytes.fromhex(protocol["magic"])
        if protocol_port not in ports or not payload.startswith(protocol_magic):
            continue
        record["protocol"] = protocol["name"]
        record["decode_status"] = "ok"
        header_length = int(protocol["header_length"])
        record["byte_fields"].append(
            {"name": "frame header", "start": 0, "length": 4, "decode": "0x" + protocol["magic"], "meaning": protocol["name"]}
        )
        if len(payload) < header_length:
            record["errors"].append(f"payload is shorter than {header_length}-byte header")
        if protocol.get("sequence_encoding") == "sgsc48" and len(payload) >= 10:
            sequence = _sgsc_sequence(payload[4:10])
            record["sequence"] = sequence
            record["byte_fields"].append(
                {"name": "sequence", "start": 4, "length": 6, "decode": str(sequence), "meaning": "SGSC 48-bit byte order"}
            )
        if "length_offset" in protocol and len(payload) >= protocol["length_offset"] + protocol["length_width"]:
            start = protocol["length_offset"]
            end = start + protocol["length_width"]
            declared = int.from_bytes(payload[start:end], protocol.get("length_byte_order", "big"))
            record["declared_length"] = declared
            record["captured_data_length"] = max(0, len(payload) - header_length)
            record["byte_fields"].append(
                {"name": "length", "start": start, "length": protocol["length_width"], "decode": f"{declared} B", "meaning": f"captured {record['captured_data_length']} B"}
            )
            if declared != record["captured_data_length"]:
                record["errors"].append(
                    f"declared payload length {declared} differs from captured {record['captured_data_length']}"
                )
        if len(payload) > header_length:
            record["data_payload_length"] = len(payload) - header_length
            record["data_payload_sha256"] = sha256_bytes(payload[header_length:])
        if record["errors"]:
            record["decode_status"] = "error"
        return record
    return record


def decode_packets(
    packets: Iterable[dict[str, Any]],
    profile: dict[str, Any],
    fpga_ip: str | None = None,
) -> list[dict[str, Any]]:
    return [decode_packet(packet, profile, fpga_ip) for packet in packets]


def packet_from_hex(
    text: str,
    number: int,
    port: int,
    direction: str,
) -> dict[str, Any]:
    payload = normalize_hex_payload(text)
    if direction == "PC -> FPGA":
        src_port, dst_port = 49152, port
    elif direction == "FPGA -> PC":
        src_port, dst_port = port, 49152
    else:
        src_port = dst_port = port
    return {
        "number": number,
        "timestamp_epoch": None,
        "src_ip": None,
        "dst_ip": None,
        "src_port": src_port,
        "dst_port": dst_port,
        "payload": payload,
        "payload_length": len(payload),
        "direction": direction,
    }


def _walk_expected(value: Any) -> list[dict[str, Any]] | None:
    if isinstance(value, list) and value and all(
        isinstance(item, dict) and "address" in item and "value" in item for item in value
    ):
        return value
    if isinstance(value, dict):
        preferred = ("items", "plan", "writes", "data", "results")
        for key in preferred:
            if key in value:
                found = _walk_expected(value[key])
                if found:
                    return found
        for child in value.values():
            found = _walk_expected(child)
            if found:
                return found
    if isinstance(value, list):
        for child in value:
            found = _walk_expected(child)
            if found:
                return found
    return None


def load_expected_plan(path: Path | None) -> list[dict[str, Any]]:
    if path is None:
        return []
    raw = load_json(path)
    items = _walk_expected(raw)
    if not items:
        raise ValueError("could not find an address/value write list in expected plan")
    result = []
    for index, item in enumerate(items):
        result.append(
            {
                "index": index,
                "address": hex16(parse_int(item["address"])),
                "value": parse_int(item["value"]) & 0xFFFFFFFF,
                "checked": bool(item.get("checked", False)),
                "label": item.get("label", ""),
            }
        )
    return result


def _set_verdict(packet: dict[str, Any], severity: str) -> None:
    if SEVERITY_RANK[severity] > SEVERITY_RANK.get(packet.get("verdict", "INFO"), 0):
        packet["verdict"] = severity


def audit_packets(
    packets: list[dict[str, Any]],
    profile: dict[str, Any],
    expected_plan: list[dict[str, Any]] | None = None,
    require_readback: bool = False,
) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []

    def add(severity: str, title: str, message: str, packet_numbers: list[int] | None = None) -> None:
        numbers = [number for number in (packet_numbers or []) if number is not None]
        findings.append(
            {
                "id": f"F{len(findings) + 1:04d}",
                "severity": severity,
                "title": title,
                "message": message,
                "packet_numbers": numbers,
            }
        )
        number_set = set(numbers)
        for packet in packets:
            if packet.get("number") in number_set:
                _set_verdict(packet, severity)

    for packet in packets:
        if packet.get("errors"):
            add("FAIL", "Malformed or invalid packet", "; ".join(packet["errors"]), [packet.get("number")])
        if packet.get("warnings"):
            add("WARN", "Packet warning", "; ".join(packet["warnings"]), [packet.get("number")])

    pending_reads: list[dict[str, Any]] = []
    responses_by_address: dict[str, list[dict[str, Any]]] = {}
    for packet in packets:
        if packet.get("protocol") != "CONTROL":
            continue
        if packet.get("command") == "READ":
            pending_reads.append(packet)
        elif packet.get("command") == "READ_RESPONSE":
            address = packet.get("address")
            responses_by_address.setdefault(address, []).append(packet)
            match = next((request for request in pending_reads if request.get("address") == address), None)
            if match:
                pending_reads.remove(match)
                if match.get("verdict") == "INFO":
                    match["verdict"] = "PASS"
                if packet.get("verdict") == "INFO":
                    packet["verdict"] = "PASS"
            else:
                add(
                    "WARN",
                    "Unmatched read response",
                    f"Read response for {address} has no earlier unmatched read request.",
                    [packet.get("number")],
                )
    for request in pending_reads:
        add(
            "WARN",
            "Missing read response",
            f"No read response was captured for {request.get('address')}.",
            [request.get("number")],
        )

    writes = [
        packet
        for packet in packets
        if packet.get("protocol") == "CONTROL" and packet.get("command") == "WRITE" and "value" in packet
    ]
    expected_plan = expected_plan or []
    if expected_plan:
        cursor = 0
        matched_packet_numbers: set[int] = set()
        for expected in expected_plan:
            exact_index = next(
                (
                    index
                    for index in range(cursor, len(writes))
                    if writes[index].get("address") == expected["address"]
                    and writes[index].get("value") == expected["value"]
                ),
                None,
            )
            if exact_index is None:
                same_address = next(
                    (packet for packet in writes[cursor:] if packet.get("address") == expected["address"]),
                    None,
                )
                if same_address:
                    add(
                        "FAIL",
                        "Expected write value mismatch",
                        f"Expected {expected['address']}={hex32(expected['value'])}, captured {same_address.get('value_hex')}.",
                        [same_address.get("number")],
                    )
                else:
                    add(
                        "FAIL",
                        "Missing expected write",
                        f"Expected {expected['address']}={hex32(expected['value'])} was not captured.",
                        [],
                    )
                    same_value = next(
                        (packet for packet in writes[cursor:] if packet.get("value") == expected["value"]),
                        None,
                    )
                    if same_value:
                        add(
                            "WARN",
                            "Possible register-map version mismatch",
                            f"Expected value {hex32(expected['value'])} at {expected['address']}, but the same value was written to "
                            f"{same_value.get('address')} ({same_value.get('register_name')}).",
                            [same_value.get("number")],
                        )
                continue
            packet = writes[exact_index]
            matched_packet_numbers.add(packet["number"])
            if exact_index != cursor:
                skipped = [candidate.get("number") for candidate in writes[cursor:exact_index]]
                add(
                    "WARN",
                    "Expected write reordered",
                    f"{expected['address']}={hex32(expected['value'])} appeared later than expected.",
                    skipped + [packet.get("number")],
                )
            elif packet.get("verdict") == "INFO":
                packet["verdict"] = "PASS"
            cursor = exact_index + 1
            if expected.get("checked") or require_readback:
                response = next(
                    (
                        response
                        for response in responses_by_address.get(expected["address"], [])
                        if response.get("number", 0) > packet.get("number", 0)
                    ),
                    None,
                )
                if response is None:
                    add(
                        "WARN",
                        "Checked write has no captured readback",
                        f"No readback was captured after writing {expected['address']}.",
                        [packet.get("number")],
                    )
                elif response.get("value") != expected["value"]:
                    add(
                        "FAIL",
                        "Write/readback mismatch",
                        f"Wrote {hex32(expected['value'])}, read back {response.get('value_hex')} from {expected['address']}.",
                        [packet.get("number"), response.get("number")],
                    )
                else:
                    if response.get("verdict") == "INFO":
                        response["verdict"] = "PASS"
        extras = [packet for packet in writes if packet.get("number") not in matched_packet_numbers]
        if extras:
            add(
                "WARN",
                "Additional writes outside expected plan",
                f"Captured {len(extras)} additional register write(s).",
                [packet.get("number") for packet in extras],
            )

    audit_rules = profile.get("audit", {})
    scan_address = audit_rules.get("scan_control_address")
    parameter_addresses = set(audit_rules.get("parameter_addresses", []))
    running: bool | None = None
    seen_writes: set[str] = set()
    for packet in writes:
        address = packet.get("address")
        value = packet.get("value", 0)
        if address == scan_address:
            state = value & 0xF
            if state == 1:
                running = True
            elif state in (0, 2):
                running = False
                seen_writes = {address}
        elif running and address in parameter_addresses:
            add(
                "WARN",
                "Parameter changed while scan is running",
                f"{address} ({packet.get('register_name')}) was written after captured scan_state became running.",
                [packet.get("number")],
            )
        for dependency in audit_rules.get("enable_dependencies", []):
            if address != dependency["address"]:
                continue
            mask = parse_int(dependency["mask"])
            equals = parse_int(dependency["equals"])
            if value & mask == equals:
                missing = [required for required in dependency.get("required_prior", []) if required not in seen_writes]
                if missing:
                    add(
                        "WARN",
                        "Enable dependency not observed",
                        dependency.get("message", "Required configuration writes were not observed")
                        + " Missing: "
                        + ", ".join(missing),
                        [packet.get("number")],
                    )
        seen_writes.add(address)

    counts = {severity: 0 for severity in ("PASS", "WARN", "FAIL", "INFO")}
    for packet in packets:
        counts[packet.get("verdict", "INFO")] += 1
    findings.sort(key=lambda item: (-SEVERITY_RANK[item["severity"]], item["id"]))
    finding_counts = {severity: 0 for severity in ("PASS", "WARN", "FAIL", "INFO")}
    for finding in findings:
        finding_counts[finding["severity"]] += 1
    return {
        "summary": {
            "packet_count": len(packets),
            "verdict_counts": counts,
            "finding_counts": finding_counts,
            "finding_count": len(findings),
            "expected_write_count": len(expected_plan),
            "captured_write_count": len(writes),
        },
        "findings": findings,
    }


def _field_groups(packet: dict[str, Any]) -> list[dict[str, Any]]:
    payload = bytes.fromhex(packet.get("payload_hex", ""))
    fields = sorted(packet.get("byte_fields", []), key=lambda field: field["start"])
    result: list[dict[str, Any]] = []
    cursor = 0
    for field in fields:
        start = max(cursor, field["start"])
        if start > cursor:
            result.append(
                {"name": "unknown", "start": cursor, "length": start - cursor, "decode": "-", "meaning": "undecoded bytes"}
            )
        length = min(field["length"], max(0, len(payload) - start))
        if length:
            item = dict(field)
            item["start"] = start
            item["length"] = length
            result.append(item)
            cursor = start + length
    if cursor < len(payload):
        result.append(
            {"name": "payload", "start": cursor, "length": len(payload) - cursor, "decode": f"{len(payload) - cursor} B", "meaning": "remaining bytes"}
        )
    return result


def format_byte_map(packet: dict[str, Any]) -> str:
    payload = bytes.fromhex(packet.get("payload_hex", ""))
    groups = _field_groups(packet)
    if not groups:
        return "Raw     " + " ".join(f"{value:02X}" for value in payload)
    rows = {"Offset": [], "Raw": [], "Field": [], "Decode": [], "Meaning": []}
    for group in groups:
        start, length = group["start"], group["length"]
        cells = {
            "Offset": " ".join(f"{index:02X}" for index in range(start, start + length)),
            "Raw": " ".join(f"{value:02X}" for value in payload[start : start + length]),
            "Field": str(group.get("name", "")),
            "Decode": str(group.get("decode", "")),
            "Meaning": str(group.get("meaning", "")),
        }
        width = max(len(value) for value in cells.values())
        for name, value in cells.items():
            rows[name].append(value.ljust(width))
    return "\n".join(f"{name:<8}" + " | ".join(values).rstrip() for name, values in rows.items())


def write_packets_csv(path: Path, packets: list[dict[str, Any]]) -> None:
    columns = [
        "number",
        "timestamp_epoch",
        "direction",
        "src_ip",
        "src_port",
        "dst_ip",
        "dst_port",
        "protocol",
        "command",
        "address",
        "register_name",
        "value_hex",
        "verdict",
        "payload_hex",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(packets)


def render_markdown(session: dict[str, Any], packets: list[dict[str, Any]], audit: dict[str, Any]) -> str:
    summary = audit["summary"]
    counts = summary["verdict_counts"]
    lines = [
        "# FPGA Packet Audit",
        "",
        f"- Profile: `{session['profile_id']}`",
        f"- Source: `{session.get('source', 'hex input')}`",
        f"- Packets: {summary['packet_count']}",
        f"- Verdicts: PASS={counts['PASS']}, WARN={counts['WARN']}, FAIL={counts['FAIL']}, INFO={counts['INFO']}",
        f"- Findings: WARN={summary['finding_counts']['WARN']}, FAIL={summary['finding_counts']['FAIL']}",
        "",
        "## Findings",
        "",
    ]
    if not audit["findings"]:
        lines.append("No deterministic findings.")
    else:
        for finding in audit["findings"]:
            packets_text = ", ".join(f"#{number}" for number in finding["packet_numbers"]) or "session"
            lines.append(f"- **{finding['severity']} {finding['title']}** ({packets_text}): {finding['message']}")
    lines.extend(["", "## Packet Index", "", "| # | Direction | Protocol | Command | Register | Value | Verdict |", "|---:|---|---|---|---|---|---|"])
    for packet in packets:
        lines.append(
            f"| {packet.get('number')} | {packet.get('direction')} | {packet.get('protocol')} | "
            f"{packet.get('command', '')} | {packet.get('address', '')} {packet.get('register_name', '')} | "
            f"{packet.get('value_hex', '')} | {packet.get('verdict')} |"
        )
    lines.extend(["", "## Packet Evidence", ""])
    for packet in packets:
        lines.extend(
            [
                f"### Packet #{packet.get('number')} — {packet.get('direction')} — {packet.get('verdict')}",
                "",
                "```text",
                format_byte_map(packet),
                "```",
                "",
            ]
        )
        if packet.get("register_fields"):
            lines.append("Decoded register fields:")
            lines.append("")
            for field in packet["register_fields"]:
                lines.append(f"- `{field['name']}`: {field['display']}")
            lines.append("")
        for error in packet.get("errors", []):
            lines.append(f"- FAIL: {error}")
        for warning in packet.get("warnings", []):
            lines.append(f"- WARN: {warning}")
        if packet.get("errors") or packet.get("warnings"):
            lines.append("")
    lines.extend(["## Evidence Integrity", "", f"- Profile SHA-256: `{session.get('profile_sha256')}`"])
    if session.get("source_sha256"):
        lines.append(f"- Source SHA-256: `{session['source_sha256']}`")
    return "\n".join(lines) + "\n"


def _safe_json_for_script(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")


def render_html(template: str, session: dict[str, Any], packets: list[dict[str, Any]], audit: dict[str, Any]) -> str:
    payload = _safe_json_for_script({"session": session, "packets": packets, "audit": audit})
    return template.replace("__AUDIT_DATA__", payload).replace("__REPORT_TITLE__", html.escape(f"FPGA Packet Audit — {session['profile_id']}"))

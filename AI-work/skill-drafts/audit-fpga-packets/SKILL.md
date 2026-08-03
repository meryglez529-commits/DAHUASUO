---
name: audit-fpga-packets
description: Capture, decode, audit, and explain FPGA host-to-board Ethernet sessions through CLI capture tools and versioned protocol profiles. Use when Codex needs to start or stop a narrowly scoped packet capture, analyze pcap/pcapng files or pasted hexadecimal payloads, verify register writes and readbacks against FPGA RTL and host expectations, identify missing or misordered commands, expose exact field-to-byte mappings, generate Markdown/HTML evidence reports, or diagnose SGSC/DB500-style UDP protocol and firmware-version mismatches.
---

# FPGA Packet Auditor

Turn FPGA Ethernet traffic into reviewable engineering evidence. Preserve captured bytes as the source of truth, use deterministic scripts for decoding and verdicts, and use AI only to explain findings and propose next checks.

## Non-Negotiable Rules

1. Never ask AI to infer protocol fields directly from an unstructured byte dump when a deterministic decoder can decide them.
2. Never alter, reorder, normalize, or omit bytes in the raw evidence view.
3. Separate captured facts, deterministic verdicts, and AI hypotheses in every report.
4. Tie every decoded field and finding to a capture file, packet number, byte offset, field width, and byte order.
5. Prefer the active FPGA project and current host encoder over a generic protocol document when they conflict.
6. Mark unsupported addresses and ambiguous protocol versions explicitly; do not silently choose a meaning.
7. Do not transmit, replay, or modify FPGA traffic. This skill captures and analyzes only unless the user separately requests and authorizes a transmit workflow.
8. Scope live capture to the requested interface, FPGA IP, and ports. Do not collect unrelated network traffic.

## Supported Inputs

Accept one or more of:

- A `.pcap` or `.pcapng` file.
- A live-capture request with interface, FPGA IP, ports, duration, or an explicit stop condition.
- `tshark` JSON or field output.
- One or more hexadecimal UDP payloads.
- A host-app dry-run/expected write plan in JSON.
- A named FPGA project, firmware version, RTL register decoder, host encoder, or protocol document used to select or build a protocol profile.

Ask only for information that cannot be discovered safely. For live capture, require a target FPGA IP and interface unless a supplied profile and local routing make both unambiguous.

## Tool and Resource Routing

Use the bundled resources when present:

- `scripts/run-audit.py`: run the complete offline decode, audit, and report pipeline.
- `scripts/capture-session.ps1`: discover CLI capture backends and run a filtered capture.
- `scripts/extract-packets.py`: extract packet metadata and exact UDP payload bytes.
- `scripts/decode-packets.py`: decode packets from a versioned protocol profile.
- `scripts/audit-session.py`: group transactions and apply deterministic audit rules.
- `scripts/render-report.py`: produce Markdown, JSON, CSV, and self-contained HTML reports.
- `scripts/validate-profile.py`: validate profile structure, address conflicts, field widths, and test vectors.
- `references/protocol-source-policy.md`: resolve disagreements among RTL, host code, captures, and documents.
- `references/audit-rules.md`: severity definitions and cross-packet checks.
- `references/report-contract.md`: required report structure and byte-evidence format.
- `assets/profiles/*.json`: versioned protocol/register profiles.
- `assets/report-template.html`: offline HTML report UI.

Do not improvise a second decoder in prose when a bundled decoder exists. If a required resource is absent, state which capability is unavailable and continue with the safe subset, such as offline hexadecimal decoding.

## Quick Commands

Resolve the installed skill root first. Audit a capture with the active SGSC profile:

```powershell
python -X utf8 <skill-root>/scripts/run-audit.py `
  --input capture.pcapng `
  --profile <skill-root>/assets/profiles/sgsc-325t-v3-172.json `
  --fpga-ip 192.168.1.8 `
  --output <project>/AI-work/reports/packet-audit/session-name
```

Audit one raw control payload:

```powershell
python -X utf8 <skill-root>/scripts/run-audit.py `
  --hex "55 55 AA AA 00 01 00 06 02 07 00 00 00 0A" `
  --output <project>/AI-work/reports/packet-audit/single-packet
```

For live capture, list interfaces first, then run a narrow capture:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>/scripts/capture-session.ps1 -ListInterfaces -OutputPath ignored.pcapng
powershell -ExecutionPolicy Bypass -File <skill-root>/scripts/capture-session.ps1 `
  -FpgaIp 192.168.1.8 -Ports 32000 -Interface <id> -DurationSeconds 30 `
  -OutputPath <session>/capture.pcapng
```

Run `capture-session.ps1 -WhatIf` before the first live capture on a machine.

## Workflow

### 1. Establish Scope

Determine:

- Offline analysis or live capture.
- FPGA IP and relevant UDP ports.
- Capture interface and duration for live work.
- Candidate firmware/project profile.
- Expected operation, when known, such as “apply laser mode” or “read version.”
- Output root.

Default runtime output to:

```text
<project>/AI-work/reports/packet-audit/<timestamp>-<session-slug>/
```

Use a user-selected directory outside the project when requested. Never write captures or reports into the installed skill directory.

### 2. Select the Protocol Profile

Apply this source precedence:

1. Active sources referenced by the current FPGA project file.
2. Current RTL packet parser and register decoder.
3. Current host-app packet encoder and expected write plan.
4. Captured behavior confirmed by request/response pairs.
5. Version-matched protocol documentation.
6. Generic or older protocol documentation.

Record provenance per packet type and register entry. Use statuses such as:

- `rtl-verified`
- `host-verified`
- `capture-observed`
- `document-only`
- `conflict`
- `unknown`

Never treat a large product-level register map as implemented merely because an address appears in a document.

### 3. Acquire or Import Evidence

For live capture:

1. Detect the supported CLI backend through `capture-session.ps1`.
2. Print the interface, capture filter, output path, and stop condition before capture starts.
3. Use a narrow capture filter such as the target FPGA host plus the required UDP ports.
4. Preserve the original `.pcapng` file.
5. Record capture tool name/version and the exact command without exposing unrelated sensitive data.

For offline analysis, hash the source capture before decoding. For pasted hexadecimal payloads, preserve the user’s original text and produce a normalized byte array separately.

Do not install packet-capture drivers or tools without explicit user authorization.

### 4. Decode Deterministically

For every packet:

1. Preserve packet number, timestamp, source/destination MAC and IP when available, UDP ports, UDP length, and raw payload.
2. Determine direction from endpoint and port evidence.
3. Validate magic, command, declared length, actual length, field widths, and byte order.
4. Decode register names, bitfields, signed values, fixed-point values, enum values, and physical units from the selected profile.
5. Retain unknown and reserved bytes in the evidence view.
6. Emit a machine-readable packet record even when decoding fails.

Never allow an invalid length or unknown protocol version to shift later field boundaries silently.

### 5. Group Transactions

Group packets into engineering operations:

- Register write.
- Register read request plus read response.
- Checked write: write followed by readback.
- Retry or timeout sequence.
- Parameter-apply sequence bounded by scan stop/start.
- Mode transition.
- Data upload stream and packet sequence, when the selected profile supports it.

Do not pair a response to a request solely by proximity when address, direction, or timing contradicts the pairing.

### 6. Audit the Session

Apply deterministic checks before AI interpretation:

- Bad magic, command, length, byte order, or field width.
- Unknown, document-only, or unsupported register address.
- Invalid reserved bits, enum values, ranges, or physical units.
- Missing required register writes.
- Extra, duplicate, contradictory, or misordered writes.
- Missing stop-before-configure or start-after-configure boundary.
- Read response address mismatch.
- Write/readback mismatch.
- Unexpected retry, timeout, or missing response.
- Old/new firmware register-map mismatch.
- Expected host plan versus captured packet difference.
- Data packet gap, duplicate, reordering, or frame-length mismatch.

Use these verdicts:

- `FAIL`: captured evidence proves a malformed or behavior-changing mismatch.
- `WARN`: suspicious, ambiguous, document-only, or unverified behavior.
- `PASS`: the checked condition is supported by captured evidence.
- `INFO`: decoded context without an acceptance claim.

Do not label a packet `PASS` merely because it could be decoded.

### 7. Explain with AI

After deterministic auditing:

1. Summarize the highest-impact finding first.
2. Explain the intended operation, captured operation, and exact difference in plain engineering language.
3. Distinguish proven cause from plausible cause.
4. Recommend the smallest next check: host encoder, firmware address map, parameter unit, packet ordering, readback, or capture scope.
5. Avoid modifying RTL or host code unless the user explicitly asks for a fix.

Label inference explicitly, for example:

```text
Inference: the host application may be using an older register map because it writes
0x0205 where the active RTL defines laser_mode_en at 0x020B.
```

## Truth-Preserving Byte Display

Show every control packet with an offset-aligned byte map. Use this exact conceptual structure:

```text
Packet #17  PC -> FPGA  UDP 32000  WRITE

Offset  00 01 02 03 | 04 05 | 06 07 | 08 09 | 10 11 12 13
Raw     55 55 AA AA | 00 01 | 00 06 | 02 07 | 00 00 00 0A
Field   frame header | command| length| address| value
Decode  0x5555AAAA   | WRITE  | 6 B   | 0x0207 | 10
Meaning protocol key | write  | valid | blanker_delay | 50 ns
```

Enforce these presentation rules:

- Display raw bytes exactly as captured, in capture order, using two uppercase hex digits per byte.
- Display offsets starting at UDP payload byte zero unless explicitly labeled otherwise.
- Insert visual separators only between decoded fields; separators are not captured bytes.
- State endianness in the decoded field metadata.
- Show declared length and captured length separately.
- Highlight malformed, extra, missing, or reserved bytes without removing them.
- For large data packets, show the complete protocol header plus a configurable payload head/tail and payload hash; preserve the full bytes in the capture and JSON evidence.
- Never replace raw bytes with a reconstructed packet.

## Report Contract

Always return a concise chat summary. For file-based or live sessions, also generate:

```text
<session>/
├── capture.pcapng          # when a capture exists
├── session.json            # tool, filter, endpoint, hashes, profile
├── packets.json            # exact packet records and decoded fields
├── packets.csv             # review-friendly packet index
├── audit.json              # deterministic findings
├── REPORT.md               # durable text report
└── report.html             # self-contained interactive report
```

The Markdown and HTML reports must contain:

1. Session scope and evidence identity.
2. PASS/WARN/FAIL counts.
3. Findings ordered by severity and impact.
4. Expected-versus-actual command sequence.
5. Packet list with filters for direction, command, register, and verdict.
6. Packet details with the truth-preserving byte display.
7. Raw and decoded values, units, provenance, and confidence.
8. Reproduction command and profile version.
9. Unresolved questions.

Make `report.html` self-contained and usable offline. Do not load JavaScript, fonts, or styles from external CDNs. Escape all capture-derived text before rendering.

## Chat Summary Format

Lead with the outcome:

```text
Captured 38 control packets: 35 PASS, 2 WARN, 1 FAIL.

FAIL packet #17: wrote 0x0205=1. Active RTL defines 0x0205 as sync2_width;
laser_mode_en is 0x020B. Raw bytes: 55 55 AA AA 00 01 00 06 02 05 00 00 00 01.

Report: <clickable REPORT.md and report.html paths>
```

Do not paste every packet into chat when a report contains them. Show the critical packets and preserve the complete session in files.

## Safety and Privacy

- Capture only the requested FPGA traffic.
- Warn when the requested filter may include unrelated hosts or protocols.
- Do not expose unrelated captured payloads in reports.
- Do not replay captures or send synthesized packets.
- Do not claim board behavior from host-to-board writes alone; require readback, response, waveform, or other evidence for board-state claims.
- Keep original captures immutable; place derived files beside them.
- Record SHA-256 hashes for original capture, profile, and generated packet JSON.

## Completion Gate

Before reporting success:

- Confirm that a profile was selected or ambiguity was explicitly reported.
- Confirm that raw byte boundaries and decoded fields agree with packet lengths.
- Confirm that deterministic checks completed without an unreported decoder exception.
- Confirm that each FAIL/WARN points to packet evidence.
- Confirm that report links resolve and that the HTML report is offline/self-contained.
- Confirm that no unrelated traffic was copied into the human-readable report.
- State which checks were not possible, such as absent readback or missing expected plan.

## Example Requests

- “Capture UDP traffic to 192.168.1.8:32000 for 30 seconds and audit the register commands.”
- “Analyze this pcapng and verify whether laser mode was configured correctly.”
- “Decode this payload and show exactly which bytes form the address and value.”
- “Compare this capture with the host-app dry-run JSON and explain every mismatch.”
- “Check whether the host used the V1.4 document map or the active FPGA firmware map.”

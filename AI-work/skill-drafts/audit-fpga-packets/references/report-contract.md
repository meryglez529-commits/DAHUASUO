# Report Contract

Produce `session.json`, `packets.json`, `packets.csv`, `audit.json`, `REPORT.md`,
and `report.html`. Preserve the source capture beside them when live capture is
used.

Every control packet detail must show:

```text
Offset  00 01 02 03 | 04 05 | 06 07 | 08 09 | 10 11 12 13
Raw     55 55 AA AA | 00 01 | 00 06 | 02 07 | 00 00 00 0A
Field   frame header | command| length| address| value
Decode  0x5555AAAA   | WRITE  | 6 B   | 0x0207 | 10
Meaning protocol key | write  | valid | blanker_delay | 50 ns
```

Raw bytes must remain in capture order. Offsets start at UDP payload byte zero.
Field separators are presentation only. State declared and captured lengths
separately.

The HTML report must be self-contained, operate offline, escape capture-derived
text, and provide filters for direction, command, register, and verdict.

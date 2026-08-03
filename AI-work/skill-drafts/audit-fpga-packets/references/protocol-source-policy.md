# Protocol Source Policy

Use this order when protocol sources disagree:

1. Active files referenced by the current FPGA project.
2. Current RTL packet parser and register decoder.
3. Current host encoder and dry-run write plan.
4. Request/response behavior observed in a capture.
5. Firmware-version-matched protocol document.
6. Generic or older protocol documents.

Record provenance on every profile entry. Use `rtl-verified`, `host-verified`,
`capture-observed`, `document-only`, `conflict`, or `unknown`.

For the SGSC 325T V3.172 project, use `sgsc-325t-v3-172.json` by default.
The DB500 V1.4 document is a broader product protocol and contains addresses and
data headers not implemented by this project. Use `db500-v1.4-document.json` only
for document comparison or when the firmware is explicitly identified as that
variant.

Known differences:

- Active RTL uses `0x000F` as `dax_fall_time`; the document also assigns that
  address to DAC output enable in another row.
- Active RTL uses `0x000C[0]` as `remote_rstn`; the document calls the address
  remote-upgrade file length.
- Active RTL uses `0x0205` as sync2 width and `0x020B` as laser-mode enable.
- Active RTL sends legacy 12-byte `AA55AA55` ADC headers and `CC55CC55` line
  packets; DB500 V1.4 documents an extended ADC/RTM header.
- Active top-level ports implement 32000, 32001, and 32004. Ports 32002 and
  32003 are reserved, and 32006 is not routed.

Never silently merge conflicting meanings into one register definition.

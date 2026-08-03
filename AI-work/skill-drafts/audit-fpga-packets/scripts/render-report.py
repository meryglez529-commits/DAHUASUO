from __future__ import annotations

import argparse
from pathlib import Path

from packet_audit_lib import load_json, render_html, render_markdown


def main() -> int:
    parser = argparse.ArgumentParser(description="Render FPGA packet audit Markdown and HTML")
    parser.add_argument("--session", type=Path, required=True)
    parser.add_argument("--packets", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    session, packets, audit = load_json(args.session), load_json(args.packets), load_json(args.audit)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "REPORT.md").write_text(render_markdown(session, packets, audit), encoding="utf-8")
    template = args.template.read_text(encoding="utf-8")
    (args.output / "report.html").write_text(render_html(template, session, packets, audit), encoding="utf-8")
    print(f"report={args.output / 'REPORT.md'} html={args.output / 'report.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

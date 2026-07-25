#!/usr/bin/env python3
"""Build an auditable HTML report from e2e scenario runs.

The step log rides the test's stdout: each `Scenario.report()` prints one
`E2E|...` line per step, which `flutter drive` echoes into its log. That is the
one channel that survives a run (integration_test won't deliver screenshots AND
reportData together, and `flutter drive` wipes app files on teardown). This
script parses those lines out of the drive logs and pairs them with the PNGs
`onScreenshot` wrote to app/test_screenshots/.

Usage:
  scripts/build_e2e_report.py app/test_screenshots/*.drive.log
  # (or pass no args to scan app/test_screenshots/*.drive.log)

Output:
  app/test_screenshots/report.html
"""
import base64
import glob
import html
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "app" / "test_screenshots"

KIND_STYLE = {
    "ui": ("#7dd3fc", "screen"),
    "api": ("#c4b5fd", "api"),
    "assert": ("#86efac", "assert"),
    "peer": ("#fca5a5", "peer"),
}


def parse_logs(paths):
    """Return {scenario_name: [step, ...]} from E2E| lines across all logs."""
    scenarios = {}
    current = None
    for path in paths:
        for raw in Path(path).read_text(errors="replace").splitlines():
            i = raw.find("E2E|")
            if i < 0:
                continue
            parts = raw[i:].split("|", 2)
            if len(parts) < 2:
                continue
            _, tag = parts[0], parts[1]
            payload = parts[2] if len(parts) > 2 else ""
            if tag == "scenario":
                current = payload.strip()
                scenarios.setdefault(current, [])
            elif tag == "step" and current is not None:
                try:
                    scenarios[current].append(json.loads(payload))
                except json.JSONDecodeError:
                    pass
            elif tag == "end":
                current = None
    return scenarios


def _img_data_uri(png: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(png.read_bytes()).decode()


def _section(name, steps) -> str:
    rows = []
    for st in steps:
        color, label = KIND_STYLE.get(st.get("kind", "ui"), ("#94a3b8", "step"))
        title = html.escape(st.get("title", ""))
        note = html.escape(st.get("note") or "")
        shot = st.get("shot")
        img = ""
        if shot:
            p = SHOTS / shot
            if p.exists():
                uri = _img_data_uri(p)
                img = f'<a href="{uri}" target="_blank"><img src="{uri}" alt="{title}"></a>'
            else:
                img = f'<div class="missing">missing screenshot: {html.escape(shot)}</div>'
        rows.append(f"""
      <div class="step">
        <div class="meta">
          <span class="idx">{st.get('index', ''):>2}</span>
          <span class="tag" style="--tag:{color}">{label}</span>
          <span class="title">{title}</span>
        </div>
        {f'<p class="note">{note}</p>' if note else ''}
        {f'<div class="shot">{img}</div>' if img else ''}
      </div>""")
    return f"""
    <section>
      <h2>{html.escape(name)} <span class="count">{len(steps)} steps</span></h2>
      <div class="steps">{''.join(rows)}</div>
    </section>"""


def main(argv) -> int:
    paths = argv[1:] or sorted(glob.glob(str(SHOTS / "*.drive.log")))
    scenarios = parse_logs(paths) if paths else {}
    sections = [_section(n, s) for n, s in scenarios.items()]

    out = SHOTS / "report.html"
    out.write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lift — e2e scenarios</title>
<style>
  :root {{ color-scheme: dark; --bg:#0b0f14; --panel:#111827; --ink:#e5e7eb; --dim:#94a3b8; --line:#1f2937; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.55 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }}
  header {{ padding:28px 32px; border-bottom:1px solid var(--line); }}
  h1 {{ margin:0; font-size:20px; letter-spacing:.02em; }}
  header p {{ margin:6px 0 0; color:var(--dim); }}
  main {{ padding:24px 32px; display:flex; flex-direction:column; gap:40px; max-width:1200px; }}
  section h2 {{ font-size:16px; margin:0 0 14px; padding-bottom:8px; border-bottom:1px solid var(--line);
    color:#fff; letter-spacing:.01em; display:flex; align-items:baseline; gap:10px; }}
  .count {{ font-size:12px; color:var(--dim); font-weight:400; }}
  .steps {{ display:flex; flex-direction:column; gap:18px; }}
  .step {{ background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:14px 16px; }}
  .meta {{ display:flex; align-items:center; gap:10px; }}
  .idx {{ font-variant-numeric:tabular-nums; color:var(--dim); font-size:13px; }}
  .tag {{ font-size:11px; text-transform:uppercase; letter-spacing:.06em; color:#0b0f14;
    background:var(--tag); padding:2px 8px; border-radius:999px; font-weight:600; }}
  .title {{ font-weight:600; }}
  .note {{ margin:8px 0 0; color:var(--dim); }}
  .shot {{ margin-top:12px; }}
  .shot img {{ max-width:300px; width:100%; border:1px solid var(--line); border-radius:8px; display:block; }}
  .missing {{ color:#fca5a5; font-size:13px; }}
</style></head>
<body>
  <header>
    <h1>Lift — end-to-end scenarios</h1>
    <p>{len(sections)} scenario(s), captured on the Android emulator against the real backend.</p>
  </header>
  <main>{''.join(sections) if sections else '<p class=note>No scenarios captured.</p>'}</main>
</body></html>""")
    print(f"wrote {out} ({len(sections)} scenarios, "
          f"{sum(len(s) for s in scenarios.values())} steps)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

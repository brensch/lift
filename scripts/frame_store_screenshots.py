#!/usr/bin/env python3
"""Turn raw app screenshots into store-ready marketing images.

Reads store/listing.yaml for the slide order and captions, takes the raw
captures from store/screenshots/raw/, and renders one framed image per slide
per store size with an HTML template in headless Chromium (Playwright):

    store/screenshots/out/play/phone/NN.png        1080 x 1920  (9:16)
    store/screenshots/out/appstore/iphone/NN.png   1320 x 2868  (6.9")
    store/screenshots/out/play/wear/NN.png         raw Wear OS capture, as is
    store/screenshots/out/appstore/watch/NN.png    raw Apple Watch capture, as is

Also writes store/screenshots/out/contact-sheet.html to eyeball everything.

    pip install playwright pyyaml && python3 -m playwright install chromium
    python3 scripts/frame_store_screenshots.py
"""

from __future__ import annotations

import base64
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "store" / "listing.yaml"
RAW = ROOT / "store" / "screenshots" / "raw"
OUT = ROOT / "store" / "screenshots" / "out"
FONTS = ROOT / "app" / "assets" / "google_fonts"


@dataclass(frozen=True)
class Target:
    store: str
    kind: str
    width: int
    height: int


TARGETS = [
    Target("play", "phone", 1080, 1920),
    Target("appstore", "iphone", 1320, 2868),
]

# Brand: the app's dark theme with its green and blue accents.
BG = "#0A0A0B"
PANEL = "#161619"
GREEN = "#3AD98B"
BLUE = "#6EA8FF"
TEXT = "#FAFAFA"
MUTED = "#9A9AA3"


def font_face(name: str, file: str, weight: int) -> str:
    data = base64.b64encode((FONTS / file).read_bytes()).decode()
    return (
        f"@font-face {{ font-family: '{name}'; font-weight: {weight}; "
        f"src: url(data:font/ttf;base64,{data}) format('truetype'); }}"
    )


def png_size(path: Path) -> tuple[int, int]:
    head = path.read_bytes()[:24]
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


# Pixels of the raw capture to drop from the top: the emulator's empty status
# bar band, which would read as a huge forehead inside the frame.
CROP_TOP = 72


def page_html(target: Target, raw_png: Path, title: str, subtitle: str, index: int) -> str:
    shot = base64.b64encode(raw_png.read_bytes()).decode()
    raw_w, raw_h = png_size(raw_png)
    w, h = target.width, target.height
    # Everything scales off the canvas width so both sizes share one design.
    u = w / 1080
    title_px = int(84 * u)
    sub_px = int(36 * u)
    caption_top = int(150 * u)
    phone_top = caption_top + title_px + int(sub_px * 1.35 * 2) + int(70 * u)
    # The phone fills the height left under the caption, bleeding 2% off the
    # bottom so its lower corners are hidden, and never wider than 84%.
    visible_aspect = (raw_h - CROP_TOP) / raw_w
    phone_w = min(int(w * 0.84), int((h * 1.02 - phone_top) / visible_aspect))
    scale = phone_w / raw_w
    radius = int(88 * u * (phone_w / (1080 * 0.80)))
    accent = GREEN if index % 2 == 0 else BLUE
    return f"""<!doctype html>
<html><head><meta charset="utf-8">
<style>
{font_face('Space Grotesk', 'SpaceGrotesk-Bold.ttf', 700)}
{font_face('Manrope', 'Manrope-Regular.ttf', 400)}
html, body {{ margin: 0; width: {w}px; height: {h}px; overflow: hidden; background: {BG}; }}
body {{
  position: relative; font-family: 'Manrope', sans-serif; color: {TEXT};
  background:
    radial-gradient(ellipse {int(w*0.9)}px {int(h*0.45)}px at 50% {int(h*0.28)}px, {accent}26 0%, transparent 70%),
    radial-gradient(ellipse {int(w*0.7)}px {int(h*0.3)}px at 50% {int(h*0.9)}px, {accent}1A 0%, transparent 70%),
    linear-gradient(180deg, {BG} 0%, #0E0E10 100%);
}}
.caption {{
  position: absolute; left: {int(48*u)}px; right: {int(48*u)}px; top: {caption_top}px; text-align: center;
}}
.title {{
  font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: {title_px}px; line-height: 1.05;
  letter-spacing: -0.02em; margin: 0;
}}
.subtitle {{
  font-size: {sub_px}px; line-height: 1.35; color: {MUTED}; margin: {int(24*u)}px auto 0; max-width: {int(w*0.9)}px;
}}
.phone {{
  position: absolute; left: 50%; transform: translateX(-50%);
  top: {phone_top}px; width: {phone_w}px; height: {int((raw_h - CROP_TOP) * scale)}px;
  border-radius: {radius}px; overflow: hidden; background: {PANEL};
  box-shadow: 0 {int(40*u)}px {int(120*u)}px rgba(0,0,0,0.65), 0 0 0 {int(3*u)}px rgba(255,255,255,0.06);
}}
.phone img {{ display: block; width: {phone_w}px; height: auto; margin-top: -{int(CROP_TOP * scale)}px; }}
</style></head>
<body>
  <div class="caption">
    <h1 class="title">{title}</h1>
    <div class="subtitle">{subtitle}</div>
  </div>
  <div class="phone"><img src="data:image/png;base64,{shot}"></div>
</body></html>"""


def render_all() -> list[Path]:
    listing = yaml.safe_load(LISTING.read_text(encoding="utf-8"))
    slides = listing.get("screenshots") or []
    if not slides:
        raise SystemExit("store/listing.yaml has no screenshots")
    for target in TARGETS:
        shutil.rmtree(OUT / target.store / target.kind, ignore_errors=True)
        (OUT / target.store / target.kind).mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for target in TARGETS:
            page = browser.new_page(viewport={"width": target.width, "height": target.height}, device_scale_factor=1)
            for i, slide in enumerate(slides):
                raw = RAW / slide["file"]
                if not raw.is_file():
                    raise SystemExit(f"missing raw screenshot {raw}")
                page.set_content(page_html(target, raw, slide["title"], slide.get("subtitle", ""), i))
                page.wait_for_load_state("networkidle")
                out = OUT / target.store / target.kind / f"{i:02d}.png"
                page.screenshot(path=str(out), full_page=False)
                written.append(out)
                print(f"wrote {out.relative_to(ROOT)} ({target.width}x{target.height}) — {slide['title']}")
            page.close()
        browser.close()

    # Watch captures go up unframed at their native, store-accepted sizes.
    for key, store, kind in (("wear_screenshots", "play", "wear"), ("apple_watch_screenshots", "appstore", "watch")):
        dest = OUT / store / kind
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)
        for i, shot in enumerate(listing.get(key) or []):
            src = RAW / shot["file"]
            if not src.is_file():
                raise SystemExit(f"missing raw screenshot {src}")
            out = dest / f"{i:02d}.png"
            shutil.copyfile(src, out)
            written.append(out)
            print(f"copied {out.relative_to(ROOT)}")

    sheet = OUT / "contact-sheet.html"
    cells = "".join(
        f'<figure><img src="{p.relative_to(OUT)}"><figcaption>{p.relative_to(OUT)}</figcaption></figure>'
        for p in written
    )
    sheet.write_text(
        "<!doctype html><meta charset=utf-8><style>body{background:#222;color:#ddd;font:14px sans-serif;margin:16px}"
        "figure{display:inline-block;margin:8px;text-align:center}img{height:520px;display:block;border:1px solid #444}"
        f"</style><h1>Store screenshots</h1>{cells}",
        encoding="utf-8",
    )
    print(f"contact sheet: {sheet.relative_to(ROOT)}")
    return written


if __name__ == "__main__":
    try:
        render_all()
    except KeyboardInterrupt:
        sys.exit(130)

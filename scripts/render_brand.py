#!/usr/bin/env python3
"""Render the brand masters: the app icon and the Play feature graphic.

Both are SVG built here in the app's own palette and faces (Space Mono Bold,
Space Grotesk Medium; see app/lib/theme/schlift_spec.dart) and rendered
pixel-exact by headless Chromium, so a change to a shape or a colour is a
diff, not a design-tool export.

    python3 scripts/render_brand.py

Outputs:
    marketing/icon.png              1024 x 1024, full bleed
    marketing/feature_graphic.png   1024 x 500

The icon goes onto every platform with `make icons`.
The feature graphic is pushed to Play by store-assets.yml.
"""

from __future__ import annotations

import base64
from html import escape
from pathlib import Path

import yaml
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "app" / "assets" / "google_fonts"
ICON = ROOT / "marketing" / "icon.png"
FEATURE = ROOT / "marketing" / "feature_graphic.png"
LISTING = ROOT / "store" / "listing.yaml"

# The app's palette.
GROUND = "#DBDAD2"
PANEL = "#EDECE5"
HAIRLINE = "#B7B6AC"
OUTLINE = "#74746E"
INK = "#111111"
MUTED = "#4A4A44"
SIGNAL = "#FF4F00"
EFFORT = "#D99A00"
# The icon's divider, and the band's drained part: the orange at 40% over the ground.
LINE = "#9C9B93"
DRAINED = "#E9A27E"

MONO = "font-family:'Space Mono';font-weight:700"
GROTESK = "font-family:'Space Grotesk';font-weight:500"


def font_css() -> str:
    def face(name: str, file: str, weight: int) -> str:
        data = base64.b64encode((FONTS / file).read_bytes()).decode()
        src = f"url(data:font/ttf;base64,{data}) format('truetype')"
        return f"@font-face{{font-family:'{name}';font-weight:{weight};src:{src};}}"

    return face("Space Mono", "SpaceMono-Bold.ttf", 700) + face(
        "Space Grotesk", "SpaceGrotesk-Medium.ttf", 500
    )


def page(width: int, height: int, svg_body: str) -> str:
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_css()}
html,body{{margin:0;width:{width}px;height:{height}px;overflow:hidden}}
svg{{display:block}}</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}"
 viewBox="0 0 {width} {height}">
{svg_body}
</svg></body></html>"""


# The icon, on a 100 grid: the end of a loaded bar, its plates climbing
# toward the middle of the bar, which runs off the right edge. From the end
# inwards: (x, width, height, colour). The collar, a change plate, a plate
# in the signal orange, two 45s. Each reaches a hair under the heavier one
# after it, which is drawn over it: two shapes that only meet leave a faint
# line of the ground between them when the icon is scaled.
ICON_PLATES = (
    (22, 5, 18, INK),
    (26.7, 7.3, 30, INK),
    (33.7, 9.3, 54, SIGNAL),
    (42.7, 10.3, 70, INK),
    (52.7, 10.3, 70, INK),
)


def icon() -> str:
    """The end of a loaded barbell, side on, in ink on the ground: the plates
    step up toward the middle like a chart going up, one of them orange, and
    the bar runs on off the edge. Drawn on a 100 grid."""
    plates = "".join(
        f'<rect x="{x:g}" y="{50 - height / 2:g}" width="{width:g}" height="{height:g}" '
        f'rx="1.5" fill="{fill}"/>'
        for x, width, height, fill in ICON_PLATES
    )
    return f"""<g transform="scale(10.24)">
<rect width="100" height="100" fill="{GROUND}"/>
<rect x="14" y="47" width="52" height="6" rx="1" fill="{INK}"/>
<rect x="60" y="48" width="40" height="4" fill="{INK}"/>
{plates}</g>"""


# The wordmark's wobble, frozen: one fixed tilt and nudge per letter.
WOBBLE_DEG = (-3, 2, -1.5, 2.5, -2, 1.5, -1)
WOBBLE_DY = (0, -0.035, 0.02, -0.02, 0.03, -0.012, 0.022)


def wordmark(x: float, y: float, size: float, fill: str) -> str:
    advance = size * 0.62
    letters = []
    for i, ch in enumerate("SCHLIFT"):
        cx = x + i * advance + advance / 2
        cy = y + WOBBLE_DY[i] * size
        pivot = f"{cx:.1f} {cy - size * 0.35:.1f}"
        letters.append(
            f'<text x="{cx:.1f}" y="{cy:.1f}" style="{MONO};font-size:{size}px" fill="{fill}" '
            f'text-anchor="middle" transform="rotate({WOBBLE_DEG[i]} {pivot})">'
            f"{ch}</text>"
        )
    return "".join(letters)


def set_circle(kind: str, cx: float, cy: float, r: float, reps: str) -> str:
    """One of the app's set circles, as the status box draws it."""
    look = {
        "done": (INK, None, PANEL),
        "short": (EFFORT, None, INK),
        "lifting": (SIGNAL, None, INK),
        "to_go": ("none", OUTLINE, MUTED),
    }
    fill, ring, ink = look[kind]
    stroke = f' stroke="{ring}" stroke-width="2"' if ring else ""
    radius = r - 1 if ring else r
    return (
        f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{radius:.1f}" fill="{fill}"{stroke}/>'
        f'<text x="{cx:.1f}" y="{cy + 1:.1f}" style="{MONO};font-size:{r * 0.95:.1f}px" '
        f'fill="{ink}" text-anchor="middle" dominant-baseline="central">{reps}</text>'
    )


def feature_graphic() -> str:
    """The app's status box blown up: the name and the listing's tagline over
    a strip of set circles, then the orange LIFTING band with its clock."""
    tagline = yaml.safe_load(LISTING.read_text(encoding="utf-8"))["tagline"]
    band_h, strip_h = 118, 96
    band_y = 500 - band_h
    strip_y = band_y - strip_h
    r = strip_h / 3
    gap = r * 0.62
    sets = [("done", "5"), ("done", "5"), ("short", "4"), ("lifting", "5"), ("to_go", "5")]
    circles = "".join(
        set_circle(kind, 60 + r + i * (2 * r + gap), strip_y + strip_h / 2, r, reps)
        for i, (kind, reps) in enumerate(sets)
    )
    word_size = 115
    word_y = (strip_y - 1) / 2 - 22 + word_size * 0.33 + 12
    band_mid = band_y + band_h / 2 + 1
    centred = 'dominant-baseline="central"'
    return f"""<rect width="1024" height="500" fill="{GROUND}"/>
{wordmark(52, word_y, word_size, INK)}
<text x="60" y="{word_y + 52:.1f}" style="{GROTESK};font-size:30px" fill="{MUTED}"
>{escape(tagline)}</text>
<rect y="{strip_y - 1}" width="1024" height="1" fill="{HAIRLINE}"/>
<rect y="{strip_y}" width="1024" height="{strip_h}" fill="{PANEL}"/>
{circles}
<rect y="{band_y - 1}" width="1024" height="1" fill="{HAIRLINE}"/>
<rect y="{band_y}" width="1024" height="{band_h}" fill="{SIGNAL}"/>
<text x="60" y="{band_mid:.1f}" style="{MONO};font-size:40px;letter-spacing:1px" fill="{INK}"
 {centred}>LIFTING</text>
<text x="964" y="{band_mid + 2:.1f}" style="{MONO};font-size:85px" fill="{INK}" text-anchor="end"
 {centred}>0:42</text>"""


def render() -> list[Path]:
    jobs = [(ICON, 1024, 1024, icon()), (FEATURE, 1024, 500, feature_graphic())]
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for out, width, height, body in jobs:
            pg = browser.new_page(
                viewport={"width": width, "height": height}, device_scale_factor=1
            )
            pg.set_content(page(width, height, body))
            pg.wait_for_load_state("networkidle")
            pg.evaluate("document.fonts.ready")
            pg.screenshot(path=str(out))
            pg.close()
            print(f"wrote {out.relative_to(ROOT)}")
        browser.close()
    return [job[0] for job in jobs]


if __name__ == "__main__":
    render()

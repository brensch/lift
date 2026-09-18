#!/usr/bin/env python3
"""Render the brand assets: app icon concepts and Play feature graphics.

Every asset is an SVG built here, typeset in the app's own faces (Space
Grotesk Bold, Manrope) and rendered pixel-exact by headless Chromium, so a
change to a shape or a colour is a diff, not a Figma export.

    python3 scripts/render_brand.py            # everything
    python3 scripts/render_brand.py --only icons

Outputs:
    marketing/icons/candidates/<name>.png          1024 x 1024, full bleed
    marketing/feature_graphic_candidates/<name>.png 1024 x 500
    marketing/brand-preview.html                    contact sheet

The chosen icon becomes the app icon with scripts/replace_app_icons.py
--source marketing/icons/candidates/<name>.png; the chosen feature graphic
is copied to marketing/feature_graphic.png. Both are pushed by store-assets.yml.
"""

from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path

import yaml
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "app" / "assets" / "google_fonts"
ICONS = ROOT / "marketing" / "icons" / "candidates"
FEATURES = ROOT / "marketing" / "feature_graphic_candidates"

# The app's palette. Near-black ground, off-white ink, one accent at a time.
BG = "#0A0A0B"
INK = "#FAFAFA"
GREEN = "#3AD98B"
BLUE = "#6EA8FF"
PINK = "#EC4899"
MUTED = "#6F6F78"


def font_css() -> str:
    def face(name: str, file: str, weight: int) -> str:
        data = base64.b64encode((FONTS / file).read_bytes()).decode()
        src = f"url(data:font/ttf;base64,{data}) format('truetype')"
        return f"@font-face{{font-family:'{name}';font-weight:{weight};src:{src};}}"

    return face("Space Grotesk", "SpaceGrotesk-Bold.ttf", 700) + face(
        "Manrope", "Manrope-Regular.ttf", 400
    )


def page(width: int, height: int, svg_body: str) -> str:
    view_box = f"0 0 {width} {height}"
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_css()}
html,body{{margin:0;width:{width}px;height:{height}px;overflow:hidden;background:{BG}}}
svg{{display:block}}</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{view_box}">
<rect width="{width}" height="{height}" fill="{BG}"/>
{svg_body}
</svg></body></html>"""


GROTESK = "font-family:'Space Grotesk';font-weight:700"
MANROPE = "font-family:'Manrope';font-weight:400"

# ── Icon concepts (1024 canvas) ───────────────────────────────────────────
# Keep the subject inside the middle ~72% so iOS's corner mask and Android's
# adaptive circle both leave it whole.


def icon_plate() -> str:
    """One weight plate. The most literal thing a gym app can be, done clean."""
    return f"""
<circle cx="512" cy="512" r="330" fill="{INK}"/>
<circle cx="512" cy="512" r="238" fill="none" stroke="{BG}" stroke-width="10"/>
<circle cx="512" cy="512" r="78" fill="{BG}"/>
<circle cx="512" cy="512" r="78" fill="none" stroke="{GREEN}" stroke-width="22"/>"""


def icon_bar_s() -> str:
    """The S of Schlift bent out of a barbell: a fat S stroke with a plate on each end."""
    return f"""
<g fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="M 690 300 C 690 170 330 150 330 310 C 330 470 700 450 700 640 C 700 820 330 860 330 700"
        stroke="{INK}" stroke-width="118"/>
</g>
<g fill="{GREEN}">
  <rect x="632" y="238" width="120" height="76" rx="22" transform="rotate(-8 692 276)"/>
  <rect x="272" y="710" width="120" height="76" rx="22" transform="rotate(-8 332 748)"/>
</g>"""


def icon_big_s() -> str:
    """The wordmark's S, oversized and cropped. Green so it reads at 40px."""
    style = f"{GROTESK};font-size:1080px"
    return f"""
<text x="512" y="900" text-anchor="middle" style="{style}" fill="{GREEN}">S</text>"""


def icon_set_dots() -> str:
    """The app's own set-progress dots: three done, one live."""
    r = 66
    xs = [206, 410, 614, 818]
    dots = "".join(
        f'<circle cx="{x}" cy="512" r="{r}" fill="{INK if i < 3 else GREEN}"/>'
        for i, x in enumerate(xs)
    )
    return dots


def icon_bolt_bell() -> str:
    """A barbell at 35 degrees. Squint and it's a lightning bolt."""
    return f"""
<g transform="rotate(-35 512 512)">
  <rect x="242" y="478" width="540" height="68" rx="34" fill="{GREEN}"/>
  <rect x="172" y="372" width="96" height="280" rx="30" fill="{INK}"/>
  <rect x="756" y="372" width="96" height="280" rx="30" fill="{INK}"/>
</g>"""


def icon_rest_arc() -> str:
    """The rest timer: most of a ring, and the moment it runs out."""
    stroke = f'stroke="{GREEN}" stroke-width="96" stroke-linecap="round"'
    return f"""
<path d="M 512 182 A 330 330 0 1 1 279 279" fill="none" {stroke}/>
<circle cx="512" cy="512" r="72" fill="{INK}"/>"""


def icon_plate_yap() -> str:
    """A plate, and someone yapping at it. The app's 'Yapping' state, made a mascot."""
    bubble = (
        "M 560 220 h 270 a 56 56 0 0 1 56 56 v 120 a 56 56 0 0 1 -56 56 h -150 l -80 74 v -74 "
        "h -40 a 56 56 0 0 1 -56 -56 v -120 a 56 56 0 0 1 56 -56 z"
    )
    dots = "".join(f'<circle cx="{cx}" cy="336" r="20" fill="{BG}"/>' for cx in (636, 700, 764))
    return f"""
<circle cx="440" cy="590" r="270" fill="{INK}"/>
<circle cx="440" cy="590" r="64" fill="{BG}"/>
<path d="{bubble}" fill="{PINK}"/>
{dots}"""


def icon_plus_five() -> str:
    """+5. What the app says after a good day."""
    style = f"{GROTESK};font-size:600px;letter-spacing:-40px"
    five = f'<tspan fill="{GREEN}">5</tspan>'
    return f"""
<text x="500" y="720" text-anchor="middle" style="{style}" fill="{INK}">+{five}</text>"""


ICON_CONCEPTS = {
    "plate": icon_plate,
    "bar-s": icon_bar_s,
    "big-s": icon_big_s,
    "set-dots": icon_set_dots,
    "bolt-bell": icon_bolt_bell,
    "rest-arc": icon_rest_arc,
    "plate-yap": icon_plate_yap,
    "plus-five": icon_plus_five,
}

# ── Feature graphics (1024 x 500) ─────────────────────────────────────────
# Play overlays a play button in the centre when there's a video and crops
# the edges on some surfaces, so the message lives off-centre but not at
# the very edge.


def wordmark(x: int, y: int, size: int, fill: str = INK, anchor: str = "start") -> str:
    style = f"{GROTESK};font-size:{size}px;letter-spacing:-0.03em"
    return (
        f'<text x="{x}" y="{y}" text-anchor="{anchor}" style="{style}" fill="{fill}">SCHLIFT</text>'
    )


def feature_wordmark_bar() -> str:
    """The name, huge, with a barbell standing in for the I. The barbell is
    placed by measuring the glyphs in the page, not by guessing."""
    glow = (
        f'<stop offset="0" stop-color="{GREEN}" stop-opacity="0.22"/>'
        f'<stop offset="1" stop-color="{GREEN}" stop-opacity="0"/>'
    )
    tag_style = f"{MANROPE};font-size:26px;letter-spacing:0.18em"
    big = f"{GROTESK};font-size:250px;letter-spacing:-0.04em"
    place_stem = (
        "stem.setAttribute('x', cx - 12); stem.setAttribute('y', capTop + 14); "
        "stem.setAttribute('height', base - capTop - 28);"
    )
    return f"""
<defs><radialGradient id="g" cx="20%" cy="110%" r="70%">{glow}</radialGradient></defs>
<rect width="1024" height="500" fill="url(#g)"/>
<text x="64" y="112" style="{tag_style}" fill="{MUTED}">WORKOUTS THAT GROW WITH YOU</text>
<text id="left" x="56" y="400" style="{big}" fill="{INK}">SCHL</text>
<text id="i" x="0" y="400" style="{big}" fill="{INK}" opacity="0">I</text>
<text id="right" x="0" y="400" style="{big}" fill="{INK}">FT</text>
<g id="bar">
  <rect id="stem" width="24" rx="12" fill="{GREEN}"/>
  <rect id="top" height="26" rx="10" fill="{INK}"/>
  <rect id="bottom" height="26" rx="10" fill="{INK}"/>
</g>
<script>
document.fonts.ready.then(() => {{
  const left = document.getElementById('left').getBBox();
  const i = document.getElementById('i');
  const gap = 22;
  i.setAttribute('x', left.x + left.width + gap);
  const ib = i.getBBox();
  document.getElementById('right').setAttribute('x', ib.x + ib.width + gap);
  // Cap height of the I: from the baseline up to the top of the glyph box.
  const capTop = 400 - 250 * 0.70, base = 400;
  const cx = ib.x + ib.width / 2;
  const stem = document.getElementById('stem');
  {place_stem}
  for (const [id, y] of [['top', capTop], ['bottom', base - 26]]) {{
    const r = document.getElementById(id);
    r.setAttribute('x', cx - 36); r.setAttribute('y', y); r.setAttribute('width', 72);
  }}
  window.__laid_out = true;
}});
</script>"""


def listing_text(key: str, default: str) -> str:
    """Copy comes from store/listing.yaml so every word on a store asset is edited in one file."""
    listing = yaml.safe_load((ROOT / "store" / "listing.yaml").read_text(encoding="utf-8")) or {}
    return str(listing.get(key) or default).strip()


def barbell(x: float, top: float, height: float, fill: str) -> str:
    """The app icon's barbell, drawn on its own 108-unit grid (see
    scripts/replace_app_icons.py) and scaled so the plates span `height`."""
    k = height / 42.0  # plates run from unit 33 to 75

    def r(u0, v0, u1, v1, rx=0.0):
        left, upper = x + (u0 - 14) * k, top + (v0 - 33) * k
        w, h = (u1 - u0) * k, (v1 - v0) * k
        return (
            f'<rect x="{left:.1f}" y="{upper:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'rx="{rx * k:.1f}" fill="{fill}"/>'
        )

    # The bar runs on under the inner plates so the joins are solid ink, not
    # two anti-aliased edges meeting.
    parts = [
        r(30, 50, 78, 58),
        r(14, 33, 20, 75, 1.2),
        r(21, 33, 27, 75, 1.2),
        r(28, 33, 34, 75, 1.2),
        r(74, 33, 80, 75, 1.2),
        r(81, 33, 87, 75, 1.2),
        r(88, 33, 94, 75, 1.2),
    ]
    return "".join(parts)


def feature_staircase() -> str:
    """The progress chart as the identity: a staircase climbing across the
    frame, the icon's barbell, and the wordmark set the way the app sets it:
    each letter nudged and tilted by a seeded random (WobblyText), a touch
    more than on screen so it reads in a still image."""
    pts = [
        (0, 400),
        (150, 400),
        (190, 350),
        (330, 350),
        (370, 300),
        (540, 300),
        (580, 245),
        (720, 245),
        (760, 180),
        (900, 180),
        (940, 120),
        (1024, 120),
    ]
    d = "M " + " L ".join(f"{x} {y}" for x, y in pts)
    area = d + " L 1024 500 L 0 500 Z"
    # Wordmark: 112px Space Grotesk Bold, baseline 160, caps ~78px tall. The
    # barbell is sized to the cap height and sits on the same baseline, so
    # glyph and letters read as one line.
    cap_h, baseline = 78, 160
    bar_w = 80 * (cap_h / 42.0)
    text_x = 64 + bar_w + 30
    byline = listing_text("tagline", "The best way to Schlift.")
    fade = (
        f'<stop offset="0" stop-color="{GREEN}" stop-opacity="0.28"/>'
        f'<stop offset="1" stop-color="{GREEN}" stop-opacity="0"/>'
    )
    stroke = f'stroke="{GREEN}" stroke-width="10" stroke-linejoin="round" stroke-linecap="round"'
    mark_style = f"{GROTESK};font-size:112px;letter-spacing:-0.03em"
    sub_style = f"{MANROPE};font-size:30px"
    lcg = "seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296;"
    return f"""
<defs>
  <linearGradient id="a" x1="0" y1="0" x2="0" y2="1">{fade}</linearGradient>
</defs>
<path d="{area}" fill="url(#a)"/>
<path d="{d}" fill="none" {stroke}/>
{barbell(64, baseline - cap_h, cap_h, INK)}
<text id="measure" x="{text_x:.0f}" y="{baseline}" style="{mark_style}" fill="none">SCHLIFT</text>
<g id="wordmark"></g>
<text x="{text_x + 4:.0f}" y="{baseline + 56}" style="{sub_style}" fill="{MUTED}">{byline}</text>
<script>
document.fonts.ready.then(() => {{
  // Same idea as the app's WobblyText: one seeded random, one nudge and one
  // tilt per letter. Amplitudes scaled for a 112px wordmark in a still.
  let seed = 42;
  const rnd = () => {{ {lcg} }};
  const m = document.getElementById('measure');
  const g = document.getElementById('wordmark');
  const word = 'SCHLIFT';
  const ns = 'http://www.w3.org/2000/svg';
  for (let i = 0; i < word.length; i++) {{
    const p = m.getStartPositionOfChar(i);
    const dx = (rnd() * 2 - 1) * 3.5, dy = (rnd() * 2 - 1) * 4;
    const deg = (rnd() * 2 - 1) * 2.4;
    const ext = m.getExtentOfChar(i);
    const cx = ext.x + ext.width / 2, cy = {baseline} - {cap_h} / 2;
    const t = document.createElementNS(ns, 'text');
    t.setAttribute('x', p.x); t.setAttribute('y', {baseline});
    t.setAttribute('style', "{mark_style}");
    t.setAttribute('fill', '{INK}');
    t.setAttribute('transform', `translate(${{dx}} ${{dy}}) rotate(${{deg}} ${{cx}} ${{cy}})`);
    t.textContent = word[i];
    g.appendChild(t);
  }}
  window.__laid_out = true;
}});
</script>"""


def feature_dont_tell_me() -> str:
    """The app's own line, said plainly. Cheeky, and true to how it works."""
    line_style = f"{GROTESK};font-size:118px;letter-spacing:-0.03em"
    full_stop = f'<tspan fill="{GREEN}">.</tspan>'
    return f"""
<text x="64" y="205" style="{line_style}" fill="{INK}">Don't tell me</text>
<text x="64" y="330" style="{line_style}" fill="{INK}">what to do{full_stop}</text>
<g transform="translate(64 400)">
  <rect x="0" y="12" width="150" height="14" rx="7" fill="{GREEN}"/>
  <rect x="-8" y="-6" width="22" height="50" rx="7" fill="{INK}"/>
  <rect x="136" y="-6" width="22" height="50" rx="7" fill="{INK}"/>
</g>
{wordmark(960, 440, 44, MUTED, "end")}"""


def feature_big_s() -> str:
    """The green S from the icon, cropped hard on the left, the name beside it."""
    sub_style = f"{MANROPE};font-size:30px"
    done = "".join(f'<circle cx="{cx}" cy="392" r="10"/>' for cx in (446, 486, 526))
    live = f'<circle cx="566" cy="392" r="10" fill="{GREEN}"/>'
    return f"""
<text x="-60" y="470" style="{GROTESK};font-size:640px" fill="{GREEN}">S</text>
{wordmark(430, 262, 128)}
<text x="434" y="322" style="{sub_style}" fill="{MUTED}">Compose it. Lift it. Watch it climb.</text>
<g fill="{INK}">{done}</g>{live}"""


FEATURE_CONCEPTS = {
    "wordmark-bar": feature_wordmark_bar,
    "staircase": feature_staircase,
    "dont-tell-me": feature_dont_tell_me,
    "big-s": feature_big_s,
}


def render(only: str | None) -> list[Path]:
    written: list[Path] = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        if only in (None, "icons"):
            ICONS.mkdir(parents=True, exist_ok=True)
            pg = browser.new_page(viewport={"width": 1024, "height": 1024}, device_scale_factor=1)
            for name, fn in ICON_CONCEPTS.items():
                pg.set_content(page(1024, 1024, fn()))
                pg.wait_for_load_state("networkidle")
                out = ICONS / f"{name}.png"
                pg.screenshot(path=str(out))
                written.append(out)
                print(f"icon     {out.relative_to(ROOT)}")
            pg.close()
        if only in (None, "features"):
            FEATURES.mkdir(parents=True, exist_ok=True)
            pg = browser.new_page(viewport={"width": 1024, "height": 500}, device_scale_factor=1)
            for name, fn in FEATURE_CONCEPTS.items():
                body = fn()
                pg.set_content(page(1024, 500, body))
                pg.wait_for_load_state("networkidle")
                if "<script>" in body:
                    pg.wait_for_function("window.__laid_out === true")
                out = FEATURES / f"{name}.png"
                pg.screenshot(path=str(out))
                written.append(out)
                print(f"feature  {out.relative_to(ROOT)}")
            pg.close()
        browser.close()
    return written


if __name__ == "__main__":
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--only", choices=["icons", "features"], default=None)
    args = ap.parse_args()
    try:
        render(args.only)
    except KeyboardInterrupt:
        sys.exit(130)

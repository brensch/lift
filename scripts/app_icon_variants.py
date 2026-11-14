#!/usr/bin/env python3
"""The app icon in each stage's colour, for the phone apps' "App icon" setting.

  python3 scripts/app_icon_variants.py

The icon (scripts/render_brand.py: `icon`) has one plate in the signal
orange. Each variant here is the same icon with that plate in another stage's
colour (app/lib/theme/schlift_spec.dart: lifting, resting, yapping); the
orange one is the default icon and is not made here. For every variant it
writes

  Android  res/mipmap-*/ic_launcher_<name>.png        the legacy icon
           res/drawable-*/ic_launcher_foreground_<name>.png
           res/mipmap-anydpi-v26/ic_launcher_<name>.xml   the adaptive icon
  iOS      Assets.xcassets/AppIcon<Name>.appiconset/  an alternate icon set

The Android manifest's activity-aliases and the Xcode project's
ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES name these and are kept by
hand: a new variant needs an alias there and a name there, and an entry in
app/lib/services/app_icon.dart.

The geometry is render_brand.py's, drawn here with Pillow (that script needs
a browser); change the icon there and here together.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw
from replace_app_icons import ADAPTIVE_DENSITIES, adaptive_foreground

ROOT = Path(__file__).resolve().parent.parent
ANDROID_RES = ROOT / "app/android/app/src/main/res"
IOS_ASSETS = ROOT / "app/ios/Runner/Assets.xcassets"

GROUND = "#DBDAD2"
INK = "#111111"

# name → the plate's colour: the stage colours of schlift_spec.dart.
VARIANTS = {
    "lifting": "#3D8B4A",
    "resting": "#3C5FB0",
    "yapping": "#D94F8C",
}

# (x, width, height, is the coloured one), on a 100 grid, lightest first;
# each is drawn over the one before it. As render_brand.py: ICON_PLATES.
PLATES = (
    (22, 5, 18, False),
    (26.7, 7.3, 30, False),
    (33.7, 9.3, 54, True),
    (42.7, 10.3, 70, False),
    (52.7, 10.3, 70, False),
)

LEGACY_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Drawn this many times too big and scaled down, for clean edges.
OVERSAMPLE = 4


def master(colour: str) -> Image.Image:
    """The 1024x1024 icon with its coloured plate in `colour`."""
    size = 1024 * OVERSAMPLE
    unit = size / 100
    image = Image.new("RGB", (size, size), GROUND)
    draw = ImageDraw.Draw(image)

    def rect(x: float, y: float, width: float, height: float, radius: float, fill: str) -> None:
        draw.rounded_rectangle(
            (x * unit, y * unit, (x + width) * unit, (y + height) * unit),
            radius=radius * unit,
            fill=fill,
        )

    rect(14, 47, 52, 6, 1, INK)
    rect(60, 48, 40, 4, 0, INK)
    for x, width, height, coloured in PLATES:
        rect(x, 50 - height / 2, width, height, 1.5, colour if coloured else INK)
    return image.resize((1024, 1024), Image.Resampling.LANCZOS).convert("RGBA")


def write_android(name: str, icon: Image.Image) -> None:
    for density, px in LEGACY_DENSITIES.items():
        target = ANDROID_RES / f"mipmap-{density}" / f"ic_launcher_{name}.png"
        icon.resize((px, px), Image.Resampling.LANCZOS).save(target, format="PNG", optimize=True)
    for density, px in ADAPTIVE_DENSITIES.items():
        target = ANDROID_RES / f"drawable-{density}" / f"ic_launcher_foreground_{name}.png"
        adaptive_foreground(icon, px).save(target, format="PNG", optimize=True)
    (ANDROID_RES / "mipmap-anydpi-v26" / f"ic_launcher_{name}.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        f'    <foreground android:drawable="@drawable/ic_launcher_foreground_{name}" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )


def write_ios(name: str, icon: Image.Image) -> None:
    """An icon set beside the default one, with the same slots and file
    names, each image at the size the default's is."""
    default = IOS_ASSETS / "AppIcon.appiconset"
    target = IOS_ASSETS / f"AppIcon{name.capitalize()}.appiconset"
    target.mkdir(exist_ok=True)
    shutil.copyfile(default / "Contents.json", target / "Contents.json")
    for slot in json.loads((default / "Contents.json").read_text())["images"]:
        filename = slot.get("filename")
        if not filename:
            continue
        with Image.open(default / filename) as existing:
            size = existing.size
        icon.resize(size, Image.Resampling.LANCZOS).convert("RGB").save(
            target / filename, format="PNG", optimize=True
        )


def main() -> None:
    for name, colour in VARIANTS.items():
        icon = master(colour)
        write_android(name, icon)
        write_ios(name, icon)
        print(f"wrote the {name} icon ({colour})")


if __name__ == "__main__":
    main()

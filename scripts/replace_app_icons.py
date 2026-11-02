#!/usr/bin/env python3
"""Put the rendered icon master on every platform.

  python3 scripts/replace_app_icons.py [--source marketing/icon.png]

The 1024x1024 master (scripts/render_brand.py) becomes the icon on iOS, macOS,
watchOS, Android legacy + adaptive, Wear OS, Windows, and the store icon in
marketing/.

The Android adaptive foreground is a raster layer: the master fills the 72dp a
launcher shows of the 108dp canvas, and its edges are stretched over the rest.
The master is a full-bleed design, so a round launcher mask crops it exactly
as the circle preview does.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def write_png_to_existing_size(master: Image.Image, path: Path, *, opaque: bool = False) -> None:
    with Image.open(path) as existing:
        width, height = existing.size

    target = master.resize((width, height), Image.Resampling.LANCZOS)
    if opaque:
        target = target.convert("RGB")
    target.save(path, format="PNG", optimize=True)


def write_png_at_size(master: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    target = master.resize((size, size), Image.Resampling.LANCZOS)
    target.convert("RGB").save(path, format="PNG", optimize=True)


def write_ico(master: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    master.save(
        path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def overwrite_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def collect_png_targets(repo_root: Path) -> list[Path]:
    patterns = [
        "app/android/app/src/main/res/mipmap-*/ic_launcher.png",
        "app/android/wear/src/main/res/mipmap-*/ic_launcher.png",
        "app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
        "app/macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    ]

    targets: set[Path] = set()
    for pattern in patterns:
        for p in repo_root.glob(pattern):
            # Skip hidden files.
            if p.name.startswith("."):
                continue
            if p.exists() and p.is_file():
                targets.add(p.relative_to(repo_root))
    return sorted(targets)


ADAPTIVE_DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
ADAPTIVE_VISIBLE_DP = 72  # of the 108dp canvas: what a launcher shows before its mask


def adaptive_foreground(master: Image.Image, px: int) -> Image.Image:
    """The master filling the 72dp a launcher shows, its edges stretched out
    over the rest of the 108dp canvas so parallax and odd masks never show a
    seam. The master is drawn full bleed, so this is the icon as designed."""
    inner = round(px * ADAPTIVE_VISIBLE_DP / 108)
    pad = (px - inner) // 2
    scaled = master.resize((inner, inner), Image.Resampling.LANCZOS)
    rest = px - pad - inner
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    canvas.paste(scaled, (pad, pad))
    # The top and bottom rows stretched up and down, then the full-height
    # edge columns stretched sideways, which fills the corners too.
    canvas.paste(scaled.crop((0, 0, inner, 1)).resize((inner, pad)), (pad, 0))
    canvas.paste(
        scaled.crop((0, inner - 1, inner, inner)).resize((inner, rest)), (pad, pad + inner)
    )
    canvas.paste(canvas.crop((pad, 0, pad + 1, px)).resize((pad, px)), (0, 0))
    canvas.paste(
        canvas.crop((pad + inner - 1, 0, pad + inner, px)).resize((rest, px)), (pad + inner, 0)
    )
    return canvas


def ground_colour(master: Image.Image) -> str:
    r, g, b, *_ = master.convert("RGBA").getpixel((4, 4))
    return f"#{r:02X}{g:02X}{b:02X}"


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    repo_root = Path(__file__).resolve().parent.parent
    ap.add_argument(
        "--source",
        type=Path,
        default=repo_root / "marketing" / "icon.png",
        help="1024x1024 PNG master (default: marketing/icon.png)",
    )
    args = ap.parse_args()
    master = Image.open(args.source).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"{args.source} is {master.size[0]}x{master.size[1]}; need 1024x1024")

    png_targets = collect_png_targets(repo_root)
    updated_files: set[Path] = set()

    for target in png_targets:
        is_ios_icon = target.parts[:2] == ("app", "ios")
        write_png_to_existing_size(master, repo_root / target, opaque=is_ios_icon)
        updated_files.add(target)

    ico_path = repo_root / "app/windows/runner/resources/app_icon.ico"
    write_ico(master, ico_path)
    updated_files.add(ico_path.relative_to(repo_root))

    # The store icon (Play listing, website apple-touch-icon): opaque, full bleed.
    store_icon = repo_root / "marketing" / "schlift-square-512.png"
    write_png_at_size(master, store_icon, 512)
    updated_files.add(store_icon.relative_to(repo_root))

    watch_icon_dir = repo_root / "app/ios/SchliftWatch/Assets.xcassets/AppIcon.appiconset"
    watch_icon_specs = [
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "24x24",
            "role": "notificationCenter",
            "subtype": "38mm",
            "pixels": 48,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "27.5x27.5",
            "role": "notificationCenter",
            "subtype": "42mm",
            "pixels": 55,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "29x29",
            "role": "companionSettings",
            "pixels": 58,
        },
        {
            "idiom": "watch",
            "scale": "3x",
            "size": "29x29",
            "role": "companionSettings",
            "pixels": 87,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "40x40",
            "role": "appLauncher",
            "subtype": "38mm",
            "pixels": 80,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "44x44",
            "role": "appLauncher",
            "subtype": "40mm",
            "pixels": 88,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "50x50",
            "role": "appLauncher",
            "subtype": "44mm",
            "pixels": 100,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "46x46",
            "role": "appLauncher",
            "subtype": "41mm",
            "pixels": 92,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "51x51",
            "role": "appLauncher",
            "subtype": "45mm",
            "pixels": 102,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "54x54",
            "role": "appLauncher",
            "subtype": "49mm",
            "pixels": 108,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "86x86",
            "role": "quickLook",
            "subtype": "38mm",
            "pixels": 172,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "98x98",
            "role": "quickLook",
            "subtype": "42mm",
            "pixels": 196,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "108x108",
            "role": "quickLook",
            "subtype": "44mm",
            "pixels": 216,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "117x117",
            "role": "quickLook",
            "subtype": "45mm",
            "pixels": 234,
        },
        {
            "idiom": "watch",
            "scale": "2x",
            "size": "129x129",
            "role": "quickLook",
            "subtype": "49mm",
            "pixels": 258,
        },
        {"idiom": "watch-marketing", "scale": "1x", "size": "1024x1024", "pixels": 1024},
    ]
    watch_images: list[dict[str, str]] = []
    for spec in watch_icon_specs:
        pixels = spec.pop("pixels")
        role = spec.get("role", "marketing")
        subtype = f"-{spec['subtype']}" if "subtype" in spec else ""
        filename = f"Icon-Watch-{role}{subtype}-{pixels}.png"
        write_png_at_size(master, watch_icon_dir / filename, pixels)
        watch_images.append(dict(spec.items()) | {"filename": filename})
        updated_files.add((watch_icon_dir / filename).relative_to(repo_root))

    contents = {
        "images": watch_images,
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }
    watch_contents = watch_icon_dir / "Contents.json"
    overwrite_text(watch_contents, json.dumps(contents, indent=2) + "\n")
    updated_files.add(watch_contents.relative_to(repo_root))

    # Raster adaptive foreground per density, solid background in the
    # master's ground colour.
    background_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{ground_colour(master)}</color>
</resources>
"""
    text_updates = {
        Path("app/android/app/src/main/res/values/colors.xml"): background_xml,
        Path("app/android/wear/src/main/res/values/colors.xml"): background_xml,
    }
    for module in ("app", "wear"):
        res = repo_root / "app" / "android" / module / "src" / "main" / "res"
        for density, px in ADAPTIVE_DENSITIES.items():
            out = res / f"drawable-{density}" / "ic_launcher_foreground.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            adaptive_foreground(master, px).save(out, format="PNG", optimize=True)
            updated_files.add(out.relative_to(repo_root))

    for rel_path, content in text_updates.items():
        overwrite_text(repo_root / rel_path, content)
        updated_files.add(rel_path)

    print(f"Updated {len(updated_files)} icon files:")
    for rel_path in sorted(updated_files):
        print(f"- {rel_path}")


if __name__ == "__main__":
    main()

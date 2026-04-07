#!/usr/bin/env python3
"""Generate and replace app icons plus marketing branding assets."""

from __future__ import annotations

from pathlib import Path
import glob
import json
import math
import random

from PIL import Image, ImageDraw, ImageFont


BLACK = (10, 10, 10, 255)  # #0A0A0A
WHITE = (250, 250, 250, 255)  # #FAFAFA
GRAY_BG = (212, 212, 212, 255)
DARK_GRAY_BG = (74, 74, 74, 255)


def draw_barbell(draw: ImageDraw.ImageDraw, size: int, color: tuple[int, int, int, int]) -> None:
    def s(unit: float) -> float:
        return unit * size / 108.0

    bar_radius = s(1.2)

    # Three equal-height plates per side for a barbell silhouette.
    plate_top = s(33)
    plate_bottom = s(75)

    # Left plates
    draw.rounded_rectangle((s(14), plate_top, s(20), plate_bottom), radius=bar_radius, fill=color)
    draw.rounded_rectangle((s(21), plate_top, s(27), plate_bottom), radius=bar_radius, fill=color)
    draw.rounded_rectangle((s(28), plate_top, s(34), plate_bottom), radius=bar_radius, fill=color)
    # Longer center bar (square ends)
    draw.rectangle((s(34), s(50), s(74), s(58)), fill=color)
    # Right plates
    draw.rounded_rectangle((s(74), plate_top, s(80), plate_bottom), radius=bar_radius, fill=color)
    draw.rounded_rectangle((s(81), plate_top, s(87), plate_bottom), radius=bar_radius, fill=color)
    draw.rounded_rectangle((s(88), plate_top, s(94), plate_bottom), radius=bar_radius, fill=color)


def draw_master_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Background circle - larger to fill the space
    cx = cy = size / 2
    radius = size * 0.48
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=BLACK,
    )

    # Barbell - scaled down to fit in safe zone
    scale = 0.75
    inner = int(size * scale)
    barbell = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    draw_barbell(ImageDraw.Draw(barbell), inner, WHITE)
    offset = ((size - inner) // 2, (size - inner) // 2)
    image.alpha_composite(barbell, offset)

    return image


def draw_marketing_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), BLACK)
    
    # Scale the barbell down even for marketing icons to account for Play Store masking
    scale = 0.75
    inner = int(size * scale)
    barbell = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    draw_barbell(ImageDraw.Draw(barbell), inner, WHITE)
    offset = ((size - inner) // 2, (size - inner) // 2)
    image.alpha_composite(barbell, offset)

    return image


def draw_rounded_square_logo(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = int(size * 0.22)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=BLACK)

    inner = int(size * 0.88)
    barbell = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    draw_barbell(ImageDraw.Draw(barbell), inner, WHITE)
    offset = ((size - inner) // 2, (size - inner) // 2)
    image.alpha_composite(barbell, offset)
    return image


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    ]
    for path in candidates:
        font_path = Path(path)
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size=size)
    return ImageFont.load_default()


def draw_wobbly_text(
    canvas: Image.Image,
    text: str,
    origin_x: int,
    origin_y: int,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    color: tuple[int, int, int, int],
    seed: int,
    max_offset: float,
    max_rotate_radians: float,
) -> None:
    rng = random.Random(seed)
    cursor_x = float(origin_x)

    for ch in text:
        # Same RNG usage pattern as mobile: x, y, angle per character.
        dx = (rng.random() * 2 - 1) * max_offset
        dy = (rng.random() * 2 - 1) * max_offset
        angle = (rng.random() * 2 - 1) * max_rotate_radians

        advance = float(font.getlength(ch if ch != "" else " "))
        if ch == " ":
            cursor_x += advance
            continue

        bbox = font.getbbox(ch)
        if bbox is None:
            cursor_x += advance
            continue
        width = max(1, int(math.ceil(bbox[2] - bbox[0])))
        height = max(1, int(math.ceil(bbox[3] - bbox[1])))
        pad = max(10, int(round(height * 0.35)))

        glyph = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
        glyph_draw = ImageDraw.Draw(glyph)
        glyph_draw.text((pad - bbox[0], pad - bbox[1]), ch, font=font, fill=color)

        rotated = glyph.rotate(
            math.degrees(angle),
            resample=Image.Resampling.BICUBIC,
            expand=True,
        )
        canvas.alpha_composite(
            rotated,
            (int(round(cursor_x + dx)), int(round(origin_y + dy))),
        )
        cursor_x += advance


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
        "app/web/favicon.png",
        "app/web/icons/Icon-192.png",
        "app/web/icons/Icon-512.png",
        "app/web/icons/Icon-maskable-192.png",
        "app/web/icons/Icon-maskable-512.png",
        "app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
        "app/macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    ]

    targets: set[Path] = set()
    for pattern in patterns:
        for match in glob.glob(str(repo_root / pattern)):
            p = Path(match)
            if p.exists() and p.is_file():
                targets.add(p.relative_to(repo_root))
    return sorted(targets)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    icon_master = draw_master_icon(1024)
    apple_icon_master = draw_marketing_icon(1024)

    png_targets = collect_png_targets(repo_root)
    updated_files: set[Path] = set()

    for target in png_targets:
        is_ios_icon = target.parts[:2] == ("app", "ios")
        source = apple_icon_master if is_ios_icon else icon_master
        write_png_to_existing_size(source, repo_root / target, opaque=is_ios_icon)
        updated_files.add(target)

    ico_path = repo_root / "app/windows/runner/resources/app_icon.ico"
    write_ico(icon_master, ico_path)
    updated_files.add(ico_path.relative_to(repo_root))

    # Square output icon set (store/export assets): opaque, full-bleed background.
    marketing_dir = repo_root / "marketing"
    marketing_dir.mkdir(parents=True, exist_ok=True)
    
    generic_output_specs = {
        "schlift-square-192.png": 192,
        "schlift-square-512.png": 512,
        "schlift-square-1024.png": 1024,
    }
    for filename, px in generic_output_specs.items():
        out_path = marketing_dir / filename
        draw_marketing_icon(px).convert("RGB").save(
            out_path,
            format="PNG",
            optimize=True,
        )
        updated_files.add(out_path.relative_to(repo_root))

    watch_icon_dir = repo_root / "app/ios/SchliftWatch/Assets.xcassets/AppIcon.appiconset"
    watch_icon_specs = [
        {"idiom": "watch", "scale": "2x", "size": "24x24", "role": "notificationCenter", "subtype": "38mm", "pixels": 48},
        {"idiom": "watch", "scale": "2x", "size": "27.5x27.5", "role": "notificationCenter", "subtype": "42mm", "pixels": 55},
        {"idiom": "watch", "scale": "2x", "size": "29x29", "role": "companionSettings", "pixels": 58},
        {"idiom": "watch", "scale": "3x", "size": "29x29", "role": "companionSettings", "pixels": 87},
        {"idiom": "watch", "scale": "2x", "size": "40x40", "role": "appLauncher", "subtype": "38mm", "pixels": 80},
        {"idiom": "watch", "scale": "2x", "size": "44x44", "role": "appLauncher", "subtype": "40mm", "pixels": 88},
        {"idiom": "watch", "scale": "2x", "size": "50x50", "role": "appLauncher", "subtype": "44mm", "pixels": 100},
        {"idiom": "watch", "scale": "2x", "size": "46x46", "role": "appLauncher", "subtype": "41mm", "pixels": 92},
        {"idiom": "watch", "scale": "2x", "size": "51x51", "role": "appLauncher", "subtype": "45mm", "pixels": 102},
        {"idiom": "watch", "scale": "2x", "size": "54x54", "role": "appLauncher", "subtype": "49mm", "pixels": 108},
        {"idiom": "watch", "scale": "2x", "size": "86x86", "role": "quickLook", "subtype": "38mm", "pixels": 172},
        {"idiom": "watch", "scale": "2x", "size": "98x98", "role": "quickLook", "subtype": "42mm", "pixels": 196},
        {"idiom": "watch", "scale": "2x", "size": "108x108", "role": "quickLook", "subtype": "44mm", "pixels": 216},
        {"idiom": "watch", "scale": "2x", "size": "117x117", "role": "quickLook", "subtype": "45mm", "pixels": 234},
        {"idiom": "watch", "scale": "2x", "size": "129x129", "role": "quickLook", "subtype": "49mm", "pixels": 258},
        {"idiom": "watch-marketing", "scale": "1x", "size": "1024x1024", "pixels": 1024},
    ]
    watch_images: list[dict[str, str]] = []
    for spec in watch_icon_specs:
        pixels = spec.pop("pixels")
        role = spec.get("role", "marketing")
        subtype = f"-{spec['subtype']}" if "subtype" in spec else ""
        filename = f"Icon-Watch-{role}{subtype}-{pixels}.png"
        write_png_at_size(apple_icon_master, watch_icon_dir / filename, pixels)
        watch_images.append({k: v for k, v in spec.items()} | {"filename": filename})
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

    background_xml = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#00000000</color>
</resources>
"""

    foreground_xml = """<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#0A0A0A"
        android:pathData="M54,4A50,50 0 1,1 54,104A50,50 0 1,1 54,4Z" />
    <path
        android:fillColor="#FAFAFA"
        android:pathData="M24,38.25h4.5v31.5h-4.5zM29.25,38.25h4.5v31.5h-4.5zM34.5,38.25h4.5v31.5h-4.5zM39,51h30v6h-30zM69,38.25h4.5v31.5h-4.5zM74.25,38.25h4.5v31.5h-4.5zM79.5,38.25h4.5v31.5h-4.5z" />
</vector>
"""

    text_updates = {
        Path("app/android/app/src/main/res/values/colors.xml"): background_xml,
        Path("app/android/wear/src/main/res/values/colors.xml"): background_xml,
        Path("app/android/app/src/main/res/drawable/ic_launcher_foreground.xml"): foreground_xml,
        Path("app/android/wear/src/main/res/drawable/ic_launcher_foreground.xml"): foreground_xml,
    }

    for rel_path, content in text_updates.items():
        overwrite_text(repo_root / rel_path, content)
        updated_files.add(rel_path)

    print(f"Updated {len(updated_files)} icon files:")
    for rel_path in sorted(updated_files):
        print(f"- {rel_path}")


if __name__ == "__main__":
    main()

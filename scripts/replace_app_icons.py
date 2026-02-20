#!/usr/bin/env python3
"""Generate and replace app icons plus marketing branding assets."""

from __future__ import annotations

from pathlib import Path
import glob
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

    cx = cy = size / 2
    radius = size * 0.44
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=BLACK,
    )
    draw_barbell(draw, size, WHITE)

    return image


def draw_marketing_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), BLACK)
    draw = ImageDraw.Draw(image)
    draw_barbell(draw, size, WHITE)

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


def draw_branding_header() -> Image.Image:
    width, height = 1024, 500
    image = Image.new("RGBA", (width, height), DARK_GRAY_BG)
    logo = draw_rounded_square_logo(248)
    image.alpha_composite(logo, (72, 126))

    title_font = load_font(172)
    byline_text = "Track lifts, get strong, together"
    byline_font_size = 54
    byline_font = load_font(byline_font_size)
    max_byline_width = width - 382 - 40
    while byline_font.getlength(byline_text) > max_byline_width and byline_font_size > 18:
        byline_font_size -= 2
        byline_font = load_font(byline_font_size)

    draw_wobbly_text(
        canvas=image,
        text="LIFT",
        origin_x=378,
        origin_y=128,
        font=title_font,
        color=WHITE,
        seed=42,
        max_offset=5.0,
        max_rotate_radians=0.10,
    )

    draw = ImageDraw.Draw(image)
    draw.text(
        (382, 330),
        byline_text,
        font=byline_font,
        fill=WHITE,
    )
    return image


def write_png_to_existing_size(master: Image.Image, path: Path) -> None:
    with Image.open(path) as existing:
        width, height = existing.size

    target = master.resize((width, height), Image.Resampling.LANCZOS)
    target.save(path, format="PNG", optimize=True)


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

    png_targets = collect_png_targets(repo_root)
    updated_files: set[Path] = set()

    for target in png_targets:
        write_png_to_existing_size(icon_master, repo_root / target)
        updated_files.add(target)

    ico_path = repo_root / "app/windows/runner/resources/app_icon.ico"
    write_ico(icon_master, ico_path)
    updated_files.add(ico_path.relative_to(repo_root))

    # Square output icon set (store/export assets): opaque, full-bleed background.
    generic_output_dir = repo_root / "app/assets/output"
    generic_output_specs = {
        "lift-square-192.png": 192,
        "lift-square-512.png": 512,
        "lift-square-1024.png": 1024,
    }
    for filename, px in generic_output_specs.items():
        out_path = generic_output_dir / filename
        out_path.parent.mkdir(parents=True, exist_ok=True)
        draw_marketing_icon(px).convert("RGB").save(
            out_path,
            format="PNG",
            optimize=True,
        )
        updated_files.add(out_path.relative_to(repo_root))

    # Branding header asset (1024x500) with rounded-square logo + wobbly title.
    branding_header = repo_root / "app/assets/branding/header.png"
    branding_header.parent.mkdir(parents=True, exist_ok=True)
    draw_branding_header().convert("RGB").save(branding_header, format="PNG", optimize=True)
    updated_files.add(branding_header.relative_to(repo_root))

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
        android:pathData="M54,10A44,44 0 1,1 54,98A44,44 0 1,1 54,10Z" />
    <path
        android:fillColor="#FAFAFA"
        android:pathData="M14,33h6v42h-6zM21,33h6v42h-6zM28,33h6v42h-6zM34,50h40v8h-40zM74,33h6v42h-6zM81,33h6v42h-6zM88,33h6v42h-6z" />
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

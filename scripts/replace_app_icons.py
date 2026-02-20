#!/usr/bin/env python3
"""Generate and replace app icons with a black-circle / white-dumbbell design."""

from __future__ import annotations

from pathlib import Path
import glob

from PIL import Image, ImageDraw


BLACK = (10, 10, 10, 255)  # #0A0A0A
WHITE = (250, 250, 250, 255)  # #FAFAFA


def draw_master_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    cx = cy = size / 2
    radius = size * 0.44
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=BLACK,
    )

    def s(unit: float) -> float:
        return unit * size / 108.0

    bar_radius = s(1.2)

    # Three equal-height plates per side for a barbell silhouette.
    plate_top = s(33)
    plate_bottom = s(75)

    # Left plates
    draw.rounded_rectangle((s(14), plate_top, s(20), plate_bottom), radius=bar_radius, fill=WHITE)
    draw.rounded_rectangle((s(21), plate_top, s(27), plate_bottom), radius=bar_radius, fill=WHITE)
    draw.rounded_rectangle((s(28), plate_top, s(34), plate_bottom), radius=bar_radius, fill=WHITE)
    # Longer center bar (square ends)
    draw.rectangle((s(34), s(50), s(74), s(58)), fill=WHITE)
    # Right plates
    draw.rounded_rectangle((s(74), plate_top, s(80), plate_bottom), radius=bar_radius, fill=WHITE)
    draw.rounded_rectangle((s(81), plate_top, s(87), plate_bottom), radius=bar_radius, fill=WHITE)
    draw.rounded_rectangle((s(88), plate_top, s(94), plate_bottom), radius=bar_radius, fill=WHITE)

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
    updated_files: list[Path] = []

    for target in png_targets:
        write_png_to_existing_size(icon_master, repo_root / target)
        updated_files.append(target)

    ico_path = repo_root / "app/windows/runner/resources/app_icon.ico"
    write_ico(icon_master, ico_path)
    updated_files.append(ico_path.relative_to(repo_root))

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
        updated_files.append(rel_path)

    print(f"Updated {len(updated_files)} icon files:")
    for rel_path in sorted(updated_files):
        print(f"- {rel_path}")


if __name__ == "__main__":
    main()

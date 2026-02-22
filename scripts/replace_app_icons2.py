#!/usr/bin/env python3
"""Generate the LIFT app feature graphic."""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

BLACK = (10, 10, 10, 255)  # #0A0A0A
WHITE = (250, 250, 250, 255)  # #FAFAFA
BG_COLOR = (34, 34, 34, 255)  # Dark gray to match the minimalist theme


def draw_barbell(draw: ImageDraw.ImageDraw, size: int, color: tuple[int, int, int, int]) -> None:
    def s(unit: float) -> float:
        return unit * size / 108.0

    bar_radius = s(1.2)
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
    # Ensure both LIFT and the byline use the exact same base font face
    candidates = [
        # Linux
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
        # Windows
        "C:\\Windows\\Fonts\\arialbd.ttf",
        # macOS
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        font_path = Path(path)
        if font_path.exists():
            try:
                return ImageFont.truetype(str(font_path), size=size)
            except OSError:
                continue
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


def draw_feature_graphic() -> Image.Image:
    width, height = 1024, 500
    image = Image.new("RGBA", (width, height), BG_COLOR)
    
    logo_size = 250
    logo_x = 90
    logo_y = (height - logo_size) // 2
    logo_radius = int(logo_size * 0.22)
    
    # 1. Draw Drop Shadow for the App Icon
    shadow_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    shadow_offset_y = 10
    shadow_draw.rounded_rectangle(
        (logo_x, logo_y + shadow_offset_y, logo_x + logo_size, logo_y + logo_size + shadow_offset_y),
        radius=logo_radius,
        fill=(0, 0, 0, 160) # Semi-transparent black
    )
    # Blur the shadow layer
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=15))
    image.alpha_composite(shadow_layer, (0, 0))

    # 2. Draw the App Icon
    logo = draw_rounded_square_logo(logo_size)
    image.alpha_composite(logo, (logo_x, logo_y))

    # 3. Text Placement Setup
    text_x = 380 # Shifted left to prevent cutoff
    title_font = load_font(180)
    
    # 4. Draw Wobbly "LIFT" Text
    draw_wobbly_text(
        canvas=image,
        text="LIFT",
        origin_x=text_x,
        origin_y=125,
        font=title_font,
        color=WHITE,
        seed=42,
        max_offset=6.0,
        max_rotate_radians=0.12,
    )

    # 5. Draw Motto with Auto-scaling (Ensures it never cuts off)
    byline_text = "Track lifts, get strong, together."
    byline_font_size = 46
    max_text_width = width - text_x - 30 # 30px padding from right edge
    
    while True:
        byline_font = load_font(byline_font_size)
        if byline_font.getlength(byline_text) <= max_text_width or byline_font_size <= 20:
            break
        byline_font_size -= 2

    draw = ImageDraw.Draw(image)
    draw.text(
        (text_x + 8, 335), # Align slightly inset with the wobbly text
        byline_text,
        font=byline_font,
        fill=WHITE,
    )
    return image


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    marketing_dir = repo_root / "marketing"
    marketing_dir.mkdir(parents=True, exist_ok=True)
    
    out_path = marketing_dir / "feature_graphic.png"
    image = draw_feature_graphic()
    
    # Convert RGBA to RGB to save cleanly as PNG
    image.convert("RGB").save(out_path, format="PNG", optimize=True)
    print(f"Success! Saved feature graphic to {out_path.absolute()}")


if __name__ == "__main__":
    main()
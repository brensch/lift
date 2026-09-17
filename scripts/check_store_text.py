#!/usr/bin/env python3
"""Validate store/listing.yaml against both stores' limits.

Runs in CI on every pull request so a too-long field fails the PR, not the
upload. The push scripts import LIMITS from here so the two never disagree.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "store" / "listing.yaml"
RAW_DIR = ROOT / "store" / "screenshots" / "raw"

# field -> (limit, which stores read it)
LIMITS = {
    "name": (30, "both"),
    "subtitle": (30, "App Store"),
    "short_description": (80, "Play"),
    "promotional_text": (170, "App Store"),
    "keywords": (100, "App Store"),
    "description": (4000, "both"),
}
CAPTION_TITLE_LIMIT = 28
CAPTION_SUBTITLE_LIMIT = 64


def load_listing(path: Path = LISTING) -> dict:
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def check(listing: dict, raw_dir: Path = RAW_DIR) -> list[str]:
    problems: list[str] = []
    for field, (limit, store) in LIMITS.items():
        value = listing.get(field)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"{field}: missing ({store})")
            continue
        text = value.strip()
        if len(text) > limit:
            problems.append(f"{field}: {len(text)} characters, {store} allows {limit}")
        if field == "keywords" and " ," in text:
            problems.append("keywords: remove the space before a comma; it counts against the 100")

    slides = listing.get("screenshots") or []
    if not 2 <= len(slides) <= 8:
        problems.append(f"screenshots: {len(slides)} slides; Play wants 2–8 (App Store 1–10)")
    for i, slide in enumerate(slides):
        where = f"screenshots[{i}]"
        if not isinstance(slide, dict) or not slide.get("file"):
            problems.append(f"{where}: needs a file")
            continue
        title = str(slide.get("title") or "").strip()
        subtitle = str(slide.get("subtitle") or "").strip()
        if not title:
            problems.append(f"{where}: needs a title")
        elif len(title) > CAPTION_TITLE_LIMIT:
            problems.append(f"{where}: title is {len(title)} characters; keep it under {CAPTION_TITLE_LIMIT} so it fits on one line")
        if len(subtitle) > CAPTION_SUBTITLE_LIMIT:
            problems.append(f"{where}: subtitle is {len(subtitle)} characters; keep it under {CAPTION_SUBTITLE_LIMIT}")
        if raw_dir.is_dir() and not (raw_dir / slide["file"]).is_file():
            problems.append(f"{where}: {slide['file']} is not in {raw_dir.relative_to(ROOT)}")

    for key, limit in (("wear_screenshots", 8), ("apple_watch_screenshots", 10)):
        shots = listing.get(key) or []
        if len(shots) > limit:
            problems.append(f"{key}: {len(shots)} shots, limit {limit}")
        for i, shot in enumerate(shots):
            if raw_dir.is_dir() and (not isinstance(shot, dict) or not (raw_dir / str(shot.get("file"))).is_file()):
                problems.append(f"{key}[{i}]: file missing from {raw_dir.relative_to(ROOT)}")
    return problems


def main() -> int:
    if not LISTING.is_file():
        print(f"{LISTING} does not exist")
        return 1
    problems = check(load_listing())
    for problem in problems:
        print(f"FAIL {problem}")
    if not problems:
        listing = load_listing()
        for field, (limit, store) in LIMITS.items():
            print(f"ok  {field}: {len(listing[field].strip())}/{limit} ({store})")
        print(f"ok  {len(listing.get('screenshots') or [])} screenshot slides")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

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
    "tagline": (30, "App Store subtitle, feature graphic byline, Play one-liner"),
    "promotional_text": (170, "App Store promo, Play one-liner"),
    "keywords": (100, "App Store"),
    "about": (3000, "both, opens the description"),
    "testimonials_heading": (140, "both"),
}
DESCRIPTION_LIMIT = 4000
PLAY_SHORT_LIMIT = 80
RETIRED = ("subtitle", "short_description", "feature_graphic_byline", "description")


def feature_text(item) -> str:
    """An other_features item is either a string or {emoji, text}; the store gets the text."""
    return str(item.get("text", "") if isinstance(item, dict) else item).strip()


def compose_description(listing: dict) -> str:
    """The store description, built from the typed pieces in a fixed order:
    about, the testimonials under their heading, then other_features."""
    parts = [str(listing.get("about", "")).strip()]
    testimonials = listing.get("testimonials") or []
    if testimonials:
        parts.append(str(listing.get("testimonials_heading", "Testimonials:")).strip())
        for t in testimonials:
            parts.append(f'"{str(t.get("quote", "")).strip()}"\n- {str(t.get("name", "")).strip()}')
    other = listing.get("other_features") or {}
    if other.get("items"):
        lines = [str(other.get("heading", "")).strip()] + [
            f"- {feature_text(i)}" for i in other["items"]
        ]
        parts.append("\n".join(line for line in lines if line))
    return "\n\n".join(p for p in parts if p)


CAPTION_TITLE_LIMIT = 28
CAPTION_SUBTITLE_LIMIT = 80


def play_short_description(listing: dict) -> str:
    """Play's one-liner: the tagline and the promotional text, one sentence after the other."""
    tagline = str(listing.get("tagline", "")).strip()
    promo = str(listing.get("promotional_text", "")).strip()
    return f"{tagline} {promo}".strip()


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

    for field in RETIRED:
        if field in listing:
            problems.append(
                f"{field}: retired; see the comments in store/listing.yaml for what replaced it"
            )
    for i, t in enumerate(listing.get("testimonials") or []):
        if (
            not isinstance(t, dict)
            or not str(t.get("quote", "")).strip()
            or not str(t.get("name", "")).strip()
        ):
            problems.append(f"testimonials[{i}]: needs a quote and a name")
    other = listing.get("other_features") or {}
    if (
        not isinstance(other, dict)
        or not str(other.get("heading", "")).strip()
        or not other.get("items")
    ):
        problems.append("other_features: needs a heading and at least one item")
    for i, item in enumerate((other.get("items") if isinstance(other, dict) else None) or []):
        if not feature_text(item):
            problems.append(f"other_features.items[{i}]: needs text")
    description = compose_description(listing)
    if len(description) > DESCRIPTION_LIMIT:
        problems.append(
            f"composed description: {len(description)} characters, "
            f"the stores allow {DESCRIPTION_LIMIT}"
        )
    short = play_short_description(listing)
    if len(short) > PLAY_SHORT_LIMIT:
        problems.append(
            f"tagline + promotional_text: {len(short)} characters; "
            f"Play's one-liner allows {PLAY_SHORT_LIMIT}"
        )

    slides = listing.get("screenshots") or []
    if not 2 <= len(slides) <= 8:
        problems.append(
            f"screenshots: {len(slides)} slides; Play wants 2\u20138 (App Store 1\u201310)"
        )
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
            problems.append(
                f"{where}: title is {len(title)} characters; "
                f"keep it under {CAPTION_TITLE_LIMIT} so it fits on one line"
            )
        if len(subtitle) > CAPTION_SUBTITLE_LIMIT:
            problems.append(
                f"{where}: subtitle is {len(subtitle)} characters; "
                f"keep it under {CAPTION_SUBTITLE_LIMIT}"
            )
        if raw_dir.is_dir() and not (raw_dir / slide["file"]).is_file():
            problems.append(f"{where}: {slide['file']} is not in {raw_dir.relative_to(ROOT)}")

    for key, limit in (("wear_screenshots", 8), ("apple_watch_screenshots", 10)):
        shots = listing.get(key) or []
        if len(shots) > limit:
            problems.append(f"{key}: {len(shots)} shots, limit {limit}")
        for i, shot in enumerate(shots):
            if raw_dir.is_dir() and (
                not isinstance(shot, dict) or not (raw_dir / str(shot.get("file"))).is_file()
            ):
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
        print(f"ok  Play one-liner: {len(play_short_description(listing))}/{PLAY_SHORT_LIMIT}")
        testimonials = listing.get("testimonials") or []
        other_items = (listing.get("other_features") or {}).get("items") or []
        print(
            f"ok  composed description: {len(compose_description(listing))}/{DESCRIPTION_LIMIT} "
            f"({len(testimonials)} testimonials, {len(other_items)} other features)"
        )
        print(f"ok  {len(listing.get('screenshots') or [])} screenshot slides")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

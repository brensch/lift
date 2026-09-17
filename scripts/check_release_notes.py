#!/usr/bin/env python3
"""Validate every file in release-notes/ so a bad one fails the PR, not the promotion.

Rules (the same ones scripts/promote_google_play.py and promote_app_store.py
enforce at promote time):
- file name is <major>.<minor>.<patch>.md
- not empty
- at most 500 characters after trimming (Google Play's limit; the App Store
  allows 4000, so Play is the binding one)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

NOTES_DIR = Path(__file__).resolve().parent.parent / "release-notes"
NAME_PATTERN = re.compile(r"^\d+\.\d+\.\d+\.md$")
PLAY_LIMIT = 500


def main() -> int:
    if not NOTES_DIR.is_dir():
        print(f"{NOTES_DIR} does not exist")
        return 1
    problems: list[str] = []
    checked = 0
    for path in sorted(NOTES_DIR.iterdir()):
        if path.name == "README.md" or path.is_dir():
            continue
        checked += 1
        rel = path.relative_to(NOTES_DIR.parent)
        if not NAME_PATTERN.match(path.name):
            problems.append(f"{rel}: name must be <major>.<minor>.<patch>.md")
            continue
        text = path.read_text(encoding="utf-8").strip()
        if not text:
            problems.append(f"{rel}: empty")
        elif len(text) > PLAY_LIMIT:
            problems.append(f"{rel}: {len(text)} characters, Google Play allows {PLAY_LIMIT}")
        else:
            print(f"ok  {rel} ({len(text)} chars)")
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"{checked} release-notes file(s) checked, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

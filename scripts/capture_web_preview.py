#!/usr/bin/env python3
"""Capture the sample dashboard for the home page's "It has web too" picture.

The home page shows a small picture of the real dashboard page (/demo, which
runs on sample data and needs no backend). This takes that picture from a
running site and writes web/public/dashboard-preview.png, to commit.

    make run-frontend        # in another terminal
    make web-preview         # → web/public/dashboard-preview.png
"""

from __future__ import annotations

import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

OUT = Path(__file__).resolve().parent.parent / "web" / "public" / "dashboard-preview.png"
# The page at a laptop's width, drawn at 1.5x so it stays sharp shrunk down.
WIDTH, HEIGHT, SCALE = 1280, 860, 1.5


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:5173"
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_context(
            viewport={"width": WIDTH, "height": HEIGHT},
            device_scale_factor=SCALE,
            reduced_motion="reduce",
        ).new_page()
        page.goto(f"{base}/demo")
        page.wait_for_selector("text=Weekly volume")
        page.wait_for_timeout(1500)
        page.screenshot(path=str(OUT))
        browser.close()
    print(f"wrote {OUT.relative_to(OUT.parent.parent.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

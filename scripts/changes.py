#!/usr/bin/env python3
"""The change log: every change, filed under the release it shipped in.

    changes/next.md        what has landed since the last release, one
                           `- ` line each, added by the change that makes it
    changes/<version>.md   a release: the date it was cut, then its changes

`cut` turns next.md into a release when one is tagged; the website lists
every release from these files (web/scripts/sync-content.mjs). The store's
own "What's new" (release-notes/<version>.md, 500 characters) is written
separately: this is the whole list.

    changes.py check [--base REF]   the files are well formed; with --base, a
                                    diff from REF that changes the product
                                    also adds a line to next.md
    changes.py cut VERSION          next.md becomes changes/VERSION.md, dated
                                    today, and next.md starts empty
    changes.py backfill             one-off: a file for every v* tag that has
                                    none, from the commits between tags
"""

from __future__ import annotations

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CHANGES = REPO / "changes"
NEXT = CHANGES / "next.md"
NOTES = REPO / "release-notes"
VERSION = re.compile(r"^\d+\.\d+\.\d+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
PLAY_LIMIT = 500

# What a user of the app, the watch apps, the website or the server could
# notice a change in. A diff touching these needs a line in next.md.
PRODUCT_PATHS = (
    "app/lib/",
    "app/native/",
    "app/android/",
    "app/ios/",
    "app/copy.yaml",
    "core/",
    "proto/",
    "src/",
    "templates/",
    "web/src/",
)
# Generated from the above, never a change of their own.
GENERATED_PATHS = ("app/lib/gen/", "web/src/gen/", "web/src/generated/")

# Commits that are bookkeeping, left out of a backfilled release.
BOOKKEEPING = re.compile(r"^(Release notes for|Format |Regenerate |Merge )", re.IGNORECASE)


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, check=True, capture_output=True, text=True
    ).stdout


def bullets(lines: list[str], where: str, problems: list[str]) -> int:
    """Check `lines` are `- ` items (blank lines between are fine); how many."""
    count = 0
    for number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        if not line.startswith("- ") or not line[2:].strip():
            problems.append(f"{where}: line {number} is not a `- ` item: {line!r}")
        else:
            count += 1
    return count


def check(base: str | None) -> int:
    problems: list[str] = []
    if not NEXT.is_file():
        problems.append("changes/next.md is missing")
    else:
        bullets(NEXT.read_text(encoding="utf-8").splitlines(), "changes/next.md", problems)

    released: set[str] = set()
    for path in sorted(CHANGES.glob("*.md")):
        if path.name in ("next.md", "README.md"):
            continue
        where = f"changes/{path.name}"
        if not VERSION.match(path.stem):
            problems.append(f"{where}: name must be <major>.<minor>.<patch>.md or next.md")
            continue
        released.add(path.stem)
        lines = path.read_text(encoding="utf-8").splitlines()
        if not lines or not DATE.match(lines[0].strip()):
            problems.append(f"{where}: the first line must be the release date, YYYY-MM-DD")
            continue
        if bullets(lines[1:], where, problems) == 0:
            problems.append(f"{where}: lists no changes")

    # A release the stores were told about is one the change log has.
    for path in sorted(NOTES.glob("*.md")):
        if VERSION.match(path.stem) and path.stem not in released:
            problems.append(
                f"release-notes/{path.name} has no changes/{path.name}: "
                f"run `make cut-release VERSION={path.stem}`"
            )

    if base:
        changed = git("diff", "--name-only", f"{base}...HEAD").split()
        product = [
            name
            for name in changed
            if name.startswith(PRODUCT_PATHS) and not name.startswith(GENERATED_PATHS)
        ]
        if product and "changes/next.md" not in changed:
            problems.append(
                "this changes the product (" + ", ".join(product[:3]) + ", …) "
                "but adds nothing to changes/next.md: say what changed there, one `- ` line"
            )

    for problem in problems:
        print(f"FAIL {problem}")
    print(f"{len(released)} release(s) in the change log, {len(problems)} problem(s)")
    return 1 if problems else 0


def cut(version: str) -> int:
    if not VERSION.match(version):
        print(f"{version!r} is not <major>.<minor>.<patch>")
        return 1
    target = CHANGES / f"{version}.md"
    if target.exists():
        print(f"changes/{version}.md already exists")
        return 1
    items = [line for line in NEXT.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not items:
        print("changes/next.md is empty: nothing has landed since the last release")
        return 1
    today = datetime.date.today().isoformat()
    target.write_text(f"{today}\n\n" + "\n".join(items) + "\n", encoding="utf-8")
    NEXT.write_text("", encoding="utf-8")
    print(f"wrote changes/{version}.md ({len(items)} changes), emptied changes/next.md")

    # The store text starts as the top of the list, for the owner to rewrite.
    notes = NOTES / f"{version}.md"
    if not notes.exists():
        draft: list[str] = []
        for item in items:
            line = "• " + item[2:].strip()
            if len("\n".join([*draft, line])) > PLAY_LIMIT:
                break
            draft.append(line)
        notes.write_text("\n".join(draft) + "\n", encoding="utf-8")
        print(f"drafted release-notes/{version}.md from it: rewrite it for the stores")
    return 0


def backfill() -> int:
    tags = sorted(
        (tag[1:] for tag in git("tag", "-l", "v*").split() if VERSION.match(tag[1:])),
        key=version_key,
    )
    CHANGES.mkdir(exist_ok=True)
    previous = None
    for version in tags:
        target = CHANGES / f"{version}.md"
        tag = f"v{version}"
        if not target.exists():
            date = git("log", "-1", "--format=%ad", "--date=short", tag).strip()
            if previous is None:
                items = ["The first release."]
            else:
                subjects = git(
                    "log", "--no-merges", "--reverse", "--format=%s", f"{previous}..{tag}"
                )
                items = [s for s in subjects.splitlines() if s and not BOOKKEEPING.match(s)]
                if not items:
                    items = ["A rebuild: nothing changed for users."]
            target.write_text(
                f"{date}\n\n" + "\n".join(f"- {item}" for item in items) + "\n",
                encoding="utf-8",
            )
            print(f"wrote changes/{version}.md ({len(items)})")
        previous = tag
    if not NEXT.exists():
        NEXT.write_text("", encoding="utf-8")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    checking = commands.add_parser("check")
    checking.add_argument("--base")
    commands.add_parser("cut").add_argument("version")
    commands.add_parser("backfill")
    args = parser.parse_args()
    if args.command == "check":
        return check(args.base)
    if args.command == "cut":
        return cut(args.version)
    return backfill()


if __name__ == "__main__":
    sys.exit(main())

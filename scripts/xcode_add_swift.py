#!/usr/bin/env python3
"""Register a new Swift file in the committed Xcode project.

app/ios/Runner.xcodeproj is committed and CI builds from it as-is (it is not
regenerated from project.yml), so a .swift file that exists on disk but not in
project.pbxproj is silently left out of the build. This adds the four entries a
source file needs, by copying the ones of a sibling that is already in the same
folder and target:

    scripts/xcode_add_swift.py app/ios/SchliftWatch/PhoneConnector.swift \\
        app/ios/SchliftWatch/PhoneConnector+Messages.swift

Idempotent: a file that is already registered is left alone. `--check` exits 1
if any tracked Swift file under app/ios is missing from the project.
"""

import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "app/ios/Runner.xcodeproj/project.pbxproj"

# Swift files that are deliberately not in the Runner project.
NOT_IN_PROJECT = ("/Generated/",)


def object_id(seed: str, taken: str) -> str:
    """A 24-hex-digit id, stable for a given file so re-runs produce no diff."""
    candidate = hashlib.sha1(seed.encode()).hexdigest()[:24].upper()
    while candidate in taken:
        candidate = hashlib.sha1(candidate.encode()).hexdigest()[:24].upper()
    return candidate


def add(sibling: Path, new: Path) -> bool:
    if sibling.parent != new.parent:
        sys.exit(f"{new} must be in the same folder as {sibling}")
    if not new.is_file():
        sys.exit(f"{new} does not exist")
    text = PBXPROJ.read_text()
    if f"/* {new.name} */" in text:
        return False

    sib = re.escape(sibling.name)
    build = re.search(
        rf"^\t\t(\w{{24}}) /\* {sib} in Sources \*/ = \{{.*fileRef = (\w{{24}}) .*$", text, re.M
    )
    ref = re.search(rf"^\t\t(\w{{24}}) /\* {sib} \*/ = \{{isa = PBXFileReference;.*$", text, re.M)
    if not build or not ref or build.group(2) != ref.group(1):
        sys.exit(f"could not find {sibling.name} in {PBXPROJ.relative_to(ROOT)}")
    sib_build_id, sib_ref_id = build.group(1), ref.group(1)

    ref_id = object_id(f"ref:{new.name}", text)
    build_id = object_id(f"build:{new.name}", text + ref_id)

    def after(line_pattern: str, new_line: str, source: str) -> str:
        match = re.search(line_pattern, source, re.M)
        if not match:
            sys.exit(f"pattern not found in project: {line_pattern}")
        return source[: match.end()] + "\n" + new_line + source[match.end() :]

    name = new.name
    text = after(
        rf"^\t\t{sib_build_id} /\* {sib} in Sources \*/ = .*$",
        f"\t\t{build_id} /* {name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};",
        text,
    )
    text = after(
        rf"^\t\t{sib_ref_id} /\* {sib} \*/ = \{{isa = PBXFileReference;.*$",
        f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; "
        f'lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};',
        text,
    )
    # The group's children list, then the target's Sources build phase.
    text = after(rf"^\t\t\t\t{sib_ref_id} /\* {sib} \*/,$", f"\t\t\t\t{ref_id} /* {name} */,", text)
    text = after(
        rf"^\t\t\t\t{sib_build_id} /\* {sib} in Sources \*/,$",
        f"\t\t\t\t{build_id} /* {name} in Sources */,",
        text,
    )
    PBXPROJ.write_text(text)
    return True


def check() -> int:
    tracked = subprocess.run(
        ["git", "ls-files", "app/ios/*.swift"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.split()
    text = PBXPROJ.read_text()
    missing = [
        path
        for path in tracked
        if not any(skip in path for skip in NOT_IN_PROJECT)
        and f"/* {Path(path).name} in Sources */" not in text
    ]
    for path in missing:
        print(f"not in project.pbxproj: {path}")
    if missing:
        print("fix: scripts/xcode_add_swift.py <sibling already in the project> <new file>")
        return 1
    print(f"all {len(tracked)} Swift files under app/ios are in the Xcode project")
    return 0


def main() -> int:
    args = sys.argv[1:]
    if args == ["--check"]:
        return check()
    if len(args) < 2:
        print(__doc__)
        return 2
    sibling = (ROOT / args[0]).resolve()
    for arg in args[1:]:
        new = (ROOT / arg).resolve()
        print(("added   " if add(sibling, new) else "present ") + str(new.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

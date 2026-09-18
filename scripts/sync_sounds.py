#!/usr/bin/env python3
"""Mirror app/assets/sounds/sound_*.wav into the two places the OS
notification systems read them from, and keep the Xcode project in step.

    python3 scripts/sync_sounds.py          # copy + patch (make sounds)
    python3 scripts/sync_sounds.py --check  # exit 1 if anything is stale (CI)

  app/assets/sounds/            the source (Flutter asset, used for previews)
  app/android/app/src/main/res/raw/   Android notification channel sounds
  app/ios/Runner/sounds/ + project.pbxproj   iOS notification sounds

A preset id is the file name without `sound_` / `.wav`; the ids the app
offers live in app/copy.yaml (`sounds:`), and this script fails if the two
sets differ, so a sound can't be listed without a file or vice versa.
"""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
SRC = APP / "assets" / "sounds"
RAW = APP / "android" / "app" / "src" / "main" / "res" / "raw"
IOS = APP / "ios" / "Runner" / "sounds"
PBX = APP / "ios" / "Runner.xcodeproj" / "project.pbxproj"
COPY = APP / "copy.yaml"


def source_files() -> list[Path]:
    return sorted(SRC.glob("sound_*.wav"))


def preset_ids(files: list[Path]) -> list[str]:
    return [f.stem[len("sound_"):] for f in files]


def pbx_id(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def render_pbxproj(text: str, files: list[Path]) -> str:
    """Drop every sound_*.wav line, then add one per file in each of the four
    places Xcode wants: build file, file reference, the `sounds` group, and
    the Runner target's resources phase."""
    # Which resources phase held the sounds (there is one per target).
    phases = list(re.finditer(r"isa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \(\n", text))
    holder = None
    for i, m in enumerate(phases):
        end = text.index("\t\t\t);", m.end())
        if "sound_" in text[m.end():end]:
            holder = i
    if holder is None:
        holder = 0
    lines = [l for l in text.split("\n") if "sound_" not in l or ".wav" not in l]
    text = "\n".join(lines)

    build, refs, group, res = [], [], [], []
    for f in files:
        name = f.name
        fid = pbx_id(f"ref:{name}")
        bid = pbx_id(f"build:{name}")
        build.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
        refs.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = audio.wav; path = {name}; sourceTree = \"<group>\"; }};")
        group.append(f"\t\t\t\t{fid} /* {name} */,")
        res.append(f"\t\t\t\t{bid} /* {name} in Resources */,")

    text = text.replace("/* Begin PBXBuildFile section */\n", "/* Begin PBXBuildFile section */\n" + "\n".join(build) + "\n", 1)
    text = text.replace("/* Begin PBXFileReference section */\n", "/* Begin PBXFileReference section */\n" + "\n".join(refs) + "\n", 1)
    m = re.search(r"(/\* sounds \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)", text)
    if not m:
        raise SystemExit("project.pbxproj: no `sounds` group")
    text = text[: m.end()] + "\n".join(group) + "\n" + text[m.end():]
    phases = list(re.finditer(r"isa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \(\n", text))
    m = phases[holder]
    text = text[: m.end()] + "\n".join(res) + "\n" + text[m.end():]
    return text


def main() -> int:
    check = "--check" in sys.argv
    files = source_files()
    if not files:
        raise SystemExit(f"no sound_*.wav under {SRC.relative_to(ROOT)}")
    listed = [str(s["id"]) for s in (yaml.safe_load(COPY.read_text()) or {}).get("sounds", [])]
    have = preset_ids(files)
    missing = sorted(set(listed) - set(have))
    extra = sorted(set(have) - set(listed))
    if missing or extra:
        raise SystemExit(f"copy.yaml sounds and assets/sounds disagree: missing files {missing}, unlisted files {extra}")

    want = {RAW / f.name: f.read_bytes() for f in files} | {IOS / f.name: f.read_bytes() for f in files}
    stale = []
    for target_dir in (RAW, IOS):
        for old in target_dir.glob("sound_*.wav"):
            if old not in want:
                stale.append(("remove", old))
    for path, data in want.items():
        if not path.exists() or path.read_bytes() != data:
            stale.append(("write", path))
    pbx_now = PBX.read_text()
    pbx_new = render_pbxproj(pbx_now, files)
    if pbx_new != pbx_now:
        stale.append(("write", PBX))

    if check:
        for action, path in stale:
            print(f"stale: {action} {path.relative_to(ROOT)}")
        if stale:
            print("run `make sounds`")
            return 1
        print(f"sounds in sync ({len(files)} presets)")
        return 0

    for action, path in stale:
        if action == "remove":
            path.unlink()
        elif path == PBX:
            PBX.write_text(pbx_new)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(want[path])
        print(f"{action} {path.relative_to(ROOT)}")
    print(f"synced {len(files)} sounds")
    return 0


if __name__ == "__main__":
    sys.exit(main())

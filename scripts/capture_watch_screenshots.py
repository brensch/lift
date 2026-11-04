#!/usr/bin/env python3
"""Capture the watch store screenshots from the debug watch apps.

Each scene is a WearWorkoutSnapshot as the phone would send it, its times set
from now, handed to the watch app's debug hook with no phone paired:

    apple  a watchOS simulator: the debug SchliftWatch.app is installed and
           launched with the snapshot in its environment
           (PhoneConnector.applyDebugLaunch). CI runs it:
           .github/workflows/watch-screenshots.yml.
    wear   a Wear OS emulator (or watch) with the debug wear app installed: the
           snapshot goes in by broadcast (DebugSnapshotReceiver), the plates
           open with a tap on the weight.

Writes <out>/<prefix>_NN_<scene>.png: apple_watch_* or wear_*, the names
store/listing.yaml lists. Needs protoc on PATH.

    python3 scripts/capture_watch_screenshots.py apple --udid <sim> \
        --app <path/SchliftWatch.app> --out <dir>
    python3 scripts/capture_watch_screenshots.py wear --serial <adb serial> --out <dir>
"""

from __future__ import annotations

import argparse
import base64
import os
import plistlib
import subprocess
import time
from collections.abc import Callable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BPM = 141
# Seconds from an Apple Watch launch to its screenshot: fonts, the first layout and
# the plate sheet's slide in.
SETTLE = 6
WEAR_ACTIVITY = "com.brensch.schlift.debug/com.brensch.schlift.wear.MainActivity"
WEAR_RECEIVER = "com.brensch.schlift.debug/com.brensch.schlift.wear.DebugSnapshotReceiver"
# The weight on the 454 px round Wear face: a tap there opens the plates.
WEAR_WEIGHT_TAP = (130, 316)

AMBIENT = """ambient_copy {
  min_left: "{n} min" under_a_min: "Under a min" min_over: "+{n} min" rest_until: "till {time}"
}"""

# The phone writes weight and reps either side of a multiplication sign.
TIMES = "\u00d7"

PLATE = {45: "#F44336", 35: "#2196F3", 25: "#FFEB3B", 10: "#4CAF50", 5: "#616161"}


def plates(per_side: list[int]) -> str:
    return "\n".join(
        f'  plates {{ label: "{p}" color_hex: "{PLATE[p]}" size: {p / 45:.3f} }}' for p in per_side
    )


def circles(states: list[str], reps: int) -> str:
    return "\n".join(
        f'circles {{ set_id: "s{i + 1}" text: "{reps}" state: WEAR_CIRCLE_STATE_{s} }}'
        for i, s in enumerate(states)
    )


def bench(
    state: str, label: str, set_no: int, circle_states: list[str], now: int, **times: int
) -> str:
    """Bench Press, set `set_no` of 4: 135 lb for 8, 27 minutes in."""
    fields = "\n".join(f"{k}: {v}" for k, v in times.items())
    return f"""workout_id: "store"
emitted_at: {now * 1000}
state: WORKOUT_STATE_{state}
workout_start_time: {now - 27 * 60}
{fields}
{circles(circle_states, 8)}
you_card {{
  state_label: "{label}"
  yapping_label: "Yapping"
  display_set {{ id: "s{set_no}" exercise: EXERCISE_BENCH_PRESS target_reps: 8 target_weight: 135 }}
  exercise_name: "Bench Press"
  set_line: "Set {set_no} of 4"
  set_text: "135 lb {TIMES} 8"
  weight_text: "135"
  unit_text: "lb"
  reps_text: "8"
{plates([45])}
  plates_text: "45 each side"
  bar_text: "Bar 45 lb"
}}
actions {{ type: WEAR_ACTION_TYPE_END_WORKOUT label: "End workout" }}
{AMBIENT}"""


def squat_plates(now: int) -> str:
    """Squat at 205 lb, the plates open: 45, 25 and 10 a side."""
    return f"""workout_id: "store"
emitted_at: {now * 1000}
state: WORKOUT_STATE_LIFTING
workout_start_time: {now - 12 * 60}
lifting_started_at: {now - 9}
{circles(["FULL", "LIFTING", "PENDING", "PENDING", "PENDING"], 5)}
you_card {{
  state_label: "Lifting"
  yapping_label: "Yapping"
  display_set {{ id: "s2" exercise: EXERCISE_SQUAT target_reps: 5 target_weight: 205 }}
  exercise_name: "Squat"
  set_line: "Set 2 of 5"
  set_text: "205 lb {TIMES} 5"
  weight_text: "205"
  unit_text: "lb"
  reps_text: "5"
{plates([45, 25, 10])}
  plates_text: "45 · 25 · 10 each side"
  bar_text: "Bar 45 lb"
}}
actions {{ type: WEAR_ACTION_TYPE_END_WORKOUT label: "End workout" }}
{AMBIENT}"""


def scenes() -> list[tuple[str, Callable[[int], str], bool]]:
    """(name, snapshot text from now, plates open), in listing order. Each is made
    when it is shown, so its timers read as written here."""
    return [
        (
            "01_active_set",
            lambda now: bench(
                "LIFTING",
                "Lifting",
                2,
                ["FULL", "LIFTING", "PENDING", "PENDING"],
                now,
                lifting_started_at=now - 21,
            ),
            False,
        ),
        (
            "02_rest_timer",
            lambda now: bench(
                "RESTING",
                "Resting",
                3,
                ["FULL", "FULL", "NEXT", "PENDING"],
                now,
                rest_until=now + 102,
                last_set_ended_at=now - 78,
            ),
            False,
        ),
        ("03_plates", squat_plates, True),
    ]


def encode(text: str) -> str:
    raw = subprocess.run(
        [
            "protoc",
            f"--proto_path={ROOT / 'proto'}",
            "--encode=workout.v1.WearWorkoutSnapshot",
            "workout/v1/wearable.proto",
        ],
        input=text.encode(),
        capture_output=True,
        check=True,
    ).stdout
    return base64.b64encode(raw).decode()


def capture_apple(udid: str, app: Path, out: Path) -> None:
    bundle = plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"]
    subprocess.run(["xcrun", "simctl", "install", udid, str(app)], check=True)
    for name, snapshot, open_plates in scenes():
        subprocess.run(["xcrun", "simctl", "terminate", udid, bundle], check=False)
        env = dict(os.environ)
        # The watch counts on its wall clock: times from when the screenshot is taken.
        env["SIMCTL_CHILD_SCHLIFT_SNAPSHOT"] = encode(snapshot(int(time.time()) + SETTLE))
        env["SIMCTL_CHILD_SCHLIFT_BPM"] = str(BPM)
        env["SIMCTL_CHILD_SCHLIFT_PLATES"] = "1" if open_plates else "0"
        subprocess.run(["xcrun", "simctl", "launch", udid, bundle], env=env, check=True)
        time.sleep(SETTLE)
        path = out / f"apple_watch_{name}.png"
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(path)], check=True)
        print(f"wrote {path}")


def capture_wear(serial: str, out: Path) -> None:
    adb = [os.environ.get("ADB", "adb"), "-s", serial]
    for name, snapshot, open_plates in scenes():
        subprocess.run([*adb, "shell", "am", "force-stop", "com.brensch.schlift.debug"], check=True)
        subprocess.run([*adb, "shell", "am", "start", "-n", WEAR_ACTIVITY], check=True)
        time.sleep(3)
        # Wear counts on from the snapshot's emitted_at, so now is the moment.
        text = snapshot(int(time.time()))
        # Sent twice: the emulator's sensor reads 0 once a set starts.
        for _ in range(2):
            subprocess.run(
                [
                    *adb,
                    "shell",
                    "am",
                    "broadcast",
                    "-n",
                    WEAR_RECEIVER,
                    "--es",
                    "snapshot",
                    encode(text),
                    "--ef",
                    "bpm",
                    str(BPM),
                ],
                check=True,
                capture_output=True,
            )
            time.sleep(1.5)
        if open_plates:
            x, y = WEAR_WEIGHT_TAP
            subprocess.run([*adb, "shell", "input", "tap", str(x), str(y)], check=True)
            time.sleep(2)
        path = out / f"wear_{name}.png"
        path.write_bytes(
            subprocess.run(
                [*adb, "exec-out", "screencap", "-p"], capture_output=True, check=True
            ).stdout
        )
        print(f"wrote {path}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("platform", choices=["apple", "wear"])
    parser.add_argument("--out", type=Path, default=ROOT / "store" / "screenshots" / "raw")
    parser.add_argument("--udid", help="apple: the booted watchOS simulator")
    parser.add_argument("--app", type=Path, help="apple: the built debug SchliftWatch.app")
    parser.add_argument("--serial", help="wear: the adb serial of the watch")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if args.platform == "apple":
        if not args.udid or not args.app:
            parser.error("apple needs --udid and --app")
        capture_apple(args.udid, args.app, args.out)
    else:
        if not args.serial:
            parser.error("wear needs --serial")
        capture_wear(args.serial, args.out)


if __name__ == "__main__":
    main()

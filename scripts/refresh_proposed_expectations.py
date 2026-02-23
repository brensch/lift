#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFIX = "__PROPOSED_EXPECT__ "


DEFAULTS = [
    ("test_linear_5x5_progression", ROOT / "src/regimes/scenarios/linear_5x5.json"),
    ("test_gzclp_progression", ROOT / "src/regimes/scenarios/gzclp.json"),
    ("test_wendler_531_progression", ROOT / "src/regimes/scenarios/wendler_531.json"),
]


def run_test_and_collect(test_name: str):
    env = os.environ.copy()
    env["LIFT_SNAPSHOT_PROPOSED"] = "1"
    cmd = ["cargo", "test", test_name, "--", "--nocapture"]
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
    )
    output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    snapshots = []
    for line in output.splitlines():
        if line.startswith(PREFIX):
            payload = json.loads(line[len(PREFIX) :])
            snapshots.append(payload)
    if proc.returncode != 0:
        sys.stderr.write(output)
        raise SystemExit(f"{test_name} failed; aborting expectation refresh")
    if not snapshots:
        raise SystemExit(f"{test_name} produced no proposal snapshots")
    return snapshots


def patch_scenario(path: Path, snapshots):
    with path.open() as f:
        scenario = json.load(f)

    workout_idxs_with_get_proposed = [
        idx for idx, w in enumerate(scenario.get("workouts", [])) if "get_proposed" in w
    ]
    if len(workout_idxs_with_get_proposed) != len(snapshots):
        raise SystemExit(
            f"{path}: snapshot count mismatch. scenario has {len(workout_idxs_with_get_proposed)} "
            f"get_proposed checkpoints, got {len(snapshots)} snapshots"
        )

    for idx, snapshot in zip(workout_idxs_with_get_proposed, snapshots):
        workout = scenario["workouts"][idx]
        workout.setdefault("get_proposed", {})
        workout["get_proposed"]["expect"] = snapshot["expect"]

    with path.open("w") as f:
        json.dump(scenario, f, indent=2)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(
        description="Refresh full get_proposed expectations in scenario JSON files by running harness tests."
    )
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        help="Test name to refresh (repeatable). Defaults to all harness scenario tests.",
    )
    args = parser.parse_args()

    selected = set(args.only) if args.only else None
    targets = [t for t in DEFAULTS if selected is None or t[0] in selected]
    if not targets:
        raise SystemExit("No matching tests selected")

    for test_name, scenario_path in targets:
        print(f"[run] {test_name}")
        snapshots = run_test_and_collect(test_name)
        print(f"[patch] {scenario_path} ({len(snapshots)} checkpoints)")
        patch_scenario(scenario_path, snapshots)

    print("Done.")


if __name__ == "__main__":
    main()

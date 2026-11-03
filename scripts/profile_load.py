#!/usr/bin/env python3
"""Profile the server under a load-test profile, and print where its CPU went.

Builds the server with line tables, runs it under samply (a sampling
profiler), drives it with the load harness, then prints the functions with
the most CPU: by self time and inclusive of what they call. With --callers,
also the call paths into one function. See docs/testing/load.md.

    scripts/profile_load.py [--profile smoke|scale] [--callers NAME]

Needs samply (`cargo install samply --locked`) and, on Linux,
`kernel.perf_event_paranoid` at 1 or lower.
"""

from __future__ import annotations

import argparse
import bisect
import collections
import gzip
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Iterator
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".tmp" / "profile"
PORT = 50177
ORIGIN = "http://localhost:5173"


def run_profile(profile: str, extra: list[str]) -> Path:
    env = {**os.environ, "CARGO_PROFILE_RELEASE_DEBUG": "line-tables-only"}
    subprocess.run(
        ["cargo", "build", "--release", "-p", "schlift", "-p", "schlift-load"],
        cwd=ROOT,
        env=env,
        check=True,
    )
    shutil.rmtree(OUT, ignore_errors=True)
    data = OUT / "data"
    data.mkdir(parents=True)
    trace = OUT / "profile.json.gz"
    server_env = {
        **os.environ,
        "DATA_DIR": str(data),
        "PORT": str(PORT),
        "RUST_LOG": "warn",
        "WEBAUTHN_RP_ID": "localhost",
        "WEBAUTHN_RP_ORIGIN": ORIGIN,
    }
    server_env.pop("MIN_APP_VERSION", None)
    with (data / "server.log").open("w") as log:
        sampler = subprocess.Popen(
            [
                "samply",
                "record",
                "--save-only",
                "--unstable-presymbolicate",
                "-o",
                str(trace),
                "--",
                str(ROOT / "target/release/schlift"),
            ],
            cwd=ROOT,
            env=server_env,
            stdout=log,
            stderr=log,
        )
        try:
            wait_for_server(sampler)
            subprocess.run(
                [
                    str(ROOT / "target/release/schlift-load"),
                    "--profile",
                    profile,
                    "--server",
                    f"http://127.0.0.1:{PORT}",
                    "--out",
                    str(OUT),
                    *extra,
                ],
                cwd=ROOT,
                check=False,
            )
        finally:
            # samply writes the profile once the server it runs has exited.
            server = subprocess.run(
                ["pgrep", "-P", str(sampler.pid)], capture_output=True, text=True
            ).stdout.split()
            for pid in server:
                os.kill(int(pid), signal.SIGINT)
            sampler.wait()
    if not trace.exists():
        sys.exit(f"no profile written; see {data / 'server.log'}")
    return trace


def wait_for_server(sampler: subprocess.Popen) -> None:
    for _ in range(100):
        if sampler.poll() is not None:
            sys.exit(f"samply stopped; see {OUT / 'data' / 'server.log'}")
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{PORT}", timeout=1)
            return
        except urllib.error.HTTPError:
            return
        except OSError:
            time.sleep(0.2)
    sys.exit("the server did not start")


class Symbols:
    """Addresses to function names, from samply's presymbolicated sidecar."""

    def __init__(self, path: Path) -> None:
        sidecar = json.loads(path.with_suffix("").with_suffix(".json.syms.json").read_text())
        self.names = sidecar["string_table"]
        self.libs = {}
        for lib in sidecar["data"]:
            table = sorted((e["rva"], e["size"], e["symbol"]) for e in lib["symbol_table"])
            self.libs[lib["debug_name"]] = ([rva for rva, _, _ in table], table)

    def name(self, lib: str, address: int) -> str:
        if lib not in self.libs:
            return f"{lib}+{address:x}"
        starts, table = self.libs[lib]
        i = bisect.bisect_right(starts, address) - 1
        if i < 0:
            return f"{lib}+{address:x}"
        start, size, symbol = table[i]
        return self.names[symbol] if address < start + size + 64 else f"{lib}+{address:x}"


def short(name: str) -> str:
    """A Rust symbol without its hash, and generic arguments cut to their last segment."""
    name = re.sub(r"::h[0-9a-f]{16}$", "", name)
    for _ in range(6):
        name = re.sub(
            r"<([^<>]*)>",
            lambda m: "{" + m.group(1).split(" as ")[-1].split("::")[-1] + "}",
            name,
        )
    return name[-120:]


def samples(profile: dict, symbols: Symbols) -> Iterator[tuple[list[str], int]]:
    """Every sample's stack, innermost first, with the CPU it took."""
    for thread in profile["threads"]:
        frames, funcs, stacks = thread["frameTable"], thread["funcTable"], thread["stackTable"]
        libs = [
            profile["libs"][lib]["debugName"] if lib is not None else "?"
            for lib in thread["resourceTable"]["lib"]
        ]
        names = []
        for func, address in zip(frames["func"], frames["address"], strict=True):
            resource = funcs["resource"][func]
            lib = libs[resource] if resource is not None and resource >= 0 else "?"
            names.append(short(symbols.name(lib, address)))
        cpu = thread["samples"].get("threadCPUDelta") or [1] * thread["samples"]["length"]
        for index, weight in zip(thread["samples"]["stack"], cpu, strict=True):
            stack = []
            while index is not None:
                stack.append(names[stacks["frame"][index]])
                index = stacks["prefix"][index]
            if stack and weight:
                yield stack, weight


def summarise(trace: Path, callers_of: str | None, top: int) -> None:
    with gzip.open(trace) as f:
        profile = json.load(f)
    own: collections.Counter[str] = collections.Counter()
    total_in: collections.Counter[str] = collections.Counter()
    paths: collections.Counter[str] = collections.Counter()
    total = 0
    for stack, weight in samples(profile, Symbols(trace)):
        total += weight
        own[stack[0]] += weight
        for name in set(stack):
            total_in[name] += weight
        if callers_of:
            for i, name in enumerate(stack):
                if callers_of in name:
                    paths[" <- ".join(stack[i + 1 : i + 7])] += weight
                    break
    if not total:
        sys.exit("no samples")

    def show(title: str, counts: collections.Counter[str], width: int = 160) -> None:
        print(f"\n== {title}")
        for name, weight in counts.most_common(top):
            print(f"{100 * weight / total:5.1f}%  {name[:width]}")

    show("self", own)
    show("inclusive", total_in)
    if callers_of:
        show(f"callers of {callers_of}", paths, 400)
    print(f"\nprofile: {trace} (open with `samply load {trace}`)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", default="smoke", help="the load-test profile")
    parser.add_argument("--callers", help="also show the call paths into this function")
    parser.add_argument("--top", type=int, default=40, help="rows per table")
    parser.add_argument(
        "--only-summarise", type=Path, help="summarise this profile instead of making one"
    )
    args, extra = parser.parse_known_args()
    trace = args.only_summarise or run_profile(args.profile, extra)
    summarise(trace, args.callers, args.top)
    return 0


if __name__ == "__main__":
    sys.exit(main())

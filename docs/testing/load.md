# Load testing

`make loadtest` starts a fresh release server and runs lightweight clients
against it. Each client is the real phone stack minus the UI: the phone's own
core (`schlift_native`'s `Store`), signing up and in with a software passkey,
syncing the way `app/lib/services/account_sync.dart` does. The code is in
`loadtest/`.

## What a client does

Every client is set up before anything is measured, a few dozen at a time:

1. **Signs up** with a real WebAuthn ceremony (`webauthn-authenticator-rs`'s
   software passkey), then **signs in** again with it.
2. **Onboards** through the core and, in a profile with `history_weeks`,
   **records that many weeks of training** first (`schlift_testkit`: a
   seeded lifter training through the phone's own store, three workouts a
   week) — an account the size real ones grow to.
3. **Opens the Sync stream** (saying what it holds, as the phone does) and
   sends everything, in pieces, until the server has placed it all
   (`sync.restore`).

Then the run proper, timed from here:
4. Some clients **train in groups of three**: the first shares its invite token,
   the others join through it, so each one's workout events go to the other
   two, folded there (`core.partner`).
5. **Watchers** (a profile's `watchers` share) only keep the app open:
   connected, heartbeating, never training.
6. The rest **train** until the run ends: a workout from home's suggestion, each set
   started and done with a tap each, the calibration ramp's question answered,
   heart rate every few seconds, ended when the plan runs out. Every write
   pushes what is still pending, and the server's placed events come back
   down into the client's `Store`; between pushes it heartbeats.
   After each workout it asks for what the website shows (`ListWorkoutSummaries`),
   which the server answers from its own fold.
7. **Drains**: waits until nothing is pending and it holds the server's head,
   then hangs up.

Each client sends `x-forwarded-for` with its own address, since the server
limits passkey ceremonies per address and every load client is really
127.0.0.1.

## What a run checks

- **Every account matches**: each client's events are read back from the
  server (a Sync stream opened from seq 0) and must be the same events, in
  order. This is exact, so it is the
  check that catches sync bugs at scale.
- **Nothing errors**: any failed call, dropped stream or stopped client fails
  the run.
- **Not clearly slower than a baseline**, when `loadtest/baseline-<profile>.json`
  exists. The run fails if an operation's p95 is up by half plus 5 ms, or the
  server's CPU per event or peak memory is up by half.

The report, with p50/p95/p99/max per operation and the server's CPU, memory
and database size, is written to `.tmp/loadtest/report-<profile>.json`. To
make a run the new baseline, copy its report over the baseline file.

## Profiles

| Profile | Clients | Run | Use |
|---|---|---|---|
| `smoke` | 40 | about a minute | before a push; CI runs it on debug builds for correctness only |
| `scale` | 1000 | about four minutes | before a release, and after anything on the sync or storage path |
| `long` | 400, each with 52 weeks of history, half only watching | about ten minutes | after anything that reads accounts: the server holds none in memory, so this is what a year-old account costs it |

`LOAD_ARGS` adds flags: `--clients`, `--seconds`, `--connections`, or
`--server <url>` to aim at a server that is already running (no CPU or memory
figures then).

```sh
make loadtest
make loadtest LOAD_PROFILE=scale
make loadtest LOAD_ARGS="--clients 3000 --seconds 300"
```

Rests are compressed (a set every few seconds rather than every few minutes),
so a client generates far more writes than a person does. 1000 load clients
is a heavier write load than several thousand real people training at once.

## Numbers

On the dev machine (16 cores, other work running), committed as the
baselines:

| | smoke (40 clients) | scale (1000 clients) |
|---|---|---|
| Accounts matching the server | 40 / 40 | 1000 / 1000 |
| Push placed and back, p50 / p95 / p99 | 1.8 / 2.6 / 3.7 ms | 1.9 / 17 / 74 ms |
| Website read (`ListWorkoutSummaries`), p95 | 1.7 ms | 12 ms |
| Server CPU, whole run (per event) | 2.2 s (1.5 ms) | 57 s (1.3 ms) |
| Server memory, peak | 26 MB | 64 MB |

A workout's heart rate is one event, recorded when it ends, so compare runs
by the CPU of the whole run as well as per event. The same scale run before
events were facts took 123 s of CPU over 69,550 events.

`long` with 300 clients, each with a year of history (1.8 million events,
1.8 GB on disk): every account matches; pushes 2.3 / 58 ms (p50 / p95);
the website's read of a year-old account, folded on request, 51 / 156 ms;
server memory at most 324 MB, during setup; 222 s of CPU. With a 256-account
cache the server held 686 MB for the same; without one, but still folding
partners' status on the server for every set, pushes took 27 s at p95.

Before storage followed authority (v0.14.1), the same server rewrote each
workout's readable tables and partners' cached status on every push, in one
transaction on the single write connection. It passed smoke, but at 1000
clients pushes queued past the pool's 30 s acquire timeout: p95 push
acknowledgement was 21.6 s and 411 clients lost their Sync stream.

## Profiling

`make loadtest-profile` (with `LOAD_PROFILE`/`LOAD_ARGS` as above) builds the
server with line tables, runs it under [samply](https://github.com/mstange/samply),
drives it with the harness and prints where its CPU went: the functions with
the most self time and the most inclusive time. `scripts/profile_load.py
--only-summarise .tmp/profile/profile.json.gz --callers <name>` reads the
same profile again and adds the call paths into one function; `samply load`
opens it in the Firefox profiler. It needs `cargo install samply --locked`
and, on Linux, `kernel.perf_event_paranoid` at 1 or lower (`echo 1 | sudo tee
/proc/sys/kernel/perf_event_paranoid`, until the next boot).

What it found when events became facts: every push woke every open stream
(one broadcast of all changes, each stream filtering for its own), a third
of the server's CPU at 1000 clients. Changes now go only to the streams they
concern (`src/db/changes.rs`).

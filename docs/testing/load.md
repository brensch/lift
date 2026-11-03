# Load testing

`make loadtest` starts a fresh release server and runs lightweight clients
against it. Each client is the real phone stack minus the UI: the phone's own
core (`schlift_native`'s `Store`), signing up and in with a software passkey,
syncing the way `app/lib/services/account_sync.dart` does. The code is in
`loadtest/`.

## What a client does

1. **Signs up** with a real WebAuthn ceremony (`webauthn-authenticator-rs`'s
   software passkey), then **signs in** again with it.
2. **Onboards** through the core, then opens the Sync stream (saying what it
   holds, as the phone does) and pushes.
3. Some clients **train in groups of three**: the first shares its invite token,
   the others join through it, so session updates fan out.
4. **Trains** until the run ends: a workout from home's suggestion, each set
   started and done with a tap each, the calibration ramp's question answered,
   heart rate every few seconds, ended when the plan runs out. Every write
   pushes what is still pending, and the server's placed events come back
   down into the client's `Store`; between pushes it heartbeats.
   After each workout it asks for what the website shows (`ListWorkoutSummaries`),
   which the server answers from its own fold.
5. **Drains**: waits until nothing is pending and it holds the server's head,
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
| Push placed and back, p50 / p95 / p99 | 2.1 / 3.8 / 5.9 ms | 2.2 / 4.8 / 14.7 ms |
| Website read (`ListWorkoutSummaries`), p95 | 1.9 ms | 2.2 ms |
| Server CPU, whole run (per event) | 3.4 s (2.4 ms) | 102 s (2.4 ms) |
| Server memory, peak | 24 MB | 71 MB |

A workout's heart rate is one event, recorded when it ends, so a run has
far fewer events than before; compare runs by the CPU of the whole run as
well as per event. The same scale run before events were facts took 123 s
of CPU over 69,550 events.

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

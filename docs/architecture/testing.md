# Testing

The rules live in one place, the Rust core, so that is where most of the
testing is. Each layer catches something the others cannot.

```mermaid
graph TD
    A["Core unit tests<br/>the plan, session outcomes, classes, volume, reducer"] --> B["Core API tests<br/>core/tests/api.rs — the app's calls end to end"]
    B --> C["Invariant fuzzer<br/>core/examples/fuzz.rs — randomised sequences"]
    B --> D["Server + store tests<br/>sync, multiplayer, deletion, the phone's file"]
    B --> E["Dart tests<br/>providers against the host build of the core"]
    D --> F["E2E scenarios<br/>headless Linux app + backend + API peers"]
```

```bash
cargo test --workspace --all-targets   # core + server
make test-app                          # host build of app/native, then flutter test
make fuzz-api                          # randomised sequences, random seed
make fuzz-api-ci                       # the fixed-seed run CI uses
make e2e                               # e2e scenarios, side by side
```

## Core unit tests — the engine

Pure and fast, inline in their modules under `core/src/`:

- `plan.rs` — the walk and the plan: a set's Epley estimate with reserve
  and fatigue, a hit nudging the max a rep up, stepping up past the top of
  the range, a miss resetting the max to what the sets showed, a lowered
  weight and stopping early holding it, time off after a hit, a lift never
  done, the missed rung giving the max, an override as a new start,
  bodyweight rep maxes, rounding down giving an extra rep before a plate;
  the set allocation (the budget, the 2-set floor, the 5-set cap, the
  weekly deficit, override sets kept) and learned timings replacing the
  defaults at ten samples.
- `exercise_progress.rs` — what a session says about a lift: sets in the
  order done and judged by their own targets, a rushed miss or an undone
  working set stopping it early, rungs apart and warmups left out.
- `exercise_catalog.rs` — every exercise is classified (the scan is pinned,
  so a `_ =>` fallback cannot quietly misfile a new lift), the class rules,
  plate snapping.
- `volume.rs` — the 7-day window, primary/secondary weighting, and the
  suggestion: recovered muscles only, a template whose first lift is
  recovering left out (and the one back soonest when every one is), the
  20% tie and the least recent, the fallback, reserves left out.
- `rotation.rs` — the rotation check: each warning (gap, overlap, too
  few), the sets a lap counts, and what a reserve or library entry
  would add (the primary muscles the lap misses).
- `workout/reducer.rs`, `workout/planning.rs` — set transitions, rest,
  calibration rungs (climb, settle, re-settle) and the weight log entries
  they make; warmup ladders.
- `template_library.rs`, `onboarding.rs`, `progress.rs`, `recovery.rs`,
  `weight_units.rs`.

## Core API tests — the seams between calls

`core/tests/api.rs` drives the account through `Call` and `View` exactly as
the app does: onboard → home → start-from-template → complete → end → the
next plan follows from the session. Each reason (and the plan against last
time first), time away cutting the max,
an override as a new start, the budget setting the sets (and "needs N
min"), Home's preview equal to a start at the same moment and budget and
to the template editor's `GetTemplatePlan`, a Clone saved unchanged, an
added lift fitting around the planned ones, a started workout following
its recorded decision whatever the rules say now, a lift without its
decision refused, every weight-log cause, the ramp, and the kg path live
here, because they only appear **between** two calls.

**Every test also checks that replaying its recorded events rebuilds exactly
the same account** — the property the phone and the server both rely on.

## Progression scenarios and the rotation

`core/tests/progression_scenarios.rs` drives scripted lifters through the
API and writes what they were told to `testdata/progression_scenarios.json`
(`make progression-explorer` rewrites it and builds the explorer page).
Its rotation run onboards Full Body, Upper, Lower and StrongLifts A and B
into the rotation and for three weeks (Mon, Wed, Thu, Sat) starts whatever
Home suggests, doing every set; each day's pick, reason and every
template's score go in the snapshot, and the explorer's Rotation tab draws
them as a calendar and a timeline beside the rotation check. The test
fails if a template is suggested two training days running while another
had rested muscles behind, if one is suggested while its first lift's
muscle is recovering and another was ready, or if Full Body takes over
40% of the days. A rotation template never suggested is flagged as info:
a short template whose muscles a bigger one also trains (StrongLifts B
beside Lower and Full Body) rarely comes within a fifth of its score.

## Invariant fuzzer

`core/examples/fuzz.rs` runs the core in-process, as the phone does, with
several simulated users driving randomised but realistic sequences —
onboard, set overrides, start from a template or an exercise list in a
random budget, start and complete sets, skip warmups, delete and edit done
sets, add/adjust/remove/reorder exercises, end the workout (sometimes
twice).

After **every mutation** it re-reads the workout and asserts, among others:

| Invariant | Catches |
|---|---|
| Completed sets reference an existing proposed set, at most one each | Orphans, double completion |
| `workout_order` is unique among live sets | The "sets jump around" class of bug |
| `next_up_set` is one of the workout's sets and not already done | Bad next-up derivation |
| A start records exactly Home's preview at that moment and budget, and the workout is its recorded decisions laid out | Plans that drift between screens, a fold that plans |
| An override is the lift's next plan | Overrides lost or ignored |
| At most six calibration rungs per exercise | Runaway ramps |
| A done set has `ended_at`, wasn't started after it ended, rests after it ended | Time faults |
| Weights finite and non-negative, reps non-negative | Arithmetic and rounding faults |
| No active workout after `EndWorkout`; a re-fired `EndWorkout` changes no plan | Leaks, a session counted twice |

And after each user: **replaying the event log rebuilds the account**.

```bash
make fuzz-api                                   # random seed
make fuzz-api FUZZ_USERS=20 FUZZ_SESSIONS=25    # heavier
cargo run --release -p schlift-core --example fuzz -- --seed 42   # replay a failure
```

A failure groups violations by invariant and prints the seed to reproduce it.
Exit status is non-zero, so it gates CI (`make fuzz-api-ci`, the `fuzz` job
in `tests.yml`).

**Validate the validator.** "No violations" only means something if the
fuzzer can fail. When adding an invariant, break the code deliberately and
confirm it trips.

## Server tests

- `src/server/sync_tests.rs` — pushed events fold into the same account, a
  resent batch is placed once, two devices' events are placed in the order
  they arrive, a push after the account is deleted stores nothing, events
  read back as they were pushed; and over a real server on a local port: a
  partner's progress arrives as it happens, a late partner gets the workout
  so far and only the workout, discarding the workout leaves the session, a
  heartbeat is answered, a deleted account cannot push again, a signed-out
  stream is sent nothing more, a deleted partner leaves the others'
  session, a new profile reaches partners without the body weight, a device
  catches up and hears the others, a stranger is turned away.
- `src/server/multiplayer_tests.rs` — the session roster and
  training-together history through the real handlers.
- `src/db/auth.rs` — every table with a `user_id` column references
  `users(id) ON DELETE CASCADE` (discovered from the schema, so a new table
  can't be missed), deleting an account leaves nothing of it and touches no
  one else, logins are stored hashed and expired ones cleared.
- `src/db/migrate.rs` — a fresh database starts at the latest version, a
  database from before versions is converted (users out of their blob,
  admins, live logins hashed, dead ones and orphaned events dropped, stale
  session memberships closed, the old tables gone), and step two refuses
  events not yet converted to facts.
- `core/tests/stored_events.rs` — one of every fact, as stored
  (`core/tests/testdata/stored_events.json`), still reads and writes back
  the same: no field renamed or removed. A new fact must be added there.
- `testkit/tests/golden.rs` — twelve weeks of a seeded lifter's training, as
  stored (`testkit/tests/testdata/golden_events.json.zst`), still fold to
  the same account, read as the app reads it (home, workouts, progress,
  settings: `golden_views.json`). `GOLDEN=views` rewrites the views to
  review a deliberate change in the diff. The lifter (`schlift_testkit`)
  trains through the phone's own store; the load test's clients use it too.
- `core/src/session.rs` — a session partner's phone, holding only their
  workout's events, sees exactly what their own screen shows (in pounds and
  kilos); only workout facts are shared; a partner goes off show after
  ending or going idle.
- `src/server/sync_tests.rs` (`stream`) — a partner's sets reach the others
  as events as they happen; one who opens the app mid-workout gets the
  workout so far; heart rate and the rest of an account never leave it.
- `src/server/auth.rs` — the `test-auth` gate on `TestLogin`, both branches.
- `src/demo_seed.rs` — the demo users seed (`test-auth`), and the walk over
  their history rises.
- `app/native/src/store.rs` — the phone's file: a reopened file is the same
  account, someone else's file is refused, its own events leave `pending`
  once placed, another device's go first and its own replay after, what the
  server lacks is offered again, heart rate is gathered and recorded once
  when the workout ends, a file from before facts drops its events
  for the server to resend, an export opens as the same account.

## Dart tests — against the real core

There is no Dart copy of the rules and no parity fixtures. The Dart tests run
the real core: `app/test/support/provider_harness.dart` loads the host build
of `app/native` from `target/debug/` and gives each test an in-memory
account. So `cargo build -p schlift_native` must run first — `make test-app`
does it, and so does CI before `flutter test`.

Most of them run on the harness; a few need no core at all.

- `test/providers/` — the providers as views over the core: the workout
  (start, done/undo taps, warmups, ending and the next plan on Home, the
  session recorded once, a ramp question not asked again after a reload),
  settings (the unit read back, every plate coloured in either unit), and
  auth with no server (a saved session published at once, what sign-out
  and a lapsed session keep).
- `test/services/` — the watch snapshot and the coordinator's sign-out,
  page tracking.
- `test/screens/`, `test/widgets/` — real screens and widgets on the
  harness: Home's rotation and time control, the template editor, the
  status box, the ramp question dialog, the partner ticker, the heart-rate
  chart's labels.
- `test/logic/` — display helpers and the "who lifts next" rules.
- `test/tutorial/`, `test/grpc_recovery_test.dart` — the tutorial's seen
  flag, and retrying a read after a reconnect.
- `test/screenshots/` — real screens at phone size
  ([`docs/testing/app-harness.md`](../testing/app-harness.md)).

## E2E scenarios

`make e2e` runs the real app, built once for Linux and run headless, many
scenarios at once, against a local backend
([`docs/testing/e2e-scenarios.md`](../testing/e2e-scenarios.md)). Partners are
*API peers* (`app/integration_test/support/api.dart`) that act like phones:
each has its own in-memory core, records events on it and pushes them over
`Sync`. A peer logged in as the app's own user only reads, so what the app
shows is the app's own doing.

## Where coverage is thin

- **Wearable protocol** is untested end to end; the watch companions have no
  automated tests.
- **The fuzzer is single-account.** Multiplayer is covered by the server
  tests and e2e scenarios, not by randomised sequences.

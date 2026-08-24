# Proposal: Composable Workouts

Status: proposal. Not implemented.

This document tells you how to remove the program state machine from
Schlift. It tells you what to delete, what to add, and in which order.

Write the code in the order of [7. Work phases](#7-work-phases). Do not keep
the old model and the new model at the same time.

## 1. Summary

Today the server selects your workout. You select a program (Linear 5x5,
GZCLP or Wendler 5/3/1). The program is a state machine. It holds a state
record for you. It proposes the next session from that state. It moves the
state forward when you complete the session.

After this change, you select your workout. You make templates. A template
is a list of exercises. You start a workout from a template.

The server keeps one weight for each exercise type. The weight goes up when
you complete the work. This is the only progression rule.

| Property | Today | After |
|---|---|---|
| Who selects the session | The program | The user |
| Setup steps before the first workout | Select a program, then set 5 to 12 program fields | Select units |
| Progression scope | The 5 lifts the program prescribes | Every exercise |
| Progression rules | 3 regimes, each different | 1 rule |
| Server state for a user | Program state record (untyped key-value) | One weight for each exercise |
| Backend code | About 7200 lines for programs | About 1500 lines for templates and trackers |

The change deletes about 12 900 lines of code and adds about 3750. The net
result is about 9150 fewer lines. It also deletes a 25 400-line test data
file. See [10. Sizes](#10-sizes).

## 2. Terms

Use these terms in code, in the proto files, and in the user interface. One
term has one meaning.

| Term | Meaning |
|---|---|
| Exercise | One movement type. An entry in the `Exercise` enum. Example: Squat. |
| Set | One performance of one exercise. |
| Exercise group | One or more exercises that you do together. The existing `ExerciseGroup` message. |
| Template | A named plan for one workout. It holds exercise groups. It holds no weights. |
| Workout | One training session. You start it from a template. |
| Tracker | The weight, the rep target and the set count for one exercise, for one user. |
| Progression | The rule that changes a tracker after a workout. |

Do not use these words after the change: regime, schplanner, program state,
phase, cycle, stage, tier, slot.

## 3. The design

### 3.1 A template holds structure. A tracker holds weight.

This is the most important rule in this document.

A template holds the exercises, the group order, the set count, the rep
target, the rest times, and the warmup flag. A template holds no weight.

A tracker holds the weight. There is one tracker for each exercise, for each
user. All templates that contain Squat use the same Squat tracker.

The server joins the two when you start a workout:

```
StartWorkout(template_id)
  for each exercise group in the template:
    for each exercise in the group:
      weight = tracker(user, exercise).working_weight
      make the working sets
      make the warmup sets            (existing generate_sets_for_group)
  write the proposed sets
```

Result: you increase your squat one time. Every template that contains
Squat shows the new weight.

Do not put a weight in a template. A weight in a template makes a second
source of truth. Two templates then disagree about your squat.

### 3.2 One progression rule

The rule is in `src/exercise_progress.rs`. The code exists. It is tested.

After you complete a workout, the server examines each exercise:

| Condition | Action |
|---|---|
| You completed every planned set at the rep target | Add one equipment step |
| You missed the rep target | Keep the weight |
| You missed the rep target two times, one after the other | Subtract 10 percent |
| The exercise has no load (bodyweight) | Keep the weight at zero |

`src/exercise_catalog.rs` gives the equipment step for each exercise. A
barbell step is 5 lb or 2.5 kg. A dumbbell step is 5 lb or 2 kg. The server
rounds the result to a weight that you can load.

### 3.3 Defaults

Ship 6 default templates as data, not as code:

- Full Body A, Full Body B
- Upper, Lower
- Push, Pull, Legs

Copy the defaults into the user's own templates at first sign-in. The user
can then edit them or delete them. Do not make the defaults read-only. Do
not give them special behaviour.

### 3.4 What the home screen becomes

The home screen shows a list of templates. Each template shows its
exercises and the weights from the trackers.

1. The user selects a template.
2. The user starts the workout, or edits the template first.

There is also an empty workout. The user starts it and adds exercises
during the session.

Remove the readiness banner controls that select or change the next
session. Keep the muscle recovery display (see [Decision 2](#decision-2-keep-muscle-recovery)).

## 4. Delete this

### 4.1 Rust

| Path | Lines | Note |
|---|---:|---|
| `src/regimes/` | 3531 | All 3 regimes, the trait, the simulator |
| `src/regimes/scenarios/` | — | 4 JSON scenarios, the refresh script, the visualiser |
| `src/schplanner.rs` | 691 | Proposal input, slot outcomes |
| `src/schplanner_tests.rs` | 492 | |
| `src/scenario_tests.rs` | 346 | |
| `src/program_state.rs` | 355 | Untyped key-value state |
| `src/onboarding.rs` | 66 | Rewrite. See [5.4](#54-onboarding) |
| `src/server/training.rs` | 663 | Training model v2. See [Decision 1](#decision-1-delete-the-v2-training-model) |
| `src/db/training.rs` | 625 | Training model v2 |
| `src/server/training_tests.rs` | 474 | Training model v2 |
| `testdata/regime_timelines.json` | 25374 | |
| `examples/bench_training.rs` | — | Benchmarks the v2 model |

Also delete these parts of files that stay:

- `src/server/workout.rs` — `generate_schedule`, `persist_program_state_after_workout_end`, `maybe_annotate_temporal_adjustment`, `set_next_workout`, `rehydrate_workout_from_events`.
- `src/server/messages.rs` — `lp_completion_messages`, `completion_messages_for_regime`, `schedule_messages_from_proposal`, `summarize_last_session`.
- `src/server/settings.rs` — the 3 program RPCs.
- `src/recovery.rs` — `RecoveryProfile` becomes one constant. Delete the per-regime selection.
- `src/weight_units.rs` — `weight_unit_from_state`. See [5.5](#55-fix-the-weight-unit-defect).

### 4.2 Flutter

| Path | Lines | Action |
|---|---:|---|
| `app/lib/screens/regime_settings_screen.dart` | 624 | Delete |
| `app/lib/screens/regime_info_screen.dart` | 251 | Delete |
| `app/lib/widgets/phase_explanation.dart` | 142 | Delete |
| `app/lib/screens/workout/exschplanation_page.dart` | 107 | Delete |
| `app/lib/screens/onboarding/` | 2092 | Replace. See [5.4](#54-onboarding) |
| `app/lib/screens/home/home_screen.dart` | 1478 | Replace with a template list |
| `app/lib/screens/home/home_selection.dart` | 229 | Delete |
| `app/lib/screens/home/group_grid.dart` | 399 | Replace |
| `app/lib/screens/home/readiness_banner.dart` | 628 | Reduce to the recovery display |

Keep `app/lib/widgets/exercise_editor/`. It already edits exercise groups.
It becomes the template editor.

### 4.3 Protobuf

Delete from `proto/workout/v1/settings.proto`:

`RegimeType`, `TrainingProgramAtAGlance`, `TrainingProgramLink`,
`TrainingProgramDefinition`, `StateFieldKind`, `StateEnumOption`,
`TrainingProgramStateFieldSchema`, `TrainingProgramStateSchema`,
`StateFieldValue`, `TrainingProgramState`, `TrainingProgramStateEvent`,
and the 4 catalog and state RPCs. The file keeps only plate colours and the
weight unit. It becomes about 60 lines.

Delete from `proto/workout/v1/workout.proto`:

`ProposedExerciseGroup`, `ProgressionHint`, `ProgressionRule`,
`RegimeContext`, `NextSessionOption`, `SlotTrainingStatus`, `WorkoutDraft`,
`GetProposedWorkoutSchedule*`, `SetNextWorkout*`, `SaveWorkoutDraft*`,
`ClearWorkoutDraft*`, `SaveProfileExerciseGroup*`,
`DeleteProfileExerciseGroup*`, `RehydrateWorkoutFromEvents*`.

Delete `proto/workout/v1/training.proto` in full.

Remove the `prescribed_by_regime` field from `ExerciseGroup`. Remove the
`progression_hint` field from `ProposedSet`, `WorkingSetSpec` and
`PlannedGroupSet`.

Keep `TrainingStatus` only if you keep muscle recovery. Remove its program
fields: `next_session_at`, `slot_statuses`, `target_sessions_per_7_days`,
`completed_sessions_per_7_days`, `remaining_sessions_per_7_days`,
`target_sets_per_7_days`, `completed_sets_per_7_days`,
`remaining_sets_per_7_days`.

## 5. Add this

### 5.1 Templates

Add one table:

```sql
CREATE TABLE workout_templates (
    id                 TEXT PRIMARY KEY,
    user_id            TEXT NOT NULL,
    name               TEXT NOT NULL,
    template_order     INTEGER NOT NULL DEFAULT 0,
    exercise_groups    BLOB NOT NULL,   -- repeated ExerciseGroup, no weights
    created_at         INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);
CREATE INDEX idx_workout_templates_user
    ON workout_templates(user_id, template_order);
```

The blob holds the same `ExerciseGroup` message that a workout uses. This
keeps one structure for the plan and for the session. Set `start_weight` and
`end_weight` to 0 in a template. The server fills them at start time.

Add these RPCs to `WorkoutService`:

```
rpc ListTemplates(ListTemplatesRequest) returns (ListTemplatesResponse);
rpc SaveTemplate(SaveTemplateRequest) returns (SaveTemplateResponse);
rpc DeleteTemplate(DeleteTemplateRequest) returns (DeleteTemplateResponse);
rpc ReorderTemplates(ReorderTemplatesRequest) returns (ReorderTemplatesResponse);
```

`SaveTemplate` creates a template when the id is empty. It updates a
template when the id exists.

### 5.2 Trackers

Add one table:

```sql
CREATE TABLE exercise_trackers (
    user_id            TEXT NOT NULL,
    exercise           INTEGER NOT NULL,
    working_weight     REAL NOT NULL,      -- lb
    target_reps        INTEGER NOT NULL,
    target_sets        INTEGER NOT NULL,
    consecutive_misses INTEGER NOT NULL DEFAULT 0,
    last_performed_at  INTEGER NOT NULL DEFAULT 0,
    updated_at         INTEGER NOT NULL,
    source             TEXT NOT NULL,      -- "workout:<id>" | "manual" | "migration"
    PRIMARY KEY(user_id, exercise)
);
```

Add these RPCs:

```
rpc ListExerciseTrackers(ListExerciseTrackersRequest) returns (ListExerciseTrackersResponse);
rpc SetExerciseTracker(SetExerciseTrackerRequest) returns (SetExerciseTrackerResponse);
```

`SetExerciseTracker` lets the user correct a weight by hand. Set `source` to
`"manual"`.

A tracker row does not have to exist. When there is no row, use
`exercise_catalog::starting_weight_lb`, `default_reps` and `default_sets`.

Keep the `program_progression_applied` table. Rename it to
`progression_applied`. It stops a repeated `EndWorkout` from moving a
tracker two times.

### 5.3 One home RPC

Replace `GetProposedWorkoutSchedule` with one RPC. The home screen needs
one round trip.

```proto
message GetHomeRequest {}

message GetHomeResponse {
  repeated WorkoutTemplate templates = 1;
  repeated ExerciseTracker trackers = 2;
  string active_workout_id = 3;
  repeated UserMessage user_messages = 4;
  TrainingStatus recovery = 5;   // muscle recovery only
}
```

Fill `WorkoutTemplate.exercise_groups` with the weights from the trackers.
The client then shows the real weights without a second call.

### 5.4 Onboarding

The new sequence has 3 steps. The old sequence has 5 steps.

1. Select the weight unit.
2. Give the bodyweight and the experience level. This step is optional.
3. Confirm.

Then:

- Seed a tracker for each of the 5 main lifts from
  `recommended_starting_weights`. If the user skipped step 2, use the
  catalogue opener.
- Copy the 6 default templates into the user's templates.

Rewrite `src/onboarding.rs`. Change `RATIOS` from program field keys to
`Exercise` values:

```rust
const RATIOS: &[(Exercise, f32)] = &[
    (Exercise::Squat, 0.95),
    (Exercise::BenchPress, 0.70),
    (Exercise::BarbellRow, 0.75),
    (Exercise::OverheadPress, 0.50),
    (Exercise::Deadlift, 1.15),
];
```

The client uses "the program state exists" to decide that onboarding is
complete (`SettingsProvider.hasProgramState`). Replace this test. Use "the
user has one or more templates".

### 5.5 Fix the weight unit defect

`weight_unit_from_state` reads the key `__weight_unit` from the program
state. **No code writes that key.** The function always returns pounds.
Users who select kilograms get warmups and progression steps that are
rounded for pounds.

Read the unit from `user_settings_current` instead. The client already
writes the unit there through `UpdateSetting`. Add
`ServerDb::get_weight_unit(user_id)`.

Do this in the same change. The old function is deleted anyway.

## 6. Migration

Run the migration one time at server start. Guard it with a marker row.
The migration must not lose a user's weights.

```
CREATE TABLE schema_migrations (name TEXT PRIMARY KEY, applied_at INTEGER NOT NULL);
```

### 6.1 Trackers

For each user, in this order:

1. Run `derive_exercise_progressions` over the user's whole workout
   history. Write one tracker for each exercise found. This code exists and
   is tested. It gives the weight that the user would lift next.
2. For each of the 5 main lifts with no tracker from step 1, read the
   program state:

| Program | Key | Tracker weight | Reps | Sets |
|---|---|---|---|---|
| Linear 5x5 | `<lift>_weight` | The value | 5 | 5, or 1 for the deadlift |
| GZCLP | `<lift>_t1_weight`, `<lift>_t2_weight` | The larger of the two | 5 | 5 |
| Wendler 5/3/1 | `<lift>_tm` | `tm * 0.85`, rounded | 5 | 3 |

3. Set `source` to `"migration"`.

History wins over program state. History is what the user did. Program
state is what a program planned.

> **Caution:** GZCLP holds two weights for one exercise. The migration
> keeps one. Tell the user in the release notes.

### 6.2 Templates

For each user:

1. Convert each row of `profile_exercise_groups` to one template. Set the
   weights to 0.
2. Convert the user's most recent completed workout to one template. Name
   it after the workout. A user then always has a starting point.
3. Copy the 6 default templates.

### 6.3 Tables

| Table | Action |
|---|---|
| `workouts`, `exercise_groups`, `proposed_sets`, `completed_sets` | Keep. No change |
| `training_program_state_latest` | Read in 6.1, then DROP |
| `proposed_schedule_cache` | DROP. Nothing reads it today |
| `workout_drafts_current` | DROP. A template replaces the draft |
| `profile_exercise_groups` | Read in 6.2, then DROP |
| `program_progression_applied` | Rename to `progression_applied` |
| `workout_events` | DROP. Write-only today; nothing reads it |
| `t_workouts`, `t_blocks`, `t_sets`, `t_entries`, `t_progression` | DROP. See [Decision 1](#decision-1-delete-the-v2-training-model) |
| `user_message_events` | Keep. Delete rows with a removed message kind |

Column changes:

- `exercise_groups`: drop `prescribed_by_regime`.
- `proposed_sets`: drop `progression_blob`.

> **Caution:** `delete_user_account_and_data` in `src/db/auth.rs:270`
> deletes each table by name. Update it for every table that you add or
> remove. Also update `seed_all_tables` in the same file. The test
> `deleting_an_account_clears_every_user_keyed_table` finds all user-keyed
> tables at run time. It fails if the delete path misses one, and it fails
> if the seed misses one.

### 6.4 Workouts that are in progress

A user can have an open workout when the server restarts with the new
code. An open workout has `end_time = 0`.

Keep the workout. Its `proposed_sets` and `completed_sets` do not change.
The user completes it as normal. `EndWorkout` then updates the trackers
with the new rule.

Do not try to attach an open workout to a template. It has no template.
Leave `template_id` empty on the workout row.

## 7. Work phases

The branch does not build between phase 1 and phase 3. This is correct.
Do not add a compatibility layer.

### Phase 1 — Protobuf

1. Delete the messages and the RPCs from [4.3](#43-protobuf).
2. Add the messages and the RPCs from [5](#5-add-this).
3. Regenerate the bindings. See [12](#12-tools).

Result: the Rust backend and the Flutter app do not compile. Continue.

### Phase 2 — Backend

1. Delete the files from [4.1](#41-rust).
2. Add the tables, the migration and the template and tracker code.
3. Change `StartWorkout` to accept a template id and to resolve weights.
4. Change `EndWorkout` to update trackers instead of program state.
5. Fix the weight unit read.
6. Update `delete_user_account_and_data`.

Result: `cargo test` passes. `cargo clippy --all-targets -- -D warnings`
passes.

### Phase 3 — Flutter

1. Delete the screens from [4.2](#42-flutter).
2. Build the template list home screen.
3. Point the exercise editor at `SaveTemplate`.
4. Build the 3-step onboarding.
5. Change the onboarding-complete test.

Result: `flutter analyze --fatal-infos` passes. `flutter test` passes.

### Phase 4 — Tests

1. Delete `scenario_tests.rs` and `schplanner_tests.rs`.
2. Write progression tests: one step up, hold, deload, bodyweight, manual
   override, and the weight unit in kilograms.
3. Write migration tests: one user for each program, plus a user with no
   program state.
4. Extend `examples/api_invariant_fuzz.rs`. Add template create, template
   edit, and start-from-template.
5. Add an invariant: a tracker never moves two times for one workout.

### Phase 5 — Release

1. Update `docs/architecture/`. Delete `regimes.md` and
   `training-model.md`. Rewrite `overview.md` and `data-model.md`.
2. Delete `docs/regime-explorer.html`.
3. Add the version gate. See [8.1](#81-old-apps-break).
4. Write the release notes. State that GZCLP users keep one weight for each
   lift.

## 8. Risks

### 8.1 Old apps break

There is **no version check** in the repo today. The server does not know
the app version. An installed app that calls a deleted RPC gets an error
that it cannot explain.

Do this before you deploy:

1. Add an app version to the gRPC metadata on every call.
2. Add a `min_supported_version` check in `src/server/support.rs`.
3. Return a specific status code when the version is too old.
4. Show a "you must update" screen in the app for that code.

Ship step 4 in a release **before** the refactor lands. Users then have an
app that can show the message.

### 8.2 Users lose their program

A user who follows Wendler 5/3/1 loses the cycle. This is the point of the
change. The user must not lose the weight. Section [6.1](#61-trackers) keeps
the weight.

Show a message at the first sign-in after the change. Tell the user where
the weights went.

### 8.3 Progression becomes less clever

Three programs become one rule. A user who wants 5/3/1 cannot get it.

The template model can express the structure of 5/3/1 for one week. It
cannot express the 4-week cycle. Accept this, or see
[Decision 4](#decision-4-cycles).

### 8.4 Test coverage drops

The scenario tests cover the regimes well. They cover persistence and RPCs
not at all (`docs/architecture/testing.md`). When the regimes go, the
scenario tests go. Phase 4 must replace the coverage at the API level, not
only at the unit level.

### 8.5 Watches and web are safe

The Wear OS app, the Apple Watch app and the web app contain **no**
reference to regimes outside generated code. The blast radius is the
backend and the Flutter phone app. Regenerate the Java, Swift and
TypeScript bindings, then build each client one time to confirm.

## 9. Decisions

Each decision has a recommendation. Change it if you disagree, but change
it before phase 1.

### Decision 1: delete the v2 training model

`src/server/training.rs`, `src/db/training.rs` and
`proto/workout/v1/training.proto` hold a second, complete workout model.
It has blocks, sets, append-only entries, and one `MutateWorkout` endpoint.
The backend is built and tested. The Flutter app does not use it. Nothing
is migrated to it.

**Recommendation: delete it.**

Reasons:

- Its `CloseWorkout` calls the regime machinery. That machinery goes away,
  so `CloseWorkout` must be rewritten anyway.
- The Flutter side has no v2 code. To adopt v2 you must also rewrite
  `workout_provider.dart` (1778 lines) and the workout screen. That
  doubles this refactor.
- A second dormant model is the kind of complexity that this change
  removes.

What you lose: v2 edits a workout one row at a time. v1 rewrites the whole
workout on each plan change (`apply_replace_exercise_group_plan`). The v1
way is slower and it caused an ordering defect that is now fixed. If you
want the row-level model later, take it from git history and apply it to
the simpler schema. That is cheaper than to carry it through this refactor.

### Decision 2: keep muscle recovery

`src/recovery.rs` computes muscle recovery from workout history. It uses a
recovery profile that the regime supplies. The rest of it does not depend
on programs.

**Recommendation: keep it. Use one fixed profile.**

It answers "are my legs ready?", which is still useful when you select your
own workout. It costs about 450 lines. Delete it if you want the smallest
possible result.

### Decision 3: keep the layoff deload

Today a program reduces your weights after time away: 90 percent after 14
days, 80 percent after 30 days.

**Recommendation: keep it. Apply it for each exercise.**

Apply it when the server resolves a tracker weight at `StartWorkout`. Do
not write the reduced weight to the tracker until the user completes the
workout. This is how the programs behave today, and it is about 20 lines
under the new model.

### Decision 4: cycles

A user cannot express "week 3 is heavy, week 4 is light" with templates
alone.

**Recommendation: do nothing now.**

A user can make 4 templates and select one. This is manual, and it matches
the aim of the change. Add a template sequence later if users ask for it.

### Decision 5: store the tracker, do not derive it

`derive_exercise_progressions` computes the weight from history each time.
A stored table is the other option.

**Recommendation: store it.**

Reasons:

- A user must be able to correct a weight by hand. A derived value has
  nowhere to hold the correction.
- A user's weight must not change when the user edits an old workout.
- The derivation code stays. It seeds the table in the migration, and it
  can repair a table.

## 10. Sizes

Use these numbers to plan, not to measure success.

| Area | Delete | Add | Net |
|---|---:|---:|---:|
| Rust | 7200 | 1500 | −5700 |
| Flutter | 5000 | 2000 | −3000 |
| Protobuf | 700 | 250 | −450 |
| **Code total** | **12 900** | **3750** | **−9150** |
| Test data (`regime_timelines.json`) | 25 400 | 0 | −25 400 |

## 11. Definition of done

The refactor is complete when all of these are true.

- [ ] The word "regime" occurs nowhere outside generated code and git history.
- [ ] `src/regimes/`, `src/schplanner.rs` and `src/program_state.rs` do not exist.
- [ ] A new user selects a unit, then starts a workout. No other setup step exists.
- [ ] A user makes a template, starts it, and the weights come from the trackers.
- [ ] A user increases the squat one time. Every template shows the new weight.
- [ ] Every exercise progresses, not only the 5 main lifts.
- [ ] A user with kilograms gets weights that are rounded for kilograms.
- [ ] The migration runs one time. A second start does nothing.
- [ ] No user loses a working weight in the migration.
- [ ] `cargo clippy --all-targets -- -D warnings` passes.
- [ ] `cargo test --all-targets` passes.
- [ ] `make fuzz-api-ci` passes.
- [ ] `flutter analyze --fatal-infos` passes.
- [ ] `flutter test` passes.
- [ ] The Wear OS app, the Apple Watch app and the web app build.
- [ ] An app with an old version shows an update message.

## 12. Tools

`buf` is installed at `~/.local/bin/buf`. Use the Makefile targets:

```bash
make proto-dart       # works
make proto-android    # works
make proto-swift      # fails: protoc-gen-swift is not on this machine
```

`make proto-all` runs all three, so it fails at the Swift step. The Swift
output is not in git, and the iOS build runs on macOS, so this does not
block Linux work.

The Android bindings were regenerated in commit `37af8e7`. They had 15
`Exercise` enum members against 80 in the proto.

The TypeScript bindings in `web/src/gen/` use a remote `buf` plugin. They
are out of date. Regenerate them with `cd proto && buf generate` and read
the diff, because it holds other people's proto changes as well as yours.

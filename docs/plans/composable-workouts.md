# Composable Workouts

Status: implemented on this branch. Kept as the design record.

This document tells you how to remove the program state machine from
Schlift and what to build in its place. Write the code in the order of
[8. Work phases](#8-work-phases). Do not keep the old model and the new
model at the same time.

## 1. Summary

Today the server selects your workout. You select a program (Linear 5x5,
GZCLP or Wendler 5/3/1). The program is a state machine. It holds a state
record for you, proposes the next session from it, and moves it forward
when you complete a session.

After this change, you compose your own workouts. You keep templates. A
template is an ordered list of exercises and nothing else. The app
prescribes the sets, the reps, the rest and the weight for each exercise.
The prescription follows hypertrophy training evidence. There is no
strength mode and there are no cycles; the app trains you for muscle
growth.

| Property | Today | After |
|---|---|---|
| Who selects the session | The program | The user, with a suggestion |
| The user sets sets, reps, weight | Yes, per group | No. The app prescribes them. Overrides are possible. |
| Setup before the first workout | Select a program, set 5 to 12 fields | Select a unit. Bodyweight is optional. |
| Progression scope | The 5 lifts the program prescribes | Every exercise |
| Progression rules | 3 regimes, each different | 1 rule: double progression |
| Volume guidance | None | Sets per muscle over 7 days, against a 10–20 band |
| Server state per user | Untyped key-value program state | One tracker per exercise |

## 2. Terms

One term has one meaning. Use these terms in code, in proto files and in
the user interface.

| Term | Meaning |
|---|---|
| Exercise | One movement type. An entry in the `Exercise` enum. |
| Set | One performance of one exercise. |
| Template | A named, ordered list of exercises. Nothing else. |
| Workout | One training session, started from a template or empty. |
| Tracker | Per user, per exercise: the working weight, the current rep target, the miss count, and optional overrides. |
| Prescription | The sets, rep range and rest derived from what an exercise is. |
| Muscle | One of 10: chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core. |
| Volume | Weighted hard sets per muscle in the last 7 days. |

Do not use these words after the change: regime, schplanner, program
state, phase, cycle, stage, tier, slot.

## 3. The training design

The design follows the strongest findings in hypertrophy research:

1. Weekly hard sets per muscle drive growth, with diminishing returns.
   About 10–20 sets per muscle per week is the useful band.
2. Sets must be near failure. The prescription assumes 0–2 reps in
   reserve; the app copy says "stop 1–2 reps before failure".
3. Progressive overload counts reps as well as load. More reps at the same
   weight is progress.
4. Load range is forgiving. 60–80 percent of maximum grows muscle when the
   set is hard. Small equipment steps are enough.
5. Rest of 2–3 minutes beats short rest, for size as well as strength.

### 3.1 A template holds structure. A tracker holds weight.

This is the most important rule in this document.

A template holds an ordered list of exercises. It holds no sets, no reps,
no weights and no rest times. All of those derive from the exercise
(see 3.2) and from the tracker (see 3.3).

Result: you increase your squat one time, and every template that contains
Squat shows the new weight. Do not put numbers in a template. A number in
a template makes a second source of truth.

### 3.2 The prescription

The prescription derives from what the exercise is. The exercise catalog
(`src/exercise_catalog.rs`) classifies every exercise by equipment
(barbell, dumbbell, machine, cable, bodyweight) and by role (compound,
isolation, core). The table:

| Class | Sets | Rep range | Rest | Rest after a miss | Warmup ladder |
|---|---:|---|---:|---:|---|
| Barbell compound, lower-body loaded | 3 | 6–10 | 180 s | 240 s | Yes |
| Barbell compound, upper body | 3 | 6–10 | 150 s | 210 s | Yes |
| Dumbbell / machine / cable compound | 3 | 8–12 | 120 s | 180 s | No |
| Bodyweight compound | 3 | 5–15 | 120 s | 180 s | No |
| Isolation | 3 | 10–15 | 90 s | 120 s | No |
| Core | 3 | 10–20 | 60 s | 90 s | No |

"Lower-body loaded" means the exercise trains quads, hamstrings or
glutes. Squats and hinges tax the whole system and earn the full three
minutes; upper-body barbell work recovers in 2:30, and the difference is
real session time. The home screen shows an estimated duration per
template so the cost of a plan is visible before starting it.

Three sets everywhere is deliberate. It is memorable, it is defensible
(per-session per-muscle volume beyond about 8 sets adds little), and the
weekly dose comes from exercise selection and frequency, which the volume
display makes visible.

A user can override sets and the rep range for one exercise. The override
lives on the tracker, not on a template, so it applies everywhere that
exercise appears. Overrides are the escape hatch; the default path never
asks the user for numbers.

### 3.3 Double progression

One rule for every exercise. The tracker holds `working_weight`,
`current_reps` (the rep target inside the range) and
`consecutive_misses`.

After a workout, for each exercise performed, let `m` be the lowest
actual rep count across the planned working sets, and let `W` be the
weight of the last working set you completed:

| Outcome | Next state |
|---|---|
| Every planned set completed at its target, and `m >= range top` | `working_weight = snap(W + step)`, `current_reps = range bottom`, misses = 0 |
| Every planned set completed at its target, `m < range top` | `current_reps = clamp(m + 1, bottom, top)`, misses = 0 |
| A set missed its target or was not done | misses + 1. At 2 misses: `working_weight = snap(W * 0.9)`, `current_reps = bottom`, misses = 0 |
| The exercise has no load (bodyweight) | Reps only: `current_reps = min(m + 1, 30)`. The weight stays 0. |

Properties to preserve:

- The basis is `W`, the weight you performed, not the stored weight. A
  mid-session edit carries through.
- `step` comes from the equipment (5 lb / 2.5 kg barbell, one dumbbell
  step, one stack step), and `snap` rounds to a loadable weight in the
  user's unit. Load moves rarely and by small amounts; reps do the
  day-to-day progressing. This is what makes one rule work for a squat
  and a lateral raise.
- Judgement uses the target stamped on each set at start time, so an
  edited session is judged by what you attempted.

### 3.4 Volume

The server computes, for each of the 10 muscles, the weighted hard sets
in the last 7 days (rolling window, in-progress workout included):

- A completed working set counts 1.0 for the exercise's primary muscle
  and 0.5 for each secondary muscle. Warmups and cancelled sets count 0.
- The target band is 10–20. Show the count against the band. Below 10 is
  the actionable signal; above 20 is a soft warning.

The exercise-to-muscle mapping lives in the catalog, primary mover first.
There is exactly one mapping. The old 7-group recovery taxonomy and the
old 8-value proto enum both give way to the 10-muscle list.

Volume drives selection in two places:

- The template suggestion (3.5).
- The exercise picker sorts muscles below the band first.

### 3.5 The template suggestion

The home screen marks one template as "up next". The rule is a pure
function, computed fresh on every request:

```
score(template) = sum over its exercises' primary muscles of
                  max(0, 10 - sets_7d(muscle)), counted once per muscle
```

Highest score wins. Ties break toward the template least recently
started (`workouts.template_id` records what started from where). The
suggestion is a sort the user can see the reason for — never stored
state, never a phase, never a thing that remembers. If it ever needs to
remember something between sessions, it has gone wrong.

The user can start any template. The suggestion is one tap but never a
gate.

### 3.6 Equipment

The exercise picker defaults to barbell, dumbbell and bodyweight
exercises. A "machines & cables" toggle shows the rest. The toggle is a
client-side preference; the server does not care.

One catalog fix: `CalfRaise` is classified `Machine` today. A standing
calf raise is dumbbell-loaded. Reclassify it `Dumbbell` so calves are
reachable in the default filter.

Known gaps with the default filter, accepted: hamstring isolation is
Nordic curls or nothing (RDL and good mornings cover hamstrings as
compounds); vertical pulling requires pull-ups.

### 3.7 Layoff deload

When an exercise was last performed 14–29 days ago, resolve its start
weight at 90 percent; 30 days or more, 80 percent, snapped. Do not write
the reduction to the tracker. Because progression follows the performed
weight (3.3), the reduction sticks only when the user trains, exactly as
today. About 20 lines, at StartWorkout resolution time.

### 3.8 Defaults

Six templates, copied into the user's own templates at onboarding, all
editable, none special. Barbell, dumbbell and bodyweight moves only:

| Template | Exercises |
|---|---|
| Full Body | Squat, Bench Press, Barbell Row, Dumbbell Shoulder Press, Barbell Curl |
| Upper | Bench Press, Barbell Row, Overhead Press, Chin Up, Dumbbell Curl, Skull Crusher |
| Lower | Squat, Romanian Deadlift, Hip Thrust, Calf Raise, Crunch |
| Push | Bench Press, Overhead Press, Incline Dumbbell Press, Lateral Raise, Skull Crusher |
| Pull | Barbell Row, Pull Up, Dumbbell Row, Rear Delt Fly, Barbell Curl |
| Legs | Squat, Romanian Deadlift, Lunge, Calf Raise, Hanging Leg Raise |

## 4. What the user sees

The home screen shows:

1. The volume display: 10 compact bars, sets against the 10–20 band.
2. The suggested template, marked, with the reason ("back and biceps are
   behind").
3. The other templates as cards. Each card lists its exercises with the
   current tracker weight ("Squat — 3×8 @ 185").
4. Start empty, for a made-up-on-the-spot session.

A template editor: name, exercise list, drag to reorder, add from the
picker. Tapping an exercise shows its derived prescription and lets the
user override sets and rep range (stored on the tracker).

The workout session screen does not change. Warmups, rest timers, set
logging, mid-workout editing and multiplayer all stay as they are.

## 5. Delete this

### 5.1 Rust

| Path | Note |
|---|---|
| `src/regimes/` | All 3 regimes, the trait, the simulator, scenarios |
| `src/schplanner.rs`, `src/schplanner_tests.rs` | |
| `src/scenario_tests.rs` | |
| `src/program_state.rs` | |
| `src/server/training.rs`, `src/db/training.rs`, `src/server/training_tests.rs` | v2 model, unused (Decision 1) |
| `testdata/regime_timelines.json` | |
| `examples/bench_training.rs` | Benchmarks the v2 model |

Parts of files that stay:

- `src/server/workout.rs` — `generate_schedule`,
  `persist_program_state_after_workout_end`,
  `maybe_annotate_temporal_adjustment`, `set_next_workout`,
  `rehydrate_workout_from_events`, draft and profile-group RPCs.
- `src/server/messages.rs` — the regime message builders. Keep the
  message infrastructure and the progression-message builder; every
  exercise now uses them.
- `src/server/settings.rs` — the 3 program RPCs.
- `src/recovery.rs` — per-regime profiles. One fixed profile over the 10
  muscles stays.
- `src/weight_units.rs` — `weight_unit_from_state`. It reads a key that
  nothing writes and always returns pounds; kilogram users get
  pound-rounded weights today. Read `user_settings_current` instead.
- `src/exercise_progress.rs` — the linear engine. Double progression
  replaces it.

### 5.2 Flutter

Delete: `regime_settings_screen.dart`, `regime_info_screen.dart`,
`phase_explanation.dart`, `exschplanation_page.dart`,
`home_selection.dart`, `readiness_banner.dart`, `group_grid.dart`, the
5-step onboarding.

Replace: `home_screen.dart` (template list + volume), onboarding (3
steps). Keep the exercise editor widgets; they become the template
editor's parts and the mid-workout dialogs, fed by trackers instead of
`ExerciseStatus`.

### 5.3 Protobuf

Delete from `workout.proto`: `ProposedExerciseGroup`, `ProgressionHint`,
`ProgressionRule`, `RegimeContext`, `NextSessionOption`,
`TrainingStatus`, `SlotTrainingStatus`, `ReadinessState`,
`WorkoutDraft`, `ExerciseStatus`, `GetProposedWorkoutSchedule*`,
`SetNextWorkout*`, `SaveWorkoutDraft*`, `ClearWorkoutDraft*`,
`SaveProfileExerciseGroup*`, `DeleteProfileExerciseGroup*`,
`RehydrateWorkoutFromEvents*`, `GetRecommendedStartingWeights*`.

Remove `prescribed_by_regime` from `ExerciseGroup` and
`progression_hint` from `ProposedSet`, `WorkingSetSpec` and
`PlannedGroupSet`. Reserve every removed field number.

Extend `MuscleGroup` with `CALVES` and `CORE` (nothing populates the old
8 values, verified). Add an `EquipmentKind` enum.

`settings.proto` keeps plate colors and the weight unit; the program
catalog and state machinery go. Delete `training.proto` in full.

Keep `UserMessageKind` values as they are so stored messages still
render.

### 5.4 What survives untouched

The workout session model — `workouts`, `exercise_groups`,
`proposed_sets`, `completed_sets`, the reducer, planning with warmup
generation, `AppendWorkoutMutations` batching, multiplayer, heart rate,
summaries, exercise progress charts, auth. The watch apps reference only
`ProposedSet`, `WorkoutState` and the wearable envelope, all of which
stay. The web app calls only surviving RPCs.

## 6. Add this

### 6.1 Proto

```proto
message WorkoutTemplate {
  string id = 1;
  string name = 2;
  int32 order = 3;
  repeated Exercise exercises = 4;
  int64 created_at = 5;
  int64 updated_at = 6;
}

// The resolved state of one exercise for one user. GetHome returns one
// for every exercise in the catalog, so the client never needs a
// fallback table.
message ExerciseTracker {
  Exercise exercise = 1;
  float working_weight = 2;        // lb, snapped for the user's unit
  int32 sets = 3;                  // resolved (override or derived)
  int32 target_reps = 4;           // current position in the range
  int32 rep_range_low = 5;
  int32 rep_range_high = 6;
  int32 rest_seconds = 7;
  int32 rest_seconds_failure = 8;
  bool include_warmup = 9;
  int64 last_performed_at = 10;
  repeated float weight_history = 11;
  bool overridden = 12;
  MuscleGroup primary_muscle = 13;
  ExerciseCategory category = 14;
  EquipmentKind equipment = 15;
}

message MuscleVolume {
  MuscleGroup muscle = 1;
  float completed_sets_7d = 2;     // weighted: primary 1.0, secondary 0.5
  int32 target_low = 3;            // 10
  int32 target_high = 4;           // 20
}

message GetHomeResponse {
  repeated WorkoutTemplate templates = 1;
  repeated ExerciseTracker trackers = 2;
  string active_workout_id = 3;
  repeated UserMessage user_messages = 4;
  repeated MuscleVolume volume = 5;
  repeated MuscleRecoveryStatus recovery = 6;
  string suggested_template_id = 7;
  string suggestion_reason = 8;    // "Back and biceps are 6 sets behind"
  bool onboarded = 9;              // templates or workouts exist
}
```

RPCs on `WorkoutService`: `GetHome`, `SaveTemplate`, `DeleteTemplate`,
`ReorderTemplates`, `SetExerciseTracker`, `CompleteOnboarding`.
`StartWorkoutRequest` gains `template_id`; when set, the server builds
the groups from the template, the trackers and the prescription, and
stamps `template_id` on the workout.

`CompleteOnboarding(body_weight_kg, experience, unit)` saves the unit
setting, seeds trackers for the 5 main lifts from the bodyweight ratios
(or catalog openers when skipped), and copies the 6 default templates.
Idempotent: it does nothing when templates already exist.

### 6.2 Tables

```sql
CREATE TABLE workout_templates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    template_order INTEGER NOT NULL DEFAULT 0,
    template_blob BLOB NOT NULL,       -- proto WorkoutTemplate
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE exercise_trackers (
    user_id TEXT NOT NULL,
    exercise INTEGER NOT NULL,
    working_weight REAL NOT NULL,      -- lb
    current_reps INTEGER NOT NULL,
    consecutive_misses INTEGER NOT NULL DEFAULT 0,
    last_performed_at INTEGER NOT NULL DEFAULT 0,
    override_sets INTEGER NOT NULL DEFAULT 0,      -- 0 = derived
    override_rep_low INTEGER NOT NULL DEFAULT 0,
    override_rep_high INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL,
    source TEXT NOT NULL,              -- "workout:<id>" | "manual" | "migration" | "onboarding"
    PRIMARY KEY(user_id, exercise)
);

CREATE TABLE schema_migrations (
    name TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL
);
```

`workouts` gains `template_id TEXT NOT NULL DEFAULT ''`.

A tracker row is optional. No row means: catalog opener weight, derived
prescription, `current_reps` at the range bottom.

Keep the `program_progression_applied` idempotency ledger, renamed
`progression_applied`. A repeated `EndWorkout` must not move a tracker
twice.

## 7. Migration

One run at server start, guarded by a `schema_migrations` row named
`composable_workouts_v1`. The migration must not lose a user's weights.

### 7.1 Trackers

Per user, in order; the first source that produces a weight wins:

1. Workout history. Replay the recent workouts through the progression
   weight rule (performed weight, cleared → +step, missed twice →
   −10 %). One tracker per exercise found. `current_reps` starts at the
   range bottom.
2. Program state, for main lifts with no history tracker. Decode the
   `training_program_state_latest` blob with local prost structs defined
   in the migration module (the proto messages are deleted; the wire
   format is stable):

| Program | Key | Weight |
|---|---|---|
| Linear 5x5 | `<lift>_weight` | The value |
| GZCLP | `<lift>_t1_weight`, `<lift>_t2_weight` | The larger of the two |
| Wendler 5/3/1 | `<lift>_tm` | `tm * 0.85`, snapped |

Set `source = "migration"`. History wins over program state: history is
what the user did.

> **Caution:** GZCLP holds two weights per lift; the migration keeps
> one. Say so in the release notes.

### 7.2 Templates

Per user: convert each `profile_exercise_groups` row to a template
(exercises only); convert the most recent completed workout to a
template named after it; copy the 6 defaults. A migrated user always has
a starting point.

### 7.3 Tables

| Table | Action |
|---|---|
| `workouts`, `exercise_groups`, `proposed_sets`, `completed_sets` | Keep. `workouts` gains `template_id`; drop `exercise_groups.prescribed_by_regime` and `proposed_sets.progression_blob` |
| `training_program_state_latest` | Read in 7.1, then DROP |
| `profile_exercise_groups` | Read in 7.2, then DROP |
| `proposed_schedule_cache`, `workout_drafts_current`, `workout_events` | DROP. All write-only or replaced |
| `t_workouts`, `t_blocks`, `t_sets`, `t_entries`, `t_progression` | DROP (Decision 1) |
| `program_progression_applied` | Rename `progression_applied` |
| `user_message_events` | Keep |

An open workout (`end_time = 0`) survives untouched and finishes under
the new `EndWorkout`. Its `template_id` stays empty.

> **Caution:** `delete_user_account_and_data` (`src/db/auth.rs`) deletes
> tables by name, and `seed_all_tables` in the same file feeds the test
> that discovers user-keyed tables at run time. Update both for every
> table added or removed, or the discovery test fails.

## 8. Work phases

The repo does not build between phase 2 and phase 4. This is correct; do
not add a compatibility layer.

1. **Spec.** This document.
2. **Proto.** Delete 5.3, add 6.1, regenerate Dart and Android
   (`make proto-dart`, `make proto-android`). Swift and TypeScript
   regenerate in their own CI.
3. **Backend.** Catalog (muscles, prescription, equipment), double
   progression, volume, suggestion, tables, migration, handlers,
   deletions, weight-unit fix, `delete_user_account_and_data`. Green:
   `cargo test --all-targets`, `cargo clippy --all-targets -- -D
   warnings`.
4. **Flutter.** Services, providers, home, template editor, onboarding,
   deletions. Green: `flutter analyze --fatal-infos`, `flutter test`.
5. **Harnesses.** `api_invariant_fuzz` gains template flows and a
   no-double-advance tracker invariant; `load_simulation` updated.
   `make fuzz-api-ci` green.
6. **Docs.** README, `overview.md`, `data-model.md`; delete
   `regimes.md`, `training-model.md`, `regime-explorer.html`.

## 9. Risks

### 9.1 Old apps break

There is no version check in the repo. Ship the gate with this change:
the app sends `x-app-version` metadata; the server, when
`MIN_APP_VERSION` is set, rejects older clients with
`FAILED_PRECONDITION` and message `app_update_required`; the app shows
an update prompt for that status. Deploy order: release an app that
sends the header and understands the error **before** setting
`MIN_APP_VERSION` on the server.

### 9.2 Users lose their program

A 5/3/1 user loses the cycle. That is the point of the change; the
weights survive (7.1). Say where the weights went in the release notes
and in a one-time message.

### 9.3 The intermediate ceiling

Double progression stalls eventually; the answer here is the 2-miss
deload and rep-range resets, not planned cycles. This is a
novice-to-intermediate bodybuilding app by design. Say it plainly in the
copy.

### 9.4 Volume blindness is now the app's job

The app prescribes per-exercise numbers, so weekly volume per muscle is
set entirely by exercise selection and frequency. The volume display
(3.4) is therefore load-bearing, not decoration. It ships in the same
phase as the prescription, not later.

### 9.5 Test coverage moves

The regime scenario tests die with the regimes. Their replacement is
API-level: handler tests for the tracker loop and the migration, and the
fuzz invariants. Phase 5 is not optional.

## 10. Decisions

Settled in review; recorded with reasons.

1. **Delete the v2 training model.** Its `CloseWorkout` depends on the
   regimes, the app never adopted it, and carrying it doubles the
   refactor. Take it from git history if row-level editing is ever
   wanted.
2. **Keep muscle recovery, one fixed profile,** over the 10-muscle
   taxonomy. "Are my legs ready" stays useful without programs.
3. **Keep the layoff deload, per exercise, resolution-time only** (3.7).
4. **No cycles, no goal dial.** Bodybuilding only. Strength-specific
   programming (waves, heavy triples) is out of scope; the old regimes
   were powerlifting programs and they are what is being deleted.
5. **Store trackers; do not derive them per request.** Manual
   corrections need a place to live, and editing an old workout must not
   move today's weight. The derivation exists to seed the migration and
   to repair.
6. **Templates rotate; exercises inside them do not.** Rotating
   exercises starves double progression of exposure. Variety comes from
   template rotation, the volume-aware suggestion, and deliberate
   swap-with-alternative in the editor.

## 11. Tools

`buf` is at `~/.local/bin/buf`. `make proto-dart` and
`make proto-android` work on this machine; `make proto-swift` needs
`protoc-gen-swift` (macOS CI has it; the output is not committed).
TypeScript bindings regenerate with `cd proto && buf generate` and are
already stale — read that diff before committing it.

## 12. Addendum (2026-08-25): flat sets — the exercise group is deleted

Since the cutover the server has created exactly one group per
exercise, always. The group was a fossil: a `name` duplicating the
exercise, an `interleave_warmups` flag nothing set, a config blob
duplicating the tracker. It is now removed entirely, along with
superset/interleaving support, which is deliberately dropped.

**Model.** A workout is an ordered list of `ProposedSet`s; each set
carries its exercise. "The sets for one exercise" is a *derived* view
(grouped by exercise, ordered by first appearance), computed where
needed — never stored, never on the wire.

**Wire surface.** `ExerciseGroup`, `ExerciseTypeConfig`,
`WorkingSetSpec`, `RestConfig`, `PlannedGroupSet`, `GroupWarmupPlan`,
`ReplaceExerciseGroupPlan` and `ReorderExerciseGroups` are deleted.
`ProposedSet` loses `exercise_group_id` and the regime-era `is_amrap` /
`instruction` (no producer remains). `UserMessage` loses
`exercise_group_id` (messages attach by `exercise`).
`ParticipantStatus` loses its group list. In their place, four
per-exercise operations matching what the UI actually does, each
returning the full visible plan (`WorkoutPlanResponse`):

- `AddExercises(workout_id, exercises)` — server prescribes from the
  trackers and appends one block per exercise.
- `AdjustExerciseWeight(workout_id, exercise, working_weight)` —
  pending working sets move to the new weight in place; pending warmups
  regenerate for it (completed sets untouched; the count-based and
  surpassed-weight guards carry over from the old edit logic).
- `RemoveExercise(workout_id, exercise)` — cancels the exercise's
  pending sets; completed sets stay.
- `ReorderExercises(workout_id, exercises)` — reassigns block order.

All four also ride `WorkoutMutation` (fields 17–20; 15–16 reserved)
through the offline queue. `StartWorkoutRequest` takes `template_id`
or an explicit `exercises` list (server prescribes); the group list is
gone.

**Migration `flat_workouts_v1`** (one-time, no backwards support):
drop `exercise_groups`; drop `proposed_sets.exercise_group_id`,
`is_amrap`, `instruction`; drop `user_message_events.exercise_group_id`.
No data rewrite: history summaries already aggregate by exercise, and
the derived block view groups legacy interleaved sets by exercise
regardless of contiguity.

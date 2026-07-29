# Thin-client migration: move all logic to the backend

> **Status: COMPLETE.** All five slices shipped and e2e-verified. The app no
> longer computes workout summaries, 1RM/volume, progress series, workout
> duration, onboarding weights, live-workout state, or warmups/plate-snapping —
> the server owns all of it and the app renders it. Deleted: `workout_reducer.dart`,
> `warmup.dart`, the plate-snapping half of `weight_units.dart`, the golden
> fixtures + parity tests + `LIFT_SNAPSHOT_*` harness, and ~1,300 lines of client
> logic. The "mirror this in two places / regenerate the golden" workflow is gone.
> Kept client-side: rendering/formatting, the plate-visualization breakdown (for
> arbitrary weights), a ~15-line optimistic "mark-done + advance" layer, and the
> weight-picker display snapping.


Goal: the Flutter app becomes an **extremely thin wrapper** — it renders server
responses, formats strings, plays sounds, and sends user intents. All business
logic lives in Rust. No app↔server duplication, no parity fixtures, no
"mirror this change in both places."

This audit was produced by sweeping `app/lib/` against `src/`. Findings are
grouped by what has to happen to eliminate them.

---

## The core realisation

There are **two workout APIs** already in the backend:

- **`TrainingService` / `WorkoutView`** (`proto/workout/v1/training.proto`) —
  render-ready: folded `blocks[] → sets[]` with `entry`, `has_entry`,
  `active_set_id`, `is_amrap`, `slot_key` inline, plus `CloseWorkout` returning
  `ProgressionChange[]` with human `headline`s.
- **`WorkoutService`** (`proto/workout/v1/workout.proto`) — raw component lists
  (`proposed_sets[]`, `completed_sets[]`) the client must join itself.

**The app still drives everything off the legacy raw API and re-aggregates
client-side.** So a large fraction of the duplication is unadopted-existing-API,
not missing capability. Migrating to `WorkoutView` deletes the whole optimistic
reducer and the proposed↔completed join for free.

---

## Category 1 — Business-logic mirrors (delete from app; server already owns it)

These are hand-maintained line-by-line ports, kept in sync only by golden tests.

| App code | Lines | Rust owner |
|---|---|---|
| `logic/weight_units.dart` plate math (`snapLoadable`, `simplestLoadableNear`, `platesForSide`, …) | ~106 | `src/weight_units.rs` |
| `logic/warmup.dart` (`generateWarmupDefs`, `rebuildExerciseSets`) | ~140 | `src/workout/planning.rs:31` / `:364` |
| `logic/workout_plan_builder.dart` (materialize sets, interleave, rest, → ProposedSets) | ~265 | `src/workout/planning.rs` (`generate_sets_for_group`, `materialized_working_sets_for_config`) |
| `logic/plate_calculator.dart` | ~27 | `src/weight_units.rs:82` (`plates_per_side`) |
| `logic/session_state.dart` next-to-lift / participant ordering | ~90 | `src/progress.rs` (`compute_next_up_set`), `src/server/support.rs` (`build_participant_status`) |
| `screens/home/group_grid.dart` set/warmup materialization for the preview | ~70 | same planner |

**Requires the server to return, per proposed/warmup set:** the plate-snapped
weight (already computed) **and** the plate breakdown per side, so the app never
does plate math. Then delete every row above.

---

## Category 2 — The optimistic reducer (the one real UX tradeoff)

`logic/workout_reducer.dart` (~139) + the reducer methods in
`providers/workout_provider.dart` (`_computeNextUpSet` `:408`, `_computeStateSnapshot`
`:419`, `_applyLocalReplaceExerciseGroupPlan`, `_applyLocalReorderExerciseGroups`,
`_rebuildExerciseGroupsCache`) re-implement `src/workout/reducer.rs` to update the
UI **before** the server confirms.

Crucially, **the server already returns `state_snapshot` + `next_up_set` on every
workout mutation** (`startSet`/`completeSet`/`cancel`/`reorder`/`replace`). So the
thin-client version is: render those straight from the response.

**Tradeoff:** dropping the local reducer means set-logging UI updates when the
server responds instead of instantly. Measured backend round-trip on a warm gRPC
channel is ~40–100 ms here, ~100–300 ms on cellular. This is the single
latency-sensitive interaction in the app (mid-set, phone in hand). Options:
1. **Drop it entirely** (purest thin client; ~one-tenth-second set-logging lag).
2. Keep a *tiny* optimistic "mark done + advance highlight" and derive nothing
   else from it. ~15 lines instead of ~280.

**Decision: option 2** — keep a ~15-line optimistic "mark tapped set done +
advance highlight" for set-logging feel; delete the rest of the reducer/state
machine and render `state_snapshot`/`next_up_set` from responses.

---

## Category 3 — Client aggregation with **no** server owner yet (new backend work)

No Rust implementation exists for any of these today.

| App code | Computes | New server surface |
|---|---|---|
| `completed_workout_screen.dart:630–826` `WorkoutSummaryData` | volume, per-exercise totals, est-1RM (Epley `w*(1+reps/30)`), lifting/rest/yapping seconds, vol/min, work:rest | `WorkoutSummary` message on `GetWorkout`/`WorkoutView`/`CloseWorkout` |
| `progress_screen.dart:49–105`, `exercise_detail_screen.dart:42–94` | N+1 `getWorkout` loop → per-exercise trend, gains, 1RM/volume series | a per-exercise **progress/analytics RPC** (series precomputed) |
| `history_screen.dart:35–88` | N+1 loop → per-workout volume, working sets, exercise list | `ListWorkoutSummaries` RPC (or summary embedded in `ListWorkouts`) |
| `home_screen.dart:359–406` `_estimatedWorkoutMinutes` | hard-coded per-set/warmup/rest seconds heuristic | `estimated_duration_seconds` on the schedule response |
| `onboarding_screen.dart:253–324` | bodyweight × per-lift ratio × experience multiplier → recommended starts | recommended-starting-weights RPC in the regime layer (`src/regimes/`) |

Est-1RM (`w*(1+reps/30)`) is implemented in **three** client spots and nowhere
in Rust — it should be computed once, server-side, per completed set / summary.

The N+1 is the biggest offender: `ListWorkouts` returns bare headers
(`workout.proto:341`), so **every** history/progress/detail screen loops
`getWorkout(id)` per workout and re-derives the same aggregates.

---

## Category 4 — Legitimately client-side (keep)

Rendering and device concerns, no backend involvement:

- `logic/audio.dart` (sound synthesis/playback), `logic/whimsical_emojis.dart`,
  `logic/utils.dart` (error-message formatting).
- Weight/clock/duration **string** formatting (`formatWeight`, `formatRestClock`),
  weight-unit suffixes.
- Plate-visualization **layout** (`widgets/plate_visualization.dart`) — renders the
  per-side breakdown the server will now provide.
- Colours/palette (`user_profile.dart` palette), profile-colour→`Color`.
- Exercise **display metadata**: emoji, short name, body-part tags
  (`logic/exercises.dart`) — presentation, not business logic. (Names could move
  server-side later; low priority.)
- Local rest-countdown ticking + rest-sound timing (needs the device clock).
- Month grouping / "this week" bucketing in history (pure view grouping).

---

## What gets deleted

- **Dart:** `warmup.dart`, `workout_plan_builder.dart`, `plate_calculator.dart`,
  `workout_reducer.dart`, the plate-math half of `weight_units.dart`, the reducer
  methods + client aggregation in `workout_provider.dart` and the four
  progress/history/detail/summary screens, onboarding weight heuristics, home
  time-estimate. (~1,000+ lines.)
- **Tests/fixtures:** `test/logic/{warmup_golden,plate_math,plate_calculator,weight_units,workout_reducer}_test.dart`,
  `testdata/warmup_golden.json` (190 KB), and the `LIFT_SNAPSHOT_*` snapshot
  harness in `planning.rs` / `simulator_tests.rs`. (`regime_timelines.json` stays —
  it pins regime progression, which is server-only.)
- **Whole concept:** the "mirror this in both places / regenerate the golden"
  workflow disappears.

---

## Phased plan (vertical slices — each is shippable and deletes real code)

Each slice adds the server capability, migrates the screen(s) to render it, then
deletes the client logic + its tests in the same change. No backwards compat.

1. **Workout summary.** Add server-computed `WorkoutSummary` (volume, est-1RM,
   duration breakdown, per-exercise totals) to `GetWorkout`/`CloseWorkout`.
   → gut `WorkoutSummaryData` from `completed_workout_screen.dart`; kill est-1RM
   duplication.
2. **History/progress/detail = one call each.** Add `ListWorkoutSummaries` +
   per-exercise progress RPC. → delete the N+1 loops and all aggregation in
   `history`, `progress`, `exercise_detail`.
3. **Active workout on `WorkoutView`.** Migrate the live workout + provider to
   `TrainingService`; render `state_snapshot`/`next_up_set`. → delete
   `workout_reducer.dart` + provider reducer methods (see Category 2 decision).
4. **Server-expanded sets + plate breakdown.** Proposal/workout responses return
   fully-expanded warmup sets with plate-snapped weights + per-side plates.
   → delete `warmup.dart`, `workout_plan_builder.dart`, `plate_calculator.dart`,
   the plate-math half of `weight_units.dart`, `group_grid` materialization, the
   golden fixture + parity tests + snapshot harness.
5. **Estimated duration + onboarding recommendations** server-side. → delete the
   two remaining heuristics.

After slice 4 the golden-fixture/parity machinery is gone entirely.
</content>

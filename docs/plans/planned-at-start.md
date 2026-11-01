# Weights planned at the start

Every weight the app prescribes is decided in one place, when a workout
starts, from what the user has lifted. The decision and its reasons are
recorded with the workout. Anything that changes a weight during the
workout is recorded beside it with its cause. Nothing else decides a
weight.

## The rule

`plan(exercise, history, starts, overrides, now) -> Decision`, in
`core/src/plan.rs`, pure. Inputs:

- **history** — every finished session of the exercise: what was lifted
  and whether every working rep was hit (`session_outcomes`).
- **starts** — the starting weights set at onboarding (from the strength
  emoji) or brought in with imported history.
- **overrides** — weights, sets and rep ranges the user has set by hand.
  The latest one is a new starting point: progression carries on from it.
- **now** — the start event's time.

It answers, for the exercise:

```
Decision {
  exercise, weight, sets, rep_low, rep_high, target_reps, rest, warmups
  source:  PROGRESSION | OVERRIDE | FIRST_TIME
  reasons: [Reason]   // in the order they applied
}

Reason {
  kind: ALL_REPS_HIT    // up a step, or the rep target up one
      | MISSED          // held: some reps missed last time
      | MISSED_THREE    // down 10%: missed three sessions running
      | TIME_OFF        // down 10% (3+ weeks) or 20% (6+ weeks)
      | USER_SET        // the user's own weight, from <when>
      | FIRST_TIME      // never done: a calibration ramp from <start>
  before, after
  days_off, misses_in_a_row, override_at, last_workout_id
}
```

### Classes

Every lift is three working sets. Its class sets the rep range and rest:

| Class | Lifts | Sets × reps | Rest | Warmups |
|---|---|---|---|---|
| Heavy | barbell compounds | 3 × 5–8 | 3:00 | 40/55/70/85% ladder |
| Standard | every other loaded lift | 3 × 8–12 | 2:00 | none |
| Bodyweight | bodyweight lifts and core | 3 × 5–15 | 1:30 | none |

Why: 1RM strength favours heavy loads, and 5–8 reps is heavy (roughly
75–85% of a max); growth is alike from about 6 to 30 reps taken near
failure (Schoenfeld et al. 2017; Lopez et al. 2021). Growth follows weekly
hard sets, about 10–20 per muscle (Schoenfeld, Ogborn & Krieger 2017):
three sets a lift across a few lifts and sessions lands there. Longer rest
beats short on the big lifts (Schoenfeld et al. 2016).

### Progression

One rule for every lift, from its last session:

| Last time | Next time | Reason |
|---|---|---|
| every working rep hit, target below the top | same weight, target +1 | ALL_REPS_HIT |
| every working rep hit at the top | weight +1 step, target to the bottom | ALL_REPS_HIT |
| reps missed | same weight, same target | MISSED |
| reps missed three sessions running | weight −10%, target to the bottom | MISSED_THREE |
| stopped early (ended, or the lift removed) | same again, not a miss | (none) |

Then from the date, per lift: 21 days or more since it was done, weight
×0.9; 42 days or more, ×0.8; either puts the target to the bottom
(TIME_OFF). Bodyweight lifts move reps only and stop at the top.

A lift never done gets the calibration ramp (FIRST_TIME): sets of 5 from
60% of its starting weight, +10% a set until a rep is missed, six sets at
most, then working sets at 90% of the heaviest set finished. A bodyweight
lift never done starts at the bottom of its range.

A step is the smallest jump the equipment allows (5 lb / 2.5 kg on a
machine or bar, the next dumbbell up). Weights snap to what can be
loaded, never under the empty bar.

Weight never drops during a workout on its own. Someone who misses reps
rests and tries again; someone who is cooked lowers the weight themselves.

## Recording it

**At the start.** The phone runs `plan` for each exercise and puts the
decisions in the `StartWorkout` event. Folding the event lays out the sets
from the recorded decisions; it never runs `plan`, so changing the rule
never changes a workout already started. `AddExercises` records decisions
the same way.

**During the workout.** Each exercise in a workout keeps a weight log: its
decision, then every change, folded from the events that made them.

```
WeightChange {
  at, from_set_id, before, after
  cause: USER_ADJUST          // AdjustExerciseWeight, phone or watch
       | CALIBRATION_STEP     // the ramp's next rung
       | CALIBRATION_SETTLED  // the ramp done: working weight set
       | CORRECTION           // EditCompletedSet: the record fixed
}
```

**Overrides.** The tracker sheet in the template editor records
`SetOverride { exercise, weight?, sets?, rep_low?, rep_high? }`. A change
mid-workout is not an override: it is history, and the next plan reads
what was lifted.

## What reads it

| Page | Shows | From |
|---|---|---|
| Home | each template's lifts at their next weight, with the reason | `plan` at now |
| Template editor | the same, and the sheet that sets an override | `plan` at now |
| Live workout, watch | the set's weight; the reason when the lift comes up; changes as they happen | the workout's log |
| Workout summary | per lift: started at, why, changes, next time | the log, and `plan` for next time |
| Exercise detail | what was lifted; next time and why | history, and `plan` |
| Progress, history | what was lifted | history |

`ExerciseTracker` becomes `ExercisePlan` (the decision as a view), the
only shape any screen reads.

## Removed

- **Trackers as stored state:** `TrackerState`, `Account.trackers`,
  `advance_tracker`, `advance_trackers`, `resolve_tracker`,
  `derive_trackers_from_history`, `set_tracker`, `layoff_adjusted_weight`,
  `TrackerRecord`, `SetExerciseTracker*`, the phone's `exercise_trackers`
  projection, `ExerciseTracker`'s unread fields.
- **User messages, entirely:** `core/src/messages.rs`, `StoredMessage`,
  `Account.messages`, `DismissUserMessages`, `UserMessage` and its enums
  and details, every `user_messages` response field. Nothing reads them;
  reasons on decisions replace them.
- **Seeding from body, experience and gender:** `starting_tracker_weights`,
  the multipliers, `Gender`, `ExperienceLevel`, those request fields.
  Onboarding records the starting weights the strength emoji picked.
- **`RateExercise`, `Effort`, `CompletedSet.effort`:** retired already.
- **The weight sheet's tracker write** after a mid-workout change.
- **demo_seed's own copy of the rules:** it imports finished sessions and
  lets `plan` decide, like any account.
- Tests of removed code; docs and Learn copy describing it.

## Moving existing accounts

No compatibility code. The new log is the only shape the core reads.

1. A throwaway script, run against production at the deploy and not kept
   in the repo, folds each account with the current core and writes a new
   log: settings, templates, `ImportHistory` (finished workouts and the
   starting weights of lifts never done) and a `SetOverride` per tracker
   the user had customised. The active workout, if any, is ended first.
   The database is backed up (`VACUUM INTO`) before.
2. The server rejects pushes from the old shape (`account_diverged`) and
   `MIN_APP_VERSION` sends old installs to the store.
3. On the phone: install the new version fresh. Sign-in pulls the
   converted log. Android Auto Backup is turned off for the account
   files so a reinstall cannot restore the old log.

Order: release the app to both stores held (Play at 0%, App Store manual
release), deploy the backend with the conversion, then release the app.
Workouts logged offline and not synced before the deploy are lost.

## Done when

- `cargo test`, the fuzzer, `make test-app` and the e2e suite pass on the
  new shape, with tests for: each reason; reasons stacking (time off after
  a hit); an override as a new starting point; a started workout
  unaffected by a later rule change; the weight log's causes.
- Home's previews and a start at the same moment give the same numbers.
- The Learn pages and docs/architecture describe this design and nothing
  else.
- Nothing in the repo mentions trackers, user messages or gender seeding.

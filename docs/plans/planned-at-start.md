# Workouts planned at the start

The user picks the lifts and how long they have. When the workout starts,
the core works out every lift's sets, reps and weight from one number per
lift, the user's estimated max, and from how long the user's sets take.
The decision and its reasons are recorded with the workout; anything that
changes a weight during the workout is recorded beside it with its cause.
Nothing else decides a weight.

## Each lift's number

Every lift has an **estimated max**: the most the user could lift once.
For bodyweight lifts it is a **rep max**: the most reps in one set.

It is worked out from history, by walking the lift's sessions in order.
A set shows the Epley estimate, counting one rep of reserve and half a rep
of fatigue for each set before it in the session:

```
shown max = weight × (1 + (reps + reserve + 0.5 × (set number − 1)) / 30)
```

where reserve is 1 for a set that hit its target (the user had reps left)
and 0 for a set short of it (it ran to failure).

| Session | The max after it |
|---|---|
| every working rep hit | the higher of the max before and what the session shows with one more rep on every set: one rep's worth up at the weight lifted; a lighter weight the user chose leaves it where it was |
| a rep missed | the most any working set shows, never more than the max before |
| stopped early | unchanged |

A session stopped early when the lift was removed, the workout ended with
working sets undone, or a miss was done before the previous set's rest had
run out (rushed, not a real miss).

Bodyweight lifts track a rep max the same way: a hit is one more rep, a
miss sets it to what the sets show.

Time off, per lift: 21 days or more since the lift was done, the max ×
0.9; 42 days or more, × 0.8. Inside the walk it comes from the gap between
one session and the next; when a workout is planned, from the gap to now,
and it is recorded in the decision, so the session that follows builds on
it.

A lift never done starts from the starting weight the strength emoji gave
it at onboarding (or that imported history brings) and runs the
calibration ramp: sets of 5 from 60% of it, +10% a set until a rep is
missed (six sets at most). The missed rung, a set to failure, gives the
max; the remaining working sets are planned from it. A bodyweight lift
never done starts at the bottom of its range.

An override from the template editor (a weight and reps, and optionally
sets) is converted to the max that prescribes it and is the new starting
point: it takes its place among the sessions by time and the walk carries
on from it. Until a session follows it, the lift is planned exactly as
set; its max is computed from its sets, or from 3 when it names none.
Reps of 0 removes it. A bodyweight lift can carry weight through an
override.

## Classes

| Class | Lifts | Reps | Rest | Warmups |
|---|---|---|---|---|
| Heavy | barbell compounds | 5–8 | 3:00 | 40/55/70/85% ladder |
| Standard | every other loaded lift | 8–12 | 2:00 | none |
| Bodyweight | bodyweight lifts and core | 5–15 | 1:30 | none |

1RM strength favours heavy loads and 5–8 reps is heavy (about 75–85% of a
max); growth is alike from about 6 to 30 reps taken near failure
(Schoenfeld et al. 2017; Lopez et al. 2021). Growth follows weekly hard
sets, about 10–20 per muscle (Schoenfeld, Ogborn & Krieger 2017). Longer
rest beats short on the big lifts (Schoenfeld et al. 2016).

## Sets: from the time budget

The user has a budget per workout: 60 minutes by default, changed in
5-minute steps on Home's workout card before starting.

Costs, from the user's own last four weeks once there are ten samples of
each, defaults until then:

| Cost | Default | Learned from |
|---|---|---|
| a working set | 40 s + the class's rest | set start → end; set end → next set's start, same lift |
| warmups (heavy lifts) | 4 min | the warmup sets' span |
| moving between lifts | 2 min | a lift's last set end → the next lift's first set start |

Allocation: every lift gets 2 sets; then one set at a time, up to 5 per
lift, to the lift whose primary muscle is furthest below 10 hard sets this
week (the weekly count Home shows) counting the sets planned so far, ties
to the earlier lift. It stops when the lift that should get the next set
does not fit the budget. If two sets each do not fit, the card says how
long the workout needs instead of starting short. Sets an override names
are kept as they are.

Each lift's `estimated_seconds` is its own share of the workout: its sets,
its warmups or ramp, and the move to it from the lift before. A workout
has each lift once.

## Reps and weight: from the max

A weight and reps are covered by the max when

```
weight × (1 + (reps + 1 + 0.5 × (sets − 1)) / 30) ≤ max
```

one rep in reserve on the first set and half a rep more for each set after
it. The plan:

1. Stay at the weight the lift was last done at, for as many reps as the
   max covers there.
2. Covered past the top of the range: up one weight step, for as many
   reps as the max covers there (capped at the top).
3. Covered short of the bottom: down to the heaviest weight the max
   covers at the bottom.
4. No last weight (first time after the ramp, an override, time off): the
   heaviest weight the max covers at the bottom of the range.

Weights snap to what can be loaded (plate maths, the equipment's steps,
never under the empty bar). With a hit worth one rep, a lift climbs a rep
a session at the same weight, steps up once it passes the top, and a miss
brings the max back to what the user showed. Bodyweight lifts take reps
from the rep max the same way, capped at the top of the range.

## The decision

The phone runs `plan` (core/src/plan.rs, pure) for each lift when it
starts a workout, and the decisions go in the `StartWorkout` event.
Folding it lays out the sets from the recorded decisions; it never runs
`plan`, so a change to the rules never changes a workout already started.

```
Decision {
  exercise, sets, reps, weight, rest, warmups
  max                      // the estimated max this was planned from
  budget_minutes, estimated_seconds
  reasons: [Reason]        // in the order they applied
}

Reason {
  kind: MAX_UP          // every rep last time: the max nudged up
      | MAX_FROM_MISS   // a missed set reset the max to what it showed
      | HELD            // stopped early, or the user lowered the weight
      | TIME_OFF        // 3 or 6 weeks away: the max cut
      | FIRST_TIME      // never done: the ramp finds the max
      | USER_SET        // the user's own weight, from <when>
      | SETS_FROM_TIME  // this many sets: the budget, and which muscles are behind
  before, after, detail (days off, the set that showed it, when)
}
```

`AddExercises` records decisions the same way; lifts already planned keep
theirs.

## During the workout

Each lift in a workout keeps a weight log: its decision, then every change.

```
WeightChange {
  at, from_set_id, before, after
  cause: USER_ADJUST          // the user changed it, phone or watch
       | CALIBRATION_STEP     // the ramp's next rung
       | CALIBRATION_SETTLED  // the ramp done: the working weight set
       | CORRECTION           // a logged set fixed
}
```

Weight never drops during a workout on its own. Someone who misses reps
rests and tries again; someone who is cooked lowers the weight.

## What each page shows

| Page | Shows | From |
|---|---|---|
| Home | the time control; each lift's sets × reps @ weight and the reason; the workout's estimated length | `plan` at now with the budget: per template (`template_plans`), and per lift with each lift as a one-lift workout (`plans`) |
| Template editor | each lift's next plan; the sheet that sets an override | `plan` |
| Live workout, watch | the set's weight and reps; the reason when the lift comes up; changes | the workout's log |
| Workout summary | per lift: what was planned and why, the changes, the max after | the log, the walk |
| Progress, exercise detail | the estimated max over time, and the heaviest weight lifted each session | the walk, history |
| History | what was lifted | history |

## Removed

- Trackers as stored state: `TrackerState`, `Account.trackers`,
  `advance_tracker(s)`, `resolve_tracker`, `derive_trackers_from_history`,
  `set_tracker`, `layoff_adjusted_weight`, `TrackerRecord`,
  `SetExerciseTracker*`, the `exercise_trackers` projection,
  `ExerciseTracker` (replaced by the plan view).
- The fixed prescription per lift (sets, rep target, deadlift's 3 sets).
- User messages, entirely: `core/src/messages.rs`, `Account.messages`,
  `DismissUserMessages`, `UserMessage` and its enums, every
  `user_messages` field. Reasons on decisions replace them.
- Seeding from body weight, experience and gender, and those enums and
  fields. Onboarding records the starting weights the emoji picks.
- `RateExercise`, `Effort`, `CompletedSet.effort`.
- The weight sheet's tracker write after a mid-workout change.
- demo_seed's own copy of the rules: it imports sessions and lets the walk
  work out the max.
- Tests, docs and Learn copy about any of it.

## Moving existing accounts

No compatibility code; the new log is the only shape the core reads.

1. A throwaway script, run against production at the deploy and not kept
   in the repo, folds each account with the current core and writes a new
   log: settings, templates, `ImportHistory` (finished workouts, and the
   starting weights of lifts never done) and an override for each lift the
   user had customised. An open workout is ended first. The database is
   backed up (`VACUUM INTO`) before.
2. `MIN_APP_VERSION` sends old installs to the store; the server rejects
   the old log shape: a start or an add naming lifts without their
   decisions does not fold, and a push carrying one is refused as
   `account_diverged` with nothing stored.
3. On the phone: install fresh and sign in; it pulls the converted log.
   Android Auto Backup excludes the account files so a reinstall cannot
   bring the old log back.

Order: both stores hold the release (Play at 0%, App Store manual
release); deploy the backend with the conversion; release the app.
Workouts logged offline and not synced before the deploy are lost.

## Done when

- Core tests cover: each reason; time off after a hit; a miss resetting
  the max; a lowered weight holding it; an override as a new start; the
  set allocation (budget, the 2-set floor, the 5-set cap, the weekly
  deficit, override sets kept, "needs N min"); learned timings replacing
  defaults at ten samples; rounding producing an extra rep before a plate;
  a started workout unaffected by a later rule change; every weight log
  cause; Home's plan equal to a start at the same now and budget.
- The fuzzer, `make test-app` and the e2e suite pass.
- The Learn pages and docs/architecture describe this design and nothing
  else; nothing in the repo mentions trackers, user messages or gender
  seeding.

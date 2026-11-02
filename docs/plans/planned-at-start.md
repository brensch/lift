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
| a miss rushed | unchanged |

A session **stopped early** when working sets of that lift were left
undone: the lift was removed, or the workout ended first. A miss done
before the previous set's rest had run out is **rushed**: excused, not a
real miss, so it is left out of the sets judged and the max holds. The two
are separate: a rushed session had every set done, and its reasons say it
was rushed, never that it stopped early.

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

A rung done with every rep asks, on the phone, "How many more could you
have done?" (the watch says "Open phone!" meanwhile). The answer is
recorded (`AnswerRung`) and counts as reps in reserve in that rung's shown
max: 0–1 as 0.5, 2–3 as 2.5, 4+ as 5 (each range's middle; 4+ as 5).

| Answer | What follows the rung |
|---|---|
| 0–1 | the ramp ends: the working sets from `weight × (1 + 5.5/30)`, laid out as after a miss |
| 2–3, 4+ | the next rung at the heaviest loadable `w` with `w × (1 + 6/30)` ≤ the max the answer shows (a rep in reserve on five), never under the usual +10% |
| none | the usual +10% rung |

With 5 reps, 2–3 shows 1.25× the rung and a rep in reserve on five is
1.04× it, so 2–3 always takes the usual rung; 4+ shows 1.33× and gives
1.11×, which beats +10% only where the weights load that way (450 lb →
500 rather than 495). A later miss still settles the ramp as a miss.
In the walk, the ramp's max is the missed rung's, or else the last
rung's with its answer's reserve (one rep unanswered).

An override from the template editor (a weight and reps, and optionally
sets) is converted to the max that prescribes it and is the new starting
point: it takes its place among the sessions by time and the walk carries
on from it. Until a session follows it, the lift is planned exactly as
set; its max is computed from its sets, or, when it names none, from the
most sets a lift gets (5), so it holds for however many the plan gives.
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

**The longest it gets.** Each template plan also carries `max_seconds`:
the workout costed the same way with every lift whose sets are the
budget's to give at 5 (an override's sets as they are). A budget at or
past it buys nothing more, so Home's card says so beside the estimate
("~62 min · the longest it gets") and turns + off. The budget itself is
shared by every template and never moves on its own; switching templates
only shows the selected one's cap.

A workout with a lift never done (a calibration ramp) has no length to
give, since the ramp runs until a set falls short: Home's card shows the
calibration line ("Calibration session due to new weight. …") in place of
the time control. The core still costs the ramp as a lead-in, so the other
lifts' sets fit around it.

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
  reasons: [Reason]        // against last time first, then the steps in order
}

Reason {
  kind: WEIGHT_UP       // against last time: heavier
      | WEIGHT_DOWN     //   lighter
      | REPS_UP         //   the same weight, more reps
      | REPS_DOWN       //   the same weight, fewer reps
      | SAME_AS_LAST    //   the same weight and reps
      | MAX_UP          // every rep last time: the max nudged up
      | MAX_FROM_MISS   // a missed set reset the max to what it showed
      | HELD            // stopped early, a rushed miss, or the user lowered the weight
      | TIME_OFF        // 3 or 6 weeks away: the max cut
      | FIRST_TIME      // never done: the ramp finds the max
      | USER_SET        // the user's own weight, from <when>
      | SETS_FROM_TIME  // this many sets: the budget, and which muscles are behind
  before, after, detail (days off, the set that showed it, when)
  // against last time: before/after are the weights, and
  cause: HIT | MISSED | STOPPED_EARLY | RUSHED | SETS | TIME_OFF
  // HELD carries STOPPED_EARLY or RUSHED too, when it was not the weight
  reps_before, reps_after, sets_before, sets_after
}
```

**Why, in terms of the weight.** The max is the rule's number; the user
sees a weight. So the first reason compares the plan with the lift's last
session — its heaviest working weight, the reps that set was planned for,
the sets the session was planned with — and says why it moved:

| Cause | When |
|---|---|
| `TIME_OFF` | the max was cut for time away |
| `SETS` | a different number of sets, and last time's number would have moved the plan another way (more sets making it lighter, fewer letting it step up); or the max held (stopped early, rushed) and the plan moved anyway, which only the sets can have done |
| `HIT`, `MISSED`, `STOPPED_EARLY`, `RUSHED` | otherwise, how the last session went |

So 4 × 110 kg with one rushed miss, then 5 sets today at 105 kg, reads
"Down to 105 kg: 5 sets today, 4 last time." — the max held, and the extra
set is what lowered the weight.

A lift with no last session to compare with (never done, an override
still the latest word, a ramp alone) has no comparison. Screens lead with
it — "Down to 107.5 kg: 4 sets today, 3 last time." — and never show a
`HELD` max beside a weight that moved; the max's steps stay as detail.

`AddExercises` records decisions the same way; lifts already planned keep
theirs.

## During the workout

Each lift in a workout keeps a weight log: its decision, then every change.

```
WeightChange {
  at, from_set_id, before, after
  cause: USER_ADJUST          // the user changed it, phone or watch
       | CALIBRATION_STEP     // the ramp's next rung (an answer re-plans it)
       | CALIBRATION_SETTLED  // the ramp done: the working weight set (a miss, 0–1, the sixth rung)
       | CORRECTION           // a logged set fixed
}
```

Weight never drops during a workout on its own. Someone who misses reps
rests and tries again; someone who is cooked lowers the weight.

## Which workout: the rotation and the suggestion

A template is in rotation or a favourite; on screen these are the **main
plan** and the **backups**. The workouts picked at onboarding are the
rotation; a library template added from the Manage sheet joins it
(`AddLibraryTemplates` with `in_rotation`; without it, a favourite); one
the user makes starts as a favourite. The template editor has an In the
main plan switch and Home's card menu moves a template either way (saved
with `SaveTemplate`); in the Manage sheet a drag moves it, within its
section or across into the other, recorded as one `ReorderTemplates`
whose `rotation_count` says where the rotation ends. A library template
stays coupled either way. Home's chips are in three groups, each under a section label:
the main plan (☆ on the suggestion; a one-line hint when it is empty),
the backups with the Empty workout, then a line of New and Manage.

A library entry is offered only while the user does not have it: no
template follows it (`library_id`) and none was made from it
(`origin_library_id`, kept when a template becomes the user's own).
`AddLibraryTemplates` drops an entry the user has before recording, so
an entry is never added twice.

Home suggests one rotation template, worked out at every `GetHome` and
never stored:

```
score(template) = Σ over its distinct primary muscles that have recovered,
                  of max(0, 10 − hard sets this week)
```

Recovered is the recovery windows, counted from the start of the last
workout that trained the muscle: 48 h for chest, back, quads, hamstrings
and glutes; 36 h for shoulders, biceps and triceps; 24 h for calves and
core. Home's recovery chips count the same way. A template whose first
lift's primary muscle is still recovering is left out. Of the rest, every
template within 20% of the best score is tied; the tie goes to the one
started least recently, never started first. If none of them scores above
0, the one started least recently (the fallback). If every rotation
template is left out, the one whose first lift's muscle recovers soonest.
Favourites are never suggested.

The answer is structured:

```
SuggestionReason {
  behind: [{muscle, sets_7d, target}]       // what won it, most behind first
  recovering: [{muscle, hours_remaining}]   // behind but not ready
  fallback                                  // nothing ready and behind
  first_lift_recovering: {muscle, hours_remaining}
                                            // every template left out:
                                            // this one's first lift is back soonest
}
```

and Home words it under the template's name: "Chest 2/10 and back 0/10
this week, both rested · quads recovering (20h)", or "Every workout
starts on something sore. Chest's back first (5h)."

The score adds muscles up, so a short template whose muscles a bigger one
also trains seldom comes within 20% of it: in the rotation run
StrongLifts B (squat, press, deadlift, beside Lower and Full Body) is
never suggested in three weeks. The rotation check's overlap warning
names a pair that shares most of its lifts (StrongLifts A inside Full
Body).

**The rotation check.** One lap of the rotation, each template once at
three working sets a lift, counted as Home counts the week (primary 1.0,
secondary 0.5): sets per muscle, and warnings only when something is
wrong:

| Warning | When |
|---|---|
| gap | a muscle nothing in rotation trains |
| overlap | two templates share over 70% of the smaller one's lifts |

It also names what each workout outside the rotation would add: for each
backup and each library entry the user does not have, the muscles its
lifts train first that the lap trains none of (`additions`; one adding
nothing is not listed).

The Manage sheet opens on it: "Here's what an average rotation would
work. Got enough butt in it? Legs? Biceps? …" above the lap's bars, then a
plain line for an overlap. The bars are Home's rows drawn as
shares: each muscle's sets against the most-trained muscle's, with no
target band, no tick and no numbers, since a lap is not a week and the
suggestion does not go through the main plan in order. The
gap has no line of its own: each backup's and library entry's row says
what it would add, under its lifts ("Trains calves and core, which you
don't have."). Then one draggable list: the main plan's
heading and its workouts, the backups' heading and theirs (an empty
section shows "Drag a workout here" to drop on). Each row is a drag
handle, the name with its lifts on one line, and delete (one of the
user's own asks first); tapping it opens the editor. Below, Add: first
the ready-made plans (StrongLifts, Upper / Lower, Push / Pull / Legs,
Full Body; `plans` in `templates/library.yaml`), each its name, its
workouts and a line, with + to make it the main plan
(`ApplyLibraryPlan`: what the user lacks is added, the user's own copy of
an entry is used, the old main plan moves to the backups); the one whose
workouts the main plan already is (in any order) says Current instead.
Then the library entries the user does not have, by group, each with +
into the main plan.

## What each page shows

| Page | Shows | From |
|---|---|---|
| Home | the main plan's chips, the backups', then New and Manage, each group under its label; the weekly volume; the suggestion and why; the time control; each lift's sets × reps @ weight and the reason; the workout's estimated length | `plan` at now with the budget: per template (`template_plans`), and per lift with each lift as a one-lift workout (`plans`); `suggest_template` |
| Manage sheet | the rotation check: each muscle's share of a lap, and its warnings; the main plan, the backups, the ready-made plans, the library entries not yet had, each backup and entry with what it would add | `rotation_check` (`volume`, `warnings`, `additions`); `ListTemplateLibrary` (`plans`); `ApplyLibraryPlan` |
| Template editor | in rotation or not; each lift's next plan, the list on screen planned as one workout with the budget (what Home's card shows for it once saved); the sheet that sets an override. Clone opens it on a library template and records nothing until Save, which makes it the user's own | `plan` (`GetTemplatePlan`) |
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
  deficit, override sets kept, "needs N min", the longest it gets); learned timings replacing
  defaults at ten samples; rounding producing an extra rep before a plate;
  a started workout unaffected by a later rule change; every weight log
  cause; Home's plan equal to a start at the same now and budget.
- Core tests cover the comparison with last time (a miss bringing the
  weight down, more sets bringing it down, a hit bringing a rep or a step
  up, stopping early keeping it, a rushed miss holding the max and an extra
  set after it taking the blame), the suggestion (recovered muscles only,
  a recovering first lift leaving a template out, the one back soonest
  when every one is, the 20% tie and the least recent, the fallback,
  favourites left out), each rotation-check warning and what a backup or
  library entry would add; a library
  template added into the rotation, an entry the user has (coupled or
  made their own) never added again, and a reorder that also moves
  templates across the rotation's end; the progression
  scenarios' rotation run turns over (no template twice running while
  another has rested muscles behind, none opening on a recovering muscle
  while another was ready, Full Body at most 40% of days).
- The fuzzer, `make test-app` and the e2e suite pass.
- The Learn pages and docs/architecture describe this design and nothing
  else; nothing in the repo mentions trackers, user messages or gender
  seeding.

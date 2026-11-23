# Writing a Schlift program

Schlift records training: the person taps each set as they do it, and the
app keeps every set, weight and rep in a log that is only ever added to.
What the app *tells them to lift* comes from their **program**: one JSON
document that holds every training rule. It covers which exercises exist,
which workouts they do, how each lift progresses from session to session,
and every number the planner uses.

You (an assistant) write the program once, and the app then plans every
workout from it by itself. When a workout starts, the planner reads the
program and the lift's history and decides each lift's sets, reps and
weight. That decision is recorded with the workout, so setting a new
program never changes a workout already done. Every program you set is kept
in the account's history, so it can be compared with earlier ones or
reverted.

## How to work

1. Look first. `get_profile` says where the person stands, `get_progress`
   how each lift has moved (its estimated max and top set per session),
   `get_history` every set they did, and `get_program` the current program. Built-in exercises
   it leaves as they are aren't shown; `list_exercises` finds those (by
   muscle, equipment or name), and `list_library` has ready-made workouts.
2. Change the program with **edits**, not by rewriting it (below). Send
   only what changes; everything else stays as it is.
3. Run it: `simulate_program` with the same edits. It checks them (each
   problem names its path, like `workouts[upper_a].exercises[2]`) and shows
   what the draft would have prescribed for their past workouts, and what
   it prescribes for the next sessions under an assumption ("every rep
   hit", "the last set one rep short"). Read the numbers. Do they progress
   the way you meant? `lifts` keeps the output to the lifts you are
   checking, and `summary` gives one short line a session per lift.
4. Set it: `set_program` with the same edits and a one-line `note` saying
   why. The person sees the note, and the next workout plans from it. To
   go back to an earlier program, open it (`get_earlier_program`) and set
   it again with today's `workouts`.
5. Say how it went: `send_feedback`, one line (at most 144 characters) on
   what was easy, hard or missing in these tools.

## Editing

An edit is one small, named change. A list of them applies in order, all or
none: if one can't apply, nothing changes and the error says which one and
why.

```json
[
  { "set": "name", "value": "Upper/Lower for size" },
  { "set": "classes.heavy.rest_seconds", "value": 150 },
  { "set": "workouts[upper_a]", "value": {
      "name": "Upper A", "exercises": ["bench_press", "barbell_row", "lateral_raise"] } },
  { "set": "workouts[a].rotation", "value": false },
  { "remove": "workouts[b]" },
  { "move": "workouts[upper_a]", "before": "workouts[a]" },
  { "set": "progressions.squat_lp", "value": {
      "kind": "linear", "reps": 5, "increment_lb": 5,
      "deload_after_fails": 3, "deload_factor": 0.9 } },
  { "set": "exercises[squat].progression", "value": "squat_lp" }
]
```

- **Paths** are dot-separated from the top of the document. An exercise is
  `exercises[<key>]` and a workout `workouts[<id>]`, by name, never by
  position. Lists without names use a position: `time_off[0].days`,
  `warmups.ladder[2].reps`. Map entries are fields: `classes.heavy`,
  `progressions.squat_lp`, `recovery.hours.chest`.
- **`set`** puts the value at the path, replacing what is there. To change
  one field, point at that field (`workouts[a].rotation`), not the whole
  item. Setting an exercise or workout that doesn't exist adds it at the
  end; its key or id comes from the path. A new workout's `rotation`
  defaults to true and its `notes` and `from_library` to "". A new
  exercise's `short_name` defaults to its name (cut to 12), `progression`
  to none and `description` to "".
- **`remove`** takes out a workout, an exercise of the program's own, a
  list item or a map entry. Built-in exercises stay: leave one out of the
  workouts instead.
- **`move`** reorders a workout or exercise: `"before"` names the item it
  goes in front of, or `null` for the end.
- `validate_program`, `simulate_program` and `set_program` all take the
  same `edits`. Each says how many `applied`.

A whole document still works for a full rewrite: send `program` instead of
`edits`. Every field is required and a field the program doesn't have is
an error, which catches typos instead of quietly dropping them. Built-in
exercises it leaves out are added back.

All weights are in **pounds**, whatever unit the person lifts in. The app
converts for display, and every planned weight is snapped to what their
equipment can load in their unit. 20 kg is 44.0925 lb. A 2.5 kg step is
5.51 lb.

## The document

```json
{
  "schema": "schlift.program/v1",
  "name": "Strength block",
  "notes": "Three days a week; wants a bigger squat.",
  "exercises": [ … ],
  "workouts": [ … ],
  "classes": { … },
  "progressions": { … },
  "estimate": { … },
  "time_off": [ … ],
  "sets": { … },
  "costs": { … },
  "warmups": { … },
  "calibration": { … },
  "volume": { … },
  "recovery": { … },
  "rotation_check": { … },
  "end_of_exercise_rest_seconds": 60,
  "equipment": { … }
}
```

- `schema`: always `"schlift.program/v1"`.
- `name`: what the person sees the program called.
- `notes`: free text for whoever reads it next (you, later). Say who it is
  for and why it is the way it is.

### `exercises`

Every lift the program knows, in the order the app's picker shows them.
The built-in ones (squat, bench press and about 75 more) are in every
program; `get_program` shows only those a program adds or changes, and
`list_exercises` finds the rest.
Each one looks like this:

```json
{ "key": "zercher_squat", "name": "Zercher Squat", "short_name": "Zercher",
  "equipment": "barbell", "muscles": ["quads", "glutes", "core"],
  "class": "heavy", "progression": null,
  "description": "The bar held in the crooks of the elbows." }
```

- `key`: how everything names the lift. Lowercase letters, digits and
  underscores, starting with a letter, at most 48 characters. **It never
  changes meaning**: every set ever done records it. Rename the `name`
  freely, but never reuse a key for a different lift.
- `name` is 1 to 60 characters. `short_name` is 1 to 12 characters, for
  tight spaces such as a watch.
- `equipment`: one of `barbell`, `dumbbell`, `machine`, `cable` or
  `bodyweight`. It decides how weights snap and step (see `equipment`).
  Bodyweight lifts progress by reps, and their weight is added weight.
- `muscles`: the muscles it trains, **primary first**. The primary counts a
  full set toward that muscle's weekly volume, and each other muscle counts
  `volume.secondary_credit`. The ten muscles are `chest`, `back`,
  `shoulders`, `biceps`, `triceps`, `quads`, `hamstrings`, `glutes`,
  `calves` and `core`.
- `class`: a name in `classes`.
- `progression`: a name in `progressions` that overrides the class's, or
  `null` to use the class's.
- `description`: plain words on how to do it, up to 500 characters. The app
  shows it for lifts it has no picture of, which includes every lift you
  add.
- `params` (optional): this lift's own values for numbers of the rule it
  follows, so one rule serves lifts that differ in a number. See "One rule,
  several lifts" under `progressions`.
- `measure` (optional): what its number counts: `"reps"` (the default),
  `"seconds"` (a plank, a hang) or `"metres"` (a carry, a sled push). Its
  rule, scheme and history all count that: a `double` from 30 to 60 with
  `rep_step` 5 climbs a hold five seconds a session. It walks like a
  bodyweight lift: its max is the most it has shown.
- `per_side` (optional): the number is for each side (single-leg,
  single-arm work). The app says "each side".
- `tempo` (optional): a short cue such as `"3-1-1"` or `"pause at the
  bottom"`, at most 20 characters. Shown with its sets, never timed.
- `scheme` (optional): a name in `schemes` that lays out its sets, over its
  class's.

To add a lift, add an entry with a new key. You cannot remove a lift the
person has done, has a starting weight for, or has set by hand; validation
refuses it. Leave it out of the workouts instead.

### `workouts`

The workouts the person picks from, in their order:

```json
{ "id": "a", "name": "Day A", "exercises": ["squat", "bench_press", "barbell_row"],
  "rotation": true, "notes": "", "from_library": "" }
```

- `id`: stable and unique, 1 to 64 characters with no spaces. A finished
  workout names the one it came from, so keep the ids of workouts you keep.
- `name`: 1 to 60 characters.
- `exercises`: keys from `exercises`, in order, each once, at most 30.
- `rotation`: `true` puts it in the rotation that Home suggests from;
  `false` makes it a reserve. Home suggests the rotation workout whose
  rested muscles are furthest behind on the week's volume.
- `notes`: free text.
- `from_library`: the library entry it was copied from, or `""`.
- `groups` (optional): lifts whose sets alternate, a superset (two) or a
  circuit or giant set (more):

  ```json
  "groups": [ { "exercises": ["bench_press", "barbell_row"], "rest_seconds": 90 } ]
  ```

  Each group's lifts are from this workout, 2 to 8 of them, and a lift is in
  at most one. Their sets go round by round in the workout's order: each
  lift's warmups first, then the first set of each, the second of each, and
  so on (a set's drops and minis stay with it). Between lifts inside a
  round the rest is the program's `transition_seconds`; after a round,
  `rest_seconds`, or the last lift's own rest when it's `null`.

The person can still start any workout, or a workout of any lifts, in the
app. The app's template editor changes this list too.

### `classes`

Groups of lifts that share a rep range, rest and warmups:

```json
"heavy": { "rep_low": 5, "rep_high": 8, "rest_seconds": 180, "warmups": true,
           "progression": "estimated_max" }
```

- `rep_low` and `rep_high`: the rep range, 1 to 100.
- `rest_seconds`: the rest after each working set, 0 to 1800.
- `warmups`: whether the warmup ladder (`warmups`) leads into the working
  sets.
- `progression`: the name in `progressions` that its lifts follow.
- `scheme`: the name in `schemes` its lifts' sets are laid out by;
  `"straight"` (identical sets) unless you change it.

Names are lowercase with underscores. The built-in program has `heavy`
(barbell compounds), `standard` (every other loaded lift) and `bodyweight`.

### `progressions`

How a lift moves from one session to the next, by name. Each one is an
object with a `kind`. Every kind is a pure function of the lift's finished
sessions and the program, so nothing is stored between workouts.

These apply to every kind:

- **Never done:** a loaded lift first runs the calibration ramp (see
  `calibration`), which finds its max in the first session. The ramp
  settles inside the decision's rep range, at the reps that progression
  works in. `fixed` doesn't ramp. A bodyweight lift starts at the bottom of
  its range.
- **Set by hand:** when the person types their own weight × reps for a
  lift, the next session is exactly that, and the progression carries on
  from it.
- **Sets:** a progression that gives no `sets` (or `null`) leaves them to
  the time budget (see `sets`).
- **One rule, several lifts:** an exercise's `params` set its own values
  for numbers of the rule it follows, instead of a copy of the rule that
  differs in one number. For a `formula` a name is one of its `let` names,
  and the lift's number replaces that expression. For `fixed`, `linear`
  and `double` it is one of the rule's fields (`sets`, `reps`, `rep_low`,
  `rep_high`, `increment_lb`, `deload_after_fails`, `deload_factor`,
  `weight_lb`). `estimated_max` and `cycle` have none. Bigger jumps for
  legs, from one rule:

  ```json
  { "set": "progressions.reps_then_weight.let.jump_lb", "value": "5" },
  { "set": "exercises[squat].params", "value": { "jump_lb": 10 } },
  { "set": "exercises[deadlift].params", "value": { "jump_lb": 10 } }
  ```

  A name the rule doesn't have, or a value that puts the rule out of
  range, is an error at the lift (`exercises[squat].params.jump_lb`).
- **Reasons:** each plan tells the person why, in the app's words. It
  compares the plan with the last session (heavier, lighter, more reps,
  fewer, the same, and why), then the progression's own steps.

#### `estimated_max`

```json
{ "kind": "estimated_max" }
```

This is the built-in rule. Every lift has an estimated max, walked through
its sessions with the Epley estimate (`estimate`):

- Every rep hit: the max goes up by about one rep's worth.
- A rep missed: the max is what the best set showed.
- Stopped early, or a miss rushed (started before the rest was up): the
  max holds.

The plan stays at the last weight for as many reps as the max covers in the
class's range. Past the top of the range it goes up one step. With time
off, the max is cut (`time_off`). Sets come from the time budget.

#### `fixed`

```json
{ "kind": "fixed", "sets": 3, "reps": 10, "weight_lb": 25 }
```

The same numbers every time, with no ramp. Use it for accessories that
never change, or for a deload week.

#### `linear`

```json
{ "kind": "linear", "sets": 3, "reps": 5, "increment_lb": 0,
  "deload_after_fails": 3, "deload_factor": 0.9 }
```

- The same reps every session.
- Every rep hit: heavier by `increment_lb`, where 0 means the equipment's
  step.
- A rep missed: the same weight.
- `deload_after_fails` misses in a row at the same weight (0 means never):
  `deload_factor` of it, which must be over 0 and at most 1.
- Time off cuts the weight by the `time_off` table.

`sets` may be `null` to use the budget.

#### `double`

```json
{ "kind": "double", "sets": null, "rep_low": 8, "rep_high": 12, "increment_lb": 0,
  "rep_step": 1 }
```

Reps climb by `rep_step` (default 1) each session with every rep hit, from `rep_low` to
`rep_high`. Past the top, the weight goes up a step (`increment_lb`, where
0 means the equipment's step) and reps go back to `rep_low`. A miss holds
both. A bodyweight lift with `increment_lb` 0 stays at the top.

#### `cycle`

```json
{ "kind": "cycle", "steps": [
  { "sets": 3, "reps": 5, "fraction": 0.75 },
  { "sets": 3, "reps": 3, "fraction": 0.85 },
  { "sets": 1, "reps": 1, "fraction": 0.95 } ] }
```

One step per session, round and round. Each step is sets × reps at
`fraction` of the walked estimated max, with the weight snapped down to
what loads. The step is the number of sessions the lift has done, modulo
the steps. Use it for waves, heavy/light days and peaking blocks. There
are 1 to 52 steps, and each `fraction` is over 0 and at most 1.5.

#### `formula`

```json
{ "kind": "formula",
  "let": { "top": "10", "hit_top": "last.hit and last.reps >= top" },
  "sets": "3",
  "reps": "if(not has_last, 6, if(hit_top, 6, if(last.hit, last.reps + 1, last.reps)))",
  "weight": "if(hit_top, last.weight + step, last.weight)",
  "rest_seconds": null,
  "note": "Reps climb to ten, then the weight goes up a step." }
```

Your own rule, as expressions:

- `weight` is in pounds and is snapped to what loads.
- `reps` is rounded and must come to 1–100.
- `sets` is rounded to 1–20; `null` leaves it to the budget.
- `rest_seconds` is 0–1800; `null` uses the class's.
- `note` (up to 300 characters) is shown beside the plan, so write it for
  the person.
- `let` names expressions the others can use, in any order, but none may
  refer to itself.

A formula is tried on several sample histories when it is set: never done,
every rep hit, a miss, three misses, stopped early, six weeks off, heavy in
kilograms, and a bodyweight lift. One that fails on any of them is refused.
One that still fails on a real history (dividing by zero, say) plans that
lift by `estimated_max` that day and says so.

**Operators:** `+ - * / %`, `== != < <= > >=`, `and or not` (also `&& || !`),
unary `-`, parentheses, and `true`/`false`. A comparison is 1 or 0, and 0
is false.

**Functions:** `if(c, a, b)`, `min(a, b, ...)`, `max(a, b, ...)`, `abs(x)`,
`floor(x)`, `ceil(x)`, `round(x)` (halves away from zero), `clamp(x, lo,
hi)`, `round_to(x, step)`, and `snap(w)` (the nearest weight the lift can
load).

**Variables:**

| Variable | Meaning |
|---|---|
| `last.weight` | The last session's heaviest working weight (lb); 0 when never done |
| `last.reps` | The reps that set was planned for |
| `last.sets` | The working sets that session was planned for |
| `last.best_reps` | The most reps done in one working set at that weight |
| `last.amrap_reps` | The reps on its as-many-as-you-can set, 0 if it had none (see `schemes`) |
| `last.rir` | The reps left its effort answers said, on average; -1 if none was asked |
| `last.hit` | 1 when every working rep was hit |
| `last.missed` | 1 when a rep was missed (not stopped early or rushed) |
| `last.stopped_early` | 1 when working sets were left undone, or a miss was rushed |
| `has_last` | 1 once there is a session to compare with |
| `sessions` | The lift's finished sessions with working sets |
| `hits_in_row` | Sessions in a row, to the last, with every rep hit |
| `fails_in_row` | Sessions in a row, to the last, with a miss at the last weight |
| `days_off` | Whole days since the lift was last done |
| `max` | The walked estimated max (lb; reps for bodyweight); 0 when unknown |
| `start` | The lift's starting weight (lb), or 0 |
| `step` | The equipment's step (lb) in the person's unit |
| `kg` | 1 when they lift in kilograms |
| `bodyweight` | 1 for a bodyweight lift |
| `rep_low` | The bottom of the class's rep range |
| `rep_high` | The top of the class's rep range |

For a periodised formula, use `sessions % n` to know where in a block the
lift is.

### `schemes`

How a lift's sets are laid out. A progression decides a lift's working
weight W, its reps R and how many main sets N it does; its scheme turns
those into the sets one by one: top sets and back-offs, pyramids, AMRAP
sets, drop sets, rest-pause and myo-reps, clusters, EMOM. A class names
its scheme, and an exercise may name its own.

```json
"top_backoff": { "steps": [
  { "role": "top", "count": 1 },
  { "role": "backoff", "count": "rest", "fraction": 0.85, "reps": 8 } ] }
```

A scheme is a list of `steps`, each some sets of one role, in order:

- `role`: `working`, `top` or `backoff` (the **main** sets: they count as
  the lift's sets and say whether the session was hit), or `drop` or `mini`
  (taken to failure by design: they don't judge the session or move the
  max, and count `volume.partial_credit` of a set toward a muscle's week).
  The first step is a main one.
- `count`: a number of sets (0 to 20), or `"rest"`: N less the numbered
  main sets, so the time budget or the rule still sets the volume. At most
  one step takes the rest, and only a main one.
- `reps` (optional): the number for each set (reps, seconds or metres, by
  the lift's measure). Without it, the rule's R.
- `fraction` (optional, default 1): of W. For a `drop`, of the set before
  it, so two drops of 0.8 are 80% then 64%. Every weight is snapped to
  what loads.
- `amrap` (optional): as many as you can. R is the minimum; the set is hit
  at R or more, and what was done feeds the rule (`last.amrap_reps`, and
  the estimated max).
- `rir` (optional): an effort target, 0 to 5 reps left in the tank, shown
  with each of its sets. After the lift's last set with a target, done in
  full, the app asks once how it went: Easy (read as 5+ left) or Hard (0–1
  left), which tighten the estimated max and give `last.rir`; a rep tapped
  off instead is a miss. Beginners judge this poorly, so ask for it where
  it matters.
- `rest_seconds` (optional): after each of its sets; for a `mini`, the
  short pause before each one. Without it, the class's rest. A set before
  a drop rests none, and a lift's last drop or mini rests the class's rest.
- `every_seconds` (optional): EMOM. The next set starts this long after
  this one started (10 to 600).
- `on_miss` (optional): what missing one of its sets (logged short of its
  reps) changes for the rest of the lift that workout. Any of:
  - `rest_seconds`: the rest after the missed set (0 to 1800); never
    less than its usual rest, so give more than the class's or the step's;
  - `fraction`: the lift's sets still to do at this share of their weight
    (under 1), snapped to what loads;
  - `stop`: true drops the lift's sets still to do (not with `fraction`).

  The set put back to every rep, or undone, takes it back. Without it a
  miss changes nothing until the next session, where the rule reads it.
  For example, back-offs that ease off after a miss:
  `{"role": "backoff", "count": "rest", "reps": 8, "fraction": 0.85,
  "on_miss": {"rest_seconds": 240, "fraction": 0.9}}`. A straight lift that
  wants one gets a scheme of one working step with `"count": "rest"`.

The built-in program defines `straight`, `top_backoff`, `plus_set` (5/3/1's
last set), `pyramid`, `drop_finish`, `myo`, `cluster` and `emom`. Use them,
or write your own. A lift whose weight the person set by hand does exactly
that, straight sets, until the rule takes over again.

### `estimate`

The Epley estimate every set is read with:

```
max = weight × (1 + (reps + reserve + fatigue × (set − 1)) / divisor)
```

- `divisor`: 30 is Epley.
- `reserve_when_hit`: reps in reserve a set that hit its target is counted
  with. A miss counts 0.
- `fatigue_per_set`: reps of fatigue added for each set before this one.

### `time_off`

A list of `{ "days": 21, "factor": 0.9 }`. Once a lift has gone that many
days without being done, its max (or weight, for `linear` and `double`) is
cut to `factor`. The entry with the most `days` reached applies.

### `sets`

How the time budget hands out working sets. The person picks a budget on
Home before starting:

- `default_budget_minutes`: the budget when they haven't picked one.
- `min` and `max`: every lift whose sets are the budget's gets `min`. Then
  one set at a time goes, up to `max`, to the lift whose primary muscle is
  furthest below `volume.target_low` this week, until the next set won't
  fit the budget.
- `override_sets`: a weight × reps the person set by hand without naming
  sets holds for this many.

### `costs`

What a workout's parts take, until the person's own timings are learned
from their set timestamps:

- `set_seconds`: one set.
- `warmup_seconds`: a lift's warmups or ramp.
- `between_seconds`: moving to the next lift.

The rest after a set is the class's. Timings are learned over the last
`learn_window_days`, once there are `learn_samples` of a kind. Sets shorter
than `learn_min_set_seconds`, and gaps shorter than
`learn_min_gap_seconds`, were tapped through and are not learned from.

### `warmups`

- `ladder`: `{ "fraction": 0.4, "reps": 5 }` steps, lightest first, each a
  fraction of the working weight. They are snapped to the simplest plate
  load, and a step at the same weight as the one before it is dropped.
  Fractions climb, under 1, at most 10 steps.
- `rest_seconds`: the rest between warmups. The last warmup rests like a
  working set.

### `calibration`

The ramp a loaded lift never done finds its max with:

- `reps` and `rest_seconds`: each rung's reps and rest.
- `start_fraction`: the first rung is this fraction of the starting weight,
  never under the opener.
- `rung_factor`: after a full rung, the next is at least this much heavier
  (and at least one step).
- `too_heavy_reps`: a rung with fewer reps than this was too heavy to say
  anything. The next rung is `step_down` of it, but never back at or under
  a rung done in full.
- `max_rungs`: the ramp stops by then whatever happened.
- `max_jump_fraction`: the most a typed jump can be, as a multiple of the
  rung.

After a full rung the app asks "how many more could you have done?" Each
answer counts as reps in reserve: 0–1 counts `reserve_zero_to_one` (and
settles the ramp), 2–4 counts `reserve_two_to_four`, and 5+ counts
`reserve_five_plus`.

### `volume`

Hard sets per muscle over the last `window_days`, which Home shows against
`target_low` to `target_high`. A working set counts 1 for its exercise's
primary muscle and `secondary_credit` for each other; a drop or mini set
counts `partial_credit` of that (default 0.5). Rotation workouts
within `tie_fraction` of the best score are tied, and the tie goes to the
one done least recently.

### `recovery`

`hours`: the hours each muscle needs before Home counts it as rested, as
`{ "chest": 48, … }`. `default_hours` applies to any muscle not named. A
rotation workout whose first lift's muscle is still recovering is not
suggested.

### `rotation_check`

Home's check of the rotation's shape. One pass counts each lift as
`sets_per_lift` sets. It warns of a muscle nothing trains, and of two
workouts sharing more than `overlap_fraction` of the smaller one's lifts.

### `end_of_exercise_rest_seconds`

The rest after a lift's last set, before moving on.

### `transition_seconds`

The rest between two lifts of a group (`workouts.groups`) inside a round,
0 to 300 (default 15): the walk from one station to the next.

### `equipment`

For each of `barbell`, `dumbbell`, `machine`, `cable` and `bodyweight`:

```json
"dumbbell": { "opener": { "lb": 20, "kg": 10 }, "step": { "lb": 5, "kg": 2 } }
```

- `opener`: the weight a lift never done starts the ramp at, in each unit's
  own scale. `null` on `barbell` means the empty bar.
- `step`: the grid weights snap to and the increment progressions add, in
  each unit's own scale. It must be over 0 for loaded equipment.

`plates`: the gym's barbell setup:

```json
"plates": { "bar": { "lb": 45, "kg": 20 },
            "lb": [45, 35, 25, 10, 5, 2.5],
            "kg": [25, 20, 15, 10, 5, 2.5, 1.25] }
```

Plates are listed heaviest first, each once. Barbell weights snap to what
the bar and a pair of plates make, and never go under the bar.

## A worked example

Three days a week, with squat on linear progression, a double progression
for a new exercise, and a three-step wave for deadlift. Only the parts that
differ from the built-in program are shown; the document you set holds
everything.

```json
"progressions": {
  "estimated_max": { "kind": "estimated_max" },
  "lp": { "kind": "linear", "sets": 3, "reps": 5, "increment_lb": 0,
          "deload_after_fails": 3, "deload_factor": 0.9 },
  "reps_then_weight": { "kind": "double", "sets": 3, "rep_low": 6, "rep_high": 10,
                        "increment_lb": 0 },
  "wave": { "kind": "cycle", "steps": [
    { "sets": 3, "reps": 5, "fraction": 0.7 },
    { "sets": 3, "reps": 3, "fraction": 0.8 },
    { "sets": 1, "reps": 1, "fraction": 0.9 } ] }
},
"exercises": [
  { "key": "squat", "...": "...", "progression": "lp" },
  { "key": "deadlift", "...": "...", "progression": "wave" },
  { "key": "pause_squat", "name": "Pause Squat", "short_name": "Pause Sq",
    "equipment": "barbell", "muscles": ["quads", "glutes"], "class": "heavy",
    "progression": "reps_then_weight",
    "description": "A full two-second pause in the hole, then drive up." }
],
"workouts": [
  { "id": "mon", "name": "Monday", "exercises": ["squat", "bench_press", "barbell_row"],
    "rotation": true, "notes": "", "from_library": "" },
  { "id": "wed", "name": "Wednesday", "exercises": ["deadlift", "overhead_press", "pull_up"],
    "rotation": true, "notes": "", "from_library": "" },
  { "id": "fri", "name": "Friday", "exercises": ["pause_squat", "bench_press", "barbell_row"],
    "rotation": true, "notes": "", "from_library": "" }
]
```

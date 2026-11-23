# Set types, and changes from other people

**Status: planned.** Builds on [programs-as-config](programs-as-config.md)
and [mcp-edits](mcp-edits.md). Keeps the hierarchy of
[one-tap-sets](one-tap-sets.md) §8 and §13: one primary number, one primary
action, everything else small and grey; a set is a circle you tap.

Two things, designed together because both are about *what a workout is
and who decides it*:

1. **Every common set type**: top sets and back-offs, pyramids, AMRAP,
   drop sets, supersets, circuits and giant sets, rest-pause, myo-reps and
   clusters, effort targets, timed and distance sets, per-side sets, tempo
   and EMOM. A program (an assistant, a friend, the built-in rules) can
   prescribe any of them; the phone and both watches show them the same
   way.
2. **Changes from other people**: someone you allow (a coach, a training
   partner, or their assistant) can suggest a workout or a program change.
   You see who suggested what, and you choose.

## Where it starts

- A lift's plan is one block of identical sets: `ExerciseDecision` has one
  `sets`, `reps`, `weight` and `rest_seconds`, and layout copies it
  (`core/src/workout/planning.rs` `working_sets`).
- A workout is a flat ordered list of sets, each naming its lift. Most
  operations find a lift's sets by that key, and a lift is in a workout at
  most once. Supersets and AMRAP existed once and were removed because
  nothing produced them (commit 2601235; `one-tap-sets.md` §2). Programs
  and assistants produce them now.
- Layout runs inside the fold, from the decision and the `Rules` recorded
  at the start. Whatever is added must lay out old decisions exactly as
  before, or completed sets stop pointing at their sets.
- The app logs a set by tapping its circle. The bottom banner
  (`StatusBox`) has no buttons and holds the same circle. The watches draw
  a snapshot the phone builds with the same functions (`setLineFor`,
  `setTextFor`, `setCircleState`), and a watch circle already carries its
  own text.
- Only one person writes an account. The one exception is an assistant
  setting a program, recorded with its name.

## 1. Set types

### The idea in one paragraph

A program's rule still decides a lift's **working weight W, reps R and
number of sets N**. A new, named **scheme** lays those sets out: a short
list of **steps**, each a few sets of one role at a fraction of W. The
lift's **measure** says whether the number R counts reps, seconds or
metres. A workout can **group** lifts so their sets alternate. Everything
else (AMRAP, effort targets, EMOM, tempo, per side) is a property of a step
or a lift. One mechanism covers the whole table:

| Type | How it's written |
|---|---|
| Straight sets | the default scheme: one step, `count: "rest"` |
| Top set + back-offs | `[{role: top, count: 1}, {role: backoff, count: "rest", fraction: 0.85, reps: 8}]` |
| Pyramid / reverse pyramid | several `working` steps with rising or falling `fraction` and `reps` |
| AMRAP / "+" set (5/3/1) | `amrap: true` on a step: R is the minimum, the reps done feed the rule |
| Drop sets | `{role: drop, count: 2, fraction: 0.8}` after the working steps: each drop is 80% of the set before it, no rest |
| Rest-pause, myo-reps | `{role: mini, count: 4, reps: 3, rest_seconds: 15}` after an activation set |
| Clusters | `working` sets of `mini` blocks: `{role: mini, count: "rest", reps: 2, rest_seconds: 20}` |
| Effort target (RIR) | `rir: 2` on a step: after the lift's last such set the banner asks *how was that?*: Easy, Hard, or its reps tapped down |
| On a miss | `on_miss: {rest_seconds: 240, fraction: 0.9}` on a step: a missed set rests longer and lightens what's left; `{stop: true}` ends the lift there |
| Timed (planks, holds) | the lift's `measure: "seconds"`: R is seconds |
| Distance (carries, sleds) | `measure: "metres"` |
| Per side | the lift's `per_side: true`: "8 each side" |
| Tempo | the lift's `tempo: "3-1-1"`: shown, not timed |
| EMOM / density | `every_seconds: 60` on a step: each set starts a minute after the last one started |
| Supersets, circuits, giant sets | a workout's `groups: [{exercises: [bench_press, barbell_row]}]` |

### In the program

```jsonc
"schemes": {
  "straight": { "steps": [ { "role": "working", "count": "rest" } ] },
  "top_backoff": { "steps": [
    { "role": "top", "count": 1 },
    { "role": "backoff", "count": "rest", "fraction": 0.85, "reps": 8 } ] },
  "531_plus": { "steps": [
    { "role": "working", "count": 2, "fraction": 0.9 },
    { "role": "working", "count": 1, "amrap": true } ] },
  "drop_finish": { "steps": [
    { "role": "working", "count": "rest" },
    { "role": "drop", "count": 2, "fraction": 0.8 } ] },
  "myo": { "steps": [
    { "role": "working", "count": 1 },
    { "role": "mini", "count": 4, "reps": 4, "rest_seconds": 15 } ] },
  "emom": { "steps": [ { "role": "working", "count": "rest", "every_seconds": 60 } ] }
}
```

- **`schemes`**: by name, like `classes` and `progressions`. A **class**
  names its `scheme` (default `"straight"`). An **exercise** may name its
  own `scheme`, over its class's, and tune it with `params` like a rule.
- **A step:**

  | Field | Default | |
  |---|---|---|
  | `role` | | `working`, `top`, `backoff`, `drop` or `mini` |
  | `count` | | a number of sets, or `"rest"`: what is left of N after the numbered steps (at least 0; at most one `"rest"`) |
  | `reps` | the rule's R | the number for each set (reps, seconds or metres, by the lift's measure) |
  | `fraction` | 1 | of W. For a `drop`, of the set before it |
  | `amrap` | false | R is the minimum; the person does what they can |
  | `rir` | none | an effort target, 0 to 5: reps left in the tank |
  | `rest_seconds` | the class's rest; 0 for a drop | after each set of the step |
  | `every_seconds` | none | EMOM: the next set starts this long after this one started |
  | `on_miss` | none | what a miss (a set logged short of its reps) changes for the rest of the lift that workout: `rest_seconds` (the rest after it, never less than the usual), `fraction` (the sets still to do at this share of their weight), `stop` (they're dropped). Put back to every rep, or undone, it's taken back |

- **On the exercise:** `measure` (`"reps"`, `"seconds"` or `"metres"`;
  default reps), `per_side` (default false), `tempo` (a short cue, default
  ""), `scheme` (default none: the class's).
- **On a workout:** `groups`, each `{ "exercises": [keys], "rest_seconds":
  null }`. A group's lifts alternate set by set, in the workout's order. The
  rest between lifts inside a round is `transition_seconds` (program-wide,
  default 15). After a round, the last lift's own rest applies, or the
  group's `rest_seconds`. A lift is in at most one group.
- **Progressions are unchanged.** They decide W, R and N whatever the
  scheme; `double` gains `rep_step` (default 1), so a hold can climb 5
  seconds at a time.
- **The built-in program** gets the example schemes above, and every class
  stays `straight`. Nobody's plan changes until a program asks for it.

### What a session tells the rule

| Role | Counts for hit or miss, and the estimated max | Weekly volume |
|---|---|---|
| `working`, `top`, `backoff` | yes, as now | 1 set |
| `drop`, `mini` | no: they are taken to failure by design | `volume.partial_credit` (default 0.5) |

- **AMRAP:** a set with `amrap` is hit at R or more, and its reps feed the
  estimate as any set's do (the walk already takes the most reps shown).
  New formula variables: `last.amrap_reps` (the reps on its AMRAP set, 0 if
  none) and `last.rir` (the average reps left reported on working sets, -1
  if none asked).
- **Effort answers** also tighten the estimate: where a working set has an
  answer, the walk uses its reps left in place of `estimate.reserve_when_hit`.
- **Timed and distance lifts** walk like bodyweight lifts: the max is the
  most seconds or metres shown, at the weight used.
- **Time budget:** a lift's cost sums its planned sets (a `mini` costs half
  a set) and their own rests; an EMOM step costs `count × every_seconds`.

### In the record

The decision records the laid-out shape, relative to W, so layout needs
nothing else and old decisions lay out as before:

- `ExerciseDecision.scheme_sets` (new, repeated `PlannedSet`): one entry a
  set, `role`, `reps`, `fraction`, `amrap`, `rir`, `rest_seconds`,
  `every_seconds`. Empty means today's identical sets. Also `measure`,
  `per_side`, `tempo` and `group` (the group's id within the workout).
- `ProposedSet` gains `role`, `amrap`, `target_rir`, `measure`, `per_side`,
  `tempo`, `group` and `every_seconds` (new numbers, new names; the reserved
  `is_amrap` and `exercise_group_id` stay reserved). Its weight is
  `snap(W × fraction)`, chained for drops. After a ramp settles, or when
  the person changes the weight mid-workout, the steps scale from the new
  W.
- `CompletedSet.actual_reps` holds the measure: reps, seconds or metres.
  The effort answer is the existing `reps_left`.
- One new fact, **`EffortAnswered { workout_id, proposed_set_id,
  reps_left }`**, from a new mutation `AnswerEffort`. A ramp keeps
  `RungAnswered`.
- **Groups:** layout interleaves the grouped lifts' sets round by round,
  which changes only `workout_order` and the rests inside a round. Each
  lift's sets stay its own, found by its key as now. Reorder moves a group
  as one; a lift added mid-workout joins no group. "Up next" is already
  "the first undone set in order", so alternating needs nothing more.
- **EMOM:** a set with `every_seconds` rests until its start plus
  `every_seconds`, not its end plus its rest.

### On the phone

The lift card keeps its shape: name, pencil, `55 lb × 8`, the reason, then
rows of circles labelled down the left edge.

- **Rows by role:** *Warmup*, *Working* (working, top and back-off
  together, in order), *Drop*, *Myo* (minis). A row appears only when the
  lift has sets of that role.
- **A circle shows its number:** `8`, `8+` for AMRAP, `45s` for seconds,
  `20m` for metres. A circle whose weight differs from the card's (a
  back-off, a drop, a pyramid step) shows its weight small underneath. A
  set with an effort target shows a small `@2` beside it.
- **Under the name**, grey, only when set: `each side`, `tempo 3-1-1`.
- **Groups:** a superset or circuit is one section, dragged as one: its
  lifts' names stacked, each with its own weight × reps and pencil, then
  one row of circles in the order they're done (A1 B1, a gap, A2 B2), the
  row labelled *Superset* (two lifts) or *Circuit* (more) and each circle
  with its lift's short code under it ("LR", "Pl"). The circle in hand
  moves along the row.
- **The banner** (`StatusBox`) keeps one primary number:
  - the position line names the role: "Top set", "Back-off 2 of 3",
    "Drop 1 of 2", "Mini 3 of 4", "2 of 5 · each side";
  - the circle is the same circle, `8+` or `45s`;
  - a **timed set** while lifting counts **down** from its target, in the
    band's clock, and buzzes at zero (lifting still starts and ends on the
    circle);
  - **EMOM** resting counts down to the next start;
  - tempo and per side ride the position line, never a new element.
- **Effort question:** once a lift a workout, after its last set with a
  target, the ramp's dialog asks *how many more could you have done?* with
  the same three answers (asking after every set was too much). It can be
  dismissed; an unanswered set is simply unanswered.
- **AMRAP entry:** a circle shows `8+`. Tapping the lifted set completes it
  at 8 as now, and each further tap on the done circle adds a rep, up to
  99, instead of taking one off (a short/zero tap-down stays on every other
  set). The banner's line says "As many as you can".

All words are placeholders in `app/copy.yaml` for the owner to write.

### On the watches

The watch face is the banner stacked for the wrist, built from the phone's
snapshot, so most of this arrives as text the phone already renders:

- `set_line` carries the role ("Drop 1 of 2"), `reps_text` and each
  `WearSetCircle.text` carry `8+`, `45s`, `20m`;
- new snapshot fields: `lifting_target_seconds` (a timed set counts down)
  and `next_start_at` (EMOM), plus `effort_prompt` with the three answers'
  labels, which the watch shows as three buttons and answers with a new
  `WearIntent.AnswerEffort`;
- AMRAP's tap-up is the phone's `tapSet`, which the watch already calls.

Wear OS (`WearScreens.kt`) and Apple Watch (`FaceScreen.swift`) each add
the countdown, the three effort buttons and the circle's small weight; the
rest is the strings.

## 2. Changes from other people

### Who may

- **A grant** is server-owned, like passkeys and assistants: a row in
  `program_editors (owner_id, editor_id, created_at)`, both referencing
  `users(id) ON DELETE CASCADE`. A grant lets the editor **see your
  training and your program, and suggest changes**. It never lets them
  change anything without you.
- You give it to someone you've trained with, from **Multiplayer →
  Friends**: each friend row gets *Can suggest workouts*. Settings →
  Program lists everyone who may, with revoke, beside the connected
  assistants.
- **Your own assistants** can be set to *Ask me first* (per grant, on the
  same screen). Then their `set_program` becomes a suggestion. The default
  stays as now: it applies.

### A suggestion

- **`ProgramSuggested { edits, note, kind, from, from_name }`**, a new fact
  in **your** log. The server places it on behalf of the editor, as it does
  an assistant's `set_program`:
  - `edits` are the MCP edits (`docs/plans/mcp-edits.md`), applied to your
    program **when you accept**, so a suggestion made last week still
    applies on top of what you have now;
  - `kind` is `workout` (it adds or changes one workout) or `program`;
  - `from` is `person:<user id>` or `mcp:<client>` (with `from_name` for
    display).

  The fold keeps pending suggestions on the account. The suggestion's id is
  the event's.
- **`SuggestionAnswered { suggestion_id, accepted }`.** Accepting records
  this and then a `ProgramSet` whose author is the suggester and whose note
  is theirs. If the edits no longer apply (say, the workout they change was
  deleted), the app says so and offers only *Decline*.
- **Ways in:**
  - **A friend, in the app:** on their own Multiplayer → Friends, a friend
    who allowed them shows *Suggest a workout*. It picks one of their own
    workouts and sends it as a `workout` suggestion, carrying any exercises
    and schemes of theirs it uses.
  - **A friend's assistant, over MCP:** `list_people` (who lets you
    suggest), and `person` on `get_program`, `get_history`, `get_progress`
    and `simulate_program` to read theirs. `suggest_change(person, edits,
    note)` sends it. Each needs the grant, checked on every call.
  - **Your assistant, on *Ask me first*:** `set_program` replies
    "suggested; they'll decide".
- **Server:** `SharingService` (`GrantEditor`, `RevokeEditor`,
  `ListEditors`, `ListPeopleICanSuggestTo`, `SuggestWorkout`). Each handler
  calls `authed_user_id` itself. Suggesting reads the owner's account,
  checks the grant, builds the fact through the core's `Call`, and pushes it
  to the owner's log, so it reaches their phones on the sync stream.

### Where it shows

No inbox; the existing places:

- **Home:** a **Pending suggestion** row above the Rotation, one chip per
  suggestion ("Push power · Sam"). Every suggestion is one whole change to
  the program, whether it adds a workout or rewrites the progressions, so
  it is decided whole.
- **The popup** (`ExplainSuggestion`, laid out by the core, said in
  `copy.yaml`): who and their note, then
  - *Your week*: the rotation after, the one now under it, and each
    workout added, changed or gone with its lifts;
  - *How your lifts move*: each trained lift whose progression or scheme
    changes, in a sentence ("5 reps a set; hit them all and it adds 5 lb"),
    with "Was: …" under it, or "New to you";
  - *Also*: any other number it changes, before → after;
  - *Use this program* and *No thanks*.
- **Settings → Program:** **Pending suggestions** above Earlier programs,
  one row each with who and their note; it opens the same popup.
- **The menu button's badge** counts pending suggestions beside the session
  count it shows now.
- **History:** Earlier programs already say who set each one; an accepted
  suggestion reads "Suggested by Sam, accepted Nov 23".

## Order of work

1. **Core:** schemes, the new decision and set fields, layout, groups,
   EMOM rests, `EffortAnswered`, outcomes and the walk, volume, the time
   budget, the simulator, validation, the guide and the MCP edits.
   `stored_events` gets the new facts.
2. **Phone:** circles, rows, the banner's position line and countdowns,
   the effort dialog, AMRAP tap-up and the group rule, with copy
   placeholders.
3. **Watches:** the snapshot fields and intent, then Wear OS and Apple
   Watch (compiled in CI: `ios-debug-compile.yml`).
4. **Suggestions:** grants and `SharingService`, the two facts, the MCP
   person tools, then Friends, Home, Program and the badge.

Each step ships to dev and is checked on a phone before the next.

## Not in this change

- Video or pictures for new lifts.
- A coach seeing many people's dashboards at once: one person at a time,
  through the same tools.

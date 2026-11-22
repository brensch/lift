# Programs as config

**Status: being built** on the `program-config` branch. This file is the
spec. The architecture docs are updated as each part lands.

## The idea

The app records what you lift. *What it tells you to lift* is decided by a
**program**: one JSON document in the account that holds every training rule.

- **Exercises:** what each lift is, how it loads, what it trains.
- **Workouts:** the templates, and which of them are the rotation.
- **Progressions:** how each lift moves from one session to the next.
- **Constants:** every number the planner used to hard-code (the estimate,
  time off, the time budget, the warmup ladder, the calibration ramp, weekly
  volume, recovery windows, equipment steps and plates).

An assistant (an LLM) writes the program through an authorised MCP
connection. From then on the app plans every workout from it without
further prompting.

The rules built into the code become a program too: `core/programs/default.json`,
the program every account starts with. Nothing about training is a
constant in the code any more.

We have a handful of alpha users. There is no compatibility layer: one
server migration rewrites every stored account into the new shapes, old
apps are refused with `MIN_APP_VERSION`, and phones drop their local copy
and pull the migrated log again.

## Principles

- **The log is the truth and is only added to.** A `ProgramSet` event holds
  the whole document. The latest one plans. Reverting means setting an
  older one again.
- **A workout records the program it was planned under**
  (`WorkoutStarted.program_id`). Its sets fold under that program whatever
  is set later, so a replay is exact and the server and phone agree even
  when a program set elsewhere is placed before a workout started offline.
- **The planner is a pure interpreter:** `(program, history, now) →
  decisions`. Because it is pure, any draft program can be run over the
  recorded history. That is what `simulate` does for an assistant.
- **The program is text an assistant can read and write.** It has a guide
  (`core/programs/GUIDE.md`) that explains every field, and the core
  validates it with errors that name the path (`progressions.squat_lp.reps`).
- **The app records; it does not decide.** Every screen shows the core's
  answer. The template editor, the rotation drag and onboarding are edits to
  the program, recorded as `ProgramSet` with `author: "app"`.

## The document

```jsonc
{
  "schema": "schlift.program/v1",
  "name": "Winter strength",
  "notes": "3 days a week; shoulder-friendly pressing.",

  "exercises": [
    { "key": "squat", "name": "Squat", "short_name": "Squat",
      "equipment": "barbell", "muscles": ["quads", "glutes"],
      "class": "heavy", "progression": null, "description": "" },
    { "key": "zercher_squat", "name": "Zercher Squat", "short_name": "Zercher",
      "equipment": "barbell", "muscles": ["quads", "glutes", "core"],
      "class": "heavy", "progression": "squat_lp",
      "description": "Bar in the crooks of the elbows." }
  ],

  "workouts": [
    { "id": "a", "name": "Day A", "exercises": ["squat", "bench_press", "barbell_row"],
      "rotation": true, "notes": "", "from_library": "stronglifts_a" }
  ],

  "classes": {
    "heavy":    { "rep_low": 5, "rep_high": 8,  "rest_seconds": 180, "warmups": true,  "progression": "estimated_max" },
    "standard": { "rep_low": 8, "rep_high": 12, "rest_seconds": 120, "warmups": false, "progression": "estimated_max" }
  },

  "progressions": {
    "estimated_max": { "kind": "estimated_max" },
    "squat_lp": { "kind": "linear", "sets": 3, "reps": 5, "increment_lb": 5,
                  "deload_after_fails": 3, "deload_factor": 0.9 },
    "ohp_reps": { "kind": "formula",
                  "let": { "top": "10" },
                  "sets": "3",
                  "reps": "if(last.hit and last.reps < top, last.reps + 1, if(last.hit, 6, last.reps))",
                  "weight": "if(last.hit and last.reps >= top, last.weight + step, last.weight)",
                  "note": "Reps climb to 10, then the weight goes up a step." }
  },

  "estimate":    { "divisor": 30, "reserve_when_hit": 1, "fatigue_per_set": 0.5 },
  "time_off":    [ { "days": 42, "factor": 0.8 }, { "days": 21, "factor": 0.9 } ],
  "sets":        { "default_budget_minutes": 60, "min": 2, "max": 5, "override_sets": 5 },
  "costs":       { "set_seconds": 40, "warmup_seconds": 240, "between_seconds": 120, "...": "..." },
  "warmups":     { "ladder": [ { "fraction": 0.4, "reps": 5 }, "..." ], "rest_seconds": 30 },
  "calibration": { "reps": 5, "rest_seconds": 90, "start_fraction": 0.6, "...": "..." },
  "volume":      { "window_days": 7, "target_low": 10, "target_high": 20, "secondary_credit": 0.5, "tie_fraction": 0.8 },
  "recovery":    { "hours": { "chest": 48, "...": 0 }, "default_hours": 48 },
  "rotation_check": { "sets_per_lift": 3, "overlap_fraction": 0.7 },
  "end_of_exercise_rest_seconds": 60,
  "equipment": {
    "barbell":  { "opener": null, "step": { "lb": 5, "kg": 2.5 },
                  "bar": { "lb": 45, "kg": 20 },
                  "plates": { "lb": [45, 35, 25, 10, 5, 2.5], "kg": [25, 20, 15, 10, 5, 2.5, 1.25] } },
    "dumbbell": { "opener": { "lb": 20, "kg": 10 }, "step": { "lb": 5, "kg": 2 } }
  }
}
```

- **Exercise identity is the `key`.** It is a string everywhere: protos,
  events, templates. The `Exercise` enum is gone. A key never changes
  meaning. A program may rename an exercise, but not drop one the account
  has history, overrides or starting weights for.
- **Muscles** stay the fixed ten (the app draws them). **Equipment** stays
  the five kinds (the app filters and does plate maths by them). Their
  numbers are the program's.
- **Workouts** replace templates. Order is the user's. `rotation: true` is
  the rotation, the rest are reserves. `id` is stable: a finished workout
  names the template it came from. `from_library` only says where it was
  copied from. Library coupling is gone: a library entry is copied, never
  followed.

### Progressions

Every progression is a pure function of the lift's finished sessions, its
walked estimated max, the program and now. Nothing is stored between
workouts.

| Kind | Sets | Reps and weight |
|---|---|---|
| `estimated_max` | the time budget | The walk (Epley with reserve and fatigue), the class's rep range, time-off cuts. Today's planner. |
| `fixed` | given | Given. |
| `linear` | given, or the budget | Fixed reps. A step heavier (`increment_lb`, 0 = the equipment's step) after every rep hit. The same weight after a miss. `deload_factor` of it after `deload_after_fails` misses in a row. |
| `double` | given, or the budget | Reps climb by one per session with every rep hit, from `rep_low` to `rep_high`. Past the top, a step heavier and back to `rep_low`. |
| `cycle` | per step | A list of steps (`sets`, `reps`, `fraction` of the estimated max), one per session, round and round: waves, heavy/light days. |
| `formula` | an expression, or the budget | Expressions (below). |

These apply to every kind:

- **Never done:** a loaded lift runs the calibration ramp. When the ramp
  settles, the working sets come from the max it found, at the decision's
  rep range. A bodyweight lift starts at the bottom of its range.
- **Time off** cuts the weight (or max) by the program's `time_off` table.
  A formula reads `days_off` and decides for itself.
- **Override** (the user's own weight × reps on the exercise sheet): the
  next session is exactly that, and the rule carries on from it.

### Formulas

Formulas are a small expression language evaluated by the core
(`core/src/program/formula.rs`). It is deterministic: f64 with only
`+ − × ÷`, comparisons and rounding, so the phone and the server agree. It
has no loops, no state, no clock and no I/O, and limits on length and depth.

- **Operators:** `+ - * / %`, `== != < <= > >=`, `and or not`, unary `-`,
  parentheses.
- **Functions:** `if(c, a, b)`, `min`, `max`, `abs`, `floor`, `ceil`,
  `round`, `clamp(x, lo, hi)`, `round_to(x, step)`, `snap(weight)` (the
  heaviest loadable weight at or under it).
- **Variables:**

  | Variable | Meaning |
  |---|---|
  | `last.weight`, `last.reps`, `last.sets` | The last session's heaviest working weight (lb), the reps it was planned for, and the sets planned |
  | `last.hit`, `last.missed`, `last.stopped_early` | How the last session went (1 or 0) |
  | `last.best_reps` | The most reps done in one working set at that weight |
  | `has_last` | 0 when the lift has never been done |
  | `sessions` | The finished sessions of this lift |
  | `hits_in_row`, `fails_in_row` | Sessions in a row with every rep hit, or with a miss |
  | `days_off` | Days since the lift was last done |
  | `max` | The walked estimated max (lb; reps for bodyweight) |
  | `start` | The starting weight |
  | `step` | The equipment's step in lb |
  | `kg` | 1 when the user lifts in kilograms |
  | `bodyweight` | 1 for a bodyweight lift |
  | `rep_low`, `rep_high` | The class's rep range |
  | your `let` names | Defined in order, each able to use the ones before it |

- **Outputs:** `weight` (lb, snapped to what loads), `reps`, and optionally
  `sets` (otherwise the budget gives them) and `rest_seconds`. `note` is
  the text shown beside the plan.
- **Checking:** a formula that doesn't parse, names an unknown variable or
  gives a non-finite or out-of-range result on the validation histories is
  refused when the program is written. If one still fails at plan time, the
  lift falls back to `estimated_max` and its reasons say so. A workout
  always starts.

## In the log

The facts change like this:

- **`ProgramSet { program, author, note }`** (new): the whole document,
  inline as JSON. `author` is `app`, `builtin`, `migration` or
  `mcp:<client>`.
- **`TemplateSaved`, `TemplateDeleted`, `TemplatesReordered`,
  `LibraryTemplatesAdded`: gone.** Template edits are program edits.
- **`Onboarded { unit, strength, starting_weights }`** loses
  `library_entries`. Onboarding records it, then a `ProgramSet` with the
  chosen workouts.
- **`WorkoutStarted`** gains `program_id`: the `ProgramSet` event's id, or
  `""` for the built-in program.
- **Exercise fields become strings** everywhere: decisions, sets, overrides,
  starting weights, imports.

The account holds the current program and its id, and every program by id,
which the workouts planned under them share.

## The API

The app's RPCs stay where they still make sense; their implementations
change.

| RPC | What it does now |
|---|---|
| `SaveTemplate`, `DeleteTemplate`, `ReorderTemplates` | Edit the program's workouts, recorded as `ProgramSet` (author `app`) |
| `AddLibraryTemplates`, `ApplyLibraryPlan` | Copy library workouts into the program. `ApplyLibraryPlan` also sets the rotation |
| `CompleteOnboarding` | `Onboarded`, then `ProgramSet` (the built-in rules with the chosen workouts) |
| `GetProgram` (new) | The current program's JSON, id, author, note and when it was set; the history of earlier programs; the guide |
| `SetProgram` (new) | Validates a whole document against the account, then records it |
| `ValidateProgram` (new) | Problems with a draft, without writing it |
| `SimulateProgram` (new) | A draft run over the recorded history (what it would have prescribed each session) and forward N sessions under an assumption: every rep hit, every session missed, or a miss every Nth session |
| `ListExercises` (new) | The program's exercises as the app shows them, and the plates |

The server's template library transport goes away. The library is
`templates/library.yaml`, built into the core.

## The MCP

The MCP is on the server binary at `/mcp` (Streamable HTTP, JSON-RPC 2.0).

### Auth

The MCP uses OAuth 2.1 as the MCP authorisation spec describes it:

- protected-resource metadata, and authorisation-server metadata
- dynamic client registration
- authorisation code with PKCE (S256 only)
- a consent page: sign in with your passkey, see the client's name, Allow.

Access tokens are short-lived, with a rotating refresh token. Grants are
server-owned rows in `mcp_clients`, `mcp_grants` and `mcp_tokens`, keyed to
`users(id) ON DELETE CASCADE`. Settings → Connected assistants lists the
grants and revokes them.

### Tools

| Tool | Does |
|---|---|
| `read_guide` | The guide: what a program is and every field |
| `get_program` | The current document, and its history |
| `get_history` | Finished workouts: every set's target and what was done, by lift and date |
| `get_profile` | Unit, starting weights, overrides, this week's volume, recovery |
| `validate_program` | A draft's problems |
| `simulate_program` | As the RPC |
| `set_program` | Validate and record. The server places the event and streams it to the phones. |

The MCP never records training. Sets are recorded by the app.

## Migration

A server step in `src/db/migrate.rs`, one time, over every account's events:

- exercise numbers become their keys, everywhere
- template events are folded the old way, coupled templates resolved
  against the library, and the result becomes one `ProgramSet` (the
  built-in rules with the user's workouts, author `migration`) where the
  first template event was
- `Onboarded.library_entries` is dropped
- seqs are renumbered.

The phone's store `FORMAT` is bumped, so every phone drops its local log
and pulls the migrated one. `MIN_APP_VERSION` refuses older apps.

## Not in this change

- Muscles beyond the ten, and equipment kinds beyond the five.
- Pictures for custom exercises: they get a generic one and their
  description.

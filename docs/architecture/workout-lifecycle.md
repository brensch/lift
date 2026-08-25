# Workout Lifecycle

This is where most of the system's complexity lives. A workout goes from a
*template* (an ordered exercise list) to an *active workout* (what you're
actually doing) to a *completed workout* (which advances the trackers).

## The loop

```mermaid
graph LR
    tmpl["Template<br/>exercises only"] -->|"StartWorkout resolves<br/>trackers + prescription"| active["Active workout"]
    active -->|"StartSet / CompleteSet"| active
    active -->|"EndWorkout"| done["Completed workout"]
    done -->|"advance_tracker<br/>(double progression)"| trk["Exercise trackers<br/>one per exercise"]
    trk --> tmpl
```

The cycle closes on `EndWorkout`: each exercise's outcome advances its
tracker, and the next start from any template resolves the new numbers.

## Objects

```mermaid
graph TD
    W["Workout<br/>id, name, start_time, end_time, session_id"]
    PS["ProposedSet<br/>what you should lift"]
    CS["CompletedSet<br/>what you did lift"]

    W -->|"ordered by workout_order"| PS
    PS -->|"0..1"| CS
```

A workout is an ordered flat list of `ProposedSet`s; each set carries its
exercise. "The sets for one exercise" is a *derived* block (grouped by
exercise), computed where a card or sheet needs it — never stored. There is
no group or superset structure.

`generate_sets_for_exercise` (`src/workout/planning.rs`) prescribes one
exercise's block: the warmup ladder (where prescribed) then the working
sets.

## Set state machine

A single set moves through these states. There is no status enum — state is
derived from which rows exist and whether their timestamps are zero.

```mermaid
stateDiagram-v2
    [*] --> Proposed: generate_sets_for_group
    Proposed --> InProgress: StartSet<br/>(inserts CompletedSet, ended_at = 0)
    InProgress --> Done: CompleteSet<br/>(sets ended_at, actual_reps, rest_until)
    Proposed --> Cancelled: CancelProposedSet<br/>(soft delete, cancelled = 1)
    Done --> Proposed: DeleteCompletedSet<br/>(removes CompletedSet row)
    Done --> [*]
    Cancelled --> [*]
```

| State | How you detect it |
|---|---|
| Proposed | `ProposedSet` exists, `cancelled = 0`, no matching `CompletedSet` |
| In progress | Matching `CompletedSet` with `ended_at = 0` |
| Done | Matching `CompletedSet` with `ended_at != 0` |
| Cancelled | `ProposedSet.cancelled = 1` |

`StartSet` creating the `CompletedSet` row up front is the non-obvious part: the
row exists before the user has lifted anything, holding only `started_at`.

## Starting a workout

```mermaid
sequenceDiagram
    participant App
    participant WS as ServerWorkoutService
    participant DB

    App->>WS: GetHome
    WS->>DB: templates + trackers + recent history
    WS-->>App: templates, resolved trackers,<br/>volume, recovery, suggestion

    App->>WS: StartWorkout(template_id)
    WS->>DB: template + trackers
    WS->>WS: one plan per exercise:<br/>tracker weight, prescription sets/reps/rest,<br/>layoff deload at resolution time
    WS->>WS: generate_sets_for_exercise per plan<br/>(warmup ladders for barbell compounds)
    WS->>DB: insert_workout (+ template_id) + proposed_sets
    WS->>DB: stamp session_id from user_current_session
    WS-->>App: StartWorkoutResponse (full state)
```

A start with an explicit `exercises` list (the "empty workout" path) runs
through the same prescription; mid-workout changes go through the four
per-exercise ops: `AddExercises`, `AdjustExerciseWeight`, `RemoveExercise`,
`ReorderExercises`.

## Optimistic mutations

The app does not wait for the server to update the UI. `WorkoutProvider` keeps a
local `ActiveWorkout`, applies the same transition the server will apply, and
reconciles when the response lands.

```mermaid
sequenceDiagram
    participant U as User
    participant P as WorkoutProvider (Dart)
    participant S as Server
    participant R as reducer (Rust)

    U->>P: complete set
    P->>P: apply locally, notifyListeners()
    Note over P: UI is already updated
    P->>S: CompleteSet / AppendWorkoutMutations
    S->>R: apply_complete_set_to_active(&mut active)
    R-->>S: new authoritative state
    S->>S: persist_workout_state (full snapshot)
    S-->>P: response with server state
    P->>P: replace local state with server state
    P->>P: onSessionRefreshNeeded()
```

The same logical transition therefore exists **twice**: in Rust
(`src/workout/reducer.rs`) and in Dart (`WorkoutProvider`). They must agree. If
they diverge, the UI flickers as the optimistic result is replaced by a
different server result.

### Batched mutations

`AppendWorkoutMutations` takes a list of mutations and applies them in order —
used when the app has been offline or has queued watch intents.

```mermaid
graph LR
    m["WorkoutMutation oneof"] --> t1["StartSet → apply_start_set_to_active"]
    m --> t2["CompleteSet → apply_complete_set_to_active"]
    m --> t3["DeleteCompletedSet → apply_delete_completed_set_to_active"]
    m --> t4["CancelProposedSet → apply_cancel_proposed_set_to_active"]
    m --> t5["EndWorkout → set end_time"]
    m --> t6["AddExercises → apply_add_exercises"]
    m --> t7["AdjustExerciseWeight → apply_adjust_exercise_weight"]
    m --> t8["RemoveExercise → apply_remove_exercise"]
    m --> t9["ReorderExercises → apply_reorder_exercises"]
```

Each mutation carries a client-generated `event_id` for dedupe and an optional
`client_created_at` so a queued action keeps its original timestamp rather than
the time it was flushed.

After applying mutations the server calls `persist_workout_state`, which writes
the whole workout back rather than diffing. Simple, and it means a partial
failure can't leave half-applied state — at the cost of rewriting every row on
every set.

## Ending a workout

```mermaid
sequenceDiagram
    participant App
    participant WS as ServerWorkoutService
    participant DB

    App->>WS: EndWorkout(workout_id, ended_at)
    WS->>DB: get_session_id_for_user
    Note over WS: captured first — end_workout clears<br/>active_workout_current, losing the link
    WS->>DB: end_workout (set end_time)
    WS->>DB: load workout, groups, proposed, completed
    WS->>DB: claim_progression(workout_id)
    Note over DB: INSERT OR IGNORE into progression_applied.<br/>0 rows → already applied → no tracker moves
    WS->>WS: session_outcomes per exercise
    WS->>WS: advance_tracker (double progression)
    WS->>DB: upsert trackers + progression messages

    alt in a session
        WS->>DB: refresh_participant_for_user (final snapshot)
        WS->>DB: clear_user_current_session
    end
    WS-->>App: workout + completion messages
```

Two ordering constraints worth knowing, both already commented in the source:

1. **Session id is read before `end_workout`**, because ending the workout
   deletes `active_workout_current` and the session link becomes unreachable.
2. **The participant blob is refreshed before leaving the session**, so peers
   still polling see your finished workout rather than a cleared slot.

Progression is idempotent via the `progression_applied` ledger — a retried
`EndWorkout` cannot move a tracker twice. Covered by
`end_workout_is_idempotent` in `src/server/workout_tests.rs` and a fuzz
invariant.

## Crash recovery

There is no event replay. On reconnect the app calls `GetActiveWorkout`, which
looks up `active_workout_current` and reloads the full workout with
`load_workout_full`. State survives because every mutation persists a complete
snapshot.

Every `ProposedSet` field is persisted, so recovery is lossless.

## Where the logic lives

| Concern | File |
|---|---|
| Warmup generation, plate snapping | `src/workout/planning.rs` |
| State transitions | `src/workout/reducer.rs` |
| Next-up-set derivation | `src/progress.rs` |
| Prescription + progression + volume | `src/exercise_catalog.rs`, `src/exercise_progress.rs`, `src/volume.rs` |
| Client-side mirror of all the above | `app/lib/providers/workout_provider.dart`, `app/lib/logic/` |

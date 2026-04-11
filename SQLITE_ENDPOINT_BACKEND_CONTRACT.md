# SQLite Endpoint Backend Contract

This is the target backend shape for `lift` if we optimize for:

- SQLite as the source of truth
- one SQLite transaction per mutating endpoint
- one indexed query or one short read transaction per read endpoint
- no in-memory dependency for correctness
- no persistent fanout work on the mutation hot path

This document is the contract the backend should be redesigned to satisfy.

## Principles

1. SQLite is the system.
2. The backend should not write the same logical fact into multiple hot-path tables unless that duplication is directly required for an indexed read.
3. Streams are transport, not persistence.
4. Multiplayer updates should be derived from SQLite reads, not from a second write-heavy denormalization path per mutation.
5. Expensive rebuilds are allowed only on cold paths, not on hot request paths.

## Hot RPC Rules

### Read RPCs

Each read RPC should do one of:

- one indexed point lookup
- one indexed range lookup
- one short read transaction with a bounded number of indexed queries

No read RPC should:

- scan historical event logs on the hot path
- rebuild a workout graph from scratch unless explicitly requested
- touch write-path synchronization

### Write RPCs

Each mutating RPC should do exactly one SQLite transaction.

Within that transaction it may:

- append one or more events
- update one current row for the entity being changed
- update at most one additional read-optimized row if needed for a critical read path

It should not:

- perform persistent fanout for other users
- rewrite full workout graphs unless the endpoint is explicitly a full replace
- do multiple unrelated logical operations in separate transactions

## Table Model

These are the tables the backend should converge toward.

### Identity / Auth

- `users`
- `auth_sessions`

### Workout Core

- `workouts`
  - one row per workout
- `workout_groups`
  - group metadata only
- `workout_sets_current`
  - current prescribed set rows for a workout
- `completed_sets`
  - actual completed sets
- `workout_events`
  - append-only mutation/event log
- `workout_heart_rate_samples`
  - append-only samples
- `active_workout_current`
  - one row per user if they have an active workout
- `workout_snapshot_current`
  - one row per user for the latest caller-visible workout payload

### Multiplayer

- `session_memberships`
  - append-only join/leave history
- `session_participants_current`
  - one row per active participant in a session, containing only what is needed for `GetCurrentSession`

### Program / Settings

- `training_program_state_latest`
- `training_program_state_events`
- `user_settings`
- `training_program_catalog`
  - static or code-backed; no hot-path issue either way
- `proposed_schedule_cache`
  - one row per user for fast schedule reads

## RPC Mapping

These are the intended endpoint shapes.

### Auth

#### `TestLogin`

One transaction:

- insert user if missing
- insert auth session
- insert initial training-program latest row if missing

Tables:

- `users`
- `auth_sessions`
- `training_program_state_latest`

### Startup Reads

#### `GetActiveWorkout`

One indexed lookup:

- `SELECT ... FROM active_workout_current WHERE user_id = ?`

#### `GetWorkout`

One short read transaction:

- read `workouts`
- read `workout_groups`
- read `workout_sets_current`
- read `completed_sets`

This is allowed to be a few indexed queries because it returns the full workout payload.

#### `GetProposedSchedule`

One indexed lookup:

- `SELECT ... FROM proposed_schedule_cache WHERE user_id = ?`

#### `GetCurrentSession`

One indexed range lookup:

- `SELECT ... FROM session_participants_current WHERE session_id = ?`

Do not rebuild from workouts/events on the hot path.

### Multiplayer Writes

#### `JoinUser`

One transaction:

- close current membership if needed
- append membership event
- upsert caller row in `session_participants_current`

Optionally also upsert the target row if the endpoint semantics require both rows to exist immediately.

Tables:

- `session_memberships`
- `session_participants_current`

#### `LeaveSession`

One transaction:

- append leave event
- delete caller from `session_participants_current`

Tables:

- `session_memberships`
- `session_participants_current`

#### `UpdateActiveWorkout`

One transaction:

- update `active_workout_current`
- update caller row in `session_participants_current`

Nothing else.

### Workout Writes

#### `StartWorkout`

One transaction:

- insert `workouts`
- insert `workout_groups`
- insert `workout_sets_current`
- upsert `active_workout_current`
- upsert `workout_snapshot_current`
- append checkpoint/start event to `workout_events`
- if in session, update caller row in `session_participants_current`

This is expected to be the heaviest normal transaction.

#### `AppendWorkoutMutations`

One transaction:

- append one or more rows to `workout_events`
- apply the mutation effects to:
  - `workout_sets_current`
  - `completed_sets`
  - `workout_snapshot_current`
- if in session, update caller row in `session_participants_current`

Important:

- no session fanout writes
- no full workout rewrite
- no rebuild from events

#### `AppendWorkoutHeartRate`

One transaction:

- batch insert sample rows into `workout_heart_rate_samples`

No other writes.

#### `EndWorkout`

One transaction:

- mark workout ended in `workouts`
- delete row from `active_workout_current`
- update `workout_snapshot_current`
- append end event to `workout_events`
- update caller row in `session_participants_current`
- if needed, append training-program state event and update latest row in the same transaction

This endpoint is allowed to be moderately heavy but still one transaction.

### Settings / Program State

#### `GetSettings`

One indexed range lookup by user.

#### `GetTrainingProgramCatalog`

Read-only, ideally memory/static or a single SQLite read.

#### `GetActiveTrainingProgramState`

One indexed lookup:

- `SELECT ... FROM training_program_state_latest WHERE user_id = ?`

## Streaming

Streaming should not add DB writes.

### `SubscribeSession`

At subscribe time:

- read `session_participants_current` for the requested session
- emit the full snapshot

For updates:

- either poll internally at a low interval
- or trigger a stream update after write endpoints commit

In both cases the streamed payload should come from a read of `session_participants_current`, not from another hot write path.

The stream is allowed to be slightly stale if that keeps the write path cheap.

## Acceptable App Compromises

Because we own the full system, the app can change to fit this model.

Allowed compromises:

- `GetCurrentSession` may be eventually consistent by a small amount
- session streams may send full snapshots rather than fine-grained deltas
- workout screens may tolerate snapshot-based refresh rather than perfect mutation-by-mutation replay
- completed workout views may omit some historical multiplayer detail if it keeps the hot path simple
- reconnect can always re-fetch from SQLite instead of relying on resumable in-memory stream state

## What To Remove

These patterns should be removed from the backend:

- persistent session fanout writes on every mutation
- separate session event logs if they are not needed for a concrete read path
- full workout flushes on normal mutation traffic
- server correctness depending on in-memory active state
- hot-path DB rebuilds of session state from multiple historical tables

## Benchmark Contract

The backend should be judged against the endpoint benchmark shape in:

- [examples/sqlite_endpoint_tx_bench.rs](/home/brensch/lift/examples/sqlite_endpoint_tx_bench.rs:1)

If a backend path is much slower than the matching endpoint benchmark shape, that is a backend design bug, not a SQLite limitation.

## Immediate Refactor Order

1. Make `AppendWorkoutMutations` one transaction only.
2. Stop persistent multiplayer fanout on mutation hot paths.
3. Reduce `GetCurrentSession` to a direct read from `session_participants_current`.
4. Collapse `StartWorkout`, `JoinUser`, `UpdateActiveWorkout`, and `EndWorkout` to the transaction shapes above.
5. Re-run the endpoint benchmark and the end-to-end load test after each stage.

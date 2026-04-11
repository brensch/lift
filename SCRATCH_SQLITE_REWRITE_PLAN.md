# Scratch SQLite Rewrite Plan

This is the reset plan for replacing the current backend with a SQLite-first,
proto-shaped CRUD design.

No migration or backward compatibility is required.
The current implementation is reference material only and should not shape the
new architecture.

## Goals

- SQLite is the source of truth.
- Each hot mutating RPC is one SQLite transaction.
- Each hot read RPC is one indexed lookup or one short bounded read transaction.
- Proto payloads are the primary row/blob representation for current-state reads.
- Multiplayer is split:
  - `me` comes from the local workout state / workout RPCs
  - `them` comes from multiplayer session polling
- No rebuild-heavy hot paths.
- No correctness dependence on in-memory state.

## Workout-Related Paths In Scope

These are the paths touching workouts directly or indirectly.

### Workout RPCs

- `StartWorkout`
- `EndWorkout`
- `GetWorkout`
- `GetActiveWorkout`
- `ListWorkouts`
- `ReplaceExerciseGroupPlan`
- `ReorderExerciseGroups`
- `StartSet`
- `CompleteSet`
- `DeleteCompletedSet`
- `CancelProposedSet`
- `AppendWorkoutMutations`
- `RehydrateWorkoutFromEvents`
- `AppendWorkoutHeartRate`
- `GetWorkoutHeartRate`
- `GetProposedWorkoutSchedule`
- `SaveWorkoutDraft`
- `ClearWorkoutDraft`

### Multiplayer RPCs touching workouts

- `JoinUser`
- `LeaveSession`
- `GetParticipantWorkout`
- `GetCurrentSession`
- `UpdateActiveWorkout`

### Settings / program-state paths coupled to workouts

- `GetActiveTrainingProgramState`
- `SetActiveTrainingProgramState`
- `ApplyPendingStateUpdate`
- workout completion -> program-state transition

### Auth / startup paths that affect load shape

- `TestLogin`
- startup:
  - `GetActiveWorkout`
  - `GetWorkout`
  - `GetProposedWorkoutSchedule`
  - `GetCurrentSession`
  - `GetSettings`
  - `GetTrainingProgramCatalog`
  - `GetActiveTrainingProgramState`

## New Table Model

The new backend should converge to this minimal model.

### Identity

- `users`
  - columns: `user_id`, `user_blob`
- `auth_sessions`
  - columns: `token`, `user_id`, `expires_at`

### Workouts

- `workouts`
  - columns: `user_id`, `workout_id`, `workout_blob`, `is_active`, `start_time`, `end_time`
- `workout_groups_current`
  - columns: `workout_id`, `group_id`, `workout_order`, `group_blob`
- `workout_sets_current`
  - columns: `workout_id`, `set_id`, `workout_order`, `set_blob`
- `completed_sets_current`
  - columns: `workout_id`, `completed_set_id`, `started_at`, `completed_blob`
- `active_workout_current`
  - columns: `user_id`, `workout_id`, `response_blob`
- `workout_events`
  - columns: `event_id`, `user_id`, `workout_id`, `recorded_at`, `event_type`, `payload`
- `workout_heart_rate_samples`
  - append-only

### Multiplayer

- `session_memberships`
  - append-only join/leave rows
- `session_participants_current`
  - columns: `session_id`, `user_id`, `participant_blob`, `updated_at`

### Schedule / settings / program state

- `proposed_schedule_cache`
  - columns: `user_id`, `response_blob`, `updated_at`
- `user_settings_current`
  - columns: `user_id`, `setting_type`, `setting_blob`, `updated_at`
- `training_program_state_latest`
  - columns: `user_id`, `state_blob`, `updated_at`
- `training_program_state_events`
  - append-only
- `workout_drafts_current`
  - columns: `user_id`, `draft_blob`, `updated_at`

## Proto-Shaped Rows

The current-state tables should store serialized protobufs directly for the read
shape the client wants.

Examples:

- `active_workout_current.response_blob` stores `GetWorkoutResponse`
- `session_participants_current.participant_blob` stores `ParticipantStatus`
- `proposed_schedule_cache.response_blob` stores `GetProposedWorkoutScheduleResponse`
- `training_program_state_latest.state_blob` stores `GetActiveTrainingProgramStateResponse`
- `user_settings_current.setting_blob` stores `UserSetting`
- `workout_drafts_current.draft_blob` stores `WorkoutDraft`

This avoids expensive assembly work in hot reads.

## Target RPC Shapes

### `TestLogin`

One transaction:

- insert user if missing
- insert auth session
- ensure initial training-program state exists

### `GetActiveWorkout`

One lookup from `active_workout_current`.

### `GetWorkout`

Prefer one lookup from `active_workout_current` for active workouts.
Historical workouts may still do a short bounded read transaction.

### `GetProposedWorkoutSchedule`

One lookup from `proposed_schedule_cache`, then merge draft if present.

### `GetCurrentSession`

One indexed lookup:

- `SELECT participant_blob FROM session_participants_current WHERE session_id = ?`

The response returns peers only. The app renders `me` from local workout state.

### `JoinUser`

One transaction:

- insert/update `session_memberships`
- update caller and target `session_participants_current`
- update active workout `session_id` rows if needed

### `LeaveSession`

One transaction:

- append leave row in `session_memberships`
- remove caller from active session membership
- optionally keep finished participant visibility row if product still wants it

### `UpdateActiveWorkout`

One transaction:

- rewrite caller `session_participants_current.participant_blob`

### `StartWorkout`

One transaction:

- create workout row
- create group rows
- create proposed/current set rows
- create `active_workout_current` blob
- append checkpoint event
- update `session_participants_current` if in session

### `AppendWorkoutMutations`

One transaction:

- append event rows
- mutate only touched current rows:
  - `completed_sets_current`
  - `workout_sets_current` when cancellation/replace/reorder affects them
  - `active_workout_current.response_blob`
  - `session_participants_current.participant_blob` if in session

No full workout rewrite.

### `AppendWorkoutHeartRate`

One transaction:

- append sample rows only

### `EndWorkout`

One transaction:

- mark workout ended
- remove `active_workout_current`
- update stored workout response/current blobs
- append end event
- update/remove session participant current row as needed
- append program-state event and latest row update

## Deletions

These concepts should disappear from the hot path:

- rebuilding sessions from normalized workout tables
- full `flush_workout` on normal mutation traffic
- split writer queues plus direct write lock paths for the same entity flow
- stream-driven multiplayer hot path
- in-memory state as correctness source

## Rewrite Order

1. Replace `db.rs` schema and CRUD around current-state/blob tables.
2. Replace `GetCurrentSession`, `JoinUser`, `LeaveSession`, `UpdateActiveWorkout`.
3. Replace `StartWorkout`, `GetActiveWorkout`, `GetWorkout`.
4. Replace `AppendWorkoutMutations`, `StartSet`, `CompleteSet`, `DeleteCompletedSet`, `CancelProposedSet`.
5. Replace `EndWorkout`.
6. Replace schedule/settings/program-state current tables.
7. Remove obsolete modules and dead tests.


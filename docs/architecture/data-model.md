# Data Model

One SQLite file, `data/server.sqlite`, in WAL mode. Schema is defined in
`SERVER_SCHEMA` (`src/db/mod.rs:24`) and created at startup.

## Naming conventions

The suffix tells you the table's shape:

| Suffix | Meaning | Example |
|---|---|---|
| `_current` | One row per key, holding the latest value. Overwritten in place. | `users_current`, `session_participants_current` |
| `_events` | Historically an append-only log. | `user_message_events` |

Note `user_message_events` is a misnomer — it has `PRIMARY KEY(user_id, message_key)`
and is upserted, so it is a `_current` table despite the name.

## Core workout entities

```mermaid
erDiagram
    users_current ||--o{ workouts : "has"
    workouts ||--o{ exercise_groups : "contains"
    exercise_groups ||--o{ proposed_sets : "generates"
    proposed_sets ||--o| completed_sets : "logged as"
    workouts ||--o{ workout_heart_rate_samples : "records"
    users_current ||--o| active_workout_current : "points at"

    users_current {
        TEXT user_id PK
        BLOB user_blob "proto User"
        TEXT username_ci UK
        TEXT invite_token UK
    }
    workouts {
        TEXT id PK
        TEXT user_id FK
        TEXT name
        INTEGER start_time
        INTEGER end_time "0 = in progress"
        TEXT session_id "'' = solo"
        TEXT template_id "'' = started empty"
    }
    exercise_groups {
        TEXT id PK
        TEXT workout_id FK
        TEXT name
        INTEGER workout_order
        INTEGER interleave_warmups
        TEXT instruction
        BLOB exercise_configs_blob
    }
    proposed_sets {
        TEXT id PK
        TEXT workout_id FK
        TEXT exercise_group_id FK
        INTEGER workout_order
        INTEGER exercise "enum"
        INTEGER target_reps
        REAL target_weight
        INTEGER warmup
        INTEGER cancelled
        INTEGER is_amrap
    }
    completed_sets {
        TEXT id PK
        TEXT workout_id FK
        TEXT proposed_set_id FK
        INTEGER actual_reps
        REAL actual_weight
        INTEGER started_at
        INTEGER ended_at "0 = in progress"
        INTEGER rest_until
    }
    active_workout_current {
        TEXT user_id PK
        TEXT workout_id
    }
```

Key points:

- **`end_time = 0` means in progress.** Same for `completed_sets.ended_at`.
  There is no separate status column anywhere; zero-as-null is the convention.
- **`completed_sets` is created on `StartSet`**, not on completion, with
  `ended_at = 0`. A row with `ended_at = 0` is the set currently being performed.
- **`proposed_sets.cancelled`** is a soft delete — skipped warmups and removed
  sets stay in the table so ordering and history remain stable.
- **`active_workout_current`** is the fast path for "does this user have a
  workout open?" It duplicates what a query on `workouts.end_time = 0` would
  give you.

## Sessions (multiplayer)

```mermaid
erDiagram
    sessions ||--o{ session_participants_current : "has"
    sessions ||--o{ user_current_session : "membership"
    users_current ||--o| user_current_session : "in at most one"

    sessions {
        TEXT session_id PK
        TEXT created_by
        INTEGER created_at
    }
    user_current_session {
        TEXT user_id PK "source of truth"
        TEXT session_id
        INTEGER joined_at
    }
    session_participants_current {
        TEXT session_id PK
        TEXT user_id PK
        BLOB participant_blob "proto ParticipantStatus"
        INTEGER updated_at
    }
```

`user_current_session` has `user_id` as **primary key**, which enforces the
core invariant: a user is in at most one session at a time. Everything else —
`workouts.session_id`, `session_participants_current` — is derived cache.
See [multiplayer.md](multiplayer.md).

## Auth

```mermaid
erDiagram
    users_current ||--o{ passkey_credentials : "registers"
    users_current ||--o{ auth_sessions : "holds"

    passkey_credentials {
        TEXT credential_id PK
        TEXT user_id FK
        TEXT credential_json "webauthn-rs Passkey"
        INTEGER created_at
        TEXT created_at_ip
    }
    auth_sessions {
        TEXT token PK
        TEXT user_id FK
        INTEGER expires_at
    }
```

See [auth.md](auth.md).

## Templates, trackers and progression

```mermaid
erDiagram
    users_current ||--o{ workout_templates : "keeps"
    users_current ||--o{ exercise_trackers : "one per exercise"
    workouts ||--o| progression_applied : "claims"

    workout_templates {
        TEXT id PK
        TEXT user_id
        TEXT name
        INTEGER template_order
        BLOB template_blob "proto WorkoutTemplate"
    }
    exercise_trackers {
        TEXT user_id PK
        INTEGER exercise PK
        REAL working_weight "lb"
        INTEGER current_reps "position in the rep range"
        INTEGER consecutive_misses
        INTEGER last_performed_at
        INTEGER override_sets "0 = derived"
        INTEGER override_rep_low
        INTEGER override_rep_high
        TEXT source "workout:<id> | manual | migration | onboarding"
    }
    progression_applied {
        TEXT workout_id PK "idempotency ledger"
        TEXT user_id
        INTEGER applied_at
    }
```

- A template holds exercises only; sets/reps/rest/weight resolve from the
  prescription (`src/exercise_catalog.rs`) and the tracker at start time.
- A tracker row is optional: no row means catalog opener weight and the
  derived prescription.
- `progression_applied` is the idempotency ledger. `EndWorkout` claims the
  `workout_id` with `INSERT OR IGNORE` before advancing any tracker, so a
  retried or duplicated `EndWorkout` cannot move a tracker twice.
- `schema_migrations` holds one row per one-time migration
  (`composable_workouts_v1` converted the old program-state world; see
  `src/db/migration.rs`).

## Everything else

| Table | Purpose |
|---|---|
| `user_settings_current` | Per-user settings, keyed by `(user_id, setting_type)` — the weight unit lives here |
| `user_message_events` | Coaching/progression messages, upserted by `message_key`, soft-dismissed via `dismissed_at` |
| `workout_heart_rate_samples` | Heart rate from the watch, one row per sample |

## Referential integrity

There are **no `FOREIGN KEY` constraints** and foreign keys are not enforced.
The `FK` markers in the diagrams above are logical, not declared. Cascading
deletes are done by hand in `delete_user_account_and_data`
(`src/db/auth.rs:270`) — if you add a table keyed by `user_id`, you must add it
to that function or account deletion will orphan rows.

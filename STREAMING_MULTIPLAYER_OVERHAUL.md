# Streaming Multiplayer Overhaul

## Goals

- Replace poll-based multiplayer reads with a server stream.
- Make multiplayer reads cheap: indexed lookups over current-state rows only.
- Keep writes simple: append events plus small current-row updates.
- Make the app resilient to disconnects, backgrounding, and cold-start recovery.
- Avoid migration complexity. Fresh schema is acceptable.

## Principles

- Use SQLite for what it is good at:
  - indexed point lookups
  - append-only event inserts
  - small row updates in short transactions
- Do not rebuild session state from normalized workout tables on every read.
- Do not require in-memory-only multiplayer truth for correctness.
- Streams are for live delivery, not for the only source of truth.
- Every reconnect must be able to recover from SQLite alone.

## New Multiplayer Model

### Source of truth

- `session_directory_current`
  - current session membership by user
  - one row per user currently attached to a session
- `session_participants_current`
  - current multiplayer-visible state for each participant in a session
  - one row per `(session_id, user_id)`
  - stores a serialized `ParticipantStatus`
- `session_events`
  - append-only session event log with monotonically increasing `version`
  - useful for debugging and future replay, but the app does not depend on replay

### Existing workout persistence

- Keep workout/event persistence for the user’s own workout APIs.
- Multiplayer no longer assembles session state from workouts, groups, proposed sets, and completed sets at read time.
- Instead, workout mutations refresh the caller’s `session_participants_current` row.

### Read path

- App cold start:
  - call unary `GetCurrentSession`
  - if no current session, do nothing
  - if current session exists, start stream subscription
- Active multiplayer session:
  - app subscribes using `SubscribeSession`
  - server sends an immediate full snapshot event
  - subsequent updates are pushed only when the session changes

### Write path

- Any multiplayer-relevant change:
  - update user workout state
  - rebuild caller `ParticipantStatus`
  - update one `session_participants_current` row
  - append one `session_events` row
  - broadcast one full session snapshot to stream subscribers

## RPC contract

### Unary

- `GetCurrentSession`
  - remains for discovery and cold-start recovery
  - returns current session snapshot from current-state tables only

### Server stream

- `SubscribeSession`
  - request:
    - `session_id`
  - stream message:
    - `session_id`
    - `version`
    - `session_status`
    - `kind`

The server always emits a full snapshot on subscription. This avoids replay complexity on reconnect.

## Reconnect strategy

- Client only opens the stream when it is in a multiplayer session.
- On stream error / EOF:
  - apply exponential backoff
  - reconnect with the same `session_id`
- On reconnect:
  - server emits a fresh snapshot immediately
  - client replaces local session state with the snapshot
- If unary `GetCurrentSession` shows that the session is gone:
  - close stream
  - clear multiplayer UI state

This makes reconnect safe even if:

- the app process restarts
- the server restarts
- the device changes network
- the socket drops while in background

## Security

- Authenticate every unary and streaming RPC via `x-session-token`.
- For `SubscribeSession`, require that the caller is attached to the target session.
- Do not allow arbitrary session snooping by session id alone.

## Backend changes

1. Add new current-state/session event tables.
2. Add a per-session broadcast registry in the backend process.
3. Replace `GetCurrentSession` implementation with current-table reads only.
4. Add `SubscribeSession`.
5. Update workout and session mutations to refresh current participant rows and publish snapshots.

## App changes

1. Replace polling timer with a stream subscription manager.
2. Keep unary `checkForSession()` for app startup / recovery.
3. Subscribe only when `sessionId != null`.
4. Reconnect automatically with bounded exponential backoff.
5. Clear stream state on logout / leave session / missing session.

## Deliberate simplifications

- Stream sends full session snapshots, not deltas.
  - cheaper to implement correctly
  - easier for Flutter client recovery
  - session sizes are small, so full snapshots are acceptable
- Current participant state is serialized proto in SQLite.
  - avoids reassembling nested state from many tables for multiplayer reads

## Expected outcome

- Multiplayer idle load drops sharply because 1 Hz polling disappears.
- Multiplayer read path becomes one indexed query plus decode.
- Multiplayer writes become short transactions with bounded work.
- App reconnect behavior becomes explicit and testable rather than incidental.

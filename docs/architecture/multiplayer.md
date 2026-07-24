# Multiplayer Sessions

Two or more lifters share a *session* so each can see what the others are doing
and whose turn it is. Sessions are lightweight: they add a `session_id` to
workouts and a fan-out of participant snapshots.

## The invariant

`user_current_session(user_id PRIMARY KEY, session_id, joined_at)` is the single
source of truth for "is this user in a group right now?". Because `user_id` is
the primary key, a user is structurally incapable of being in two sessions.

Everything else is derived cache:

```mermaid
graph TD
    ucs["user_current_session<br/><b>source of truth</b>"]
    ucs -.->|"stamped at StartWorkout"| ws["workouts.session_id"]
    ucs -.->|"refreshed on set actions"| spc["session_participants_current<br/>participant_blob"]
    s["sessions<br/>session_id, created_by, created_at"] --- ucs

    style ucs fill:#2d5a2d,color:#fff
```

If those disagree, `user_current_session` wins.

## Transitions

```mermaid
stateDiagram-v2
    [*] --> Solo
    Solo --> InSession: JoinViaInvite<br/>(upsert both users' rows)
    InSession --> InSession: StartSet / CompleteSet<br/>(refresh caller's blob)
    InSession --> Solo: LeaveCurrentSession<br/>(delete caller's row)
    InSession --> Solo: EndWorkout<br/>(refresh final blob, then delete row)
    note right of Solo
        Last participant_blob is retained
        so peers keep seeing your result.
    end note
```

Handled across two files:

| Transition | Where |
|---|---|
| `JoinViaInvite`, `LeaveCurrentSession` | `src/server/multiplayer.rs` |
| `StartWorkout` session stamping, set actions, `EndWorkout` | `src/server/workout.rs` |

## Joining

```mermaid
sequenceDiagram
    participant A as Alice (inviter)
    participant B as Bob (joiner)
    participant S as Server
    participant DB

    A->>S: GetMyInviteToken
    S->>DB: users_current.invite_token
    S-->>A: token
    Note over A,B: shared out of band (QR / link)

    B->>S: JoinViaInvite(token)
    S->>DB: lookup_user_by_invite_token
    S->>S: place_user_in_session
    S->>DB: upsert user_current_session for BOTH users
    S->>DB: backfill workouts.session_id for both active workouts
    S->>DB: refresh both participant blobs
    S-->>B: session_id
```

The invite token lives on the user, not the session — it is a stable personal
handle, rotatable via `RotateInviteToken`. Joining someone pulls *both* of you
into a session, creating one if the inviter wasn't already in one.

Backfilling `workouts.session_id` matters: if you were already mid-workout when
you joined, your in-progress workout is retroactively attached to the session.

## Reading session state

The app polls `GetCurrentSession` at **1 Hz** (`MultiplayerProvider`).

```mermaid
sequenceDiagram
    loop every 1s
        App->>Server: GetCurrentSession
        Server->>DB: get_user_current_session(caller)
        alt no session
            Server-->>App: empty session_id
        else in session
            Server->>DB: get_session_participants(session_id)
            Server->>Server: drop caller from list
            Server-->>App: SessionStatus{participants}
        end
    end
```

Note the server **excludes the caller** from the participants list — the app
renders itself from its own local state and peers from this list.

### The empty next-up fields

`SessionStatus` has `next_up_user_id`, `next_up_set`, `next_up_rest_until` and
`currently_lifting_user_id`. The server sets all of them to empty/zero
(`src/server/multiplayer.rs:200`). "Who's up next" is computed client-side from
the participant blobs. Treat these proto fields as dead.

### Polling resilience

`MultiplayerProvider._poll()` requires **3 consecutive empty responses** before
clearing `_sessionId`, so one dropped request doesn't make the session bar
vanish. Polling calls use a short 5s timeout
(`MultiplayerServiceWrapper._pollCallOptions`) so a stalled request can't block
the next tick.

After any set operation `WorkoutProvider` fires `onSessionRefreshNeeded`, wired in
`app/lib/main.dart:136` to `multiplayerProvider.checkForSession()`, so the
session view updates immediately rather than waiting up to a second for the next
poll tick.

## Why polling

`SubscribeSession` exists in the proto as a server-streaming RPC and returns
`Status::unimplemented`. At the current scale 1 Hz polling over a shared HTTP/2
connection is cheaper to operate than maintaining stream lifecycles across
mobile network transitions and app suspension. Revisit if participant counts or
user counts grow substantially.

## Failure modes to know

- **Stale participant blobs.** A blob is only refreshed when its owner acts. A
  peer who backgrounds the app mid-set leaves a snapshot that ages silently;
  there is no heartbeat or staleness marker.
- **Sessions are never garbage collected.** Rows in `sessions` and
  `session_participants_current` persist after everyone leaves. Harmless at
  current scale, unbounded growth over time.
- **Leaving is not broadcast.** Peers discover it on their next poll, by absence.

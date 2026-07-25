# Issues surfaced by the e2e scenarios

Findings from building and running the emulator scenario suite. Each is either
confirmed in code or reproduced on the emulator. These are observations to
triage — not all are necessarily bugs, but each is a real behaviour the tests
exposed.

## 1. A departed peer stays visible to other session members

**Confirmed (code + `multiplayer_leave` scenario).**

`leave_current_session` (`src/server/multiplayer.rs`) only clears the *leaver's*
`user_current_session`:

```rust
self.db.clear_user_current_session(&caller_id).await?;  // DELETE FROM user_current_session
```

But `get_current_session` builds its participant list from
`session_participants_current` (`src/db/session.rs`), and nothing prunes that row
on leave — `get_session_participants` returns every row for the session and
`get_current_session` only filters out the caller. So after a peer leaves, other
members keep seeing them until something else rewrites that row.

The `multiplayer_leave` scenario had to be written from the app user's own leave
(which *is* reflected) because a peer's leave is invisible to the app.

**Fix direction:** clear the leaver from `session_participants_current` in
`leave_current_session` (and on session teardown), or have
`get_session_participants` filter to rows whose `user_current_session` still
points at the session.

## 2. The phone never reconciles its active workout with the backend

**Confirmed (code + `progression` scenario screenshot).**

`WorkoutProvider._startTimer` (`app/lib/providers/workout_provider.dart`) runs a
1 Hz timer that only does:

```dart
_setNow(DateTime.now());
unawaited(_checkRestSound());
unawaited(_flushPendingWearHeartRateUploads());
```

It never re-fetches `getActiveWorkout`. That call only happens on load/restart.
So once the phone holds a local active workout, a workout ended by anything other
than the phone's own UI (server-side, another logged-in client, the watch over
gRPC) is never noticed — the phone shows the stale in-progress workout until the
app is restarted. Reproduced: 3 s after an external `EndWorkout`, the phone still
rendered the in-progress workout at the old weight.

Normal single-device use is fine (the UI-driven finish path shows the correct
summary + progression). This matters for multi-device / mirrored-session stories.

**Fix direction:** on the periodic tick (or a slower one), reconcile the active
workout id against `getActiveWorkout` and clear/refresh if the server disagrees.

## 3. Health Connect workout writes fail — missing calorie permissions

**Confirmed (logcat + manifest).**

On `EndWorkout` the app writes the workout to Health Connect with calories:

```dart
// app/lib/services/health_service.dart
want(HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataAccess.READ_WRITE);
...
final success = await health.writeWorkoutData(..., totalEnergyBurned: calories, ...);
```

But `AndroidManifest.xml` declares none of the calorie permissions
(`WRITE_TOTAL_CALORIES_BURNED`, `READ/WRITE_ACTIVE_CALORIES_BURNED`). On the
emulator this throws and the write is dropped:

```
SecurityException: Caller doesn't have android.permission.health.WRITE_TOTAL_CALORIES_BURNED
  to write to record type ... TotalCaloriesBurnedRecord
Health: writeWorkoutData result=false
```

So workouts are silently not saved to Health Connect on Android, and the
`requestWorkoutHealthPermissions` request for `ACTIVE_ENERGY_BURNED` can't be
granted either (it isn't declared). See also [[project_healthkit_auth]].

**Fix direction:** declare the calorie permissions the app actually uses in the
Android manifest (and the corresponding Health Connect permission rationale), or
stop writing calories if that's out of scope.

## 4. (Fixed here) scheduleRest threw from a fire-and-forget path

`NotificationService.scheduleRest` is called `unawaited(...)` on set completion
and used exact alarms unconditionally. On a device without the exact-alarm
permission (common on Android 14) `zonedSchedule` throws
`PlatformException(exact_alarms_not_permitted)` into the void. Now it degrades
exact → inexact and swallows the final failure with a logged warning.

## What passed (no issue)

- `progression` — a full workout advances Linear 5×5 by the right amount (45→50).
- `workout_backend_sync` — a UI-completed set persists to the backend.
- `crash_recovery` — a cold restart resumes the in-progress workout with its set.
- `onboarding_gzclp` — selecting GZCLP persists a GZCLP program.
- The UI-driven finish shows the correct summary with per-lift progression.

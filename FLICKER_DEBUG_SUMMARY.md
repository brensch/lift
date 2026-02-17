# Flicker Debug Summary

## Symptom
- On watch, a black "screenshot-like" zoom/flicker appears during transitions.
- Not limited to button taps.
- Reproduces when phone state changes and watch updates right after transition.

## What We Tried

1. Removed app-side periodic workout sync flicker source on phone UI.
- Change: removed per-build post-frame sync call in `app/lib/screens/workout_tab.dart`.
- Result: did not fix watch transition flicker.

2. Made `StartWorkout` idempotent and state-returning.
- Change:
  - `proto/workout/v1/workout.proto` (`StartWorkoutResponse` returns full state)
  - `src/service_workout.rs` returns existing active workout instead of error.
  - Flutter provider/service consume mutation response directly.
- Result: good API behavior, but watch flicker still present.

3. Tested global Flutter interaction visual effects on phone.
- Change attempts in `app/lib/theme/app_theme.dart`:
  - switched splash/ripple behavior
  - disabled splash/highlight/hover
  - tested no page transitions
- Result: not the root cause for watch flicker.

4. Removed dialog-based global error overlay path.
- Change: `app/lib/services/error_modal_service.dart` from `showDialog` to snackbar.
- Result: reduced possible overlay path, but did not resolve watch flicker.

5. Focused on watch lifecycle teardown/restart.
- Initial finding: watch `MainActivity` effect used state as a key and could restart streaming/session on transitions.
- Change: moved cleanup/start logic so state transitions should not force teardown.
- Further test: removed teardown calls completely in watch UI path.
- Result: flicker still present.

6. Focused on "finished workout" transition path.
- Finding: `watch icon` commit (`1a98983`) introduced:
  - `WorkoutCompleteScreen` branch swap when state becomes `ALL_DONE`
  - additional completion summary/state handling in snapshot builder.
- Change attempts:
  - disabled complete-screen branch swap in watch UI
  - normalized non-ended `ALL_DONE` snapshots to avoid hard screen swap.
- Result: flicker still present.

7. Nuclear rollback test.
- Action:
  - fully checked out repo at `d23e777` ("watch app usable") for whole-tree A/B test.
  - then switched back to latest branch head (`ios-release/placeholder-ci`, `1d519e8`).
- User-reported result: flicker still present even after rollback test.

## Current Status
- No code-only change tested so far has eliminated the watch transition flicker.
- Since behavior persisted even after whole-tree rollback, likely causes now include:
  - watch OS / device rendering behavior
  - environment/build/runtime differences outside git-tracked app logic
  - transport/update cadence interactions that are not isolated by prior changes.

## Useful Git Commands Used
- Roll back entire tree to test point:
  - `git checkout d23e777`
- Return to latest branch:
  - `git checkout ios-release/placeholder-ci`
  - `git pull --ff-only`


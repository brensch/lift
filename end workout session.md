# End Workout Session

## Goal
Make the watch handle workout completion properly:
- Phone should send a completion-state snapshot to the watch.
- Watch should render a dedicated completion screen with summary metrics.
- User should still be able to end workout from watch when in all-done state but not yet server-ended.

## Proto / Contract Changes
Updated wearable contract:
- `proto/workout/v1/wearable.proto`
  - Added `WearCompletionSummary`:
    - `duration_text`
    - `completed_working_sets`
    - `total_volume_lb`
  - Added `completion_summary` field to `WearWorkoutSnapshot`.

Regenerated code with buf:
- Ran: `make proto-all`
- Updated generated artifacts:
  - `app/lib/gen/workout/v1/wearable.pb.dart`
  - `app/android/shared-proto/src/main/java/workout/v1/Wearable.java`

## Phone-Side Flow Changes
### Snapshot Builder
File: `app/lib/services/wearable_snapshot_builder.dart`

Changes:
- Snapshot builder now supports both:
  - active workouts
  - ended workouts (`workout.endTime != 0`)
- When workout is ended:
  - snapshot state is forced to `WORKOUT_STATE_ALL_DONE`
  - `completion_summary` is populated
- Completion summary computation:
  - `duration_text`: from workout start/end (or now if still active)
  - `completed_working_sets`: completed non-warmup sets only
  - `total_volume_lb`: sum of `actualReps * actualWeight` for completed non-warmup sets, rounded to int
- Action behavior:
  - if all sets done but workout not ended: includes `End Workout` action
  - if already ended: no end action needed, still sends completion snapshot

### Wear Sync Coordinator
File: `app/lib/services/wearable_sync_coordinator.dart`

Changes:
- `_publishSnapshot()` now publishes when either is true:
  - `hasActiveWorkout`
  - `isWorkoutEnded`

This ensures the watch still receives final completion state after the phone ends the workout.

## Watch UI Changes
File: `app/android/wear/src/main/kotlin/com/lift/lift/wear/MainActivity.kt`

Added dedicated completion UI:
- If snapshot state is `WORKOUT_STATE_ALL_DONE` and `completionSummary` exists:
  - render completion screen instead of active workout UI
- Completion screen content:
  - Title/status
  - Duration
  - Sets
  - Volume
  - Primary action button (uses provided action label when present, fallback `Done`)

Layout iterations applied:
- Converted completion view to left/right split to fit round display.
- Final layout:
  - Left side: metrics area (`2/3` width)
  - Right side: full-height button (`1/3` width)
  - No outer padding around the right button region

## Build / Validation
Executed during implementation:
- `make proto-all` (buf generation)
- `cd app && flutter analyze lib/services/wearable_snapshot_builder.dart lib/services/wearable_sync_coordinator.dart` (no issues)
- `cd app/android && ./gradlew :wear:assembleDebug` (passes)
- `make run-wear` (installs and launches on watch)

## Current End-Workout Behavior
1. Workout reaches all-done state:
   - watch can send `EndWorkout` intent from watch action.
2. Phone ends workout on server.
3. Phone still publishes a completion snapshot (ended workout supported).
4. Watch shows completion summary screen with duration/sets/volume.
5. Completion screen button is shown in the right 1/3 full-height column.

## Notes
- Summary values on watch are intentionally aligned with mobile completion logic:
  - working sets exclude warmups
  - volume uses completed set actuals
- Contract is now extensible for future watch summary fields without changing action intents.

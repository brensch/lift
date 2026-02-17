# Wear OS Companion Investigation and Implementation Plan

Date: 2026-02-17

## Goals

- Keep the phone app as the source of truth for workout state and all API calls.
- Add a watch companion UI that mirrors the workout bottom bar:
  - `YOU` status card
  - `GROUP` status card
  - timer(s)
  - action buttons (`Start Set`, `Start Early`, rep completion, `Skip Warmup`, `End Workout`)
- Stream heart-rate data from watch to phone during workouts and store it with workout data.
- Keep architecture extensible for a later Apple Watch companion.

## Current App Surfaces to Mirror

Phone workout bottom bar logic is already centralized in:

- `app/lib/widgets/workout_bottom_bar.dart`
- `app/lib/providers/workout_provider.dart`
- `app/lib/providers/multiplayer_provider.dart`

Watch UI should be derived from the same state machine semantics:

- Workout states: `ALL_DONE`, `LIFTING`, `RESTING`, `READY`
- Derived timers:
  - active set elapsed
  - rest remaining / overrun ("yapping")
  - workout elapsed
- Actions:
  - `startSet(setId)`
  - `completeSet(setId, reps, weight)`
  - `skipWarmup(setId)`
  - `endWorkout()`

## Platform Reality (important)

- Flutter officially lists supported deploy platforms as Android/iOS/desktop/web, and does not list watchOS as a Flutter deploy platform.
- Wear OS watch apps are built as Android Wear modules (typically Kotlin + Compose for Wear).
- For watch-phone communication, Google recommends Wear Data Layer APIs (`MessageClient`, `DataClient`, `CapabilityClient`, `ChannelClient`), and specifically calls out fitness data flow watch -> phone -> Health Connect.
- Health Services on Wear OS is the recommended sensor path for heart rate and exercise tracking, with runtime permissions required on the watch app itself.

Implication:

- Android side should use a native Wear module now.
- We should avoid embedding business logic in platform UI code and keep shared domain models/protocols so iOS/watchOS can plug in later.

## Recommended Architecture

### 1) Phone remains orchestrator

Phone app stays authoritative for:

- backend calls
- workout state machine
- multiplayer/session logic
- Health Connect write (already in `WorkoutProvider.endWorkout()` flow)

### 2) Add an Android Wear module (native)

Add `:wear` module (Kotlin + Compose for Wear) to `app/android` project.

Watch responsibilities:

- Render compact bottom-bar-equivalent UI.
- Emit user intents (button taps, rep completion).
- Collect heart-rate stream via Health Services (`MeasureClient` and/or `ExerciseClient`) when workout is active.
- Send intents + sensor payloads to phone via Data Layer.

### 3) Define a cross-platform wearable protocol now

Create transport-agnostic message contract (protobuf or JSON schema) with two channels:

- `Phone -> Wear` state snapshots
- `Wear -> Phone` intents + sensor events

Suggested message families:

- `WearWorkoutSnapshot`
  - workout id
  - state enum
  - display set (exercise, reps, target weight, warmup)
  - timers (`rest_until`, `active_started_at`, `workout_start`)
  - group summary (`next_up_name`, `group_state`, `group_timer`)
  - allowed actions
- `WearIntent`
  - `START_SET(set_id)`
  - `COMPLETE_SET(set_id, reps, actual_weight)`
  - `SKIP_WARMUP(set_id)`
  - `END_WORKOUT`
- `WearSensorSample`
  - timestamp
  - heart rate bpm
  - availability/status
  - optional quality/source fields

Why this matters:

- Android Wear transport can be Data Layer now.
- Apple Watch transport can be WatchConnectivity later.
- Phone integration surface stays stable.

### 4) Add phone-side wearable bridge layer

In Flutter app, add a `WearBridgeService` abstraction:

- receives wearable intents
- pushes state snapshots
- buffers and persists HR samples

Android implementation options:

- Preferred: native Android service + Flutter `MethodChannel`/`EventChannel` bridge into Dart provider layer.
- Alternative: Flutter plugin wrapping Data Layer and Health Services (more work/risk if plugin maturity is limited).

### 5) Workout + health data ownership

- Use watch sensors as source for HR during active workouts.
- Persist incoming HR stream with workout id on phone (local DB + backend upload path).
- Keep Health Connect writes on phone initially (single source, already implemented).
- Optionally later add watch-side exercise session recording for resilience if phone disconnects.

## Pixel Watch Testing Strategy

### Local development loop

1. Emulator first:
   - Wear OS emulator in Android Studio.
   - Pair with phone emulator/device using Wear Pairing Assistant.
   - Use emulator Health Services controls to simulate HR.
2. Physical Pixel Watch:
   - Enable Developer Options + ADB debugging on watch.
   - Connect with `adb pair` + `adb connect` over Wi-Fi (Bluetooth debugging is not supported on Wear OS 3+).
   - Run wear module directly from Android Studio.

### WSL2 + Pixel Watch connection checklist

1. On the watch:
   - Settings -> Developer options -> enable `ADB debugging`.
   - Enable `Wireless debugging`.
   - Tap `Pair new device` and note `IP:PORT` + pairing code.
2. In WSL2:
   - `~/android-sdk/platform-tools/adb pair <WATCH_IP:PAIR_PORT>`
   - enter the pairing code shown on watch.
   - `~/android-sdk/platform-tools/adb connect <WATCH_IP:ADB_PORT>`
   - verify with `~/android-sdk/platform-tools/adb devices` (watch should show as `device`).
3. Run from repo root:
   - `make run-wear`
4. If the watch disappears after network changes:
   - rerun `adb connect <WATCH_IP:ADB_PORT>`.
5. Device targeting tips:
   - `run-android` auto-selects the first non-watch Android device.
   - `run-wear` auto-selects a connected watch device.
   - Override manually when needed: `WEAR_SERIAL=<serial> make run-wear`.

### Functional test matrix

- Pairing/connection:
  - watch installed + phone installed
  - watch installed first (phone absent)
  - reconnection after Bluetooth/Wi-Fi interruptions
- State rendering:
  - READY, RESTING, LIFTING, ALL_DONE
  - warmup vs working set
  - group summary present/absent
- Action correctness:
  - each watch action produces the exact phone provider mutation
  - idempotency on duplicate taps/retries
- HR streaming:
  - normal streaming
  - permission denied on watch
  - sensor unavailable
  - app background/foreground transitions
- Timing:
  - rest timer drift tolerance
  - active duration alignment (watch vs phone)

## Health + Permission Notes

- Watch app must request its own permissions; phone permissions do not automatically grant watch permissions.
- For active exercise tracking with Health Services, ensure foreground-service and sensor permissions are configured correctly.
- For API level 36+, heart-rate permission handling differs from older BODY_SENSORS behavior; implement version-aware permission checks.

## Rollout Plan

### Phase 0 (design hardening)

- Freeze wearable protocol schema.
- Define mapping from `WorkoutProvider`/`MultiplayerProvider` state -> `WearWorkoutSnapshot`.
- Define action authorization rules (what actions are legal in each state).

### Phase 1 (MVP companion control)

- Add Wear module UI with:
  - YOU card
  - GROUP card
  - elapsed + rest/active timer
  - action buttons
- One-way state sync phone -> watch.
- Watch actions -> phone mutation (no HR yet).

### Phase 2 (heart rate ingestion)

- Start/stop HR collection tied to active workout lifecycle.
- Stream HR samples watch -> phone.
- Persist with workout timeline and upload/store with workout record.
- Add observability (sample count, last sample ts, drop rate).

### Phase 3 (resilience + UX)

- Reconnect/backfill behavior.
- Queue intents offline on watch, replay on reconnect with dedupe ids.
- Better watch affordances (haptics, confirmation states, quick retry).

### Phase 4 (Apple Watch parity preparation)

- Keep protocol unchanged.
- Implement watch transport adapter for iOS (WatchConnectivity + Swift/SwiftUI).
- Reuse same phone-side wearable bridge contract and domain mapping.

## Concrete Next Build Tasks

1. Create `:wear` Android module and skeleton Compose for Wear app.
2. Implement Data Layer capability detection and phone/watch handshake.
3. Add phone native bridge service and Dart `WearBridgeService` interface.
4. Implement snapshot push from current `WorkoutProvider` state every state/timer tick.
5. Implement watch actions mapped to existing provider commands.
6. Implement HR collector on watch + sample ingestion endpoint on phone side.

## Sources

- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Wear OS create/run app (includes architecture guidance + Data Layer usage): https://developer.android.com/training/wearables/get-started/creating
- Wear Data Layer overview: https://developer.android.com/training/wearables/data/overview
- Handle Data Layer events: https://developer.android.com/training/wearables/data/events
- Integrate Wear module + Health Services + send data to handheld: https://developer.android.com/health-and-fitness/fitness/basic-app/integrate-wear-os
- Health Services ExerciseClient guidance: https://developer.android.com/health-and-fitness/health-services/active-data
- Wear permissions guidance: https://developer.android.com/training/wearables/apps/permissions
- Wear standalone vs non-standalone: https://developer.android.com/training/wearables/apps/standalone-apps
- Wear emulator/testing docs: https://developer.android.com/training/wearables/get-started/emulator
- Wear debugging docs: https://developer.android.com/training/wearables/get-started/debugging

# Schlift

A strength-training app. You log your lifts on a phone or a watch. You can
share a live session with other lifters.

| Part | Path | Stack |
|---|---|---|
| Backend | `src/` | Rust, gRPC (tonic), one SQLite file |
| App | `app/` | Flutter — phone, Wear OS, Apple Watch |
| Web | `web/` | React, Vite — landing page, privacy, account deletion |

Bundle ID on all platforms: `com.brensch.schlift`.

## How it works

- **Backend** — One Rust binary (`src/main.rs`). One SQLite file in WAL
  mode. The write pool has 1 connection, so writes run in series. The read
  pool has 16. RPC handlers are in `src/server/`.
- **Training** — You compose workout templates (ordered exercise lists).
  The app prescribes sets, reps, rest and weight per exercise
  (`src/exercise_catalog.rs`), and one rule progresses every exercise:
  double progression (`src/exercise_progress.rs`). Weekly volume per
  muscle is tracked against a 10–20 band (`src/volume.rs`).
- **Protobuf** — `proto/workout/v1/` is the only contract between the
  backend and the clients. Generated code is committed.
- **App** — `app/lib/` holds `screens/`, `widgets/`, `providers/` (state),
  `services/` (transport) and `logic/` (pure functions).
- **Watches** — The watches never call the backend. They exchange protobuf
  messages with the phone. The phone holds the truth.
- **Auth** — Passkeys only. There are no passwords.

Full reference: [`docs/architecture/`](docs/architecture/).

## Build and run

```bash
cargo build --release && ./target/release/schlift    # backend on :50051
cd app && flutter pub get && flutter run             # app
cd web && npm install && npm run dev                 # web
```

Regenerate the bindings after you edit a `.proto` file:

```bash
make proto-dart       # app/lib/gen/            — needs protoc-gen-dart
make proto-android    # app/android/shared-proto/
make proto-swift      # watchOS — needs protoc-gen-swift (macOS only)
```

Rust regenerates through `build.rs` on the next build.

Install the tools one time:

```bash
curl -fsSL -o ~/.local/bin/buf \
  https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64
chmod +x ~/.local/bin/buf
dart pub global activate protoc_plugin        # gives protoc-gen-dart
```

> **Caution:** generated code is committed. If you edit a proto and do not
> regenerate, the backend and the app disagree at run time, not at build
> time.

## Test

```bash
cargo test --all-targets                       # backend
cargo clippy --all-targets -- -D warnings      # lints, as CI runs them
make fuzz-api                                  # randomised API sequences
cd app && flutter test                         # app
```

`make fuzz-api` starts a throwaway backend. It drives random workout
sequences — onboarding, template starts, mid-workout edits, double
EndWorkout — and checks the state invariants after every change.

See [`docs/architecture/testing.md`](docs/architecture/testing.md) for what
each layer catches.

## Release

Push to `main` to deploy the backend. Push a `v*` tag to build the signed
Android, Wear OS and iOS artifacts.

```bash
git tag v0.9.6 origin/main && git push origin v0.9.6
```

The version comes from the tag. Do not edit `app/pubspec.yaml`; it stays at
the `0.0.0+1` placeholder.

See [`docs/releasing.md`](docs/releasing.md) for signing, secrets and the
store checklists.

## Layout

```
src/        Rust backend
app/        Flutter app (phone, Wear OS, Apple Watch)
web/        React site
proto/      Protobuf contracts
examples/   Load test and API invariant harness
make/       Makefile target groups
deploy/     systemd and Caddy configs
docs/       Architecture reference and runbooks
```

## Documents

| Document | Subject |
|---|---|
| [`docs/architecture/`](docs/architecture/) | How the system works, with diagrams |
| [`docs/plans/composable-workouts.md`](docs/plans/composable-workouts.md) | The composable-workouts design: templates, trackers, double progression |
| [`docs/android_dev.md`](docs/android_dev.md) | Emulator and device workflow |
| [`docs/releasing.md`](docs/releasing.md) | Signing, secrets, store checklists |
| [`docs/calorie_maths.md`](docs/calorie_maths.md) | How the calorie estimate works |
| [`docs/design-history/`](docs/design-history/) | Replaced design plans, kept for context |

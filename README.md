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
- **Programs** — `src/regimes/` holds 3 training programs (Linear 5x5,
  GZCLP, Wendler 5/3/1) behind the `WorkoutRegime` trait. Each program is a
  state machine. It proposes the next session and moves its state forward
  when you finish.
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

Regenerate the Dart bindings after you edit a `.proto` file:

```bash
dart pub global activate protoc_plugin
cd proto && protoc --dart_out=grpc:../app/lib/gen -I . workout/v1/*.proto
```

`make proto-all` also builds the Java and Swift bindings, but it needs
`buf`. Rust regenerates through `build.rs` on the next build.

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
sequences and checks the state invariants after every change. Program
behaviour is covered by JSON scenarios in `src/regimes/scenarios/`.

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
| [`docs/plans/composable-workouts.md`](docs/plans/composable-workouts.md) | **Proposal:** remove the programs; users compose their own workouts |
| [`docs/regime-explorer.html`](docs/regime-explorer.html) | How each program progresses, stalls and deloads |
| [`docs/android_dev.md`](docs/android_dev.md) | Emulator and device workflow |
| [`docs/releasing.md`](docs/releasing.md) | Signing, secrets, store checklists |
| [`docs/calorie_maths.md`](docs/calorie_maths.md) | How the calorie estimate works |
| [`docs/design-history/`](docs/design-history/) | Replaced design plans, kept for context |

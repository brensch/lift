# Schlift

A multiplayer strength-training app. Track your lifts solo or in a shared
session, follow an adaptive program (5×5, GZCLP, Wendler 5/3/1), and drive your
workout from your phone or watch.

The repo holds three things:

| Component | Path | Stack |
|-----------|------|-------|
| Backend | `src/` | Rust + gRPC (tonic), SQLite single-file store |
| Mobile app | `app/` | Flutter — phone, Wear OS, and Apple Watch |
| Web (landing + account) | `web/` | React + Vite (marketing, privacy, delete-account) |

Package / bundle ID across platforms: `com.brensch.schlift`.

## Architecture

- **Backend** — A Rust gRPC server (`src/main.rs`) backed by a single SQLite
  database (`data/central.sqlite`). The DB layer (`src/db/`) uses a write-worker
  pattern with a read pool. RPC handlers live in `src/server/`
  (`workout`, `multiplayer`, `settings`, `user`, `auth`, `support`).
- **Adaptive regimes** — `src/regimes/` implements the program state machine
  (Linear 5×5, GZCLP, Wendler 5/3/1) behind the `WorkoutRegime` trait. Program
  state is stored as an append-only event log and replayed to a latest snapshot.
  See [`docs/historised_state_machine.md`](docs/historised_state_machine.md).
- **Protobuf** — Contracts in `proto/workout/v1/`. Generated Dart lands in
  `app/lib/gen/`, generated TypeScript in `web/src/gen/`.
- **Flutter app** — `app/lib/` is organised into `screens/`, `widgets/`,
  `providers/` (state), `services/` (transport), and `logic/`. The watch
  companions mirror phone state; the phone remains the source of truth.

## Getting started

### Backend

```bash
cargo build --release
./target/release/schlift        # listens on :50051
```

### Flutter app

```bash
cd app
flutter pub get
flutter run
```

Regenerate protobuf bindings after editing `proto/`:

```bash
PATH="$PATH:$HOME/.pub-cache/bin" \
  protoc --dart_out=grpc:app/lib/gen --proto_path=proto proto/workout/v1/*.proto
```

### Web

```bash
cd web
npm install
npm run dev
```

## Tests

```bash
cargo test                      # backend + regime scenario tests
cd app && flutter test          # Flutter unit/widget tests
```

Regime behaviour is covered by JSON scenarios in `src/regimes/scenarios/`,
driven through the real scheduler and state machine.

## Releasing

Releases are triggered by pushing a `v*` tag (e.g. `v0.9.5`), which runs the
signed Android/Wear and iOS build workflows. The backend deploys on push to
`main`.

1. Merge release-ready changes to `main` via PR.
2. Tag the merged commit and push: `git tag v0.9.6 origin/main && git push origin v0.9.6`.

The version is derived automatically — name from the tag (`v0.9.6` → `0.9.6`),
build number from the run number. `app/pubspec.yaml` stays a `0.0.0+1`
placeholder; there is no manual version bump.

See [`docs/releasing.md`](docs/releasing.md) for signing setup, required GitHub
Actions secrets, and the Play Store / App Store checklists.

## Repo layout

```
src/        Rust backend (gRPC server, db, regimes, scheduler)
app/        Flutter app (phone + Wear OS + Apple Watch)
web/        React landing / privacy / account-deletion site
proto/      Protobuf contracts (source of truth for generated code)
examples/   Rust benchmarks and one-off inspection binaries
scripts/    Release / icon / deploy helper scripts
deploy/     Deployment configs
docs/        Architecture notes and runbooks
```

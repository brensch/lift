# Schlift

A strength-training app for phone and watch, with live group sessions.

```
 Apple Watch / Wear OS ──protobuf──▶ Phone (Flutter) ──Sync stream──▶ Backend (Rust)
   draws what the phone sends        Rust core linked in               event store + groups
```

- **Core** (`core/`, Rust): every rule. An account is the fold of its events;
  each write is one event. Runs on the phone (via `app/native`) and on the
  server. Folds are deterministic: no clock, no randomness.
- **App** (`app/`, Flutter): local-first. Works offline; syncs events to the
  server. `screens/` `widgets/` `providers/` (state) `services/` (transport)
  `logic/` (pure functions). Copy lives in `app/copy.yaml`.
- **Watches** (`app/android/wear`, `app/ios/SchliftWatch`): never call the
  backend. The phone sends a rendered snapshot; the watch sends taps back.
- **Backend** (`src/`, Rust, gRPC, one SQLite file): stores each account's
  events, serves the template library (`templates/library.yaml`), runs
  multiplayer sessions. Every handler authenticates itself.
- **Contract** (`proto/workout/v1/`): the only interface between all of the
  above. Generated code is committed.
- **Web** (`web/`, React): landing page, privacy, account deletion.

Run: `make dev` (local backend + app with hot reload). Check: `make fmt`,
`make lint-check`, `cargo test --workspace`, `make test-app`.
Release: push to `main` deploys the backend; a `v*` tag builds to the store
testing tracks; a `prod-v*` tag promotes to production.

More: [`docs/architecture/`](docs/architecture/) (how it works),
[`docs/makefile.md`](docs/makefile.md) (every target),
[`docs/releasing.md`](docs/releasing.md) (shipping), [`CLAUDE.md`](CLAUDE.md)
(rules that are easy to get wrong).

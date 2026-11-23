# System Overview

Schlift is a strength-training app. A user composes workout templates, logs
sets against the targets planned for them, and can share a live session with other
lifters. The account lives on the phone and works fully offline: the Rust
core (`core/`) is linked into the app and runs every rule there. What it
tells the user to lift comes from the account's **program**, one JSON
document of training rules, which an assistant (an LLM, over MCP) can
rewrite. The server keeps a synced copy for multiplayer, the web,
assistants and analytics. The watch is a remote control and sensor for the
phone.

## Components

```mermaid
graph TB
    subgraph clients["Clients"]
        subgraph phone["Flutter app — phone (iOS / Android)"]
            ui["screens + providers"]
            native["app/native<br/>core + account file (SQLite)"]
            ui --> native
        end
        wear["Wear OS companion<br/>Kotlin"]
        watchos["Apple Watch companion<br/>SwiftUI"]
        webapp["Web<br/>React + Vite"]
        assistant["Assistant<br/>MCP client"]
    end

    subgraph server["Backend — single Rust binary"]
        grpc["tonic gRPC<br/>+ tonic-web"]
        handlers["RPC handlers<br/>src/server/"]
        mcp["MCP + OAuth<br/>src/mcp/"]
        core["core/ — the same crate<br/>Account, apply, api"]
        dbl["DB layer<br/>src/db/"]
    end

    sqlite[("SQLite<br/>data/server.sqlite<br/>WAL")]

    wear <-->|"Data Layer<br/>protobuf envelopes"| phone
    watchos <-->|"WatchConnectivity<br/>protobuf envelopes"| phone
    phone <-->|"gRPC: Sync stream,<br/>auth, multiplayer"| grpc
    webapp -->|"gRPC-Web: reads,<br/>assistant consent"| grpc
    assistant -->|"HTTP JSON-RPC<br/>/api/mcp"| mcp
    grpc --> handlers
    handlers --> core
    handlers --> dbl
    mcp --> core
    mcp --> dbl
    dbl --> sqlite
```

The watches never talk to the backend. They exchange protobuf envelopes with
the phone over the platform transport. The phone answers them from its own
account, so a watch works whenever the phone is reachable, network or not.

## Repository layout

```
core/               The domain, pure Rust (no IO): shared by phone and server
  programs/         default.json (the built-in program), GUIDE.md (its fields)
  src/events.rs     Event and Fact: what is stored and synced
  src/account.rs    Account, apply, fold
  src/api.rs        The app's RPCs answered from an Account (View / Call)
  src/program/      The program: types, validation, formulas, loading
  src/plan.rs       The planner: interprets the program
  src/simulate.rs   A draft program run over history and forward
  src/migrate.rs    The one-time move of stored events to programs
  src/projection.rs The account as SQL tables, for an exported file
  src/workout/      Workout planning + state reduction
  src/exercise_progress.rs, volume.rs, …
  tests/api.rs      The API end to end
  examples/fuzz.rs  The invariant fuzzer
src/                Rust backend
  server/           gRPC handlers, one module per service
  mcp/              The MCP server and its OAuth endpoints, for assistants
  db/               SQLite access: auth, sessions, the event store, assistants, migrations
app/                Flutter app
  native/           The core's host shim: account file, flutter_rust_bridge API
  rust_builder/     cargokit: builds app/native into the app
  lib/screens/      Full-page UI
  lib/widgets/      Reusable UI
  lib/providers/    App state (ChangeNotifier)
  lib/services/     The core doorway, sync, transport, platform integration
  lib/logic/        Display helpers (no widgets, no platform I/O)
  lib/gen/          Generated Dart (protobuf, flutter_rust_bridge) — do not edit
  android/wear/     Wear OS companion (Kotlin)
  ios/SchliftWatch/ Apple Watch companion (SwiftUI)
web/                React landing, routines, sign-in + dashboard, admin, privacy, account deletion, /connect (assistant consent)
proto/workout/v1/   Protobuf contracts — source of truth
```

## Protobuf is the contract

`proto/workout/v1/` generates code for every client. The one other thing the
backend and the app share is the `core/` crate itself, which speaks these
messages: the app passes it request bytes and gets response bytes back.

```mermaid
graph LR
    proto["proto/workout/v1/*.proto"]
    proto -->|"prost-build (core/build.rs)<br/>tonic-build (build.rs)"| rust["Rust types<br/>schlift_core::pb, services"]
    proto -->|"buf.gen.dart.yaml"| dart["app/lib/gen/"]
    proto -->|"buf.gen.android.yaml"| java["app/android/shared-proto/"]
    proto -->|"buf.gen.swift.yaml"| swift["Swift (watch)"]
    proto -->|"buf.gen.yaml"| ts["web/src/gen/"]
```

Regenerate after editing a `.proto`:

```bash
make proto-all      # dart + android + web + swift
```

Rust regenerates automatically via `build.rs` on the next `cargo build`.

> **Caveat:** generated Dart is committed. If you edit a proto and forget to
> regenerate, the Dart side and the core will disagree silently until runtime.

## A write end to end

Completing a set, from tap to the server's copy:

```mermaid
sequenceDiagram
    participant U as User
    participant P as WorkoutProvider
    participant N as app/native Store
    participant C as core (api + apply)
    participant Y as AccountSync
    participant S as Server Sync

    U->>P: tap "done, 5 reps"
    P->>N: call("AppendWorkoutMutations", bytes)
    N->>C: Call::append_workout_mutations
    C->>C: decide the fact, record the Event (apply through the reducer)
    N->>N: append the event to pending
    C-->>P: GetWorkoutResponse (the new state)
    P->>P: notifyListeners()
    Note over P: on screen; no network involved
    N-->>Y: writes stream fires
    Y->>S: SyncRequest{events: pending, zstd JSON}
    S->>S: push_events: place, store
    S-->>Y: Events{the placed events, head}
    Y->>N: receive — they leave pending
```

The answer the app shows is the core's answer, computed on the phone. Sync
happens afterwards and never blocks a screen. See
[local-first.md](local-first.md).

## Deployment

Production is bare metal: a systemd-managed binary behind Caddy.

```mermaid
graph LR
    internet(("Internet")) -->|"HTTPS<br/>schlift.com"| caddy["Caddy<br/>deploy/Caddyfile"]

    caddy -->|"POST /workout.v1.*<br/>h2c"| binary
    caddy -->|"/api/* (incl. /api/mcp), /.well-known/*<br/>/apple-app-site-association"| binary
    caddy -->|"everything else"| static["/opt/schlift/web<br/>SPA fallback"]

    subgraph unit["systemd: schlift.service"]
        binary["schlift binary<br/>127.0.0.1:50051"]
    end

    binary --> data[("/opt/schlift/shared<br/>data/server.sqlite")]
```

Server layout (see `deploy/README.md`):

```
/opt/schlift/
  current -> releases/<git-sha>    # ExecStart target
  releases/
  shared/                          # WorkingDirectory
    data/server.sqlite
    schlift.env                    # EnvironmentFile
```

Deployment is push-to-`main` via `.github/workflows/backend-deploy.yml`: an
arm64 GitHub runner builds the binary, and the server (an Oracle Cloud Ampere VM) pulls it: an agent on the
box (`deploy/puller/`) sees the new GitHub Deployment, checks the build against a
copy of the database, installs it into a new release directory, restarts the unit
and reports back. There is no runner on the server.

The backend is a single binary with an embedded SQLite file — no external
database, no cache, no queue. See `deploy/` and `docs/releasing.md`.

App releases are tag-triggered: push a `v*` tag to build signed Android/Wear and
iOS artifacts. The version comes from the tag; `app/pubspec.yaml` stays a
`0.0.0+1` placeholder.

## Scale assumptions

The architecture assumes a small user base:

- One SQLite file, one write connection. All writes serialise.
- No account is held in memory: the website's reads fold one from its
  history when asked. In-flight WebAuthn challenges and join requests are
  in memory, so the backend is single-instance.
- New events and multiplayer updates go out over each phone's Sync stream,
  told in process to the streams they concern; no external queue.

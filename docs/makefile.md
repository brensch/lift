# Makefile reference

Every `make` target, what it does, and which ones to reach for. The top-level
`Makefile` holds the variables and includes `make/*.mk`, one file per area.

**Build on this machine.** Anything destined for a phone or an emulator is built
locally and installed with `adb` — a local release build takes about 80 seconds.
CI is for what only CI can do: PR checks, the production backend deploy on merge
to `main`, the dev backend deploy, and store uploads
([`releasing.md`](releasing.md)). Do not push a tag and wait for a workflow just
to get an APK.

Variables worth knowing (all overridable, `make VAR=value target`):

| Variable | Default | |
|---|---|---|
| `FLUTTER`, `DART` | `~/flutter-sdk/bin/…` | Not on `PATH` |
| `BUN` | `~/.bun/bin/bun` | Not on `PATH` |
| `ANDROID_SDK` | `~/android-sdk` | |
| `ADB` | `$(ANDROID_SDK)/platform-tools/adb` | Not on `PATH`. A phone on wireless debugging shows up as `192.168.x.x:port` |
| `PHONE_SERIAL`, `WEAR_SERIAL` | auto-detected | Pick the phone or watch when several are attached. Otherwise the first non-watch / watch device on adb |
| `ANDROID_SERIAL` | `emulator-5554` | The emulator the agent, e2e and store targets drive |
| `DEV_SERVER_HOST` | `dev.schlift.com` | Backend the dev app is compiled against |

Release builds of the app default to `schlift.com:443`; debug builds default to
`localhost:50051`. Override either with `--dart-define=SERVER_HOST=… SERVER_PORT=…`.

## The fast loop

```bash
make dev
```

The backend under `cargo watch` (log in `.tmp/dev-backend.log`), a debug build
on the phone against it through `adb reverse`, and a hot reload whenever a
`.dart` file under `app/lib` is saved. A Rust save is serving again in about
two seconds; a Dart save is on the phone in under one. Ctrl+C stops all of it.

| Target | |
|---|---|
| `make hot-reload` / `make hot-restart` | Signal the running `run-android` session, the same as `r` / `R` in its terminal. |
| `make hot-reload-on-save` | The watcher `dev` runs. A save under `app/lib/theme/` or to `main.dart` hot *restarts*: the themes and app wiring are built once at startup, so a reload would keep the old ones. |

Hot reload covers Dart code. A proto change: `make proto-dart`, then
`make hot-restart` (the backend regenerates its side by itself). Native code —
including the Rust core the app links (`core/`, `app/native`) — pubspec and
`--dart-define` changes need a fresh `make dev`.

## Getting a build onto a phone

| Target | What you get |
|---|---|
| `make deploy-android-dev` | **The one to use on a real phone.** Release build of the side-by-side dev app (`com.brensch.schlift.dev`, "Schlift Dev") pointed at `dev.schlift.com`, installed over whatever dev build is there. Same package and release key as the CI dev build, so it upgrades in place and keeps the login. Picks a build number one above the installed one, so adb never refuses it as a downgrade. Never uninstalls anything. |
| *(both release targets)* | Build only the connected device's ABI (`--target-platform`), not all three. |
| `make run-android` | `flutter run` (debug, attached, hot reload) on the phone, with `adb reverse tcp:50051` so it talks to the **local** backend (`make run-backend`). The phone half of `make dev`. `FLUTTER_RUN_ARGS` adds flags. |
| `make run-android-prod` | Same, but compiled against `schlift.com:443`. |
| `make run-android-clean` | `gradlew clean` + `flutter clean` first. |
| `make deploy-android` | Release APK of the **production package** `com.brensch.schlift`, for emulators and phones without the Play install. Play re-signs its installs, so on a phone with the real app the install fails with a signature mismatch; the target stops there and never uninstalls. |
| `make run-linux`, `make run-app`, `make stop-app` | Desktop build / run / stop. |

`deploy-android-dev` needs release signing: `app/android/key.properties` and the
keystore it names. Both are gitignored, so **a fresh git worktree does not have
them** — copy them from the main checkout, and delete them again afterwards.

The dev app only shows new backend behaviour if the dev backend has it. Deploy a
branch there with `gh workflow run dev-backend-deploy.yml --ref <branch>` (see
[`dev-channel.md`](dev-channel.md)); the backend is the one half of the dev
channel that does come from CI, because it runs on the server.

## Backend

| Target | |
|---|---|
| `make run-backend` | `cargo watch` dev server on `:50051` with `--features test-auth` (dev login). Rebuilds on a save under `src/`, `core/`, `proto/`, `templates/`, `build.rs` or the Cargo files, nothing else. Kills any running `schlift` first. |
| `make run-backend-release` | Same, release build, no watch. |
| `make run-backend-scratch` | Same as `run-backend` without the watch, on an empty database in `.tmp/scratch-backend` wiped every start. |
| `make agent-backend-start` / `agent-backend-stop` | Background instance with a pidfile and a log, waits for `/api/health`. Uses `:50051`, so it collides with any other backend on the machine. |
| `make run-web-dev` | Backend + web dev server together. `make run-frontend` is the web half. |
| `make run-prod` | `docker-compose up --build`. |
| `make check` | `cargo check` + web build. |
| `make fuzz-api` | The core's invariant fuzzer, in-process (`cargo run -p schlift-core --example fuzz`; `FUZZ_USERS`, `FUZZ_SESSIONS`, `FUZZ_SEED`). No backend needed. `make fuzz-api-ci` is the fixed-seed run CI does. |

For a throwaway instance that collides with nothing, skip make:
`DATA_DIR=<scratch dir> PORT=50077 ./target/debug/schlift` (build with
`cargo build --features test-auth` for dev login).

If the backend fails to build with missing proto types or fields that the
`.proto` plainly has, the generated code is stale: cargo reruns `build.rs`
only when a `.proto` is newer than its last run, which a branch switch or a
file copied with its old mtime can defeat. `touch proto/workout/v1/*.proto`.

The binary is also the admin CLI: `schlift admin add|remove|list <username>`
([`architecture/analytics.md`](architecture/analytics.md)).

## Code generation

| Target | |
|---|---|
| `make proto-dart` / `proto-android` / `proto-swift` / `proto-all` | Regenerate protobuf code. `proto-swift` needs `protoc-gen-swift`; CI does it on macOS. |
| *(no target)* web TypeScript | `cd proto && buf generate --template buf.gen.yaml` |
| `make copy` | `app/copy.yaml` → `app/lib/gen/copy.dart` |
| *(no target)* Rust ↔ Dart bridge | After changing `app/native/src/api/`: `flutter_rust_bridge_codegen generate` in `app/`. Writes `app/lib/gen/native/` and `app/native/src/frb_generated.rs` (config: `app/flutter_rust_bridge.yaml`). |
| `make sounds`, `make icons`, `make brand` | Sound manifest, launcher icons, brand renders |

Generated code is committed, and is the only code exempt from formatting and
linting.

## Formatting and linting

| Target | |
|---|---|
| `make fmt` | Format every language in place. |
| `make lint-check` | **Run before pushing.** Format check + lint for every language — exactly what CI enforces. |
| `make fmt-check`, `make lint` | The two halves of `lint-check`. |
| `make lint-tools` | Install the pinned ruff, shellcheck, shfmt, ktlint, swiftformat and swiftlint into `.tools/bin`. The targets above run it for you. |

All of them take `LANGS="dart rust web python shell kotlin swift proto"` to
limit the run. Full reference, tool versions and the no-suppressions rule:
[`linting.md`](linting.md).

## Emulator

`android-sdk-check`, `android-phone-avd-create`, `android-phone-play-avd-create`,
`android-phone-play-emulator-start`, `android-emulator-start`,
`android-emulator-stop`, `android-emulator-wait`, `android-emulator-unlock`,
`android-emulator-reverse`, `android-screenshot`, `android-tap`, `android-text`,
`android-run-emulator`, `android-agent-start`, `android-agent-stop`. Walkthrough
in [`android_dev.md`](android_dev.md).

## Tests

| Target | |
|---|---|
| `make test-app` | The Dart tests against the real core: `cargo build -p schlift_native` (the host build they load from `target/debug/`), then `flutter test`. A bare `flutter test` fails to load the library without that build. |
| `cargo test --workspace --all-targets` | The core, the server and `app/native`. No target. |

## End-to-end tests and store assets

| Target | |
|---|---|
| `make e2e` | `e2e-up` + `e2e-run` (`SCENARIO=<name>` for one). Report at `app/test_screenshots/report.html`. See [`testing/e2e-scenarios.md`](testing/e2e-scenarios.md). |
| `make store-capture`, `store-frame`, `store-check`, `store-backend-start`, `store-backend-stop` | Store screenshots and listing checks. |

## Release and signing

`print-cert-hashes`, `ci-android-prepare-signing` (writes `key.properties` from
env), `ci-android-check-signing`, `ci-android-build-release` (phone AAB + wear
AAB), `build-aabs-release` (the same, moved to `aab/` with a date and hash),
`ci-android-release-local`, `ci-android-clean-signing`. Uploading to the stores
is tag-driven CI — [`releasing.md`](releasing.md).

## Wear OS and Apple Watch

`run-wear`, `run-wear-logs`, `run-wear-debug`, `build-wear-release`,
`deploy-wear` (never uninstalls, like `deploy-android`), `android-wear-avd-create`, `android-wear-emulator-start`,
`android-wear-run-emulator`, `android-wear-pairing-notes`; and on macOS
`watch-setup`, `watch-generate`, `watch-build`, `watch-build-release`,
`watch-sim`, `watch-sim-list`.

## Setup

`setup-flutter`, `install-deps`, `check-android-java`.

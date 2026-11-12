# Working in this repo

Start with [`docs/architecture/`](docs/architecture/README.md) for how the
system works, [`docs/makefile.md`](docs/makefile.md) for how to run, build and
ship it, and [`docs/linting.md`](docs/linting.md) for formatting and linting. This file is only the rules that are easy to get wrong.

- **Build locally.** To put a build on a phone or emulator, use the Makefile on
  this machine and `adb`. `make dev` is the fast loop: local backend, debug app,
  hot reload on save. `make deploy-android-dev` is the release dev app. Do not
  push a tag and wait for CI to produce an APK. CI is for PR checks, backend
  deploys and store uploads.
- **Never uninstall `com.brensch.schlift` from a phone.** `make deploy-android`
  cannot install over the Play build (signature mismatch) and stops there; do
  not "fix" that by uninstalling the real app.
- **Format and lint before you push: `make fmt`, then `make lint-check`.**
  Every language has a formatter and a linter (Dart, Rust, TypeScript, Python,
  shell, Kotlin, Swift, protobuf) and CI fails on anything unformatted or
  unlinted. It is the same command CI runs, with pinned tool versions, so
  clean locally means clean in CI. Details: [`docs/linting.md`](docs/linting.md).
- **Fix findings in the code. Never suppress them.** No `// ignore:`,
  `# noqa`, `#[allow(...)]`, `eslint-disable`, `swiftlint:disable`,
  `buf:lint:ignore`, per-file excludes or loosened thresholds to make a check
  pass. If a rule is genuinely wrong for this codebase, that is a project-level
  config change with the reason written beside it, called out in the PR — not
  something to slip in.
- **In a fresh git worktree run `flutter pub get` before any Dart tooling**, or
  `dart format` picks the wrong language version and restyles everything.
- **`web/` has two lockfiles** (`bun.lock` for local work, `package-lock.json`
  for `npm ci` in CI and the production deploy). Change dependencies in both;
  see `docs/linting.md` for how to regenerate `package-lock.json` safely.
- **Swift cannot be compiled on this machine.** After editing Swift, run
  `gh workflow run ios-debug-compile.yml --ref <branch>`. A new `.swift` file
  must also be registered in the committed Xcode project with
  `scripts/xcode_add_swift.py` (CI checks this). Keep the empty `RunnerTests`
  target: Flutter's generated Podfile names it, and `pod install` fails
  without it.
- **`flutter`, `dart`, `bun` and `adb` are not on `PATH`.** Paths are in
  `docs/makefile.md`.
- **A git worktree has no signing files** (`app/android/key.properties`, the
  keystore — gitignored). Copy them from the main checkout for a release build
  and remove them afterwards.
- **Every gRPC handler calls `authed_user_id` (or `authed_admin_id`) itself**;
  there is no middleware. The deliberate exception is `report_auth_failure`
  (besides the passkey handshake, which includes the recovery request and
  its status) — do not copy it.
- **Account state lives in the core, not the server or Dart.** A new write
  is a new `Fact` in `core/src/events.rs`, a branch in `Account::apply`
  (`core/src/account.rs`) and a method in `core/src/api.rs` that decides it;
  never a new server RPC or a rule in a provider. A fact is what was
  decided (times filled in, plans and library entries as they were), never
  the request; it must fold deterministically: no clock, no randomness, ids
  from the event's id.
  See [`docs/architecture/local-first.md`](docs/architecture/local-first.md).
- **Stored events are JSON and are only ever added to.** Never rename or
  remove a field of a fact, or of a proto message a fact holds (a template,
  a decision, a workout): stored events would stop reading.
  `core/tests/stored_events.rs` fails on it, and a new fact goes in its
  `testdata/stored_events.json`. Changing how an existing fact folds changes
  every stored account: the phone and the server must fold the same events
  to the same account. An older app keeps a fact it doesn't know and folds it
  as nothing; nothing may write a new kind into accounts until the app that
  knows it is required (`MIN_APP_VERSION`). In the protos, a removed field's number and name go
  in that message's `reserved`; never reuse a number or delete a
  `reserved` line.
- **Storage follows authority.** What the phone makes (training, templates,
  settings) is only ever account events; the server places and stores them
  and never copies them into tables. What the server owns (users,
  passkeys, logins, who trained together, telemetry) is plain columns, no
  proto blobs. What only matters while the server runs (join requests,
  which stream watches whom) is in memory. The server holds no folded
  account and computes no live state: partners' status is folded on each
  phone from the workout events the server routes to it.
- **Server schema changes are a new step in `src/db/migrate.rs`**: an
  `if version < N` block at the end of `migrate`, run once at startup and
  tracked by `PRAGMA user_version`. Never edit a step that has shipped.
- **After changing `app/native/src/api/`, run `flutter_rust_bridge_codegen
  generate` in `app/`** and commit the regenerated `app/lib/gen/native/` and
  `app/native/src/frb_generated.rs`.
- **Dart tests load the host build of the core**: run them with
  `make test-app` (or `cargo build -p schlift_native` first).
- **A table with a `user_id` column references `users(id) ON DELETE
  CASCADE`**: deleting the user deletes their rows. A test fails if one does
  not.
- **No hard-coded colours, fonts, text sizes, weights or radii in widgets.**
  Read them from the theme (`context.tokens`, the colour scheme); new tokens
  go in `ThemeSpec`, values in `schlift_spec.dart`.
  See "Theming" in [`docs/architecture/app.md`](docs/architecture/app.md).
- **User-visible text lives in `app/copy.yaml`**, read through `copy`; the
  owner writes it, so new strings are placeholders for them to replace. Run
  `make copy` to regenerate `app/lib/gen/copy.dart`, and never edit or
  `dart format` that file: CI checks it is exactly what the generator writes.
- **Releases are tag-driven**; never hand-bump `pubspec.yaml`. See
  [`docs/releasing.md`](docs/releasing.md).

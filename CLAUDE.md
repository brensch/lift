# Working in this repo

Start with [`docs/architecture/`](docs/architecture/README.md) for how the
system works, [`docs/makefile.md`](docs/makefile.md) for how to run, build and
ship it, and [`docs/linting.md`](docs/linting.md) for formatting and linting. This file is only the rules that are easy to get wrong.

- **Build locally.** To put a build on a phone or emulator, use the Makefile on
  this machine (`make deploy-android-dev`, `make run-android`) and `adb`. Do not
  push a tag and wait for CI to produce an APK. CI is for PR checks, backend
  deploys and store uploads.
- **Never run `make deploy-android` against a phone with the real app.** On a
  signature mismatch — guaranteed against a Play install — it uninstalls
  `com.brensch.schlift`.
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
  must also be added to `app/ios/Runner.xcodeproj/project.pbxproj`.
- **`flutter`, `dart`, `bun` and `adb` are not on `PATH`.** Paths are in
  `docs/makefile.md`.
- **A git worktree has no signing files** (`app/android/key.properties`, the
  keystore — gitignored). Copy them from the main checkout for a release build
  and remove them afterwards.
- **Every gRPC handler calls `authed_user_id` (or `authed_admin_id`) itself**;
  there is no middleware. The deliberate exceptions are `list_template_library`
  and `report_auth_failure` — do not copy them.
- **A new table with a `user_id` column** must be added to
  `delete_user_account_and_data` (`src/db/auth.rs`); a test fails if it is not.
- **Releases are tag-driven**; never hand-bump `pubspec.yaml`. See
  [`docs/releasing.md`](docs/releasing.md).

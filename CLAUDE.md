# Working in this repo

Start with [`docs/architecture/`](docs/architecture/README.md) for how the
system works and [`docs/makefile.md`](docs/makefile.md) for how to run, build
and ship it. This file is only the rules that are easy to get wrong.

- **Build locally.** To put a build on a phone or emulator, use the Makefile on
  this machine (`make deploy-android-dev`, `make run-android`) and `adb`. Do not
  push a tag and wait for CI to produce an APK. CI is for PR checks, backend
  deploys and store uploads.
- **Never run `make deploy-android` against a phone with the real app.** On a
  signature mismatch — guaranteed against a Play install — it uninstalls
  `com.brensch.schlift`.
- **Do not run `dart format` or `cargo fmt` across the repo.** It is not
  formatter-clean and CI does not check. Format only files you created. In a
  fresh git worktree run `flutter pub get` before any Dart tooling, or the
  formatter picks the wrong style.
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

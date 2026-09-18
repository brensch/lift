# Formatting and linting

Every language in the repo has a formatter and a linter, and CI fails on
anything unformatted or unlinted. There is one entry point, and CI runs exactly
the same command you do:

```sh
make fmt          # format everything in place
make lint-check   # what CI enforces: format check + lint, every language
```

Limit either to some languages with `LANGS`, e.g. `make fmt LANGS="dart web"`.
Under the hood that is `scripts/lint.sh <fmt|fmt-check|lint|check> [lang...]`.

**Run `make fmt` then `make lint-check` before you push.** A red `lint`,
`rust`, `flutter` or `web` job on a PR is almost always one of these.

## What runs

| Language | Files | Format | Lint | Config |
|---|---|---|---|---|
| `dart` | `app/**/*.dart` | `dart format` | `flutter analyze --fatal-infos` | `app/analysis_options.yaml` |
| `rust` | the crate, `examples/` | `cargo fmt` | `cargo clippy --all-targets -- -D warnings` | — |
| `web` | `web/` (TS, TSX, CSS, JSON, MD) | `prettier` | `eslint --max-warnings=0`, `tsc -b` | `web/.prettierrc.json`, `web/eslint.config.js` |
| `python` | `scripts/*.py` | `ruff format` | `ruff check` | `ruff.toml` |
| `shell` | `*.sh` | `shfmt` | `shellcheck` | — |
| `kotlin` | `app/android/**/*.kt`, `*.kts` | `ktlint --format` | `ktlint` | `.editorconfig` |
| `swift` | `app/ios`, `app/macos` | `swiftformat` | `swiftlint --strict` | `.swiftformat`, `.swiftlint.yml` |
| `proto` | `proto/` | `buf format` | `buf lint` | `proto/buf.yaml` |

Generated code is excluded, and only generated code: `app/lib/gen`,
`web/src/gen`, `web/src/generated`, `app/android/shared-proto`,
`app/ios/SchliftWatch/Generated` and Flutter's `GeneratedPluginRegistrant`.

## The rule: fix the code

A finding is fixed in the code. Do not add `// ignore:`, `# noqa`,
`#[allow(...)]`, `// eslint-disable`, `// swiftlint:disable`,
`// buf:lint:ignore`, a per-file exclude, or a relaxed threshold to get a
check to pass. If a rule is genuinely wrong for this codebase, that is a
project-level decision: change the tool's config, say why in a comment beside
it, and call it out in the PR. The places that has happened so far:

- `proto/buf.yaml` turns off `RPC_REQUEST_RESPONSE_UNIQUE` and
  `RPC_RESPONSE_STANDARD_NAME`. Several RPCs share a response message on
  purpose; satisfying the rules means a wire break for shipped apps or
  byte-identical duplicate messages.
- `.editorconfig` tells ktlint that `@Composable` functions are PascalCase,
  which Compose requires.
- `.swiftlint.yml` aligns two layout rules with what swiftformat produces.
- swiftlint runs without SourceKit (`SWIFTLINT_DISABLE_SOURCEKIT=1`) because a
  Linux box and the CI runner have no Swift toolchain. It reports the one rule
  that needs it (`statement_position`) as skipped.

## Tool versions are pinned

A formatter's output changes between releases, so the version that formats the
code has to be the version that checks it.

| Tools | Pinned in |
|---|---|
| ruff, shellcheck, shfmt, ktlint, swiftformat, swiftlint | `scripts/install_lint_tools.sh` (version + sha256), installed to `.tools/bin` by `make lint-tools`, which `make fmt` / `make lint-check` run for you |
| Flutter / Dart | `FLUTTER_VERSION` in `.github/workflows/tests.yml`. Keep it equal to your local SDK. |
| buf | `BUF_VERSION` in `.github/workflows/tests.yml` |
| prettier, eslint, typescript | `web/package.json` + both lockfiles |
| rustfmt, clippy | the `stable` toolchain |

Bumping a pinned tool: change the version, re-run the formatter over the
repo, commit the result as its own commit, and add that commit to
`.git-blame-ignore-revs`.

`scripts/install_lint_tools.sh` fetches Linux binaries. On macOS install the
same tools with Homebrew; `scripts/lint.sh` falls back to `PATH`.

## Gotchas

- **Run `flutter pub get` before any Dart tooling in a fresh checkout or
  worktree.** Without a package config `dart format` assumes a different
  language version and reformats everything in a different style.
- **`web/` has two lockfiles.** Local work uses bun (`bun.lock`); the production
  deploy and CI use `npm ci` (`package-lock.json`), which refuses to run if the
  lockfile has drifted. After changing dependencies, update both — and
  regenerate `package-lock.json` with a full `npm install` in a clean
  directory, because `npm install --package-lock-only` drops optional wasm
  dependencies and produces a lockfile `npm ci` rejects.
- **Swift can only be compiled on macOS.** After changing Swift, run the
  *iOS Debug Compile* workflow against your branch
  (`gh workflow run ios-debug-compile.yml --ref <branch>`). The Xcode project
  is committed, not generated in CI, so a new `.swift` file must also be added
  to `app/ios/Runner.xcodeproj/project.pbxproj`.
- **Kotlin** is compiled by
  `cd app/android && ./gradlew :wear:compileDebugKotlin :app:compileDebugKotlin`.
- **`git blame`** skips the mechanical reformat commits listed in
  `.git-blame-ignore-revs`: `git config blame.ignoreRevsFile .git-blame-ignore-revs`
  (GitHub does this automatically).

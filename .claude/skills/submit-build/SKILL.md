---
name: submit-build
description: Build and submit the Lift app to TestFlight / Google Play from a branch. Use when asked to "submit for a build", "make a build", "push to TestFlight", "ship a build", or release the app.
---

# Submit a Lift app build

The iOS and Android release workflows build the Flutter app and, when store
secrets are present, upload to **TestFlight** (iOS) and **Google Play**
(Android). They trigger on push to the `release` branch **or** manually via
`workflow_dispatch` against any branch that has the workflow files.

Prefer `workflow_dispatch` against a feature branch — it produces a real
store build without merging to `release` (the production branch).

## Steps

1. **Bump the version** (required before every store build). Edit
   `app/pubspec.yaml` `version: X.Y.Z+N` and bump **both** parts:
   - **Semver `X.Y.Z`** — always increment. Patch (`Z`) for fixes, minor
     (`Y`) for features, major (`X`) for breaking changes. This is the
     user-visible version and must move every build.
   - **Build number `+N`** — always increment by 1. Stores reject duplicate
     build numbers. (Android's `versionCode` is also auto-bumped in CI, but
     iOS/TestFlight relies on this `+N`.)

   Example bugfix bump: `0.9.2+48` → `0.9.3+49`.

2. **Commit and push** the change on a feature branch (create one if on
   `main`/`release`). Include the version bump in the commit.

3. **Dispatch the builds** against the branch:
   ```bash
   gh workflow run ios-build.yml --ref <branch>
   gh workflow run android-release.yml --ref <branch>
   ```
   Run only the platform(s) requested; default to both for cross-platform
   changes.

4. **Report run status**:
   ```bash
   gh run list --branch <branch> --limit 5
   ```
   Give the user the run URLs (`gh run view <id> --web`). Do not block waiting
   for completion unless asked.

## Notes

- Workflows: `.github/workflows/ios-build.yml`, `android-release.yml`.
- iOS uploads to App Store Connect via `altool` using
  `APP_STORE_CONNECT_*` secrets; Android uploads via Google Play service
  account. If those secrets are missing the workflow still builds an artifact
  but skips the upload.
- A `workflow_dispatch` run uses the workflow definition from the chosen
  `--ref`, so the branch must contain the workflow files (branches off `main`
  do).
- Pushing to the `release` branch triggers the same builds automatically —
  use that only for an actual production release.

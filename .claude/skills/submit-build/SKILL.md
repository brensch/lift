---
name: submit-build
description: Build and submit the Lift app to TestFlight / Google Play. Use when asked to "submit for a build", "make a build", "push to TestFlight", "ship a build", or release the app.
---

# Submit a Lift app build

The iOS and Android release workflows build the Flutter app and, when store
secrets are present, upload to **TestFlight** (iOS) and **Google Play**
(Android). They trigger on push to the **`release`** branch.

**Always ship via the `release` branch.** Do not use `gh workflow run` /
`workflow_dispatch` against a feature branch to cut a real build — that
bypasses code review and pollutes the store with builds that aren't on
`release`. The canonical flow is: PR into `main`, merge, then promote `main`
to `release`. A push to `release` is what triggers the build.

## Steps

1. **Bump the version** (required before every build). Edit
   `app/pubspec.yaml` `version: X.Y.Z+N` and bump **both** parts:
   - **Semver `X.Y.Z`** — always increment. Patch (`Z`) for fixes, minor
     (`Y`) for features, major (`X`) for breaking changes. This is the
     user-visible version and must move every build.
   - **Build number `+N`** — always increment by 1. Stores reject duplicate
     build numbers. (Android's `versionCode` is also auto-bumped in CI, but
     iOS/TestFlight relies on this `+N`.)

   Example bugfix bump: `0.9.2+48` → `0.9.3+49`.

2. **PR into `main`.** Commit the change (including the version bump) on a
   feature branch, open a PR to `main`, get it merged.
   ```bash
   gh pr create --base main --head <branch> --title "..." --body "..."
   gh pr merge <branch> --squash   # or --merge, after checks/review
   ```

3. **Promote `main` to `release`.** This push is what triggers both builds:
   ```bash
   git fetch origin
   git push origin origin/main:release
   ```
   (Or open a `main → release` PR and merge it if you want a review gate on
   the promotion too.)

4. **Report run status:**
   ```bash
   gh run list --branch release --limit 5
   ```
   Give the user the run URLs (`gh run view <id> --web`). Do not block waiting
   for completion unless asked.

## Notes

- Workflows: `.github/workflows/ios-build.yml`, `android-release.yml`. Both
  declare `workflow_dispatch` as well, but reserve that for throwaway
  device-test builds only — never for an actual release.
- iOS uploads to App Store Connect via `altool` using `APP_STORE_CONNECT_*`
  secrets; Android uploads via Google Play service account. If those secrets
  are missing the workflow still builds an artifact but skips the upload.
- The upload step only checks that store secrets exist, not which branch the
  run is on — which is exactly why a feature-branch `workflow_dispatch` would
  still push to the stores. Stick to the `release` flow.

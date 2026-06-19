---
name: submit-build
description: Build and submit the Lift app to TestFlight / Google Play. Use when asked to "submit for a build", "make a build", "push to TestFlight", "ship a build", or release the app.
---

# Submit a Lift app build

The iOS and Android release workflows build the Flutter app and, when store
secrets are present, upload to **TestFlight** (iOS) and **Google Play**
(Android). They trigger on pushing a **`v*` git tag** (e.g. `v0.9.5`).

**Always ship by tagging a commit on `main`.** Do not use `gh workflow run` /
`workflow_dispatch` against a feature branch to cut a real build — that
bypasses code review and pollutes the store with builds that aren't on
`main`. The canonical flow is: PR into `main`, merge, then tag the merged
commit `vX.Y.Z` and push the tag. Pushing the tag is what triggers both builds.

> GitHub Actions runs the workflow file **as it exists at the tagged commit**.
> So the commit you tag must already contain these tag-triggered workflows —
> always tag a commit on `main` that has them, never an older one.

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

3. **Tag the merged commit and push the tag.** This push is what triggers
   both builds. Tag `main` after the PR lands (use the same `X.Y.Z` as the
   version bump):
   ```bash
   git fetch origin
   git tag v0.9.5 origin/main
   git push origin v0.9.5
   ```

4. **Report run status:**
   ```bash
   gh run list --event push --limit 5      # tag pushes show as 'push' events
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
- The upload step only checks that store secrets exist, not what ref the run
  is on — which is exactly why a feature-branch `workflow_dispatch` would
  still push to the stores. Stick to the tag flow.

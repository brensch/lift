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

## Version comes from the tag — do NOT hand-edit it

The version is injected by CI; there is **no manual version bump**:

- **Name (`X.Y.Z`)** is the tag with the `v` stripped — tag `v0.9.6` ships as
  `0.9.6`. Choose it like semver: patch for fixes, minor for features, major
  for breaking changes.
- **Build number** is `1000 + GITHUB_RUN_NUMBER`, generated per run on both
  platforms — monotonic, so stores never see a duplicate.

`app/pubspec.yaml` holds a frozen `0.0.0+1` placeholder used only for local/dev
builds. Leave it alone.

## Steps

1. **Land your changes on `main`** via the normal PR flow (nothing version-
   related to edit):
   ```bash
   gh pr create --base main --head <branch> --title "..." --body "..."
   gh pr merge <branch> --squash   # or --merge, after checks/review
   ```

2. **Tag the merged commit and push the tag.** This push is what triggers both
   builds. Pick the next `vX.Y.Z`:
   ```bash
   git fetch origin
   git tag v0.9.6 origin/main
   git push origin v0.9.6
   ```

3. **Report run status:**
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
- Both workflows resolve the version in a `Resolve version from tag + run
  number` step. On a `workflow_dispatch` (non-tag) run the name falls back to
  `0.0.0-dev`, so those builds are clearly marked and won't collide with a real
  release name.
- The upload step only checks that store secrets exist, not what ref the run
  is on — which is exactly why a feature-branch `workflow_dispatch` would
  still push to the stores. Stick to the tag flow.

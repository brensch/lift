# Dev channel: dev.schlift.com + side-by-side dev app

Run WIP on a real phone over the air, against an isolated dev backend, installed
**alongside** the prod app — no cable, no wiping your real install.

## What it is

| | Production | Dev |
|---|---|---|
| Host | `schlift.com` | `dev.schlift.com` |
| Backend instance | `/opt/schlift`, `schlift.service`, port `50051` | `/opt/schlift-dev`, `schlift-dev.service`, port `50052` |
| Database | `/opt/schlift/shared/data` | `/opt/schlift-dev/shared/data` (separate, starts empty) |
| WebAuthn RP | `schlift.com` | `dev.schlift.com` (separate passkeys) |
| App package | `com.brensch.schlift` | `com.brensch.schlift.dev` ("Schlift Dev") |
| App delivery | tag `v*` → Play internal/alpha/beta | tag `dev-*` → signed APK at `https://dev.schlift.com/schlift-dev.apk` |
| Backend code | `main` (`Backend Deploy`) | tag `dev-*`, or any branch on demand (`Dev Backend Deploy`) |

Both backend instances live on the same box, fronted by the same Caddy; the dev
vhost just reverse-proxies to `:50052`. TLS is automatic because `*.schlift.com`
resolves to the box.

The dev app has a **distinct applicationId** (`com.brensch.schlift.dev`) so it
installs next to prod, but is signed with the **same key**. It's a sideloaded
APK, not a Play upload (a different package would be a different Play app, which
defeats side-by-side). Passkeys still work because the dev backend's
`/.well-known/assetlinks.json` lists the `.dev` package (`ANDROID_PACKAGE_NAMES`)
with the same signing fingerprints.

## One-time bootstrap

1. **Workflows reachable.** Tag-triggered runs (`dev-*`) execute from the tagged
   commit, so they work from any branch that contains these workflow files. (Only
   the `workflow_dispatch` *buttons* additionally require the files on `main`.)
2. **DNS.** `dev.schlift.com` must resolve to the box — the `*.schlift.com`
   A-record covers it.
3. **Runner sudo.** On the deploy box, reinstall the runner sudoers from
   `deploy/schlift-runner.sudoers.example` (it whitelists
   `/opt/repo-schlift-dev-current/scripts/deploy_schlift_dev.sh`; hosting the APK
   uses the already-whitelisted `/usr/bin/install`).
4. **Stand up the dev backend:** push a `dev-*` tag (or run **Dev Backend
   Deploy**). It installs `schlift-dev.service` on `:50052`, seeds
   `/opt/schlift-dev/shared/schlift.env` from `deploy/schlift-dev.env.example`,
   and adds the `dev.schlift.com` vhost with a graceful Caddy reload.
5. **Verify:** `curl https://dev.schlift.com/.well-known/assetlinks.json` returns
   two statements (`com.brensch.schlift` and `com.brensch.schlift.dev`).
6. **Phone:** allow installing unknown apps for your browser, then open
   `https://dev.schlift.com/schlift-dev.apk`. (The APK lives in the shared web
   root, so until the DNS record exists it's also reachable at
   `https://schlift.com/schlift-dev.apk` — but the app inside points at
   `dev.schlift.com`, so it won't connect until that name resolves.)

## Routine

Dev releases are tag-driven, same as prod's `v*` — just a `dev-*` prefix so the
two can never collide.

- **Cut a dev release (backend + app from one commit):**
  ```
  T=dev-$(date +%Y%m%d-%H%M); git tag "$T" && git push origin "$T"
  ```
  A `dev-*` tag fires **both** `Dev Backend Deploy` (redeploys `:50052` from that
  commit) and `Android Dev Release` (builds the `.dev` APK and hosts it), so the
  app and the backend it talks to stay in lockstep. Re-open the APK URL on your
  phone to update. Prod is untouched.
- **No-tag fallbacks** (`workflow_dispatch`):
  - `gh workflow run dev-backend-deploy.yml --ref <branch>` — redeploy an
    arbitrary WIP branch to the dev backend.
  - `gh workflow run android-dev-release.yml` — rebuild + host the dev APK.
- **Which backend am I on?** The in-app build-info screen shows `SERVER_HOST` and
  `GIT_HASH`; the launcher icon says "Schlift Dev".

## Notes / gotchas

- **Side-by-side:** dev and prod are different packages, so they coexist with
  independent data, passkeys, and notifications. Uninstalling one leaves the
  other alone.
- **Passkeys are per-domain.** Register a fresh passkey the first time on
  `dev.schlift.com`; the dev DB is empty so it's a clean account anyway.
- **`test-auth` is NOT enabled on dev** — real passkeys, same as prod. (Dev Login
  stays a debug-build-only convenience.)
- **Join deep-links** still point at `schlift.com`, so tapping a join link opens
  the prod app, not dev. Fine for solo dev testing; revisit if link-join needs
  testing on dev.
- **versionCode** is `500000 + run_number`, so a newer dev APK always upgrades an
  older one in place.
- **Rollback:** `deploy_schlift_dev.sh` keeps the previous release symlinked and
  auto-rolls-back if the new binary fails its healthcheck.

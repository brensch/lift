# Dev channel: dev.schlift.com + Play internal nightly

Run WIP on a real phone over the air, against an isolated dev backend, without
plugging into a computer.

## What it is

| | Production | Dev |
|---|---|---|
| Host | `schlift.com` | `dev.schlift.com` |
| Backend instance | `/opt/schlift`, `schlift.service`, port `50051` | `/opt/schlift-dev`, `schlift-dev.service`, port `50052` |
| Database | `/opt/schlift/shared/data` | `/opt/schlift-dev/shared/data` (separate, starts empty) |
| WebAuthn RP | `schlift.com` | `dev.schlift.com` (separate passkeys) |
| App build | prod release (tag `v*`) → internal/alpha/beta | `Android Dev Nightly` → **internal** only |
| Backend code | `main` (`Backend Deploy`) | any branch (`Dev Backend Deploy`) |

Both instances live on the same box, fronted by the same Caddy. The dev vhost
just reverse-proxies to `:50052`. TLS is automatic because `*.schlift.com`
resolves to the box.

The dev app build is the **same package** (`com.brensch.schlift`) signed with the
**same key** — that's why passkeys work on the dev domain with no new Play app.
The trade-off: any device on the Play **internal** track receives the dev build
and points at `dev.schlift.com`. Keep your everyday phone on the production/beta
track if you want the real backend; use internal for dogfooding.

## One-time bootstrap

1. **Land the workflows on `main`.** `workflow_dispatch` only appears once the
   workflow file is on the default branch. Merge this branch.
2. **DNS.** `dev.schlift.com` must resolve to the box. A `*.schlift.com` A-record
   already covers it.
3. **Runner sudo.** On the deploy box, reinstall the runner sudoers from
   `deploy/schlift-runner.sudoers.example` (it now whitelists
   `/opt/repo-schlift-dev-current/scripts/deploy_schlift_dev.sh`).
4. **Stand up the dev backend:** run the **Dev Backend Deploy** workflow once
   (`gh workflow run dev-backend-deploy.yml --ref <branch>`). It builds that
   branch's binary, installs `schlift-dev.service` on `:50052`, seeds
   `/opt/schlift-dev/shared/schlift.env` from `deploy/schlift-dev.env.example`,
   and adds the `dev.schlift.com` Caddy vhost with a graceful reload.
5. **Verify:** `curl https://dev.schlift.com/.well-known/assetlinks.json` should
   return the app fingerprint.
6. **Play testers.** Make sure your account is on the app's **internal testing**
   track in the Play Console (one-time opt-in link).

## Routine

- **Ship a dev app to your phone:** run **Android Dev Nightly**
  (`gh workflow run android-dev-nightly.yml`). It builds a signed AAB compiled
  with `--dart-define=SERVER_HOST=dev.schlift.com` and publishes to the internal
  track. Installs/updates on enrolled devices within minutes.
- **Update the dev backend** (new server code): run **Dev Backend Deploy** on the
  branch you want (`--ref <branch>`). Prod is untouched.
- **Which backend am I on?** The in-app build-info screen shows `SERVER_HOST` and
  `GIT_HASH`.

## Notes / gotchas

- **versionCode:** dev uses `500000 + run_number`, clear of prod (`1000+`) and
  wear (`~1,001,000+`), so Play never rejects a duplicate. Because it's the
  highest code, the internal track always serves the latest dev nightly.
- **Passkeys are per-domain.** Your `schlift.com` passkey won't log you into
  `dev.schlift.com`; register a fresh one the first time. The dev DB is empty, so
  it's a clean account anyway.
- **`test-auth` is NOT enabled on dev** — it authenticates with real passkeys,
  same as prod. (Dev Login remains a debug-build-only convenience.)
- **Rollback:** `deploy_schlift_dev.sh` keeps the previous release symlinked and
  auto-rolls-back if the new binary fails its healthcheck.

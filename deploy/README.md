# Bare-Metal Backend Deploy

This deploy flow builds the backend on a GitHub-hosted ARM64 runner, uploads the `schlift` binary as an artifact, and deploys it from a self-hosted runner on the server.

The dev instance (`dev.schlift.com`) on the same box is described in [`docs/dev-channel.md`](../docs/dev-channel.md).

## Server layout

```text
/opt/schlift/
  current -> /opt/schlift/releases/<git-sha>
  releases/
  shared/
    data/
    schlift.env

/opt/repo-schlift-current/
  deploy/
  scripts/
  ...
```

The backend runs with `WorkingDirectory=/opt/schlift/shared`, so SQLite lives at `/opt/schlift/shared/data/server.sqlite` (plus the WAL sidecars `server.sqlite-wal` and `server.sqlite-shm` — back up all three, or checkpoint first).

## One-time server setup

1. Install the self-hosted runner on the server.
2. Allow the runner user to run the deploy scripts and `systemctl` without a password.
3. Install the service:

```bash
sudo mkdir -p /opt/schlift
sudo chown -R opc:opc /opt/schlift
sudo mkdir -p /opt/repo-schlift-current
sudo INSTALL_ROOT=/opt/schlift LIFT_USER=opc LIFT_GROUP=opc ./scripts/install_schlift_service.sh
sudo ./deploy/setup-prod-env.sh
```

4. Trigger the `Backend Deploy` workflow once.

Suggested runtime values:

```bash
RUST_LOG=warn
WEBAUTHN_RP_ID=schlift.com
WEBAUTHN_RP_ORIGIN=https://schlift.com
APPLE_TEAM_ID=REPLACE_WITH_YOUR_APPLE_TEAM_ID
```

Use `schlift.com` as the shared RP ID and origin to keep Android app association, passkeys, and the hosted web app on the same domain.

For iOS passkeys, the backend serves `/.well-known/apple-app-site-association` and `/apple-app-site-association`.
Set `APPLE_TEAM_ID` for the default `TEAMID.com.brensch.schlift` app identifier, or set `APPLE_APP_IDS` to a comma-separated list if you need multiple Apple app identifiers.

## TLS / Reverse Proxy

This deploy flow installs Caddy from the production setup script and copies the checked-in `Caddyfile` to `/etc/caddy/Caddyfile`. On every deploy, the self-hosted runner syncs the current repo checkout to `/opt/repo-schlift-current` and reapplies the checked-in Caddy config from there.

Open OCI ingress for:

```text
tcp/80
tcp/443
```

Do not expose `50051` publicly. Let Caddy proxy `schlift.com` to `127.0.0.1:50051`.

## Required sudoers entry

The self-hosted runner user must be able to run the deploy scripts non-interactively. A narrow sudoers entry is better than blanket `NOPASSWD`.

The entry for `opc` (including the dev deploy script) is in `deploy/schlift-runner.sudoers.example`; copy it into `/etc/sudoers.d/`.

## Downtime model

This flow restarts a single `systemd` service in place and rolls back to the previous release if the new binary fails to start or fails the local health check. The deploy script polls `http://127.0.0.1:50051/api/health` (override with `HEALTHCHECK_URL`) for up to 60 seconds, since the server runs migrations before it listens. It is intentionally simple and SQLite-friendly. It does not provide true zero downtime.

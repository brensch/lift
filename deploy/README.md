# Bare-Metal Backend Deploy

This deploy flow builds the backend on a GitHub-hosted ARM64 runner and uploads the `schlift` binary as an artifact. The server pulls it: a small agent on the box ([`puller/`](puller/)) checks for a new GitHub Deployment every 20 seconds, downloads the build with a read-only token, deploys it, and reports the result back to the deployment. There is no runner on the server, so nothing on GitHub can run a command there.

The dev instance (`dev.schlift.com`) on the same box is described in [`docs/dev-channel.md`](../docs/dev-channel.md).

## Server layout

```text
/opt/schlift/
  current -> /opt/schlift/releases/<git-sha>
  releases/
  shared/
    data/
    schlift.env

/opt/schlift-puller/            # the deploy agent and the scripts it runs, pinned
  schlift-puller.sh             # (installed by deploy/puller/install.sh, never fetched from GitHub)
  scripts/
  deploy/
/etc/schlift-puller/token       # fine-grained token, root-only (see below)
```

The backend runs with `WorkingDirectory=/opt/schlift/shared`, so SQLite lives at `/opt/schlift/shared/data/server.sqlite` (plus the WAL sidecars `server.sqlite-wal` and `server.sqlite-shm` — back up all three, or checkpoint first).

## One-time server setup

1. Install the service:

```bash
sudo mkdir -p /opt/schlift
sudo chown -R opc:opc /opt/schlift
sudo INSTALL_ROOT=/opt/schlift LIFT_USER=opc LIFT_GROUP=opc ./scripts/install_schlift_service.sh
sudo ./deploy/setup-prod-env.sh
```

2. Make the deploy token: GitHub → Settings → Developer settings → Fine-grained tokens →
   new token, **only** the `brensch/lift` repository, permissions **Actions: Read**,
   **Deployments: Read and write** (Metadata: Read is added automatically). Nothing else.
3. Install the deploy agent from your machine (it asks for the token):

```bash
deploy/puller/install.sh opc@<box> --token
```

4. Trigger the `Backend Deploy` workflow once.

To change the agent or the scripts it runs, edit them here and re-run
`deploy/puller/install.sh opc@<box>` (keeps the token). Fine-grained tokens expire;
the agent warns in its journal (`journalctl -u schlift-puller`) two weeks ahead, then
re-run with `--token`.

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

The production setup script installs Caddy and the checked-in `Caddyfile`. The build artifact carries the `Caddyfile` too: when it differs from `/etc/caddy/Caddyfile`, the agent validates it and reloads Caddy gracefully (open connections are not dropped); when it is unchanged, Caddy is not touched.

Open OCI ingress for:

```text
tcp/80
tcp/443
```

Do not expose `50051` publicly. Let Caddy proxy `schlift.com` to `127.0.0.1:50051`.

## Downtime model

Users should not see a deploy:

1. **Pre-flight.** Before the live service is touched, the agent starts the new build on a spare port (50061 prod, 50062 dev) against a consistent copy of the live database: its migrations must apply and `/api/health` must answer. A build that fails never reaches users.
2. **Restart under a held line.** The live unit then restarts in place (one process: SQLite and the in-memory state allow only one). While it is down, Caddy holds incoming requests and retries the upstream for up to 30 s (`lb_try_duration` in the shared `backend` snippet of the `Caddyfile`), so requests see a short pause instead of a 502.
3. **Streams reconnect.** Open Sync streams are cut by the restart; the app redials with backoff and resends anything pending, so nothing is lost.
4. **Rollback.** If the new release fails to start or its health check, the deploy script puts the previous release back.

Two processes side by side (blue/green) are deliberately not used: both would write the one SQLite file, and the new one's migrations could break the old one.

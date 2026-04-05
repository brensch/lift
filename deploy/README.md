# Bare-Metal Backend Deploy

This deploy flow builds the backend on a GitHub-hosted ARM64 runner, uploads the `schlift` binary as an artifact, and deploys it from a self-hosted runner on the server.

## Server layout

```text
/opt/schlift/
  current -> /opt/schlift/releases/<git-sha>
  releases/
  shared/
    data/
    schlift.env
```

The backend runs with `WorkingDirectory=/opt/schlift/shared`, so SQLite lives at `/opt/schlift/shared/data/central.sqlite`.

## One-time server setup

1. Install the self-hosted runner on the server.
2. Allow the runner user to run the deploy scripts and `systemctl` without a password.
3. Install the service:

```bash
sudo mkdir -p /opt/schlift
sudo chown -R opc:opc /opt/schlift
sudo INSTALL_ROOT=/opt/schlift LIFT_USER=opc LIFT_GROUP=opc ./scripts/install_schlift_service.sh
sudoedit /opt/schlift/shared/schlift.env
```

4. Trigger the `Backend Deploy` workflow once.

## Required sudoers entry

The self-hosted runner user must be able to run the deploy scripts non-interactively. A narrow sudoers entry is better than blanket `NOPASSWD`.

Example for `opc`:

```text
opc ALL=(root) NOPASSWD:SETENV: /opt/actions-runner/_work/schlift/schlift/scripts/install_schlift_service.sh, /opt/actions-runner/_work/schlift/schlift/scripts/deploy_schlift_release.sh, /usr/bin/systemctl, /usr/bin/journalctl
```

Adjust the workspace path to match your runner's checkout directory. If you prefer less path churn, keep the repo checked out in a fixed deploy workspace and call the scripts from there.

A copyable example file lives at `deploy/schlift-runner.sudoers.example`.

## Downtime model

This flow restarts a single `systemd` service in place and rolls back to the previous release if the new binary fails to start or fails the local health check. It is intentionally simple and SQLite-friendly. It does not provide true zero downtime.

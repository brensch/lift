# Bare-Metal Backend Deploy

This deploy flow builds the backend on a GitHub-hosted ARM64 runner, uploads the `lift` binary as an artifact, and deploys it from a self-hosted runner on the server.

## Server layout

```text
/opt/lift/
  current -> /opt/lift/releases/<git-sha>
  releases/
  shared/
    data/
    lift.env
```

The backend runs with `WorkingDirectory=/opt/lift/shared`, so SQLite lives at `/opt/lift/shared/data/central.sqlite`.

## One-time server setup

1. Install the self-hosted runner on the server.
2. Allow the runner user to run the deploy scripts and `systemctl` without a password.
3. Install the service:

```bash
sudo mkdir -p /opt/lift
sudo chown -R opc:opc /opt/lift
sudo INSTALL_ROOT=/opt/lift LIFT_USER=opc LIFT_GROUP=opc ./scripts/install_lift_service.sh
sudoedit /opt/lift/shared/lift.env
```

4. Trigger the `Backend Deploy` workflow once.

## Required sudoers entry

The self-hosted runner user must be able to run the deploy scripts non-interactively. A narrow sudoers entry is better than blanket `NOPASSWD`.

Example for `opc`:

```text
opc ALL=(root) NOPASSWD:SETENV: /opt/actions-runner/_work/lift/lift/scripts/install_lift_service.sh, /opt/actions-runner/_work/lift/lift/scripts/deploy_lift_release.sh, /usr/bin/systemctl, /usr/bin/journalctl
```

Adjust the workspace path to match your runner's checkout directory. If you prefer less path churn, keep the repo checked out in a fixed deploy workspace and call the scripts from there.

A copyable example file lives at `deploy/lift-runner.sudoers.example`.

## Downtime model

This flow restarts a single `systemd` service in place and rolls back to the previous release if the new binary fails to start or fails the local health check. It is intentionally simple and SQLite-friendly. It does not provide true zero downtime.

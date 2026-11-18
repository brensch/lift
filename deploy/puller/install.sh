#!/usr/bin/env bash
# Install (or update) the pull deployer on the schlift box, from a checkout on your machine.
#   deploy/puller/install.sh opc@<box>             # update scripts, keep the token
#   deploy/puller/install.sh opc@<box> --token     # also (re)set the token (read from stdin)
# What it installs is pinned on the box: later deploys never fetch scripts from the repo.
set -euo pipefail
HOST="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
mkdir -p "${STAGE}/scripts" "${STAGE}/deploy"
cp "${REPO_ROOT}/deploy/puller/schlift-puller.sh" "${REPO_ROOT}/deploy/puller/schlift-puller.service" \
	"${REPO_ROOT}/deploy/puller/schlift-puller.timer" "${STAGE}/"
cp "${REPO_ROOT}/scripts/deploy_schlift_release.sh" "${REPO_ROOT}/scripts/deploy_schlift_dev.sh" "${STAGE}/scripts/"
cp "${REPO_ROOT}/deploy/schlift.service" "${REPO_ROOT}/deploy/schlift-dev.env.example" "${STAGE}/deploy/"
rsync -a --delete "${STAGE}/" "${HOST}:/tmp/schlift-puller-stage/"
if [[ "${2:-}" == "--token" ]]; then
	echo "paste the fine-grained token, then press enter:" >&2
	read -rs token
	printf '%s' "${token}" | ssh "${HOST}" 'sudo install -d -m 0700 /etc/schlift-puller && sudo tee /etc/schlift-puller/token >/dev/null && sudo chmod 600 /etc/schlift-puller/token'
fi
ssh "${HOST}" 'set -e
S=/tmp/schlift-puller-stage
sudo install -d -m 0755 /opt/schlift-puller /opt/schlift-puller/scripts /opt/schlift-puller/deploy
sudo install -m 0755 $S/schlift-puller.sh /opt/schlift-puller/
sudo install -m 0755 $S/scripts/* /opt/schlift-puller/scripts/
sudo install -m 0644 $S/deploy/* /opt/schlift-puller/deploy/
sudo install -m 0644 $S/schlift-puller.service $S/schlift-puller.timer /etc/systemd/system/
rm -rf $S
sudo test -s /etc/schlift-puller/token || { echo "no token yet: re-run with --token"; exit 1; }
sudo systemctl daemon-reload
sudo systemctl enable --now schlift-puller.timer
systemctl list-timers schlift-puller.timer --no-pager | head -3'

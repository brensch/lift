#!/usr/bin/env bash
# Box hardening, captured as code: fail2ban (shed SSH scanning).
#
# Idempotent — safe to re-run. Run as root on the server:
#   sudo scripts/harden_box.sh
#
# The service users and the dev/prod isolation are handled by the deploy
# scripts (install_schlift_service.sh, deploy_schlift_dev.sh); the systemd
# sandbox in deploy/schlift.service does the per-process confinement.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "run as root" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export DEBIAN_FRONTEND=noninteractive

# --- fail2ban -----------------------------------------------------------------
apt-get install -y -qq fail2ban
install -m 0644 -o root -g root "${REPO_ROOT}/deploy/fail2ban/jail.local" /etc/fail2ban/jail.local
systemctl enable --now fail2ban
systemctl restart fail2ban
echo "fail2ban: $(systemctl is-active fail2ban)"

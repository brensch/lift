#!/usr/bin/env bash
# Box hardening, captured as code: fail2ban (shed SSH scanning) and AppArmor
# profiles for the internet-facing processes (the Rust backend and Caddy).
#
# Idempotent — safe to re-run. Run as root on the server:
#   sudo scripts/harden_box.sh
#
# The service users and the dev/prod isolation are handled by the deploy
# scripts (install_schlift_service.sh, deploy_schlift_dev.sh); this covers the
# box-level layers that sit alongside the systemd sandbox in deploy/schlift.service.
#
# AppArmor note: the profiles load in COMPLAIN mode (they log violations but
# block nothing). After a few days of real traffic with a clean log
# (`journalctl -g 'apparmor.*DENIED'`), move them to enforce:
#   sudo aa-enforce /etc/apparmor.d/schlift /etc/apparmor.d/caddy
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

# --- AppArmor -----------------------------------------------------------------
apt-get install -y -qq apparmor apparmor-utils
for profile in schlift caddy; do
	install -m 0644 -o root -g root "${REPO_ROOT}/deploy/apparmor/${profile}" "/etc/apparmor.d/${profile}"
	apparmor_parser -r -W "/etc/apparmor.d/${profile}"
	# Start in complain mode; see the note at the top before enforcing.
	aa-complain "/etc/apparmor.d/${profile}"
done
echo "apparmor profiles loaded in complain mode (schlift, caddy)"
echo "restart the backends and caddy for the profiles to attach (a deploy does this)"

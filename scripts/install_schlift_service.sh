#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "run as root" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

INSTALL_ROOT="${INSTALL_ROOT:-/opt/schlift}"
LIFT_USER="${LIFT_USER:-opc}"
LIFT_GROUP="${LIFT_GROUP:-${LIFT_USER}}"
# The dev backend's own user, so the cert sync hands dev's certificates to it,
# not to prod's user.
DEV_LIFT_USER="${DEV_LIFT_USER:-schlift-dev}"
getent passwd "${LIFT_USER}" >/dev/null 2>&1 ||
	useradd --system --no-create-home --shell /usr/sbin/nologin "${LIFT_USER}"
getent passwd "${DEV_LIFT_USER}" >/dev/null 2>&1 ||
	useradd --system --no-create-home --shell /usr/sbin/nologin "${DEV_LIFT_USER}"
UNIT_PATH="/etc/systemd/system/schlift.service"
TMP_UNIT="$(mktemp)"
mkdir -p "${INSTALL_ROOT}/releases" "${INSTALL_ROOT}/shared/data"
# Prod's shared dir holds its data and secrets: only its own user may enter it.
chown -R "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}"
chmod 750 "${INSTALL_ROOT}/shared"

sed \
	-e "s#__INSTALL_ROOT__#${INSTALL_ROOT}#g" \
	-e "s#__LIFT_USER__#${LIFT_USER}#g" \
	-e "s#__LIFT_GROUP__#${LIFT_GROUP}#g" \
	"${REPO_ROOT}/deploy/schlift.service" >"${TMP_UNIT}"

install -m 0644 "${TMP_UNIT}" "${UNIT_PATH}"
rm -f "${TMP_UNIT}"

if [[ ! -f "${INSTALL_ROOT}/shared/schlift.env" ]]; then
	install -m 0640 "${REPO_ROOT}/deploy/schlift.env.example" "${INSTALL_ROOT}/shared/schlift.env"
	chown "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}/shared/schlift.env"
	echo "created ${INSTALL_ROOT}/shared/schlift.env from example; edit it before first start"
fi

# The copy of Caddy's certificates for the apps' own TLS listeners
# (deploy/schlift-tls-sync.*): run on every renewal, and at boot. It runs as
# root, so it lives where only root can change it: never in shared/, which
# the service user owns.
DEV_INSTALL_ROOT="${DEV_INSTALL_ROOT:-/opt/schlift-dev}"
install -d -m 0755 -o root -g root /usr/local/lib/schlift
install -m 0755 -o root -g root "${REPO_ROOT}/deploy/schlift-tls-sync.sh" /usr/local/lib/schlift/schlift-tls-sync.sh
rm -f "${INSTALL_ROOT}/shared/schlift-tls-sync.sh"
sed \
	-e "s#__INSTALL_ROOT__#${INSTALL_ROOT}#g" \
	-e "s#__DEV_INSTALL_ROOT__#${DEV_INSTALL_ROOT}#g" \
	-e "s#__DEV_LIFT_USER__#${DEV_LIFT_USER}#g" \
	-e "s#__LIFT_USER__#${LIFT_USER}#g" \
	"${REPO_ROOT}/deploy/schlift-tls-sync.service" >/etc/systemd/system/schlift-tls-sync.service
install -m 0644 "${REPO_ROOT}/deploy/schlift-tls-sync.path" /etc/systemd/system/schlift-tls-sync.path

systemctl daemon-reload
systemctl enable schlift.service schlift-tls-sync.service schlift-tls-sync.path
systemctl start schlift-tls-sync.service schlift-tls-sync.path

echo "installed ${UNIT_PATH}"
echo "shared state lives under ${INSTALL_ROOT}/shared"

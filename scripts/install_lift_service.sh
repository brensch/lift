#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

INSTALL_ROOT="${INSTALL_ROOT:-/opt/lift}"
LIFT_USER="${LIFT_USER:-opc}"
LIFT_GROUP="${LIFT_GROUP:-${LIFT_USER}}"
UNIT_PATH="/etc/systemd/system/lift.service"
TMP_UNIT="$(mktemp)"

mkdir -p "${INSTALL_ROOT}/releases" "${INSTALL_ROOT}/shared/data"
chown -R "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}"

sed \
  -e "s#__INSTALL_ROOT__#${INSTALL_ROOT}#g" \
  -e "s#__LIFT_USER__#${LIFT_USER}#g" \
  -e "s#__LIFT_GROUP__#${LIFT_GROUP}#g" \
  "${REPO_ROOT}/deploy/lift.service" > "${TMP_UNIT}"

install -m 0644 "${TMP_UNIT}" "${UNIT_PATH}"
rm -f "${TMP_UNIT}"

if [[ ! -f "${INSTALL_ROOT}/shared/lift.env" ]]; then
  install -m 0640 "${REPO_ROOT}/deploy/lift.env.example" "${INSTALL_ROOT}/shared/lift.env"
  chown "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}/shared/lift.env"
  echo "created ${INSTALL_ROOT}/shared/lift.env from example; edit it before first start"
fi

systemctl daemon-reload
systemctl enable lift.service

echo "installed ${UNIT_PATH}"
echo "shared state lives under ${INSTALL_ROOT}/shared"

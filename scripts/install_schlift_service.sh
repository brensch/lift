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
UNIT_PATH="/etc/systemd/system/schlift.service"
TMP_UNIT="$(mktemp)"
BIN_DIR="${INSTALL_ROOT}/bin"
SHARE_DIR="${INSTALL_ROOT}/share/deploy"

if [[ -f "${REPO_ROOT}/scripts/install_schlift_service.sh" && -f "${REPO_ROOT}/deploy/Caddyfile" ]]; then
  SOURCE_SCRIPT_DIR="${REPO_ROOT}/scripts"
  SOURCE_DEPLOY_DIR="${REPO_ROOT}/deploy"
else
  SOURCE_SCRIPT_DIR="${BIN_DIR}"
  SOURCE_DEPLOY_DIR="${SHARE_DIR}"
fi

mkdir -p "${INSTALL_ROOT}/releases" "${INSTALL_ROOT}/shared/data" "${BIN_DIR}" "${SHARE_DIR}"
chown -R "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}"

install -m 0755 "${SOURCE_SCRIPT_DIR}/install_schlift_service.sh" "${BIN_DIR}/install_schlift_service.sh"
install -m 0755 "${SOURCE_SCRIPT_DIR}/deploy_schlift_release.sh" "${BIN_DIR}/deploy_schlift_release.sh"
install -m 0755 "${SOURCE_DEPLOY_DIR}/setup-prod-env.sh" "${BIN_DIR}/setup-prod-env.sh"
install -m 0644 "${SOURCE_DEPLOY_DIR}/schlift.service" "${SHARE_DIR}/schlift.service"
install -m 0644 "${SOURCE_DEPLOY_DIR}/schlift.env.example" "${SHARE_DIR}/schlift.env.example"
install -m 0644 "${SOURCE_DEPLOY_DIR}/Caddyfile" "${SHARE_DIR}/Caddyfile"
install -m 0644 "${SOURCE_DEPLOY_DIR}/schlift-runner.sudoers.example" "${SHARE_DIR}/schlift-runner.sudoers.example"

sed \
  -e "s#__INSTALL_ROOT__#${INSTALL_ROOT}#g" \
  -e "s#__LIFT_USER__#${LIFT_USER}#g" \
  -e "s#__LIFT_GROUP__#${LIFT_GROUP}#g" \
  "${SHARE_DIR}/schlift.service" > "${TMP_UNIT}"

install -m 0644 "${TMP_UNIT}" "${UNIT_PATH}"
rm -f "${TMP_UNIT}"

if [[ ! -f "${INSTALL_ROOT}/shared/schlift.env" ]]; then
  install -m 0640 "${SHARE_DIR}/schlift.env.example" "${INSTALL_ROOT}/shared/schlift.env"
  chown "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}/shared/schlift.env"
  echo "created ${INSTALL_ROOT}/shared/schlift.env from example; edit it before first start"
fi

systemctl daemon-reload
systemctl enable schlift.service

echo "installed ${UNIT_PATH}"
echo "installed admin scripts under ${BIN_DIR}"
echo "shared state lives under ${INSTALL_ROOT}/shared"

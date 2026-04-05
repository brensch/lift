#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

ARTIFACT_DIR="${ARTIFACT_DIR:-}"
RELEASE_ID="${RELEASE_ID:-}"
INSTALL_ROOT="${INSTALL_ROOT:-/opt/schlift}"
LIFT_USER="${LIFT_USER:-opc}"
LIFT_GROUP="${LIFT_GROUP:-${LIFT_USER}}"
SERVICE_NAME="${SERVICE_NAME:-schlift.service}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-http://127.0.0.1:50051/}"

if [[ -z "${ARTIFACT_DIR}" || -z "${RELEASE_ID}" ]]; then
  echo "ARTIFACT_DIR and RELEASE_ID are required" >&2
  exit 1
fi

BINARY_SRC="${ARTIFACT_DIR}/schlift"
if [[ ! -f "${BINARY_SRC}" ]]; then
  echo "binary not found at ${BINARY_SRC}" >&2
  exit 1
fi

RELEASE_DIR="${INSTALL_ROOT}/releases/${RELEASE_ID}"
PREVIOUS_TARGET=""
if [[ -L "${INSTALL_ROOT}/current" ]]; then
  PREVIOUS_TARGET="$(readlink -f "${INSTALL_ROOT}/current")"
fi

mkdir -p "${RELEASE_DIR}" "${INSTALL_ROOT}/shared/data"
install -m 0755 "${BINARY_SRC}" "${RELEASE_DIR}/schlift"
chown -R "${LIFT_USER}:${LIFT_GROUP}" "${RELEASE_DIR}" "${INSTALL_ROOT}/shared"

ln -sfn "${RELEASE_DIR}" "${INSTALL_ROOT}/current"

rollback() {
  if [[ -n "${PREVIOUS_TARGET}" && -d "${PREVIOUS_TARGET}" ]]; then
    ln -sfn "${PREVIOUS_TARGET}" "${INSTALL_ROOT}/current"
    systemctl restart "${SERVICE_NAME}" || true
  fi
}

if ! systemctl restart "${SERVICE_NAME}"; then
  echo "restart failed; rolling back" >&2
  rollback
  exit 1
fi

sleep 2
if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo "service failed to become active; rolling back" >&2
  rollback
  exit 1
fi

if ! curl --fail --silent --show-error "${HEALTHCHECK_URL}" >/dev/null; then
  echo "health check failed; rolling back" >&2
  rollback
  exit 1
fi

echo "deployed ${RELEASE_ID}"

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
HEALTHCHECK_URL="${HEALTHCHECK_URL:-http://127.0.0.1:50051/api/health}"
HEALTHCHECK_HOST="${HEALTHCHECK_HOST:-127.0.0.1}"
HEALTHCHECK_PORT="${HEALTHCHECK_PORT:-50051}"
HEALTHCHECK_MODE="${HEALTHCHECK_MODE:-tcp}"

if [[ -z "${ARTIFACT_DIR}" || -z "${RELEASE_ID}" ]]; then
  echo "ARTIFACT_DIR and RELEASE_ID are required" >&2
  exit 1
fi

BINARY_SRC="${ARTIFACT_DIR}/schlift"
WEB_SRC="${WEB_DIR:-}"

if [[ ! -f "${BINARY_SRC}" ]]; then
  echo "binary not found at ${BINARY_SRC}" >&2
  exit 1
fi

RELEASE_DIR="${INSTALL_ROOT}/releases/${RELEASE_ID}"
PREVIOUS_TARGET=""
if [[ -L "${INSTALL_ROOT}/current" ]]; then
  PREVIOUS_TARGET="$(readlink -f "${INSTALL_ROOT}/current")"
fi

mkdir -p "${RELEASE_DIR}" "${INSTALL_ROOT}/shared/data" "${INSTALL_ROOT}/web"
install -m 0755 "${BINARY_SRC}" "${RELEASE_DIR}/schlift"

# Deploy web frontend if provided
if [[ -n "${WEB_SRC}" && -d "${WEB_SRC}" ]]; then
  rsync -a --delete "${WEB_SRC}/" "${INSTALL_ROOT}/web/"
  echo "deployed web frontend to ${INSTALL_ROOT}/web"
fi

chown -R "${LIFT_USER}:${LIFT_GROUP}" "${RELEASE_DIR}" "${INSTALL_ROOT}/shared" "${INSTALL_ROOT}/web"

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

healthcheck_ok=0
case "${HEALTHCHECK_MODE}" in
  tcp)
    if bash -c "exec 3<>/dev/tcp/${HEALTHCHECK_HOST}/${HEALTHCHECK_PORT}" >/dev/null 2>&1; then
      healthcheck_ok=1
    fi
    ;;
  http)
    if curl --fail --silent --show-error "${HEALTHCHECK_URL}" >/dev/null; then
      healthcheck_ok=1
    fi
    ;;
  *)
    echo "unsupported HEALTHCHECK_MODE: ${HEALTHCHECK_MODE}" >&2
    rollback
    exit 1
    ;;
esac

if [[ "${healthcheck_ok}" -ne 1 ]]; then
  echo "health check failed; rolling back" >&2
  rollback
  exit 1
fi

echo "deployed ${RELEASE_ID}"

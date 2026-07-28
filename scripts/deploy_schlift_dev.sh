#!/usr/bin/env bash
# Deploy the dev backend instance (dev.schlift.com) onto the same box as prod.
# Fully isolated from prod: its own install root, systemd unit, DB and port.
# Adds/refreshes the dev.schlift.com Caddy vhost via a graceful reload so prod
# is never interrupted.
#
# Required env:  ARTIFACT_DIR (dir containing the `schlift` binary), RELEASE_ID
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

INSTALL_ROOT="${INSTALL_ROOT:-/opt/schlift-dev}"
LIFT_USER="${LIFT_USER:-opc}"
LIFT_GROUP="${LIFT_GROUP:-${LIFT_USER}}"
SERVICE_NAME="schlift-dev.service"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}"
HEALTHCHECK_PORT="${HEALTHCHECK_PORT:-50052}"
ARTIFACT_DIR="${ARTIFACT_DIR:-}"
RELEASE_ID="${RELEASE_ID:-}"

if [[ -z "${ARTIFACT_DIR}" || -z "${RELEASE_ID}" ]]; then
  echo "ARTIFACT_DIR and RELEASE_ID are required" >&2
  exit 1
fi
BINARY_SRC="${ARTIFACT_DIR}/schlift"
if [[ ! -f "${BINARY_SRC}" ]]; then
  echo "binary not found at ${BINARY_SRC}" >&2
  exit 1
fi

# --- systemd unit (templated from the shared prod unit) -----------------------
mkdir -p "${INSTALL_ROOT}/releases" "${INSTALL_ROOT}/shared/data"
chown -R "${LIFT_USER}:${LIFT_GROUP}" "${INSTALL_ROOT}"

TMP_UNIT="$(mktemp)"
sed \
  -e "s#__INSTALL_ROOT__#${INSTALL_ROOT}#g" \
  -e "s#__LIFT_USER__#${LIFT_USER}#g" \
  -e "s#__LIFT_GROUP__#${LIFT_GROUP}#g" \
  -e "s#Description=Schlift backend#Description=Schlift backend (dev)#" \
  "${REPO_ROOT}/deploy/schlift.service" > "${TMP_UNIT}"
install -m 0644 "${TMP_UNIT}" "${UNIT_PATH}"
rm -f "${TMP_UNIT}"

# --- env file (seed once; never clobber a hand-edited one) --------------------
ENV_PATH="${INSTALL_ROOT}/shared/schlift.env"
if [[ ! -f "${ENV_PATH}" ]]; then
  install -m 0640 "${REPO_ROOT}/deploy/schlift-dev.env.example" "${ENV_PATH}"
  chown "${LIFT_USER}:${LIFT_GROUP}" "${ENV_PATH}"
  echo "seeded ${ENV_PATH} from example"
fi

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

# --- release swap (symlink flip + healthcheck + rollback) ---------------------
RELEASE_DIR="${INSTALL_ROOT}/releases/${RELEASE_ID}"
PREVIOUS_TARGET=""
if [[ -L "${INSTALL_ROOT}/current" ]]; then
  PREVIOUS_TARGET="$(readlink -f "${INSTALL_ROOT}/current")"
fi
mkdir -p "${RELEASE_DIR}"
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
if ! bash -c "exec 3<>/dev/tcp/127.0.0.1/${HEALTHCHECK_PORT}" >/dev/null 2>&1; then
  echo "health check on 127.0.0.1:${HEALTHCHECK_PORT} failed; rolling back" >&2
  rollback
  exit 1
fi

# --- Caddy: install the dual-host Caddyfile and reload gracefully -------------
# The prod block is byte-identical to what's already live, so this only adds the
# dev.schlift.com vhost. `reload` keeps prod connections up (no restart blip).
if command -v caddy >/dev/null 2>&1; then
  install -m 0644 "${REPO_ROOT}/deploy/Caddyfile" /etc/caddy/Caddyfile
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
  systemctl reload caddy
  echo "reloaded caddy with dev.schlift.com vhost"
else
  echo "WARNING: caddy not found; dev.schlift.com will not be reachable" >&2
fi

echo "deployed dev backend ${RELEASE_ID} on :${HEALTHCHECK_PORT}"

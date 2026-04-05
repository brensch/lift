#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

INSTALL_ROOT="${INSTALL_ROOT:-/opt/schlift}"
APP_USER="${APP_USER:-opc}"
APP_GROUP="${APP_GROUP:-${APP_USER}}"
ENV_PATH="${INSTALL_ROOT}/shared/schlift.env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDYFILE_SRC="${CADDYFILE_SRC:-${SCRIPT_DIR}/Caddyfile}"
WRITE_ENV="${WRITE_ENV:-1}"

mkdir -p "${INSTALL_ROOT}/shared"

if [[ "${WRITE_ENV}" == "1" ]]; then
cat > "${ENV_PATH}" <<'EOF'
RUST_LOG=info
WEBAUTHN_RP_ID=schlift.com
WEBAUTHN_RP_ORIGIN=https://schlift.com
WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:oX5Jnmwq_UQ8_8dpupoKwQlGNOmMSUbcVSLLHh-lwsg,android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:kEDowpBvMt8rjVsbNoz919m3GjRFguoj8v4WJu0FYwA
ANDROID_CERT_SHA256=A1:7E:49:9E:6C:2A:FD:44:3C:FF:C7:69:BA:9A:0A:C1:09:46:34:E9:8C:49:46:DC:55:22:CB:1E:1F:A5:C2:C8
EOF

chown "${APP_USER}:${APP_GROUP}" "${ENV_PATH}"
chmod 640 "${ENV_PATH}"
fi

if ! command -v caddy >/dev/null 2>&1; then
  dnf install -y 'dnf-command(copr)'
  dnf copr enable @caddy/caddy -y
  dnf install -y caddy
fi

install -m 0644 "${CADDYFILE_SRC}" /etc/caddy/Caddyfile
systemctl enable caddy
systemctl restart caddy

cat <<EOF
env file: ${ENV_PATH} (WRITE_ENV=${WRITE_ENV})
installed /etc/caddy/Caddyfile

verify after deploy:
  curl https://schlift.com/.well-known/assetlinks.json
EOF

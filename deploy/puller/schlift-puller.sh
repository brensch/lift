#!/usr/bin/env bash
# Pull-based deploys for the schlift box (replaces the self-hosted GitHub runner).
#
# CI builds on GitHub-hosted runners and records a GitHub Deployment whose payload
# names the run and its artifacts. This script, run by schlift-puller.timer as root,
# picks up the newest deployment for each environment it serves, downloads the
# artifacts with a read-only token, deploys them with the scripts installed beside
# it (never scripts from the repo), and reports back to the deployment:
# in_progress, then success or failure. The workflow waits for that verdict.
#
# Nothing on GitHub can run a command here: the token can read Actions artifacts and
# write deployment statuses, and the only code it fetches is the build itself.
#
# Zero downtime: the new build is first started on a spare port against a copy of
# the database (migrations run, health check must pass) before the live service is
# touched; Caddy holds requests during the restart (lb_try_duration) and is only
# reloaded, gracefully, when the Caddyfile actually changed.
set -euo pipefail

REPO="${REPO:-brensch/lift}"
API="https://api.github.com/repos/${REPO}"
HERE="/opt/schlift-puller"
STATE="/var/lib/schlift-puller"
TOKEN_FILE="/etc/schlift-puller/token"
ENVIRONMENTS="${ENVIRONMENTS:-production dev dev-apk}"

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

[[ "${EUID}" -eq 0 ]] || {
	echo "run as root" >&2
	exit 1
}
mkdir -p "${STATE}"
exec 9>"${STATE}/lock"
flock -n 9 || exit 0 # a deploy is already running

TOKEN="$(<"${TOKEN_FILE}")"
gh() { # gh METHOD PATH [json-body]
	local method="$1" path="$2" body="${3:-}" hdr
	hdr="$(mktemp)"
	local out
	out="$(curl -fsS -X "${method}" -D "${hdr}" \
		-H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		${body:+-H "Content-Type: application/json" --data "${body}"} "${API}${path}")"
	# fine-grained tokens expire: warn in the journal a fortnight ahead
	local exp
	exp="$(sed -n 's/^github-authentication-token-expiration: //Ip' "${hdr}" | tr -d '\r')"
	rm -f "${hdr}"
	if [[ -n "${exp}" ]] && (($(date -d "${exp}" +%s) - $(date +%s) < 14 * 86400)); then
		log "WARNING: the deploy token expires ${exp}; make a new one (deploy/puller/README.md)"
	fi
	printf '%s' "${out}"
}

status() { # status DEPLOYMENT_ID STATE DESCRIPTION [ENV_URL]
	local body
	body="$(jq -nc --arg s "$2" --arg d "${3:0:139}" --arg u "${4:-}" \
		'{state:$s, description:$d, auto_inactive:true} + (if $u != "" then {environment_url:$u} else {} end)')"
	gh POST "/deployments/$1/statuses" "${body}" >/dev/null || log "could not report status $2 for deployment $1"
}

fetch_artifacts() { # fetch_artifacts RUN_ID DEST NAME...
	local run="$1" dest="$2"
	shift 2
	local list
	list="$(gh GET "/actions/runs/${run}/artifacts?per_page=100")"
	for name in "$@"; do
		local url
		url="$(jq -r --arg n "${name}" '[.artifacts[] | select(.name == $n and .expired == false)][0].archive_download_url // empty' <<<"${list}")"
		[[ -n "${url}" ]] || {
			echo "artifact ${name} not found in run ${run}" >&2
			return 1
		}
		curl -fsSL -H "Authorization: Bearer ${TOKEN}" -o "${dest}/${name}.zip" "${url}"
		mkdir -p "${dest}/${name}"
		unzip -q -o "${dest}/${name}.zip" -d "${dest}/${name}"
	done
}

# Start a build on a spare port against a consistent copy of the live database:
# its migrations must apply and its health check must pass before anything live changes.
preflight() { # preflight BINARY INSTALL_ROOT PORT
	local bin="$1" root="$2" port="$3" dir
	dir="$(mktemp -d /var/tmp/schlift-preflight.XXXXXX)"
	mkdir -p "${dir}/data"
	if [[ -f "${root}/shared/data/server.sqlite" ]]; then
		python3 - "${root}/shared/data/server.sqlite" "${dir}/data/server.sqlite" <<'PY'
import sqlite3, sys
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
dst = sqlite3.connect(sys.argv[2])
src.backup(dst)  # consistent snapshot even while the live server writes
dst.close(); src.close()
PY
	fi
	# The build sits in a root-only download folder; the preflight runs it as opc.
	install -m 0755 "${bin}" "${dir}/schlift"
	bin="${dir}/schlift"
	chown -R opc:opc "${dir}"
	# A transient unit with the live unit's user and EnvironmentFile: systemd reads the
	# env file exactly as it does for the real service.
	local unit ok=0
	unit="schlift-preflight-${port}"
	systemctl stop "${unit}" 2>/dev/null || true
	systemctl reset-failed "${unit}" 2>/dev/null || true
	systemd-run --quiet --collect --unit="${unit}" \
		-p User=opc -p Group=opc -p WorkingDirectory="${dir}" \
		-p EnvironmentFile=-"${root}/shared/schlift.env" \
		-E PORT="${port}" -E DATA_DIR="${dir}/data" "${bin}"
	local inv
	inv="$(systemctl show -p InvocationID --value "${unit}")"
	for _ in $(seq 1 120); do
		if curl -fsS "http://127.0.0.1:${port}/api/health" >/dev/null 2>&1; then
			ok=1
			break
		fi
		systemctl is-active --quiet "${unit}" || break
		sleep 0.5
	done
	if [[ "${ok}" -ne 1 ]]; then
		log "preflight failed; its log:"
		journalctl _SYSTEMD_INVOCATION_ID="${inv}" -n 30 --no-pager -o cat || true
	fi
	systemctl stop "${unit}" 2>/dev/null || true
	rm -rf "${dir}"
	[[ "${ok}" -eq 1 ]]
}

apply_caddyfile() { # apply_caddyfile NEW_CADDYFILE
	local new="$1"
	[[ -f "${new}" ]] || return 0
	cmp -s "${new}" /etc/caddy/Caddyfile && return 0
	caddy validate --config "${new}" --adapter caddyfile >/dev/null 2>&1 || {
		echo "new Caddyfile does not validate; keeping the old one" >&2
		return 1
	}
	install -m 0644 "${new}" /etc/caddy/Caddyfile
	systemctl reload caddy # graceful: open connections are not dropped
	log "Caddyfile updated (graceful reload)"
}

deploy_one() { # deploy_one ENV DEPLOYMENT_JSON WORKDIR
	local env="$1" dep="$2" work="$3" run rid
	run="$(jq -r '.payload.run_id' <<<"${dep}")"
	rid="$(jq -r '.payload.release_id // .sha' <<<"${dep}")"
	local artifacts
	mapfile -t artifacts < <(jq -r '.payload.artifacts[]' <<<"${dep}")
	fetch_artifacts "${run}" "${work}" "${artifacts[@]}"
	case "${env}" in
	production)
		local a="${work}/backend-linux-arm64"
		[[ -f "${a}/schlift.sha256" ]] && (cd "${a}" && sha256sum -c --quiet schlift.sha256)
		chmod 755 "${a}/schlift"
		preflight "${a}/schlift" /opt/schlift 50061
		apply_caddyfile "${a}/Caddyfile"
		ARTIFACT_DIR="${a}" WEB_DIR="${work}/web-dist" RELEASE_ID="${rid}" \
			"${HERE}/scripts/deploy_schlift_release.sh"
		;;
	dev)
		local a="${work}/dev-backend-linux-arm64"
		[[ -f "${a}/schlift.sha256" ]] && (cd "${a}" && sha256sum -c --quiet schlift.sha256)
		chmod 755 "${a}/schlift"
		preflight "${a}/schlift" /opt/schlift-dev 50062
		ARTIFACT_DIR="${a}" RELEASE_ID="${rid}" "${HERE}/scripts/deploy_schlift_dev.sh"
		;;
	dev-apk)
		install -m 0644 "${work}/schlift-dev-apk/schlift-dev.apk" /opt/schlift/web/schlift-dev.apk
		;;
	*)
		echo "unknown environment ${env}" >&2
		return 1
		;;
	esac
}

env_url() {
	case "$1" in
	production) echo "https://schlift.com" ;;
	dev) echo "https://dev.schlift.com" ;;
	dev-apk) echo "https://dev.schlift.com/schlift-dev.apk" ;;
	esac
}

for env in ${ENVIRONMENTS}; do
	dep="$(gh GET "/deployments?environment=${env}&task=pull-deploy&per_page=1" | jq -c '.[0] // empty')" || {
		log "GitHub unreachable for ${env}"
		continue
	}
	[[ -n "${dep}" ]] || continue
	id="$(jq -r '.id' <<<"${dep}")"
	done_id="$(cat "${STATE}/done-${env}" 2>/dev/null || echo 0)"
	((id > done_id)) || continue
	# a deployment already finished (e.g. by a previous puller run) is not redone
	last="$(gh GET "/deployments/${id}/statuses?per_page=1" | jq -r '.[0].state // "none"')"
	if [[ "${last}" == "success" || "${last}" == "failure" || "${last}" == "error" ]]; then
		echo "${id}" >"${STATE}/done-${env}"
		continue
	fi
	sha="$(jq -r '.sha' <<<"${dep}")"
	log "${env}: deploying ${sha:0:12} (deployment ${id})"
	status "${id}" in_progress "deploying ${sha:0:12} on $(hostname -s)"
	work="$(mktemp -d /var/tmp/schlift-deploy.XXXXXX)"
	out="${work}.log"
	# A subshell outside any `if`, so `set -e` holds inside it: any failing step,
	# the preflight included, stops the deploy (in an `if` condition bash ignores -e).
	set +e
	(
		set -e
		deploy_one "${env}" "${dep}" "${work}"
	) >"${out}" 2>&1
	rc=$?
	set -e
	if [[ "${rc}" -eq 0 ]]; then
		status "${id}" success "deployed ${sha:0:12}" "$(env_url "${env}")"
		log "${env}: deployed ${sha:0:12}"
	else
		reason="$(grep -v '^\s*$' "${out}" | tail -n 1)"
		status "${id}" failure "${reason:-deploy failed} (journalctl -u schlift-puller)"
		log "${env}: FAILED ${sha:0:12}"
	fi
	cat "${out}"
	echo "${id}" >"${STATE}/done-${env}"
	rm -rf "${work}" "${out}"
done

#!/usr/bin/env bash
# Ask the schlift box to deploy this run's build, and wait for its verdict.
#
# Runs on a GitHub-hosted runner. It records a GitHub Deployment whose payload names
# this run and its artifacts; the box's puller (deploy/puller) picks it up, deploys it
# and reports in_progress, then success or failure. This step fails if the deploy does,
# so the workflow run shows the outcome, and the repo's Deployments panel keeps the history.
# task "pull-deploy" tells these apart from the deployment GitHub makes by itself for a job
# that names an environment (that one has no payload; the puller ignores it).
#
#   scripts/request_deploy.sh <environment> <release-id> <artifact>...
# Needs GH_TOKEN (the job's token, with `deployments: write`), GITHUB_REPOSITORY,
# GITHUB_SHA, GITHUB_RUN_ID.
set -euo pipefail

ENVIRONMENT="$1"
RELEASE_ID="$2"
shift 2
TIMEOUT_S="${DEPLOY_TIMEOUT_S:-900}"

artifacts="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
body="$(jq -nc --arg ref "${GITHUB_SHA}" --arg env "${ENVIRONMENT}" --arg rid "${RELEASE_ID}" \
	--argjson run "${GITHUB_RUN_ID}" --argjson arts "${artifacts}" \
	'{ref:$ref, environment:$env, task:"pull-deploy", auto_merge:false, required_contexts:[],
	  description:("deploy " + $rid), payload:{run_id:$run, release_id:$rid, artifacts:$arts}}')"
id="$(gh api "repos/${GITHUB_REPOSITORY}/deployments" --input - <<<"${body}" --jq .id)"
echo "deployment ${id} recorded for ${ENVIRONMENT}; waiting for the box to apply it"

deadline=$(($(date +%s) + TIMEOUT_S))
last=""
while (($(date +%s) < deadline)); do
	st="$(gh api "repos/${GITHUB_REPOSITORY}/deployments/${id}/statuses?per_page=1" \
		--jq '.[0] // {} | "\(.state // "queued")\t\(.description // "")"')"
	state="${st%%$'\t'*}"
	if [[ "${st}" != "${last}" ]]; then
		echo "  ${st}"
		last="${st}"
	fi
	case "${state}" in
	success) exit 0 ;;
	failure | error)
		echo "::error::deploy failed: ${st#*$'\t'}"
		exit 1
		;;
	esac
	sleep 5
done
echo "::error::the box did not report back within ${TIMEOUT_S}s (is schlift-puller.timer running?)"
exit 1

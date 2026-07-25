#!/usr/bin/env bash
# Run the e2e scenario suite on the Android emulator against the real backend,
# then build an HTML report. Each scenario is a `flutter drive` target under
# app/integration_test/; its stdout (screenshots + E2E| step log) is teed to
# app/test_screenshots/<name>.drive.log for the report builder.
#
#   scripts/run_e2e.sh                 # run every *_test.dart scenario
#   scripts/run_e2e.sh solo_workout    # run only matching scenarios
#
# Prereqs (see `make e2e` which wires these up):
#   - emulator booted (emulator-5554), backend up with --features test-auth,
#     `adb reverse tcp:50051 tcp:50051` set.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
ADB="${ADB:-$HOME/android-sdk/platform-tools/adb}"
DEVICE="${DEVICE:-emulator-5554}"
SHOTS="$APP/test_screenshots"

cd "$APP"
mkdir -p "$SHOTS"

# Pick scenarios: integration_test/*_test.dart, minus the support/ dir.
mapfile -t ALL < <(ls integration_test/*_test.dart 2>/dev/null | xargs -n1 basename)
SCENARIOS=()
if [ "$#" -gt 0 ]; then
  for f in "${ALL[@]}"; do
    for pat in "$@"; do [[ "$f" == *"$pat"* ]] && SCENARIOS+=("$f"); done
  done
else
  SCENARIOS=("${ALL[@]}")
fi

if [ "${#SCENARIOS[@]}" -eq 0 ]; then
  echo "no scenarios matched" >&2; exit 1
fi

echo "=> ${#SCENARIOS[@]} scenario(s): ${SCENARIOS[*]}"
"$ADB" reverse tcp:50051 tcp:50051 >/dev/null 2>&1 || true

# Note: scenarios set HealthService.suppressPermissionPrompts before launch, so
# the native Health Connect sheet never appears — no permission granting needed.

fail=0
for f in "${SCENARIOS[@]}"; do
  name="${f%_test.dart}"
  log="$SHOTS/$name.drive.log"
  echo "== running $name =="
  # Clear this scenario's old screenshots so a rename can't leave stale PNGs.
  rm -f "$SHOTS/${name}_"*.png 2>/dev/null
  flutter drive \
    --driver test_driver/integration_test.dart \
    --target "integration_test/$f" \
    -d "$DEVICE" > "$log" 2>&1
  rc=$?
  if grep -q 'All tests passed' "$log"; then
    echo "   ok ($name)"
  else
    echo "   FAIL ($name) rc=$rc — see $log"; fail=1
    grep -E 'Test failed|Exception|Error:|EXCEPTION|failed to' "$log" | head -5 | sed 's/^/     /'
  fi
done

echo "== building report =="
python3 "$ROOT/scripts/build_e2e_report.py" "$SHOTS"/*.drive.log
echo "report: $SHOTS/report.html"
exit $fail

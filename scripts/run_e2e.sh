#!/usr/bin/env bash
# Run the e2e scenarios against the real backend, many at once, then build an
# HTML report. Every scenario under app/integration_test/ is built into one
# Linux binary, once; each runs as its own process of that binary
# (E2E_SCENARIO picks which), with its own home directory, on a headless X
# server. Each scenario's output goes to app/test_screenshots/<name>.log and
# its screenshots beside it.
#
#   scripts/run_e2e.sh                 # every *_test.dart scenario
#   scripts/run_e2e.sh solo_workout    # only those whose name matches
#   scripts/run_e2e.sh --build-only    # build the binary and stop
#   scripts/run_e2e.sh --no-build --shard 2/4
#                                      # the second quarter, on a binary
#                                      # built before (CI's build job)
#
# Needs: the backend up on localhost:50051 with --features test-auth
# (`make e2e-up`), and Xvfb (`apt install xvfb`; XVFB names another).
# E2E_JOBS scenarios run at once (default: half the cores); each gets
# E2E_TIMEOUT seconds (default 300).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
SHOTS="$APP/test_screenshots"
WORK="$ROOT/.tmp/e2e"
ENTRY="$APP/build/e2e/main.dart"
BIN="$APP/build/linux/x64/debug/bundle/schlift"
JOBS="${E2E_JOBS:-$(($(nproc) / 2))}"
[ "$JOBS" -ge 1 ] || JOBS=1
TIMEOUT="${E2E_TIMEOUT:-300}"
XVFB="${XVFB:-Xvfb}"

build=1
run=1
shard=1/1
while [ "$#" -gt 0 ]; do
	case "$1" in
	--build-only) run=0 ;;
	--no-build) build=0 ;;
	--shard)
		shard="$2"
		shift
		;;
	*) break ;;
	esac
	shift
done
shard_index="${shard%/*}"
shard_count="${shard#*/}"

ALL=()
for path in "$APP"/integration_test/*_test.dart; do
	ALL+=("$(basename "$path" _test.dart)")
done
SCENARIOS=()
if [ "$#" -gt 0 ]; then
	for name in "${ALL[@]}"; do
		for pat in "$@"; do [[ "$name" == *"$pat"* ]] && SCENARIOS+=("$name") && break; done
	done
else
	SCENARIOS=("${ALL[@]}")
fi
# A shard takes every shard_count-th scenario, from its own index.
SHARD=()
for i in "${!SCENARIOS[@]}"; do
	[ $((i % shard_count + 1)) -eq "$shard_index" ] && SHARD+=("${SCENARIOS[$i]}")
done
SCENARIOS=("${SHARD[@]}")
if [ "${#SCENARIOS[@]}" -eq 0 ]; then
	echo "no scenarios matched" >&2
	exit 1
fi

if [ "$build" -eq 1 ]; then
	# One entry point for every scenario, so one build serves any run.
	mkdir -p "$(dirname "$ENTRY")"
	{
		echo "// Written by scripts/run_e2e.sh: every scenario in one binary."
		echo "import 'dart:io';"
		echo "import 'package:integration_test/integration_test.dart';"
		for name in "${ALL[@]}"; do
			echo "import '../../integration_test/${name}_test.dart' as $name;"
		done
		echo "const scenarios = <String, void Function()>{"
		for name in "${ALL[@]}"; do echo "  '$name': $name.main,"; done
		echo "};"
		cat <<-'DART'
			void main() {
			  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
			  final run = scenarios[Platform.environment['E2E_SCENARIO']];
			  if (run == null) {
			    stderr.writeln('E2E_SCENARIO is one of: ${scenarios.keys.join(' ')}');
			    exit(2);
			  }
			  binding.allTestsPassed.future.then((passed) => exit(passed ? 0 : 1));
			  run();
			}
		DART
	} >"$ENTRY"

	echo "=> building every scenario into one binary"
	mkdir -p "$WORK"
	(cd "$APP" && "${FLUTTER:-flutter}" build linux --debug --target "$ENTRY" \
		--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false) >"$WORK.build.log" 2>&1 ||
		{
			tail -30 "$WORK.build.log"
			exit 1
		}
fi
[ "$run" -eq 1 ] || exit 0

# A display of its own for the run; its windows are never looked at, the
# screenshots are taken inside the app.
display=90
while [ -e "/tmp/.X11-unix/X$display" ] || [ -e "/tmp/.X$display-lock" ]; do display=$((display + 1)); done
"$XVFB" ":$display" -screen 0 1280x1024x24 -nolisten tcp -nolisten unix >"$WORK.xvfb.log" 2>&1 &
xvfb=$!
trap 'kill $xvfb 2>/dev/null' EXIT
sleep 1

run_one() {
	local name="$1" home="$WORK/$1"
	rm -rf "$home" "$home.status" && mkdir -p "$home"
	rm -f "$SHOTS/${name}_"*.png
	env -u WAYLAND_DISPLAY HOME="$home" XDG_DATA_HOME="$home/data" \
		XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache" \
		DISPLAY=":$display" GDK_BACKEND=x11 E2E_SCENARIO="$name" E2E_OUT="$SHOTS" \
		timeout "$TIMEOUT" "$BIN" >"$SHOTS/$name.log" 2>&1
	echo $? >"$home.status"
}

mkdir -p "$SHOTS"
echo "=> ${#SCENARIOS[@]} scenario(s), $JOBS at a time"
started=$SECONDS
running=()
for name in "${SCENARIOS[@]}"; do
	while [ "${#running[@]}" -ge "$JOBS" ]; do
		wait -n "${running[@]}"
		alive=()
		for pid in "${running[@]}"; do kill -0 "$pid" 2>/dev/null && alive+=("$pid"); done
		running=("${alive[@]}")
	done
	run_one "$name" &
	running+=($!)
done
[ "${#running[@]}" -eq 0 ] || wait "${running[@]}"

fail=0
for name in "${SCENARIOS[@]}"; do
	rc=$(cat "$WORK/$name.status")
	if [ "$rc" -eq 0 ]; then
		echo "   ok ($name)"
	else
		fail=1
		[ "$rc" -eq 124 ] && why="timed out after ${TIMEOUT}s" || why="rc=$rc"
		echo "   FAIL ($name) $why — see $SHOTS/$name.log"
		grep -E 'SCENARIO FAILED|^ERROR|Exception|Error:' "$SHOTS/$name.log" | head -4 | sed 's/^/     /'
	fi
done
echo "=> $((SECONDS - started))s for the scenarios"

logs=()
for name in "${SCENARIOS[@]}"; do logs+=("$SHOTS/$name.log"); done
python3 "$ROOT/scripts/build_e2e_report.py" "${logs[@]}"
exit $fail

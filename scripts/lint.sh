#!/usr/bin/env bash
# One entry point for formatting and linting every language in the repo.
# CI runs exactly this, so a clean run here is a clean run there.
#
#   scripts/lint.sh fmt        [lang...]   rewrite files in place
#   scripts/lint.sh fmt-check  [lang...]   fail if anything would be rewritten
#   scripts/lint.sh lint       [lang...]   static analysis, warnings are errors
#   scripts/lint.sh check      [lang...]   fmt-check + lint (what CI enforces)
#
# Languages: dart rust web python shell kotlin swift proto. Default: all.
#
# Generated code is excluded, and only generated code: app/lib/gen,
# web/src/gen, app/android/shared-proto, app/ios/SchliftWatch/Generated and
# Flutter's GeneratedPluginRegistrant. Everything else is held to the rules —
# fix the code, don't add an ignore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Pinned tools first (scripts/install_lint_tools.sh), then the usual homes of
# the toolchains on this project's machines, then PATH.
export PATH="$ROOT/.tools/bin:$PATH:$HOME/flutter-sdk/bin:$HOME/.bun/bin:$HOME/go/bin:$HOME/.cargo/bin"

ALL_LANGS=(dart rust web python shell kotlin swift proto)

need() { # tool, how to get it
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "missing tool: $1 — $2" >&2
		exit 127
	fi
}
need_pinned() { need "$1" "run scripts/install_lint_tools.sh"; }

# Tracked files matching the given pathspecs, NUL-separated, minus generated code.
tracked() {
	git ls-files -z -- "$@" |
		grep -zv -e '^app/lib/gen/' -e '^web/src/gen/' -e '^app/android/shared-proto/' \
			-e '/Generated/' -e 'GeneratedPluginRegistrant' || true
}

# ── dart ──
dart_files() { tracked 'app/*.dart'; }
fmt_dart() {
	need dart "install the Flutter SDK"
	dart_files | xargs -0 -r dart format
}
fmt_check_dart() {
	need dart "install the Flutter SDK"
	dart_files | xargs -0 -r dart format --output=none --set-exit-if-changed
}
lint_dart() {
	need flutter "install the Flutter SDK"
	(cd app && flutter analyze --fatal-infos --fatal-warnings)
}

# ── rust ──
fmt_rust() { cargo fmt --all; }
fmt_check_rust() { cargo fmt --all -- --check; }
lint_rust() { cargo clippy --all-targets -- -D warnings; }

# ── web (TypeScript / React) ──
# bun locally (fast); npm where bun is absent, which is what CI uses so that
# `npm ci` also proves package-lock.json is in sync — the deploy depends on it.
web_run() {
	if command -v bun >/dev/null 2>&1; then
		(cd web && bun run "$@")
	else
		need npm "install Node.js"
		(cd web && npm run --silent "$@")
	fi
}
web_deps() {
	[ -d web/node_modules ] && return 0
	if command -v bun >/dev/null 2>&1; then
		(cd web && bun install --frozen-lockfile)
	else
		need npm "install Node.js"
		(cd web && npm ci --no-audit --no-fund)
	fi
}
fmt_web() { web_deps && web_run format; }
fmt_check_web() { web_deps && web_run format:check; }
lint_web() {
	# typecheck reads src/generated, which `sync` writes from the listing.
	web_deps && web_run lint && web_run sync && web_run typecheck
}

# ── python ──
fmt_python() {
	need_pinned ruff
	ruff format .
}
fmt_check_python() {
	need_pinned ruff
	ruff format --check .
}
lint_python() {
	need_pinned ruff
	ruff check .
}

# ── shell ──
shell_files() { tracked '*.sh'; }
fmt_shell() {
	need_pinned shfmt
	shell_files | xargs -0 -r shfmt -w
}
fmt_check_shell() {
	need_pinned shfmt
	shell_files | xargs -0 -r shfmt -d
}
lint_shell() {
	need_pinned shellcheck
	shell_files | xargs -0 -r shellcheck
}

# ── kotlin ──
kotlin_files() { tracked '*.kt' '*.kts'; }
fmt_kotlin() {
	need_pinned ktlint
	kotlin_files | xargs -0 -r ktlint --format
}
fmt_check_kotlin() {
	# ktlint's checker is its formatter: every rule is both.
	need_pinned ktlint
	kotlin_files | xargs -0 -r ktlint
}
lint_kotlin() { fmt_check_kotlin; }

# ── swift ──
swift_files() { tracked '*.swift'; }
fmt_swift() {
	need_pinned swiftformat
	swift_files | xargs -0 -r swiftformat
}
fmt_check_swift() {
	need_pinned swiftformat
	swift_files | xargs -0 -r swiftformat --lint
}
lint_swift() {
	need_pinned swiftlint
	# SourceKit ships with Xcode / a Swift toolchain, which a Linux box and the
	# CI runner do not have. Without it swiftlint still runs every rule that
	# works on syntax alone (nearly all); it says which it skipped.
	swift_files | SWIFTLINT_DISABLE_SOURCEKIT=1 xargs -0 -r swiftlint lint --strict --quiet
}

# ── proto ──
fmt_proto() {
	need buf "make install-deps"
	(cd proto && buf format -w)
}
fmt_check_proto() {
	need buf "make install-deps"
	(cd proto && buf format -d --exit-code)
}
lint_proto() {
	need buf "make install-deps"
	(cd proto && buf lint)
}

mode="${1:-}"
shift || true
case "$mode" in
fmt | fmt-check | lint | check) ;;
*)
	sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac

langs=("$@")
[ ${#langs[@]} -eq 0 ] && langs=("${ALL_LANGS[@]}")

failed=()
run() { # label, function
	echo "── $1"
	if ! "$2"; then failed+=("$1"); fi
}
for lang in "${langs[@]}"; do
	case " ${ALL_LANGS[*]} " in
	*" $lang "*) ;;
	*)
		echo "unknown language: $lang (have: ${ALL_LANGS[*]})" >&2
		exit 2
		;;
	esac
	case "$mode" in
	fmt) run "fmt $lang" "fmt_$lang" ;;
	fmt-check) run "fmt-check $lang" "fmt_check_$lang" ;;
	lint) run "lint $lang" "lint_$lang" ;;
	check)
		run "fmt-check $lang" "fmt_check_$lang"
		run "lint $lang" "lint_$lang"
		;;
	esac
done

if [ ${#failed[@]} -gt 0 ]; then
	echo
	echo "FAILED: ${failed[*]}" >&2
	[ "$mode" != fmt ] && echo "Formatting failures are fixed by: scripts/lint.sh fmt" >&2
	exit 1
fi
echo
echo "ok"

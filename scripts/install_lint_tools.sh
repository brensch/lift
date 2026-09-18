#!/usr/bin/env bash
# Installs the formatters and linters that are not part of a language
# toolchain, at pinned versions, into .tools/bin (gitignored). CI and local
# runs both use this, so "passes here" means "passes there".
#
#   scripts/install_lint_tools.sh          install whatever is missing
#   scripts/install_lint_tools.sh --force  reinstall everything
#
# Toolchain-provided tools are not handled here: dart format / flutter
# analyze (Flutter SDK), cargo fmt / clippy (rustup), eslint / prettier
# (web/package.json), buf (see make install-deps).
#
# To bump a tool: change its version, run with --print-checksums, paste the
# new hashes below.
set -euo pipefail

RUFF_VERSION=0.16.8
SHELLCHECK_VERSION=0.11.0
SHFMT_VERSION=3.14.1
KTLINT_VERSION=1.8.0
SWIFTFORMAT_VERSION=0.63.0
SWIFTLINT_VERSION=0.65.1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
BIN="$TOOLS/bin"
FORCE=0
PRINT=0
for arg in "$@"; do
	case "$arg" in
	--force) FORCE=1 ;;
	--print-checksums)
		PRINT=1
		FORCE=1
		;;
	*)
		echo "unknown argument: $arg" >&2
		exit 2
		;;
	esac
done

os="$(uname -s)"
arch="$(uname -m)"
if [ "$os" != "Linux" ]; then
	cat >&2 <<-EOF
		This installer fetches Linux binaries. On macOS install the same versions with:
		  brew install ruff shellcheck shfmt ktlint swiftformat swiftlint
		and put them on PATH; scripts/lint.sh falls back to PATH.
	EOF
	exit 1
fi
case "$arch" in
x86_64)
	ruff_asset="ruff-x86_64-unknown-linux-gnu.tar.gz"
	shellcheck_asset="shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
	shfmt_asset="shfmt_v${SHFMT_VERSION}_linux_amd64"
	swiftformat_asset="swiftformat_linux.zip"
	swiftlint_asset="swiftlint_linux_amd64.zip"
	;;
aarch64 | arm64)
	ruff_asset="ruff-aarch64-unknown-linux-gnu.tar.gz"
	shellcheck_asset="shellcheck-v${SHELLCHECK_VERSION}.linux.aarch64.tar.xz"
	shfmt_asset="shfmt_v${SHFMT_VERSION}_linux_arm64"
	swiftformat_asset="swiftformat_linux_aarch64.zip"
	swiftlint_asset="swiftlint_linux_arm64.zip"
	;;
*)
	echo "unsupported architecture: $arch" >&2
	exit 1
	;;
esac

# sha256 of each downloaded asset, keyed by file name. Only x86_64 is
# recorded (CI and the dev box); on arm64 run --print-checksums once and add
# the hashes.
declare -A SHA256=(
	["ruff-x86_64-unknown-linux-gnu.tar.gz"]="c4a8c7c152532bcb7e7ede4bd6ccd440dcacddffcdcdd79b90090ac6021f41c2"
	["shellcheck-v0.11.0.linux.x86_64.tar.xz"]="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198"
	["shfmt_v3.14.1_linux_amd64"]="76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf"
	["ktlint"]="a3fd620207d5c40da6ca789b95e7f823c54e854b7fade7f613e91096a3706d75"
	["swiftformat_linux.zip"]="b4a3cbb8c852a0baaf9adf853e221ff1dabf921a3d8957a602e0bda3af8470f1"
	["swiftlint_linux_amd64.zip"]="caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d"
)

mkdir -p "$BIN" "$TOOLS/dl"

fetch() { # url
	local url="$1" name
	name="$(basename "$url")"
	local out="$TOOLS/dl/$name"
	curl -fsSL --retry 3 -o "$out" "$url"
	local got
	got="$(sha256sum "$out" | cut -d' ' -f1)"
	if [ "$PRINT" = 1 ]; then
		echo "	[\"$name\"]=\"$got\"" >&2
	elif [ "${SHA256[$name]:-}" != "$got" ]; then
		echo "checksum mismatch for $name: got $got, want ${SHA256[$name]:-<none recorded>}" >&2
		rm -f "$out"
		exit 1
	fi
	echo "$out"
}

have() { # name version-marker
	[ "$FORCE" = 0 ] && [ -x "$BIN/$1" ] && [ -f "$TOOLS/$1.version" ] && [ "$(cat "$TOOLS/$1.version")" = "$2" ]
}
done_with() { echo "$2" >"$TOOLS/$1.version" && echo "installed $1 $2"; }

if ! have ruff "$RUFF_VERSION"; then
	f="$(fetch "https://github.com/astral-sh/ruff/releases/download/${RUFF_VERSION}/${ruff_asset}")"
	tar -xzf "$f" -C "$TOOLS/dl"
	install -m 0755 "$TOOLS/dl/${ruff_asset%.tar.gz}/ruff" "$BIN/ruff"
	done_with ruff "$RUFF_VERSION"
fi

if ! have shellcheck "$SHELLCHECK_VERSION"; then
	f="$(fetch "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/${shellcheck_asset}")"
	tar -xJf "$f" -C "$TOOLS/dl"
	install -m 0755 "$TOOLS/dl/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$BIN/shellcheck"
	done_with shellcheck "$SHELLCHECK_VERSION"
fi

if ! have shfmt "$SHFMT_VERSION"; then
	f="$(fetch "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/${shfmt_asset}")"
	install -m 0755 "$f" "$BIN/shfmt"
	done_with shfmt "$SHFMT_VERSION"
fi

# ktlint is a self-executing jar: needs a JRE on PATH (the Android build
# already requires a JDK).
if ! have ktlint "$KTLINT_VERSION"; then
	f="$(fetch "https://github.com/pinterest/ktlint/releases/download/${KTLINT_VERSION}/ktlint")"
	install -m 0755 "$f" "$BIN/ktlint"
	done_with ktlint "$KTLINT_VERSION"
fi

if ! have swiftformat "$SWIFTFORMAT_VERSION"; then
	f="$(fetch "https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/${swiftformat_asset}")"
	rm -rf "$TOOLS/dl/swiftformat" && mkdir -p "$TOOLS/dl/swiftformat"
	unzip -q -o "$f" -d "$TOOLS/dl/swiftformat"
	install -m 0755 "$(find "$TOOLS/dl/swiftformat" -type f -name 'swiftformat*' | head -1)" "$BIN/swiftformat"
	done_with swiftformat "$SWIFTFORMAT_VERSION"
fi

if ! have swiftlint "$SWIFTLINT_VERSION"; then
	f="$(fetch "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/${swiftlint_asset}")"
	rm -rf "$TOOLS/dl/swiftlint" && mkdir -p "$TOOLS/dl/swiftlint"
	unzip -q -o "$f" -d "$TOOLS/dl/swiftlint"
	install -m 0755 "$(find "$TOOLS/dl/swiftlint" -type f -name 'swiftlint*' | head -1)" "$BIN/swiftlint"
	done_with swiftlint "$SWIFTLINT_VERSION"
fi

rm -rf "$TOOLS/dl"

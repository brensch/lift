# Formatting and linting, every language. Thin wrappers over scripts/lint.sh,
# which is also exactly what CI runs — see docs/linting.md.
#
#   make fmt                  format everything in place
#   make lint-check           what CI enforces: format check + lint, all languages
#   make fmt LANGS="dart web" limit to some languages
#
# Languages: dart rust web python shell kotlin swift proto

LANGS ?=

# Pinned ruff, shellcheck, shfmt, ktlint, swiftformat and swiftlint in .tools/bin.
lint-tools:
	scripts/install_lint_tools.sh

fmt: lint-tools
	scripts/lint.sh fmt $(LANGS)

fmt-check: lint-tools
	scripts/lint.sh fmt-check $(LANGS)

lint: lint-tools
	scripts/lint.sh lint $(LANGS)

# Run this before pushing. CI runs the same thing and fails on any finding.
lint-check: lint-tools
	scripts/lint.sh check $(LANGS)

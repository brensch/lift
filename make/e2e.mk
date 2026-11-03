# End-to-end scenario suite: the real app against a real backend, every
# scenario built into one Linux binary and many run at once on a headless X
# server, a screenshot and step log per interaction, an HTML report at the end.
# See docs/testing/e2e-scenarios.md.

.PHONY: e2e e2e-up e2e-run

# Xvfb, the headless X server the scenarios draw on (`apt install xvfb`).
XVFB ?= Xvfb

# e2e-up: the backend (with test-auth dev login) on localhost:50051. Idempotent.
e2e-up: agent-backend-start

# e2e-run: run scenarios only (assumes `e2e-up` already ran). Pass a filter with
# SCENARIO=..., e.g. `make e2e-run SCENARIO=multiplayer`; E2E_JOBS sets how many
# run at once.
e2e-run:
	FLUTTER="$(FLUTTER)" XVFB="$(XVFB)" bash scripts/run_e2e.sh $(SCENARIO)

# e2e: the one-shot entry point — backend up, the whole suite, the report at
# app/test_screenshots/report.html.
e2e: e2e-up e2e-run
	@echo "report: app/test_screenshots/report.html"

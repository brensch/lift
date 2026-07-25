# End-to-end scenario suite: drives the real app on the Android emulator against
# a real backend, capturing a screenshot + step log per interaction and building
# an HTML report. See docs/testing/e2e-scenarios.md.

# e2e-up: bring up everything a run needs — backend (with test-auth dev login),
# emulator, and the localhost:50051 reverse tunnel. Idempotent.
e2e-up:
	$(MAKE) agent-backend-start
	$(MAKE) android-emulator-start
	$(MAKE) android-emulator-wait
	$(MAKE) android-emulator-unlock
	$(MAKE) android-emulator-reverse

# e2e-run: run scenarios only (assumes `e2e-up` already ran). Pass a filter with
# SCENARIO=..., e.g. `make e2e-run SCENARIO=multiplayer`.
e2e-run:
	ADB="$(ADB)" DEVICE="$(ANDROID_SERIAL)" bash scripts/run_e2e.sh $(SCENARIO)

# e2e: the one-shot entry point — bring the world up, run the whole suite, build
# the report at app/test_screenshots/report.html.
e2e: e2e-up e2e-run
	@echo "report: app/test_screenshots/report.html"

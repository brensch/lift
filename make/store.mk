# Store assets: capture raw screenshots locally (emulator + seeded backend),
# frame them, and push listing text + images via .github/workflows/store-assets.yml.
# See docs/releasing.md → "Store listing and screenshots".

STORE_BACKEND_DATA_DIR ?= .tmp/store-backend/data
STORE_BACKEND_LOG ?= .tmp/store-backend/backend.log
STORE_BACKEND_PID ?= .tmp/store-backend/backend.pid
STORE_RAW_DIR ?= store/screenshots/raw
STORE_VENV ?= .tmp/store-venv

.PHONY: store-capture store-backend-start store-backend-stop store-frame store-check

# store-backend-start: a throwaway backend with dev login and the seeded
# `demo` account (weeks of history), on the usual :50051. Fresh data every run.
store-backend-start:
	@bash -ec '\
		$(MAKE) store-backend-stop >/dev/null; \
		rm -rf "$(STORE_BACKEND_DATA_DIR)"; mkdir -p "$(STORE_BACKEND_DATA_DIR)"; \
		cargo build --bin schlift --features test-auth; \
		DATA_DIR="$(STORE_BACKEND_DATA_DIR)" SEED_DEMO_USER=demo PORT=50051 \
		WEBAUTHN_RP_ID=schlift.com WEBAUTHN_RP_ORIGIN=https://schlift.com \
		nohup target/debug/schlift > "$(STORE_BACKEND_LOG)" 2>&1 & \
		echo $$! > "$(STORE_BACKEND_PID)"; \
		for i in $$(seq 1 60); do grep -q "Server listening" "$(STORE_BACKEND_LOG)" 2>/dev/null && break; sleep 1; done; \
		grep -q "Server listening" "$(STORE_BACKEND_LOG)" || { echo "backend did not start; see $(STORE_BACKEND_LOG)"; exit 1; }; \
		echo "store backend up (pid $$(cat $(STORE_BACKEND_PID)), demo account seeded)"; \
	'

store-backend-stop:
	@bash -ec '\
		if [ -f "$(STORE_BACKEND_PID)" ]; then \
			pid=$$(cat "$(STORE_BACKEND_PID)"); kill "$$pid" >/dev/null 2>&1 || true; rm -f "$(STORE_BACKEND_PID)"; \
			echo "store backend stopped"; \
		fi; \
	'

# store-capture: emulator up (dark mode, animations off) → seeded backend →
# drive app/integration_test/store_shots_test.dart → raw PNGs land in
# $(STORE_RAW_DIR). Commit them; CI frames and uploads.
store-capture:
	$(MAKE) android-emulator-start
	$(MAKE) android-emulator-wait
	$(MAKE) android-emulator-unlock
	$(ADB) -s $(ANDROID_SERIAL) shell cmd uimode night yes
	$(ADB) -s $(ANDROID_SERIAL) shell settings put global window_animation_scale 0
	$(ADB) -s $(ANDROID_SERIAL) shell settings put global transition_animation_scale 0
	$(ADB) -s $(ANDROID_SERIAL) shell settings put global animator_duration_scale 0
	$(MAKE) store-backend-start
	ADB="$(ADB)" DEVICE="$(ANDROID_SERIAL)" bash scripts/run_e2e.sh store_shots; rc=$$?; \
		$(MAKE) store-backend-stop; \
		[ $$rc -eq 0 ] || { echo "capture failed — see app/test_screenshots/store_shots.drive.log"; exit $$rc; }
	@mkdir -p "$(STORE_RAW_DIR)"
	@rm -f "$(STORE_RAW_DIR)"/store_*.png
	@cp app/test_screenshots/store_[0-9]*.png "$(STORE_RAW_DIR)"/
	@ls "$(STORE_RAW_DIR)"/store_*.png
	@echo "raw screenshots updated in $(STORE_RAW_DIR) — review, then commit"

# store-frame: render the framed store images locally (same script CI runs).
store-frame:
	@[ -x "$(STORE_VENV)/bin/python" ] || { python3 -m venv "$(STORE_VENV)" && "$(STORE_VENV)/bin/pip" install --quiet playwright pyyaml && "$(STORE_VENV)/bin/python" -m playwright install chromium; }
	"$(STORE_VENV)/bin/python" scripts/frame_store_screenshots.py

# store-check: the listing-text and release-notes checks CI runs.
store-check:
	python3 scripts/check_store_text.py
	python3 scripts/check_release_notes.py

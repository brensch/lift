# Flutter app: phone targets, linux desktop, icons, deps.
# Split from the top-level Makefile; variables live there.

.PHONY: dev test-app run-web-dev run-frontend run-app run-android run-android-prod run-android-clean \
	hot-reload hot-reload-on-save hot-restart run-linux stop-app setup-flutter install-deps check-android-java \
	icons copy sounds brand deploy-android deploy-android-dev

# The fast loop. The backend under cargo watch (rebuilds and restarts when
# Rust is saved; log in $(DEV_BACKEND_LOG)), a debug build on the phone, and
# a hot reload whenever a file under app/lib is saved. R in this terminal or
# `make hot-restart` for a full restart.
#
# Wi-Fi adb drops the debug connection now and then while the app keeps
# running ("Lost connection to device"). flutter attach cannot find the app
# again under WSL (it relies on mDNS), so dev reruns run-android, an
# incremental build and install. Ctrl+C, or q (which ends the app), stops it
# all.
DEV_BACKEND_LOG = .tmp/dev-backend.log
DEBUG_APP_ID = com.brensch.schlift.debug
dev:
	@mkdir -p .tmp
	@echo "Backend log: $(DEV_BACKEND_LOG)"
	@bash -c '\
		$(PICK_PHONE) \
		trap "STOP=1" INT; \
		cleanup() { kill $$(jobs -p) 2>/dev/null; $(STOP_DEV_BACKEND); }; \
		trap cleanup EXIT; \
		$(MAKE) run-backend > "$(DEV_BACKEND_LOG)" 2>&1 & \
		$(MAKE) hot-reload-on-save & \
		$(MAKE) run-android PHONE_SERIAL="$$SERIAL"; \
		app_alive() { for i in 1 2 3; do [ -n "$$(timeout 10 $(ADB) -s "$$SERIAL" shell pidof $(DEBUG_APP_ID) 2>/dev/null)" ] && return 0; done; return 1; }; \
		while [ -z "$$STOP" ] && app_alive; do \
			echo "Lost the debug connection with the app still running; starting it again."; \
			$(MAKE) run-android PHONE_SERIAL="$$SERIAL" || break; \
		done; \
	'
# Killing make does not reach the cargo watch and server under it.
STOP_DEV_BACKEND = pkill -f "[c]argo-watch watch $(firstword $(BACKEND_WATCH))"; $(STOP_LOCAL_BACKENDS)

# Backend + web dashboard dev server. `run-frontend` is the web half.
# The Dart tests, against the real core: the host build of app/native first.
test-app:
	cargo build -p schlift_native
	cd app && $(FLUTTER) test

run-web-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; $(MAKE) run-backend & $(MAKE) run-frontend & wait'

run-frontend:
	cd web && npm run dev

run-app:
	@$(MAKE) stop-app || true
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		mkdir -p "$(TMP_RUN_DIR)"; \
		ANDROID_DEVICE_ARGS=""; \
		if [ -x "$(ADB)" ]; then \
			while read -r DEVICE_ID DEVICE_STATE; do \
				[ "$$DEVICE_STATE" = "device" ] || continue; \
				CHARACTERISTICS=$$($(ADB) -s "$$DEVICE_ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r"); \
				if echo "$$CHARACTERISTICS" | grep -qi watch; then \
					echo "Skipping Wear OS device: $$DEVICE_ID"; \
					continue; \
				fi; \
				echo "Android device detected: $$DEVICE_ID"; \
				ANDROID_DEVICE_ARGS="$$ANDROID_DEVICE_ARGS -d $$DEVICE_ID"; \
				$(ADB) -s "$$DEVICE_ID" reverse tcp:50051 tcp:50051 || true; \
			done < <($(ADB) devices | awk "NR > 1 { print \$$1, \$$2 }"); \
		fi; \
		echo "Starting interactive Flutter hot-reload session (linux + non-watch android)..."; \
		cd app && $(FLUTTER) run -d linux $$ANDROID_DEVICE_ARGS --dart-define=INSTANCE=ubuntu; \
	'

# Debug build on the phone, attached, against the local backend through adb
# reverse. FLUTTER_RUN_ARGS adds flags (run-android-prod uses it). The pid
# file is what hot-reload / hot-restart signal.
FLUTTER_PID_FILE = $(CURDIR)/.tmp/flutter-run.pid
FLUTTER_RUN_ARGS ?=
# Sends signal $(1) to the run-android session, checking first that the pid
# in the file is still a flutter process and not a recycled one.
SIGNAL_FLUTTER = PID=$$(cat "$(FLUTTER_PID_FILE)" 2>/dev/null); \
	[ -n "$$PID" ] && grep -q flutter_tools "/proc/$$PID/cmdline" 2>/dev/null && kill -$(1) "$$PID"
run-android:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		$(PICK_PHONE) \
		$(ADB) -s "$$SERIAL" reverse tcp:50051 tcp:50051 || true; \
		mkdir -p "$(dir $(FLUTTER_PID_FILE))"; \
		rm -f "$(FLUTTER_PID_FILE)"; \
		cd app && $(FLUTTER) run -d "$$SERIAL" --pid-file "$(FLUTTER_PID_FILE)" $(FLUTTER_RUN_ARGS); \
	'

run-android-prod:
	$(MAKE) run-android FLUTTER_RUN_ARGS="--dart-define=SERVER_HOST=schlift.com --dart-define=SERVER_PORT=443"

run-android-clean:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		(cd app/android && ./gradlew :wear:clean :app:clean); \
		(cd app && $(FLUTTER) clean && $(FLUTTER) pub get); \
	'
	$(MAKE) run-android

# Hot reload / hot restart the running run-android session, the same as
# pressing r / R in its terminal. Dart changes only: native code, pubspec
# assets and --dart-define changes need a fresh run-android.
hot-reload:
	@$(call SIGNAL_FLUTTER,USR1) && echo "Hot reload sent" || { echo "No run-android session running"; exit 1; }

# Polls app/lib once a second and, after a save, hot reloads the run-android
# session; a save under lib/theme/, to main.dart or to lib/gen/ hot restarts
# instead: the themes and app wiring are built once at startup, and generated
# code (copy.dart's const classes, protos) changes shape, which a reload
# refuses. Runs as part of `make dev`.
hot-reload-on-save:
	@bash -c '\
		STAMP=$$(mktemp); \
		trap "rm -f $$STAMP" EXIT; \
		while sleep 1; do \
			CHANGED=$$(find app/lib -name "*.dart" -newer "$$STAMP"); \
			[ -n "$$CHANGED" ] || continue; \
			touch "$$STAMP"; \
			if echo "$$CHANGED" | grep -qE "app/lib/(theme/|gen/|main\.dart)"; then \
				$(call SIGNAL_FLUTTER,USR2) && echo "[hot restart]"; \
			else \
				$(call SIGNAL_FLUTTER,USR1) && echo "[hot reload]"; \
			fi; \
		done; \
	'

hot-restart:
	@$(call SIGNAL_FLUTTER,USR2) && echo "Hot restart sent" || { echo "No run-android session running"; exit 1; }

run-linux:
	@bash -ec '\
		mkdir -p "$(TMP_RUN_DIR)"; \
		SESSION_ROOT=$$(mktemp -d "$(PWD)/$(TMP_RUN_DIR)/linux-session-XXXXXX"); \
		SESSION_ID=$$(basename "$$SESSION_ROOT"); \
		mkdir -p "$$SESSION_ROOT/data" "$$SESSION_ROOT/config" "$$SESSION_ROOT/cache"; \
		echo "Starting interactive Flutter hot-reload session (linux)..."; \
		echo "Linux session id: $$SESSION_ID"; \
		echo "Linux session root: $$SESSION_ROOT"; \
		cd app && \
			XDG_DATA_HOME="$$SESSION_ROOT/data" \
			XDG_CONFIG_HOME="$$SESSION_ROOT/config" \
			XDG_CACHE_HOME="$$SESSION_ROOT/cache" \
			LIBGL_ALWAYS_SOFTWARE="$(LINUX_SOFTWARE_RENDER)" \
			$(FLUTTER) run -d linux --dart-define=INSTANCE=$$SESSION_ID; \
	'

stop-app:
	@echo "Stopping app processes..."
	@bash -ec '\
		if [ -d "$(TMP_RUN_DIR)" ]; then \
			for pidfile in "$(TMP_RUN_DIR)"/*.pid; do \
				[ -f "$$pidfile" ] || continue; \
				pid=$$(cat "$$pidfile" 2>/dev/null || true); \
				[ -n "$$pid" ] && kill "$$pid" 2>/dev/null || true; \
				rm -f "$$pidfile"; \
			done; \
		fi; \
		pkill -f "[/]app/build/linux/x64/debug/bundle/schlift" 2>/dev/null || true; \
		pkill -f "[/]flutter-sdk/bin/flutter.*run -d" 2>/dev/null || true; \
	'

setup-flutter:
	$(FLUTTER) config --enable-custom-devices
	mkdir -p $(HOME)/.config/flutter
	cp .flutter/custom_devices.json $(HOME)/.config/flutter/custom_devices.json

TMP_RUN_DIR = .tmp/run-app
LINUX_SOFTWARE_RENDER ?= 1

install-deps:
	@echo "=== Installing Linux build dependencies ==="
	sudo apt-get update
	sudo apt-get install -y cmake ninja-build clang lld libgtk-3-dev pkg-config protobuf-compiler curl git unzip openjdk-17-jdk
	@echo "=== Installing Flutter SDK ==="
	@if [ ! -d "$(HOME)/flutter-sdk" ]; then \
		git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $(HOME)/flutter-sdk; \
	else \
		echo "Flutter SDK already installed at $(HOME)/flutter-sdk"; \
	fi
	@echo "=== Flutter doctor ==="
	$(FLUTTER) doctor
	@echo "=== Installing Dart protoc plugin ==="
	$(DART) pub global activate protoc_plugin
	@echo "=== Installing Flutter app dependencies ==="
	cd app && $(FLUTTER) pub get
	@echo "=== Installing web dependencies ==="
	cd web && npm install
	@echo "=== Checking Android Java toolchain ==="
	$(MAKE) check-android-java
	@echo "=== Done ==="
	@echo ""
	@echo "Optional: add Flutter to your PATH permanently:"
	@echo '  echo '\''export PATH="$(HOME)/flutter-sdk/bin:$$PATH"'\'' >> ~/.bashrc'

check-android-java:
	@bash -ec '\
		if ! command -v java >/dev/null 2>&1; then \
			echo "java not found"; \
			exit 1; \
		fi; \
		if ! command -v javac >/dev/null 2>&1; then \
			echo "javac not found (install a full JDK, not just a JRE)"; \
			exit 1; \
		fi; \
		JAVA_REAL=$$(readlink -f "$$(command -v java)"); \
		JAVAC_REAL=$$(readlink -f "$$(command -v javac)"); \
		JAVA_HOME_REAL="$$(dirname "$$(dirname "$$JAVA_REAL")")"; \
		JAVAC_HOME_REAL="$$(dirname "$$(dirname "$$JAVAC_REAL")")"; \
		echo "java  -> $$JAVA_REAL"; \
		echo "javac -> $$JAVAC_REAL"; \
		echo "JAVA_HOME (from javac) -> $$JAVAC_HOME_REAL"; \
		if [ "$$JAVA_HOME_REAL" != "$$JAVAC_HOME_REAL" ]; then \
			echo "Warning: java and javac come from different installs."; \
			echo "Android make targets will use JAVA_HOME=$$JAVAC_HOME_REAL"; \
		fi; \
		"$$JAVAC_HOME_REAL/bin/javac" -version; \
	'

# icons: regenerate every platform icon. With ICON_SOURCE=<1024 png> the
# rendered master (see `make brand`) becomes the icon everywhere; without it
# the old procedural barbell is drawn.
icons:
	@echo "=== Regenerating app icons ==="
	python3 scripts/replace_app_icons.py $(if $(ICON_SOURCE),--source $(ICON_SOURCE))
	@echo "Done."

# copy: regenerate app/lib/gen/copy.dart from app/copy.yaml (all in-app copy
# that has been moved to the YAML so far). CI checks it is up to date.
copy:
	python3 scripts/gen_copy.py

# sounds: mirror app/assets/sounds into the Android raw resources, the iOS
# bundle and the Xcode project. CI checks nothing is stale.
sounds:
	python3 scripts/sync_sounds.py

# brand: render the icon and feature-graphic candidates from
# scripts/render_brand.py into marketing/. Pick one, then
#   make icons ICON_SOURCE=marketing/icons/candidates/<name>.png
#   cp marketing/feature_graphic_candidates/<name>.png marketing/feature_graphic.png
STORE_VENV ?= .tmp/store-venv
brand:
	@[ -x "$(STORE_VENV)/bin/python" ] || { python3 -m venv "$(STORE_VENV)" && "$(STORE_VENV)/bin/pip" install --quiet playwright pyyaml && "$(STORE_VENV)/bin/python" -m playwright install chromium; }
	"$(STORE_VENV)/bin/python" scripts/render_brand.py

# Release APK of the production package com.brensch.schlift, for an emulator
# or a phone without the Play install. Play re-signs its installs, so on a
# phone with the real app this fails with a signature mismatch. It never
# uninstalls anything to get past that.
deploy-android:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		$(PICK_PHONE) \
		$(DEVICE_TARGET_PLATFORM) \
		(cd app && $(FLUTTER) build apk --release --target-platform $$PLATFORM); \
		$(ADB) -s "$$SERIAL" install -r app/build/app/outputs/flutter-apk/app-release.apk; \
	'

# The side-by-side dev app (com.brensch.schlift.dev, "Schlift Dev", talks to
# dev.schlift.com), built and installed from this machine. This is the local
# twin of .github/workflows/android-dev-release.yml: same package, same
# release key, so it upgrades the installed dev app in place and keeps its
# login. Needs app/android/key.properties + the keystore (gitignored — a
# fresh git worktree will not have them).
#
# The build number is one more than whatever is installed, so adb never sees
# a downgrade. There is deliberately no uninstall fallback: a failed install
# is reported, never "fixed" by wiping the app.
DEV_SERVER_HOST ?= dev.schlift.com
DEV_APP_ID = com.brensch.schlift.dev
deploy-android-dev:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		$(PICK_PHONE) \
		$(DEVICE_TARGET_PLATFORM) \
		if [ ! -f app/android/key.properties ]; then \
			echo "Missing app/android/key.properties (release signing). In a git worktree, copy it and the keystore from the main checkout."; \
			exit 1; \
		fi; \
		INSTALLED=$$($(ADB) -s "$$SERIAL" shell dumpsys package $(DEV_APP_ID) </dev/null 2>/dev/null | grep -o "versionCode=[0-9]*" | head -1 | cut -d= -f2); \
		CODE=$$(( $${INSTALLED:-500100} + 1 )); \
		NAME=$$(git describe --tags --match "v*" --abbrev=0 2>/dev/null | sed "s/^v//"); \
		echo "Building $(DEV_APP_ID) $${NAME:-0.0.0}+$$CODE ($$PLATFORM) for $$SERIAL (backend: $(DEV_SERVER_HOST))"; \
		(cd app && SCHLIFT_DEV=1 $(FLUTTER) build apk --release --target-platform $$PLATFORM \
			--build-name="$${NAME:-0.0.0}" --build-number="$$CODE" \
			--dart-define=GIT_HASH=$$(git rev-parse --short HEAD) \
			--dart-define=SERVER_HOST=$(DEV_SERVER_HOST) \
			--dart-define=SERVER_PORT=443); \
		$(ADB) -s "$$SERIAL" install -r app/build/app/outputs/flutter-apk/app-release.apk; \
	'

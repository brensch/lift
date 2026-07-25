# Flutter app: phone targets, linux desktop, icons, deps.
# Split from the top-level Makefile; variables live there.

run-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; make run-backend & make run-frontend & wait'

run-frontend:
	cd web && npm run dev

define EXPORT_JAVA_HOME_FROM_JAVAC
	if command -v javac >/dev/null 2>&1; then \
		JAVAC_REAL=$$(readlink -f "$$(command -v javac)"); \
		export JAVA_HOME="$$(dirname "$$(dirname "$$JAVAC_REAL")")"; \
		echo "Using JAVA_HOME=$$JAVA_HOME (from javac)"; \
	else \
		echo "javac not found. Install a full JDK (e.g. openjdk-17-jdk or openjdk-21-jdk)."; \
		exit 1; \
	fi; \
	if [ ! -x "$$JAVA_HOME/bin/javac" ]; then \
		echo "JAVA_HOME does not contain javac: $$JAVA_HOME"; \
		exit 1; \
	fi; \
	true;
endef

run-app:
	@make stop-app || true
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		mkdir -p "$(TMP_RUN_DIR)"; \
		if [ ! -x "$(ADB)" ]; then \
			echo "adb not found at $(ADB); launching Flutter multi-device without adb prep."; \
			ANDROID_DEVICE_ARGS=""; \
		else \
			ANDROID_DEVICE_ARGS=""; \
			while read -r DEVICE_ID DEVICE_STATE; do \
				[ "$$DEVICE_STATE" = "device" ] || continue; \
				CHARACTERISTICS=$$($(ADB) -s "$$DEVICE_ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
				MODEL=$$($(ADB) -s "$$DEVICE_ID" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d "\r"); \
				if echo "$$CHARACTERISTICS" | grep -q "watch"; then \
					echo "Skipping Wear OS device: $$DEVICE_ID ($$MODEL)"; \
					continue; \
				fi; \
				echo "Android device detected: $$DEVICE_ID ($$MODEL)"; \
				ANDROID_DEVICE_ARGS="$$ANDROID_DEVICE_ARGS -d $$DEVICE_ID"; \
				$(ADB) -s "$$DEVICE_ID" reverse tcp:50051 tcp:50051 || true; \
			done < <($(ADB) devices | awk '\''NR > 1 { print $$1, $$2 }'\''); \
			if [ -z "$$ANDROID_DEVICE_ARGS" ]; then \
				echo "No non-watch Android device found; launching Linux only."; \
			fi; \
		fi; \
		echo "Starting interactive Flutter hot-reload session (linux + non-watch android)..."; \
		if [ -n "$$ANDROID_DEVICE_ARGS" ]; then \
			cd app && $(FLUTTER) run -d linux $$ANDROID_DEVICE_ARGS --dart-define=INSTANCE=ubuntu; \
		else \
			cd app && $(FLUTTER) run -d linux --dart-define=INSTANCE=ubuntu; \
		fi; \
	'

run-android:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		SERIAL=$$($(ADB) devices | awk '\''NR > 1 && $$2 == "device" { print $$1 }'\'' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if ! echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
		if [ -z "$$SERIAL" ]; then \
			echo "No non-watch Android device found."; \
			$(ADB) devices; \
			exit 1; \
		fi; \
		echo "Using Android target: $$SERIAL"; \
		$(ADB) -s "$$SERIAL" reverse tcp:50051 tcp:50051 || true; \
		cd app && $(FLUTTER) run -d "$$SERIAL"; \
	'

run-android-prod:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		SERIAL=$$($(ADB) devices | awk '\''NR > 1 && $$2 == "device" { print $$1 }'\'' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if ! echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
		if [ -z "$$SERIAL" ]; then \
			echo "No non-watch Android device found."; \
			$(ADB) devices; \
			exit 1; \
		fi; \
		echo "Using Android target: $$SERIAL"; \
		cd app && $(FLUTTER) run -d "$$SERIAL" --dart-define=SERVER_HOST=schlift.com --dart-define=SERVER_PORT=443; \
	'

run-android-clean:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		SERIAL=$$($(ADB) devices | awk '\''NR > 1 && $$2 == "device" { print $$1 }'\'' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if ! echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
		if [ -z "$$SERIAL" ]; then \
			echo "No non-watch Android device found."; \
			$(ADB) devices; \
			exit 1; \
		fi; \
		echo "Using Android target: $$SERIAL"; \
		(cd app/android && ./gradlew :wear:clean :app:clean); \
		(cd app && $(FLUTTER) clean); \
		(cd app && $(FLUTTER) pub get); \
		$(ADB) -s "$$SERIAL" reverse tcp:50051 tcp:50051 || true; \
		(cd app && $(FLUTTER) run -d "$$SERIAL"); \
	'

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
LINUX_BUNDLE = app/build/linux/x64/debug/bundle/schlift
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

icons:
	@echo "=== Regenerating app icons and marketing assets ==="
	python3 scripts/replace_app_icons.py
	python3 scripts/replace_app_icons2.py
	@echo "Done."

# ── Apple Watch (SchliftWatch) ───────────────────────────────────────────

deploy-android:
	cd app && $(FLUTTER) build apk --release
	@SERIAL="$$($(ADB) devices | awk 'NR > 1 && $$2 == "device" { print $$1 }' | while read -r ID; do \
		CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
		if ! echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
	done)"; \
	if [ -z "$$SERIAL" ]; then \
		echo "No non-watch Android device found."; \
		$(ADB) devices; \
		exit 1; \
	fi; \
	echo "Deploying android release to: $$SERIAL"; \
	if ! $(ADB) -s "$$SERIAL" install -r app/build/app/outputs/flutter-apk/app-release.apk; then \
		echo "Release install failed. Retrying with uninstall (signature mismatch fallback)..."; \
		$(ADB) -s "$$SERIAL" uninstall com.brensch.schlift || true; \
		$(ADB) -s "$$SERIAL" install app/build/app/outputs/flutter-apk/app-release.apk || exit 1; \
	fi

# Headless screenshot harness: drives the real app against a real backend and
# captures a legible screenshot of each screen into app/test_screenshots/, plus
# an HTML report. The runner ends via a timeout (a live-gRPC app never lets the
# fake-async test loop idle) — the artifacts, not the exit code, are the product,
# so success = a report was produced. See app/test/e2e/README.md.
e2e-screens:
	@rm -rf app/test_screenshots
	-cd app && timeout 120 $(FLUTTER) test test/e2e/ --tags e2e
	@test -f app/test_screenshots/*/report.html 2>/dev/null && \
		echo "\n✓ screenshots: app/test_screenshots/*/report.html" || \
		{ echo "\n✗ no screenshots produced"; exit 1; }

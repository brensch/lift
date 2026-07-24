.PHONY: fuzz-api fuzz-api-ci run-dev run-backend run-backend-release run-frontend run-app run-android run-android-prod run-android-clean run-linux run-wear run-wear-logs run-wear-debug run-prod check install-deps check-android-java proto-dart proto-android proto-swift proto-all icons print-cert-hashes ci-android-prepare-signing ci-android-check-signing ci-android-build-release ci-android-release-local ci-android-clean-signing build-wear-release deploy-wear build-aabs-release android-sdk-check android-phone-avd-create android-phone-play-avd-create android-phone-play-emulator-start android-wear-avd-create android-emulator-start android-emulator-stop android-emulator-wait android-emulator-unlock android-emulator-reverse android-screenshot android-tap android-text android-run-emulator agent-backend-start agent-backend-stop android-agent-start android-agent-stop android-wear-emulator-start android-wear-run-emulator android-wear-pairing-notes watch-setup watch-generate watch-build watch-build-release watch-sim watch-sim-list

FLUTTER = $(HOME)/flutter-sdk/bin/flutter
DART = $(HOME)/flutter-sdk/bin/dart
BUN = $(HOME)/.bun/bin/bun
RELEASE_ENV_FILE ?= .env
AAB_OUT_DIR ?= aab

ANDROID_SDK ?= $(HOME)/android-sdk
ANDROID_HOME ?= $(ANDROID_SDK)
ANDROID_PLATFORM ?= android-34
ANDROID_PHONE_AVD ?= lift_api34
ANDROID_PHONE_PLAY_AVD ?= lift_api34_play
ANDROID_WEAR_AVD ?= lift_wear_api34
ANDROID_PHONE_IMAGE ?= system-images;$(ANDROID_PLATFORM);google_apis;x86_64
ANDROID_PHONE_PLAY_IMAGE ?= system-images;$(ANDROID_PLATFORM);google_apis_playstore;x86_64
ANDROID_WEAR_IMAGE ?= system-images;$(ANDROID_PLATFORM);android-wear;x86_64
ANDROID_PHONE_DEVICE ?= pixel_6
ANDROID_WEAR_DEVICE ?= wearos_large_round
ANDROID_SERIAL ?= emulator-5554
ANDROID_SCREENSHOT_OUT ?= .tmp/screenshots/android.png
ANDROID_EMULATOR_WINDOW ?= 0
ANDROID_EMULATOR_EXTRA_ARGS ?=
ANDROID_EMULATOR_HEADLESS_ARGS = -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -camera-back none -camera-front none
ANDROID_EMULATOR_VISIBLE_ARGS = -no-audio -gpu swiftshader_indirect -camera-back none -camera-front none
ANDROID_EMULATOR_ARGS = $(if $(filter 1 true yes,$(ANDROID_EMULATOR_WINDOW)),$(ANDROID_EMULATOR_VISIBLE_ARGS),$(ANDROID_EMULATOR_HEADLESS_ARGS)) $(ANDROID_EMULATOR_EXTRA_ARGS)
ANDROID_AVDMANAGER = $(ANDROID_SDK)/cmdline-tools/latest/bin/avdmanager
ANDROID_SDKMANAGER = $(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager
ANDROID_EMULATOR = $(ANDROID_SDK)/emulator/emulator
ADB = $(ANDROID_SDK)/platform-tools/adb
AGENT_TMP_DIR ?= .tmp/agent-android
AGENT_BACKEND_DATA_DIR ?= $(AGENT_TMP_DIR)/data
AGENT_BACKEND_LOG ?= $(AGENT_TMP_DIR)/backend.log

# Debug keystore config
DEBUG_KEYSTORE = $(HOME)/.android/debug.keystore
DEBUG_ALIAS = androiddebugkey
DEBUG_STOREPASS = android

run-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; make run-backend & make run-frontend & wait'

run-backend:
	@pkill -f "[/]target/debug/schlift" || true
	@pkill -f "[/]target/release/schlift" || true
	RUST_LOG=info \
	WEBAUTHN_RP_ID=schlift.com \
	WEBAUTHN_RP_ORIGIN=https://schlift.com \
	TEST_AUTH_ENABLED=1 \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='),android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo watch -x "run --bin schlift --features test-auth"

run-backend-release:
	@pkill -f "[/]target/debug/schlift" || true
	@pkill -f "[/]target/release/schlift" || true
	RUST_LOG=info \
	WEBAUTHN_RP_ID=schlift.com \
	WEBAUTHN_RP_ORIGIN=https://schlift.com \
	TEST_AUTH_ENABLED=1 \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='),android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo run --release --bin schlift --features test-auth

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

android-sdk-check:
	@bash -ec '\
		for path in "$(ANDROID_SDKMANAGER)" "$(ANDROID_AVDMANAGER)" "$(ANDROID_EMULATOR)" "$(ADB)" "$(FLUTTER)"; do \
			if [ ! -x "$$path" ]; then \
				echo "Missing executable: $$path"; \
				exit 1; \
			fi; \
		done; \
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		echo "ANDROID_SDK=$(ANDROID_SDK)"; \
		echo "JAVA_HOME=$$JAVA_HOME"; \
		if [ -e /dev/kvm ]; then \
			ls -l /dev/kvm; \
		else \
			echo "Warning: /dev/kvm is missing; emulator boot may be very slow or fail."; \
		fi; \
		$(FLUTTER) doctor -v; \
	'

android-phone-avd-create: android-sdk-check
	@bash -ec '\
		"$(ANDROID_SDKMANAGER)" "platform-tools" "emulator" "platforms;$(ANDROID_PLATFORM)" "$(ANDROID_PHONE_IMAGE)"; \
		if "$(ANDROID_EMULATOR)" -list-avds | grep -qx "$(ANDROID_PHONE_AVD)"; then \
			echo "Phone AVD already exists: $(ANDROID_PHONE_AVD)"; \
		else \
			printf "no\n" | "$(ANDROID_AVDMANAGER)" create avd --force \
				--name "$(ANDROID_PHONE_AVD)" \
				--package "$(ANDROID_PHONE_IMAGE)" \
				--device "$(ANDROID_PHONE_DEVICE)"; \
		fi; \
	'

android-phone-play-avd-create: android-sdk-check
	@bash -ec '\
		"$(ANDROID_SDKMANAGER)" "platform-tools" "emulator" "platforms;$(ANDROID_PLATFORM)" "$(ANDROID_PHONE_PLAY_IMAGE)"; \
		if "$(ANDROID_EMULATOR)" -list-avds | grep -qx "$(ANDROID_PHONE_PLAY_AVD)"; then \
			echo "Play Store phone AVD already exists: $(ANDROID_PHONE_PLAY_AVD)"; \
		else \
			printf "no\n" | "$(ANDROID_AVDMANAGER)" create avd --force \
				--name "$(ANDROID_PHONE_PLAY_AVD)" \
				--package "$(ANDROID_PHONE_PLAY_IMAGE)" \
				--device "$(ANDROID_PHONE_DEVICE)"; \
		fi; \
	'

android-phone-play-emulator-start:
	$(MAKE) android-emulator-start \
		ANDROID_PHONE_AVD="$(ANDROID_PHONE_PLAY_AVD)" \
		ANDROID_PHONE_IMAGE="$(ANDROID_PHONE_PLAY_IMAGE)"

android-wear-avd-create: android-sdk-check
	@bash -ec '\
		"$(ANDROID_SDKMANAGER)" "platform-tools" "emulator" "platforms;$(ANDROID_PLATFORM)" "$(ANDROID_WEAR_IMAGE)"; \
		if "$(ANDROID_EMULATOR)" -list-avds | grep -qx "$(ANDROID_WEAR_AVD)"; then \
			echo "Wear AVD already exists: $(ANDROID_WEAR_AVD)"; \
		else \
			printf "no\n" | "$(ANDROID_AVDMANAGER)" create avd --force \
				--name "$(ANDROID_WEAR_AVD)" \
				--package "$(ANDROID_WEAR_IMAGE)" \
				--device "$(ANDROID_WEAR_DEVICE)"; \
		fi; \
	'

android-emulator-start: android-phone-avd-create
	@bash -ec '\
		mkdir -p "$(AGENT_TMP_DIR)/logs"; \
		if "$(ADB)" -s "$(ANDROID_SERIAL)" get-state >/dev/null 2>&1; then \
			echo "Android emulator already online: $(ANDROID_SERIAL)"; \
			exit 0; \
		fi; \
		echo "Starting AVD $(ANDROID_PHONE_AVD) as $(ANDROID_SERIAL)"; \
		nohup "$(ANDROID_EMULATOR)" @"$(ANDROID_PHONE_AVD)" $(ANDROID_EMULATOR_ARGS) \
			> "$(AGENT_TMP_DIR)/logs/$(ANDROID_PHONE_AVD).log" 2>&1 & \
		echo $$! > "$(AGENT_TMP_DIR)/$(ANDROID_PHONE_AVD).pid"; \
		echo "Emulator log: $(AGENT_TMP_DIR)/logs/$(ANDROID_PHONE_AVD).log"; \
	'

android-emulator-stop:
	@bash -ec '\
		"$(ADB)" -s "$(ANDROID_SERIAL)" emu kill >/dev/null 2>&1 || true; \
		if [ -f "$(AGENT_TMP_DIR)/$(ANDROID_PHONE_AVD).pid" ]; then \
			pid=$$(cat "$(AGENT_TMP_DIR)/$(ANDROID_PHONE_AVD).pid"); \
			kill "$$pid" >/dev/null 2>&1 || true; \
			rm -f "$(AGENT_TMP_DIR)/$(ANDROID_PHONE_AVD).pid"; \
		fi; \
	'

android-emulator-wait:
	@bash -ec '\
		"$(ADB)" -s "$(ANDROID_SERIAL)" wait-for-device; \
		for i in $$(seq 1 90); do \
			boot=$$("$(ADB)" -s "$(ANDROID_SERIAL)" shell getprop sys.boot_completed 2>/dev/null | tr -d "\r"); \
			if [ "$$boot" = "1" ]; then \
				echo "Android emulator booted: $(ANDROID_SERIAL)"; \
				"$(ADB)" -s "$(ANDROID_SERIAL)" shell wm size || true; \
				exit 0; \
			fi; \
			sleep 2; \
		done; \
		echo "Timed out waiting for $(ANDROID_SERIAL) to boot"; \
		exit 1; \
	'

android-emulator-unlock:
	@bash -ec '\
		"$(ADB)" -s "$(ANDROID_SERIAL)" shell settings put system screen_off_timeout 2147483647 || true; \
		"$(ADB)" -s "$(ANDROID_SERIAL)" shell input keyevent 82 || true; \
	'

android-emulator-reverse:
	$(ADB) -s $(ANDROID_SERIAL) reverse tcp:50051 tcp:50051

android-screenshot:
	@mkdir -p "$$(dirname "$(ANDROID_SCREENSHOT_OUT)")"
	$(ADB) -s $(ANDROID_SERIAL) exec-out screencap -p > "$(ANDROID_SCREENSHOT_OUT)"
	@file "$(ANDROID_SCREENSHOT_OUT)"

android-tap:
	@test -n "$(X)" -a -n "$(Y)" || { echo "Usage: make android-tap X=540 Y=1300 [ANDROID_SERIAL=...]"; exit 1; }
	$(ADB) -s $(ANDROID_SERIAL) shell input tap $(X) $(Y)

android-text:
	@test -n "$(TEXT)" || { echo "Usage: make android-text TEXT=codex [ANDROID_SERIAL=...]"; exit 1; }
	$(ADB) -s $(ANDROID_SERIAL) shell input text "$(TEXT)"

android-run-emulator: android-emulator-reverse
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		cd app && \
			ANDROID_HOME="$(ANDROID_SDK)" \
			PATH="$(ANDROID_SDK)/platform-tools:$(ANDROID_SDK)/emulator:$(ANDROID_SDK)/cmdline-tools/latest/bin:$$PATH" \
			"$(FLUTTER)" run -d "$(ANDROID_SERIAL)" --debug --no-resident; \
	'

agent-backend-start:
	@bash -ec '\
		mkdir -p "$(AGENT_TMP_DIR)" "$(AGENT_BACKEND_DATA_DIR)"; \
		if [ -f "$(AGENT_TMP_DIR)/backend.pid" ]; then \
			pid=$$(cat "$(AGENT_TMP_DIR)/backend.pid" 2>/dev/null || true); \
			if [ -n "$$pid" ] && kill -0 "$$pid" >/dev/null 2>&1; then \
				echo "Backend already running with pid $$pid"; \
				exit 0; \
			fi; \
		fi; \
		APK_HASH=$$(keytool -exportcert -keystore "$(DEBUG_KEYSTORE)" -alias "$(DEBUG_ALIAS)" -storepass "$(DEBUG_STOREPASS)" 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr "+/" "-_" | tr -d "=" || true); \
		CERT_SHA=$$(keytool -list -v -keystore "$(DEBUG_KEYSTORE)" -alias "$(DEBUG_ALIAS)" -storepass "$(DEBUG_STOREPASS)" 2>/dev/null | grep SHA256 | head -1 | sed "s/.*SHA256: //" || true); \
		echo "Starting backend on localhost:50051"; \
		DATA_DIR="$(AGENT_BACKEND_DATA_DIR)" \
		RUST_LOG=info \
		TEST_AUTH_ENABLED=1 \
		WEBAUTHN_RP_ID=schlift.com \
		WEBAUTHN_RP_ORIGIN=https://schlift.com \
		WEBAUTHN_ANDROID_ORIGIN="android:apk-key-hash:$$APK_HASH" \
		WEBAUTHN_ANDROID_ORIGINS="android:apk-key-hash:$$APK_HASH,android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk" \
		ANDROID_CERT_SHA256="$$CERT_SHA" \
		cargo run --bin schlift --features test-auth > "$(AGENT_BACKEND_LOG)" 2>&1 & \
		echo $$! > "$(AGENT_TMP_DIR)/backend.pid"; \
		for i in $$(seq 1 120); do \
			if curl -fsS http://127.0.0.1:50051/api/health >/dev/null 2>&1; then \
				echo "Backend ready: http://127.0.0.1:50051/api/health"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "Backend did not become healthy. Tail of $(AGENT_BACKEND_LOG):"; \
		tail -80 "$(AGENT_BACKEND_LOG)" || true; \
		exit 1; \
	'

agent-backend-stop:
	@bash -ec '\
		if [ -f "$(AGENT_TMP_DIR)/backend.pid" ]; then \
			pid=$$(cat "$(AGENT_TMP_DIR)/backend.pid" 2>/dev/null || true); \
			[ -n "$$pid" ] && kill "$$pid" >/dev/null 2>&1 || true; \
			rm -f "$(AGENT_TMP_DIR)/backend.pid"; \
		fi; \
	'

android-agent-start:
	$(MAKE) agent-backend-start
	$(MAKE) android-emulator-start
	$(MAKE) android-emulator-wait
	$(MAKE) android-emulator-unlock
	$(MAKE) android-emulator-reverse
	$(MAKE) android-run-emulator
	$(MAKE) android-screenshot ANDROID_SCREENSHOT_OUT=.tmp/screenshots/android-agent-start.png

android-agent-stop: agent-backend-stop android-emulator-stop

android-wear-emulator-start: android-wear-avd-create
	@bash -ec '\
		mkdir -p "$(AGENT_TMP_DIR)/logs"; \
		WATCH_SERIAL=$$("$(ADB)" devices | awk '\''NR > 1 && $$2 == "device" { print $$1 }'\'' | while read -r ID; do \
			CH=$$("$(ADB)" -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
		if [ -n "$$WATCH_SERIAL" ]; then \
			echo "Wear emulator already online: $$WATCH_SERIAL"; \
			exit 0; \
		fi; \
		echo "Starting Wear AVD $(ANDROID_WEAR_AVD)"; \
		nohup "$(ANDROID_EMULATOR)" @"$(ANDROID_WEAR_AVD)" $(ANDROID_EMULATOR_ARGS) \
			> "$(AGENT_TMP_DIR)/logs/$(ANDROID_WEAR_AVD).log" 2>&1 & \
		echo $$! > "$(AGENT_TMP_DIR)/$(ANDROID_WEAR_AVD).pid"; \
		echo "Wear emulator log: $(AGENT_TMP_DIR)/logs/$(ANDROID_WEAR_AVD).log"; \
	'

android-wear-run-emulator: android-wear-emulator-start
	@bash -ec '\
		SERIAL=""; \
		for i in $$(seq 1 120); do \
			SERIAL=$$("$(ADB)" devices | awk '\''NR > 1 && $$2 == "device" { print $$1 }'\'' | while read -r ID; do \
				CH=$$("$(ADB)" -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
				if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
			done); \
			if [ -n "$$SERIAL" ]; then break; fi; \
			sleep 2; \
		done; \
		if [ -z "$$SERIAL" ]; then \
			echo "Timed out waiting for a Wear OS emulator"; \
			"$(ADB)" devices; \
			exit 1; \
		fi; \
		echo "Using Wear target: $$SERIAL"; \
		$(MAKE) run-wear WEAR_SERIAL="$$SERIAL"; \
	'

android-wear-pairing-notes:
	@printf '%s\n' \
		'Wear OS emulator pairing status:' \
		'' \
		'- Yes, Android supports pairing a Wear emulator with a phone device/emulator.' \
		'- Current Android docs require a phone on Android 11+ with the Google Play Store' \
		'  for the Wear OS emulator pairing assistant.' \
		'- This repo can create:' \
		'    make android-phone-play-avd-create' \
		'    make android-wear-avd-create' \
		'- To pair those two AVDs, use Android Studio Device Manager -> Pair Wearable.' \
		'  Android Studio is not installed in this WSL environment right now.' \
		'- Command-line-only automation can still boot both emulators, install both APKs,' \
		'  screenshot them, and tap/type through adb. It does not establish the official' \
		'  Google Play Services Wear node connection by itself.' \
		'- For a physical watch, use wireless debugging:' \
		'    adb pair <watch_ip>:<pair_port>' \
		'    adb connect <watch_ip>:<debug_port>' \
		'    WEAR_SERIAL=<watch_ip>:<debug_port> make run-wear'

WEAR_SERIAL ?=
WEAR_LOG_FILTER ?= SchliftWear:D SchliftWearBridge:D Wearable:D WearTransport:D *:S

run-wear:
	@SERIAL="$(WEAR_SERIAL)"; \
	if [ -z "$$SERIAL" ]; then \
		SERIAL=$$($(ADB) devices | awk 'NR>1 && $$2=="device" {print $$1}' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
	fi; \
	if [ -z "$$SERIAL" ]; then \
		echo "No connected Wear OS device found."; \
		$(ADB) devices; \
		exit 1; \
	fi; \
	echo "Using wear target: $$SERIAL"; \
	cd app/android && bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		GRADLE_CMD="./gradlew"; \
		if [ ! -x "$$GRADLE_CMD" ]; then \
			PROP_FILE="gradle/wrapper/gradle-wrapper.properties"; \
			if [ ! -f "$$PROP_FILE" ]; then \
				echo "Missing $$PROP_FILE and no ./gradlew present."; \
				exit 1; \
			fi; \
			DIST_URL=$$(sed -n '\''s/^distributionUrl=//p'\'' "$$PROP_FILE" | sed '\''s#\\:##g'\''); \
			VER=$$(echo "$$DIST_URL" | sed -E '\''s#.*gradle-([0-9.]+)-.*#\1#'\''); \
			ROOT_DIR="$$(cd ../.. && pwd)"; \
			CACHE_DIR="$$ROOT_DIR/.tmp/gradle-$$VER"; \
			ZIP_PATH="$$ROOT_DIR/.tmp/gradle-$$VER-bin.zip"; \
			GRADLE_CMD="$$CACHE_DIR/bin/gradle"; \
			if [ ! -x "$$GRADLE_CMD" ]; then \
				echo "Bootstrapping Gradle $$VER from $$DIST_URL"; \
				mkdir -p "$$ROOT_DIR/.tmp"; \
				curl -fsSL "$$DIST_URL" -o "$$ZIP_PATH"; \
				unzip -qo "$$ZIP_PATH" -d "$$ROOT_DIR/.tmp"; \
			fi; \
		fi; \
		"$$GRADLE_CMD" :wear:assembleDebug; \
	'
	@if [ ! -f "app/build/wear/outputs/apk/debug/wear-debug.apk" ]; then \
		echo "Wear APK not found at app/build/wear/outputs/apk/debug/wear-debug.apk"; \
		echo "Check Gradle output and try again."; \
		exit 1; \
	fi
	@SERIAL="$(WEAR_SERIAL)"; \
	if [ -z "$$SERIAL" ]; then \
		SERIAL=$$($(ADB) devices | awk 'NR>1 && $$2=="device" {print $$1}' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
	fi; \
	$(ADB) -s "$$SERIAL" install -r app/build/wear/outputs/apk/debug/wear-debug.apk; \
	$(ADB) -s "$$SERIAL" shell am start -n com.brensch.schlift/com.brensch.schlift.wear.MainActivity

run-wear-logs:
	@SERIAL="$(WEAR_SERIAL)"; \
	if [ -z "$$SERIAL" ]; then \
		SERIAL=$$($(ADB) devices | awk 'NR>1 && $$2=="device" {print $$1}' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
	fi; \
	if [ -z "$$SERIAL" ]; then \
		echo "No connected Wear OS device found."; \
		$(ADB) devices; \
		exit 1; \
	fi; \
	echo "Streaming Wear logs from: $$SERIAL"; \
	echo "Filter: $(WEAR_LOG_FILTER)"; \
	$(ADB) -s "$$SERIAL" logcat -c || true; \
	$(ADB) -s "$$SERIAL" logcat $(WEAR_LOG_FILTER)

run-wear-debug:
	@bash -ec '\
		trap "kill 0" SIGINT SIGTERM EXIT; \
		$(MAKE) run-wear WEAR_SERIAL="$(WEAR_SERIAL)" & \
		sleep 2; \
		$(MAKE) run-wear-logs WEAR_SERIAL="$(WEAR_SERIAL)"; \
	'

setup-flutter:
	$(FLUTTER) config --enable-custom-devices
	mkdir -p $(HOME)/.config/flutter
	cp .flutter/custom_devices.json $(HOME)/.config/flutter/custom_devices.json

TMP_RUN_DIR = .tmp/run-app
LINUX_BUNDLE = app/build/linux/x64/debug/bundle/schlift
LINUX_SOFTWARE_RENDER ?= 1

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

run-backend-scratch:
	@pkill -f "[/]target/release/schlift" || true
	@rm -f data/scratch.sqlite data/scratch.sqlite-wal data/scratch.sqlite-shm
	RUST_LOG=info TEST_AUTH_ENABLED=1 cargo run --release --bin schlift --features test-auth

load-test:
	cargo run --release --example load_simulation -- --duration 3000

# Randomised API sequences against a throwaway backend, with invariant checks
# after every mutation. Spawns its own server on its own port and SQLite file,
# so it never touches a dev database. Non-zero exit on any violation.
fuzz-api:
	cargo run --release --example api_invariant_fuzz -- \
		--users $(or $(FUZZ_USERS),10) \
		--sessions $(or $(FUZZ_SESSIONS),14) \
		--seed $(or $(FUZZ_SEED),$(shell date +%s))

# A fixed-seed run small enough for CI.
fuzz-api-ci:
	cargo run --release --example api_invariant_fuzz -- \
		--users 6 --sessions 8 --seed 20240101

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

build-wear-release:
	cd app/android && ./gradlew :wear:assembleRelease

deploy-wear: build-wear-release
	@SERIAL="$(WEAR_SERIAL)"; \
	if [ -z "$$SERIAL" ]; then \
		SERIAL=$$($(ADB) devices | awk 'NR>1 && $$2=="device" {print $$1}' | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r" | tr "[:upper:]" "[:lower:]"); \
			if echo "$$CH" | grep -q "watch"; then echo "$$ID"; break; fi; \
		done); \
	fi; \
	if [ -z "$$SERIAL" ]; then \
		echo "No connected Wear OS device found."; \
		$(ADB) devices; \
		exit 1; \
	fi; \
	if [ ! -f "app/build/wear/outputs/apk/release/wear-release.apk" ]; then \
		echo "Wear release APK not found at app/build/wear/outputs/apk/release/wear-release.apk"; \
		exit 1; \
	fi; \
	echo "Deploying wear release to: $$SERIAL"; \
	if ! $(ADB) -s "$$SERIAL" install -r app/build/wear/outputs/apk/release/wear-release.apk; then \
		echo "Release install failed. Retrying with uninstall (signature mismatch fallback)..."; \
		$(ADB) -s "$$SERIAL" uninstall com.brensch.schlift || true; \
		$(ADB) -s "$$SERIAL" install app/build/wear/outputs/apk/release/wear-release.apk || exit 1; \
	fi; \
	$(ADB) -s "$$SERIAL" shell am start -n com.brensch.schlift/com.brensch.schlift.wear.MainActivity

ci-android-prepare-signing:
	@bash -ec '\
		if [ ! -f "$(RELEASE_ENV_FILE)" ]; then \
			echo "Missing $(RELEASE_ENV_FILE)."; \
			exit 1; \
		fi; \
		set -a; . "$(RELEASE_ENV_FILE)"; set +a; \
		missing=0; \
		for name in RELEASE_KEYSTORE_BASE64 RELEASE_KEYSTORE_PASSWORD RELEASE_KEY_ALIAS RELEASE_KEY_PASSWORD; do \
			if [ -z "$${!name:-}" ]; then \
				echo "Missing variable in $(RELEASE_ENV_FILE): $$name"; \
				missing=1; \
			fi; \
		done; \
		if [ "$$missing" -eq 1 ]; then \
			exit 1; \
		fi; \
		echo "$$RELEASE_KEYSTORE_BASE64" | base64 --decode > app/android/release-keystore.jks; \
		printf "storeFile=release-keystore.jks\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n" \
			"$$RELEASE_KEYSTORE_PASSWORD" "$$RELEASE_KEY_ALIAS" "$$RELEASE_KEY_PASSWORD" \
			> app/android/key.properties; \
		echo "Prepared app/android/key.properties and app/android/release-keystore.jks"; \
	'

ci-android-check-signing: ci-android-prepare-signing
	cd app/android && ./gradlew :app:validateSigningRelease :wear:validateSigningRelease --no-daemon

ci-android-build-release: ci-android-prepare-signing
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		(cd app && $(FLUTTER) pub get); \
		(cd app && $(FLUTTER) build appbundle --release); \
		(cd app/android && ./gradlew :wear:bundleRelease --no-daemon); \
	'
	@echo "Phone AAB: app/build/app/outputs/bundle/release/app-release.aab"
	@echo "Wear AAB:  app/build/wear/outputs/bundle/release/wear-release.aab"

# Local alias that mirrors the GitHub Android release workflow build steps.
build-aabs-release: ci-android-build-release
	@mkdir -p "$(AAB_OUT_DIR)"
	@set -e; \
		DATE_TAG=$$(date +%Y%m%d); \
		PHONE_SRC="app/build/app/outputs/bundle/release/app-release.aab"; \
		WEAR_SRC="app/build/wear/outputs/bundle/release/wear-release.aab"; \
		ALT_WEAR_SRC="app/android/wear/build/outputs/bundle/release/wear-release.aab"; \
		if [ ! -f "$$PHONE_SRC" ]; then \
			echo "Phone AAB not found: $$PHONE_SRC"; \
			exit 1; \
		fi; \
		if [ ! -f "$$WEAR_SRC" ] && [ -f "$$ALT_WEAR_SRC" ]; then \
			WEAR_SRC="$$ALT_WEAR_SRC"; \
		fi; \
		if [ ! -f "$$WEAR_SRC" ]; then \
			echo "Wear AAB not found at $$WEAR_SRC (or $$ALT_WEAR_SRC)"; \
			exit 1; \
		fi; \
		PHONE_HASH=$$(sha256sum "$$PHONE_SRC" | awk '{print substr($$1,1,8)}'); \
		WEAR_HASH=$$(sha256sum "$$WEAR_SRC" | awk '{print substr($$1,1,8)}'); \
		PHONE_OUT="$(AAB_OUT_DIR)/app-release-$$DATE_TAG-$$PHONE_HASH.aab"; \
		WEAR_OUT="$(AAB_OUT_DIR)/wear-release-$$DATE_TAG-$$WEAR_HASH.aab"; \
		mv "$$PHONE_SRC" "$$PHONE_OUT"; \
		mv "$$WEAR_SRC" "$$WEAR_OUT"; \
		echo "Moved AABs to $(AAB_OUT_DIR)/"; \
		echo "Phone: $$PHONE_OUT"; \
		echo "Wear:  $$WEAR_OUT"

ci-android-release-local: ci-android-check-signing ci-android-build-release

ci-android-clean-signing:
	@rm -f app/android/key.properties app/android/release-keystore.jks
	@echo "Removed local signing files."

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && npm run build

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

print-cert-hashes:
	@echo "=== Debug keystore ==="
	@echo "SHA256 (colon-separated):"
	@keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: /  /'
	@echo "APK key hash (base64url):"
	@echo -n "  android:apk-key-hash:" && keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
	@echo ""
	@echo "To get release keystore hashes, run:"
	@echo "  make print-cert-hashes DEBUG_KEYSTORE=/path/to/release.keystore DEBUG_ALIAS=myalias DEBUG_STOREPASS=mypass"

proto-dart:
	@echo "=== Generating Dart protobuf files with buf ==="
	cd proto && PATH="$(HOME)/flutter-sdk/bin:$(HOME)/.pub-cache/bin:$$PATH" buf generate --template buf.gen.dart.yaml
	@echo "Done. Generated files in app/lib/gen/"

proto-android:
	@echo "=== Generating Android protobuf files (lite) with buf ==="
	cd proto && buf generate --template buf.gen.android.yaml
	@echo "Done. Generated files in app/android/shared-proto/src/main/java/"

proto-swift:
	@echo "=== Generating Swift protobuf files with buf ==="
	@mkdir -p app/ios/SchliftWatch/Generated
	cd proto && buf generate --template buf.gen.swift.yaml
	@echo "Done. Generated files in app/ios/SchliftWatch/Generated/"

proto-all: proto-dart proto-android proto-swift

icons:
	@echo "=== Regenerating app icons and marketing assets ==="
	python3 scripts/replace_app_icons.py
	python3 scripts/replace_app_icons2.py
	@echo "Done."

# ── Apple Watch (SchliftWatch) ───────────────────────────────────────────

# One-time setup: install xcodegen + swift-protobuf, generate xcodeproj
watch-setup:
	@echo "=== Apple Watch: checking dependencies ==="
	@command -v xcodegen >/dev/null 2>&1 || { echo "Installing xcodegen..."; brew install xcodegen; }
	@command -v protoc-gen-swift >/dev/null 2>&1 || { echo "Installing swift-protobuf..."; brew install swift-protobuf; }
	@echo "=== Generating Swift protobuf files ==="
	$(MAKE) proto-swift
	@echo "=== Generating Xcode project from project.yml ==="
	$(MAKE) watch-generate
	@echo ""
	@echo "Done! Build with: make watch-build"
	@echo "Run on simulator: make watch-sim"

# Regenerate Runner.xcodeproj from project.yml (run after changing project.yml)
watch-generate:
	cd app/ios && xcodegen generate
	@echo "Generated Runner.xcodeproj from project.yml"

# Build SchliftWatch for watchOS simulator
WATCH_SIM_DEST ?= platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)

watch-build:
	cd app/ios && xcodebuild build \
		-project Runner.xcodeproj \
		-scheme SchliftWatch \
		-destination '$(WATCH_SIM_DEST)' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO \
		| tail -20

watch-build-release:
	cd app/ios && xcodebuild build \
		-project Runner.xcodeproj \
		-scheme SchliftWatch \
		-destination 'generic/platform=watchOS' \
		-configuration Release

# Boot a watchOS simulator and install/launch the app
watch-sim:
	@echo "=== Building SchliftWatch for watchOS Simulator ==="
	$(MAKE) watch-build
	@echo "=== Booting watchOS simulator ==="
	@WATCH_UDID=$$(xcrun simctl list devices available watchOS | grep -m1 "Watch" | sed 's/.*(\([A-F0-9-]*\)).*/\1/'); \
	if [ -z "$$WATCH_UDID" ]; then \
		echo "No watchOS simulator found. Run: make watch-sim-list"; \
		exit 1; \
	fi; \
	echo "Using simulator: $$WATCH_UDID"; \
	xcrun simctl boot "$$WATCH_UDID" 2>/dev/null || true; \
	open -a Simulator; \
	APP_PATH=$$(find app/ios/build -name "SchliftWatch.app" -path "*/watchOS*" 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "SchliftWatch.app not found in build output"; \
		exit 1; \
	fi; \
	echo "Installing $$APP_PATH"; \
	xcrun simctl install "$$WATCH_UDID" "$$APP_PATH"; \
	xcrun simctl launch "$$WATCH_UDID" com.brensch.schlift.watchkitapp

watch-sim-list:
	@echo "Available watchOS simulators:"
	@xcrun simctl list devices available watchOS

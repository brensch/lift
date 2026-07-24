# Wear OS: run on device, logs, emulator, release build and deploy.
# Split from the top-level Makefile; variables live there.

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

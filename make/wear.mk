# Wear OS: run on device, logs, emulator, release build and deploy.
# Split from the top-level Makefile; variables live there.

.PHONY: run-wear run-wear-logs run-wear-debug build-wear-release deploy-wear \
	android-wear-emulator-start android-wear-run-emulator android-wear-pairing-notes

WEAR_APK_DEBUG = app/build/wear/outputs/apk/debug/wear-debug.apk
WEAR_APK_RELEASE = app/build/wear/outputs/apk/release/wear-release.apk
WEAR_ACTIVITY = com.brensch.schlift/com.brensch.schlift.wear.MainActivity
# The debug build sits beside the store one, like the phone's.
WEAR_ACTIVITY_DEBUG = com.brensch.schlift.debug/com.brensch.schlift.wear.MainActivity

run-wear:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		$(PICK_WATCH) \
		(cd app/android && ./gradlew :wear:assembleDebug); \
		$(ADB) -s "$$SERIAL" install -r $(WEAR_APK_DEBUG); \
		$(ADB) -s "$$SERIAL" shell am start -n $(WEAR_ACTIVITY_DEBUG); \
	'

run-wear-logs:
	@bash -ec '\
		$(PICK_WATCH) \
		echo "Filter: $(WEAR_LOG_FILTER)"; \
		$(ADB) -s "$$SERIAL" logcat -c || true; \
		$(ADB) -s "$$SERIAL" logcat $(WEAR_LOG_FILTER); \
	'

run-wear-debug:
	@bash -ec '\
		trap "kill 0" SIGINT SIGTERM EXIT; \
		$(MAKE) run-wear WEAR_SERIAL="$(WEAR_SERIAL)" & \
		sleep 2; \
		$(MAKE) run-wear-logs WEAR_SERIAL="$(WEAR_SERIAL)"; \
	'

build-wear-release:
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		cd app/android && ./gradlew :wear:assembleRelease; \
	'

# Like deploy-android, this never uninstalls to get past a signature
# mismatch: a watch with the Play build keeps it.
deploy-wear: build-wear-release
	@bash -ec '\
		$(PICK_WATCH) \
		$(ADB) -s "$$SERIAL" install -r $(WEAR_APK_RELEASE); \
		$(ADB) -s "$$SERIAL" shell am start -n $(WEAR_ACTIVITY); \
	'

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

WEAR_LOG_FILTER ?= SchliftWear:D SchliftWearBridge:D Wearable:D WearTransport:D *:S

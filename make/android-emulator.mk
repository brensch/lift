# Android SDK checks, AVDs, emulator lifecycle, screenshot/input automation for agents.
# Split from the top-level Makefile; variables live there.

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

android-agent-start:
	$(MAKE) agent-backend-start
	$(MAKE) android-emulator-start
	$(MAKE) android-emulator-wait
	$(MAKE) android-emulator-unlock
	$(MAKE) android-emulator-reverse
	$(MAKE) android-run-emulator
	$(MAKE) android-screenshot ANDROID_SCREENSHOT_OUT=.tmp/screenshots/android-agent-start.png

android-agent-stop: agent-backend-stop android-emulator-stop

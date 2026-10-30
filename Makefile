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

# Phone targets pick the first adb device that is not a watch; watch targets
# the first that is. Set PHONE_SERIAL / WEAR_SERIAL to choose explicitly.
# ANDROID_SERIAL above is the emulator the agent and e2e targets drive.
PHONE_SERIAL ?=
WEAR_SERIAL ?=

# Shell snippets for recipes. Each one is spliced into a `bash -ec '...'`
# script (so no single quotes inside) and ends with `;`.

# JAVA_HOME from the javac on PATH, so Gradle gets a full JDK.
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
	fi;
endef

# Sets SERIAL to the phone ($(1) = PHONE_SERIAL, grep flag -v) or the watch
# ($(1) = WEAR_SERIAL, no flag), or exits.
define PICK_ADB_DEVICE
	SERIAL="$($(1))"; \
	if [ -z "$$SERIAL" ]; then \
		SERIAL=$$($(ADB) devices | awk "NR > 1 && \$$2 == \"device\" { print \$$1 }" | while read -r ID; do \
			CH=$$($(ADB) -s "$$ID" shell getprop ro.build.characteristics </dev/null 2>/dev/null | tr -d "\r"); \
			if echo "$$CH" | grep -qi $(2) watch; then echo "$$ID"; break; fi; \
		done); \
	fi; \
	if [ -z "$$SERIAL" ]; then \
		echo "No $(3) on adb. Set $(1) to pick one."; \
		$(ADB) devices; \
		exit 1; \
	fi; \
	echo "Using $(3): $$SERIAL";
endef
PICK_PHONE = $(call PICK_ADB_DEVICE,PHONE_SERIAL,-v,phone)
PICK_WATCH = $(call PICK_ADB_DEVICE,WEAR_SERIAL,,watch)

# Sets PLATFORM to the Flutter --target-platform for $$SERIAL. A release APK
# for one ABI builds much faster than the default three.
define DEVICE_TARGET_PLATFORM
	case "$$($(ADB) -s "$$SERIAL" shell getprop ro.product.cpu.abi </dev/null | tr -d "\r")" in \
		arm64-v8a) PLATFORM=android-arm64 ;; \
		x86_64) PLATFORM=android-x64 ;; \
		*) PLATFORM=android-arm ;; \
	esac;
endef

# Environment for a local backend with dev login, trusting passkeys from the
# debug-signed app plus the two release signing keys.
DEBUG_APK_KEY_HASH = $(shell keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
DEBUG_CERT_SHA256 = $(shell keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //')
RELEASE_APK_ORIGINS = android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk
BACKEND_DEV_ENV = \
	RUST_LOG=info \
	TEST_AUTH_ENABLED=1 \
	WEBAUTHN_RP_ID=schlift.com \
	WEBAUTHN_RP_ORIGIN=https://schlift.com \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$(DEBUG_APK_KEY_HASH) \
	WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:$(DEBUG_APK_KEY_HASH),$(RELEASE_APK_ORIGINS) \
	ANDROID_CERT_SHA256=$(DEBUG_CERT_SHA256)

# Targets are grouped by concern under make/. Variables above are shared.
include make/backend.mk
include make/app.mk
include make/android-emulator.mk
include make/store.mk
include make/wear.mk
include make/watch.mk
include make/release.mk
include make/proto.mk
include make/e2e.mk
include make/lint.mk

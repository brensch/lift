.PHONY: fuzz-api fuzz-api-ci run-dev run-backend run-backend-release run-frontend run-app run-android run-android-prod run-android-clean run-linux run-wear run-wear-logs run-wear-debug run-prod check install-deps check-android-java proto-dart proto-android proto-swift proto-all icons print-cert-hashes ci-android-prepare-signing ci-android-check-signing ci-android-build-release ci-android-release-local ci-android-clean-signing build-wear-release deploy-wear build-aabs-release android-sdk-check android-phone-avd-create android-phone-play-avd-create android-phone-play-emulator-start android-wear-avd-create android-emulator-start android-emulator-stop android-emulator-wait android-emulator-unlock android-emulator-reverse android-screenshot android-tap android-text android-run-emulator agent-backend-start agent-backend-stop android-agent-start android-agent-stop android-wear-emulator-start android-wear-run-emulator android-wear-pairing-notes watch-setup watch-generate watch-build watch-build-release watch-sim watch-sim-list e2e e2e-up e2e-run

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

# Targets are grouped by concern under make/. Variables above are shared.
include make/backend.mk
include make/app.mk
include make/android-emulator.mk
include make/wear.mk
include make/watch.mk
include make/release.mk
include make/proto.mk
include make/e2e.mk

.PHONY: run-dev run-backend run-backend-release run-frontend run-app run-android run-android-clean run-linux run-wear run-prod check install-deps proto-dart proto-android proto-all print-cert-hashes

FLUTTER = $(HOME)/flutter-sdk/bin/flutter
DART = $(HOME)/flutter-sdk/bin/dart
BUN = $(HOME)/.bun/bin/bun

# Debug keystore config
DEBUG_KEYSTORE = $(HOME)/.android/debug.keystore
DEBUG_ALIAS = androiddebugkey
DEBUG_STOREPASS = android

run-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; make run-backend & make run-frontend & wait'

run-backend:
	@pkill -f "[/]target/debug/lift" || true
	@pkill -f "[/]target/release/lift" || true
	WEBAUTHN_RP_ID=lift.snek2.ddns.net \
	WEBAUTHN_RP_ORIGIN=https://lift.snek2.ddns.net \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo watch -x "run --bin lift --features test-auth"

run-backend-release:
	@pkill -f "[/]target/debug/lift" || true
	@pkill -f "[/]target/release/lift" || true
	WEBAUTHN_RP_ID=lift.snek2.ddns.net \
	WEBAUTHN_RP_ORIGIN=https://lift.snek2.ddns.net \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo run --release --bin lift --features test-auth

run-frontend:
	cd web && $(BUN) run dev

ADB = $(HOME)/android-sdk/platform-tools/adb

run-android:
	@bash -ec '\
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

run-android-clean:
	@bash -ec '\
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

WEAR_SERIAL ?=

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
	cd app/android && ./gradlew :wear:assembleDebug
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
	$(ADB) -s "$$SERIAL" shell am start -n com.lift.lift/com.lift.lift.wear.MainActivity

setup-flutter:
	$(FLUTTER) config --enable-custom-devices
	mkdir -p $(HOME)/.config/flutter
	cp .flutter/custom_devices.json $(HOME)/.config/flutter/custom_devices.json

TMP_RUN_DIR = .tmp/run-app
LINUX_BUNDLE = app/build/linux/x64/debug/bundle/lift
LINUX_SOFTWARE_RENDER ?= 1

run-app:
	@make stop-app || true
	@bash -ec '\
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
		mkdir -p "$(TMP_RUN_DIR)" .tmp/linux-1 .tmp/linux-2; \
		echo "Building Linux bundle once..."; \
		(cd app && $(FLUTTER) build linux --debug); \
		if [ ! -x "$(LINUX_BUNDLE)" ]; then \
			echo "Linux bundle missing: $(LINUX_BUNDLE)"; \
			exit 1; \
		fi; \
		echo "Launching linux-1 and linux-2..."; \
		nohup env XDG_DATA_HOME="$(PWD)/.tmp/linux-1" LIBGL_ALWAYS_SOFTWARE="$(LINUX_SOFTWARE_RENDER)" \
			"$(PWD)/$(LINUX_BUNDLE)" --dart-define=INSTANCE=1 \
			> "$(TMP_RUN_DIR)/linux-1.log" 2>&1 & \
		echo $$! > "$(TMP_RUN_DIR)/linux-1.pid"; \
		nohup env XDG_DATA_HOME="$(PWD)/.tmp/linux-2" LIBGL_ALWAYS_SOFTWARE="$(LINUX_SOFTWARE_RENDER)" \
			"$(PWD)/$(LINUX_BUNDLE)" --dart-define=INSTANCE=2 \
			> "$(TMP_RUN_DIR)/linux-2.log" 2>&1 & \
		echo $$! > "$(TMP_RUN_DIR)/linux-2.pid"; \
		echo "Linux logs: $(TMP_RUN_DIR)/linux-1.log, $(TMP_RUN_DIR)/linux-2.log"; \
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
		pkill -f "[/]app/build/linux/x64/debug/bundle/lift" 2>/dev/null || true; \
		pkill -f "[/]flutter-sdk/bin/flutter.*run -d" 2>/dev/null || true; \
	'

load-test:
	cargo run --release --example load_simulation --all-features -- --duration 3000

deploy-android:
	cd app && $(FLUTTER) build apk --release
	$(ADB) install -r app/build/app/outputs/flutter-apk/app-release.apk

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && $(BUN) run build

install-deps:
	@echo "=== Installing Linux build dependencies ==="
	sudo apt-get update
	sudo apt-get install -y cmake ninja-build clang lld libgtk-3-dev pkg-config protobuf-compiler curl git unzip
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
	cd web && $(BUN) install
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

proto-all: proto-dart proto-android

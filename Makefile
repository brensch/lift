.PHONY: run-dev run-backend run-backend-release run-frontend run-app run-android run-linux run-prod check install-deps proto-dart print-cert-hashes

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
	@pkill -x lift || true
	WEBAUTHN_RP_ID=lift.snek2.ddns.net \
	WEBAUTHN_RP_ORIGIN=https://lift.snek2.ddns.net \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo watch -x "run --bin lift --features test-auth"

run-backend-release:
	@pkill -x lift || true
	WEBAUTHN_RP_ID=lift.snek2.ddns.net \
	WEBAUTHN_RP_ORIGIN=https://lift.snek2.ddns.net \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo run --release --bin lift --features test-auth

run-frontend:
	cd web && $(BUN) run dev

ADB = $(HOME)/android-sdk/platform-tools/adb

run-android:
	$(ADB) reverse tcp:50051 tcp:50051 || true
	cd app && $(FLUTTER) run -d android

setup-flutter:
	$(FLUTTER) config --enable-custom-devices
	mkdir -p $(HOME)/.config/flutter
	cp .flutter/custom_devices.json $(HOME)/.config/flutter/custom_devices.json

WINDOW_WIDTH = 450
WINDOW_HEIGHT = 900

run-app:
	@make stop-app || true
	@$(ADB) reverse tcp:50051 tcp:50051 || true
	@mkdir -p .tmp/linux-1 .tmp/linux-2
	cd app && $(FLUTTER) run -d all --dart-define=WINDOW_WIDTH=$(WINDOW_WIDTH) --dart-define=WINDOW_HEIGHT=$(WINDOW_HEIGHT)

stop-app:
	@echo "Stopping all lift instances..."
	@pkill -9 -f "bundle/lift" || true
	@pkill -9 -f "dart.*INSTANCE=" || true
	@pkill -9 -f "flutter_assets" || true

load-test:
	cargo run --release --example load_simulation --all-features -- --duration 300

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
	@echo "=== Generating Dart protobuf files ==="
	mkdir -p app/lib/gen/workout/v1
	PATH="$(HOME)/flutter-sdk/bin:$(HOME)/.pub-cache/bin:$$PATH" \
		protoc --dart_out=grpc:app/lib/gen/workout/v1 \
		--proto_path=proto \
		proto/workout/v1/workout.proto proto/workout/v1/group.proto proto/workout/v1/auth.proto
	@# Fix nested directory structure from protoc
	@if [ -d "app/lib/gen/workout/v1/workout/v1" ]; then \
		mv app/lib/gen/workout/v1/workout/v1/*.dart app/lib/gen/workout/v1/; \
		rm -rf app/lib/gen/workout/v1/workout; \
	fi
	@echo "Done. Generated files in app/lib/gen/workout/v1/"

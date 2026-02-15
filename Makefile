.PHONY: run-dev run-backend run-frontend run-app run-prod check install-deps proto-dart

FLUTTER = $(HOME)/flutter-sdk/bin/flutter
DART = $(HOME)/flutter-sdk/bin/dart
BUN = $(HOME)/.bun/bin/bun

run-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; make run-backend & make run-frontend & wait'

run-backend:
	@pkill -x lift || true
	cargo watch -x "run --bin lift"

run-frontend:
	cd web && $(BUN) run dev

ADB = $(HOME)/android-sdk/platform-tools/adb

run-app:
	$(ADB) reverse tcp:50051 tcp:50051
	cd app && $(FLUTTER) run

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

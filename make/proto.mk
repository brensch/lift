# Protobuf generation for every client.
# Split from the top-level Makefile; variables live there.

.PHONY: proto-dart proto-android proto-web proto-swift proto-all

proto-dart:
	@echo "=== Generating Dart protobuf files with buf ==="
	cd proto && PATH="$(HOME)/flutter-sdk/bin:$(HOME)/.pub-cache/bin:$$PATH" buf generate --template buf.gen.dart.yaml
	@echo "Done. Generated files in app/lib/gen/"

# Kotlin uses only the wearable messages, so only wearable.proto and its
# imports are generated.
proto-android:
	@echo "=== Generating Android protobuf files (lite) with buf ==="
	cd proto && buf generate --template buf.gen.android.yaml \
		--path workout/v1/wearable.proto --path workout/v1/workout.proto --path workout/v1/settings.proto
	@echo "Done. Generated files in app/android/shared-proto/src/main/java/"

proto-web:
	@echo "=== Generating web TypeScript protobuf files with buf ==="
	cd proto && buf generate --template buf.gen.yaml
	@echo "Done. Generated files in web/src/gen/"

proto-swift:
	@echo "=== Generating Swift protobuf files with buf ==="
	@mkdir -p app/ios/SchliftWatch/Generated
	cd proto && buf generate --template buf.gen.swift.yaml
	@echo "Done. Generated files in app/ios/SchliftWatch/Generated/"

proto-all: proto-dart proto-android proto-web proto-swift

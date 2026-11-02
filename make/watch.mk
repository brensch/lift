# Apple Watch: builds, simulator.
# Split from the top-level Makefile; variables live there.

.PHONY: watch-setup watch-build watch-build-release watch-sim watch-sim-list

# One-time setup: install swift-protobuf, generate the Swift protos
watch-setup:
	@echo "=== Apple Watch: checking dependencies ==="
	@command -v protoc-gen-swift >/dev/null 2>&1 || { echo "Installing swift-protobuf..."; brew install swift-protobuf; }
	@echo "=== Generating Swift protobuf files ==="
	$(MAKE) proto-swift
	@echo ""
	@echo "Done! Build with: make watch-build"
	@echo "Run on simulator: make watch-sim"

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

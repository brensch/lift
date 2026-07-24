# Release signing and store artifacts (Android/Wear AABs).
# Split from the top-level Makefile; variables live there.

print-cert-hashes:
	@echo "=== Debug keystore ==="
	@echo "SHA256 (colon-separated):"
	@keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: /  /'
	@echo "APK key hash (base64url):"
	@echo -n "  android:apk-key-hash:" && keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
	@echo ""
	@echo "To get release keystore hashes, run:"
	@echo "  make print-cert-hashes DEBUG_KEYSTORE=/path/to/release.keystore DEBUG_ALIAS=myalias DEBUG_STOREPASS=mypass"

ci-android-prepare-signing:
	@bash -ec '\
		if [ ! -f "$(RELEASE_ENV_FILE)" ]; then \
			echo "Missing $(RELEASE_ENV_FILE)."; \
			exit 1; \
		fi; \
		set -a; . "$(RELEASE_ENV_FILE)"; set +a; \
		missing=0; \
		for name in RELEASE_KEYSTORE_BASE64 RELEASE_KEYSTORE_PASSWORD RELEASE_KEY_ALIAS RELEASE_KEY_PASSWORD; do \
			if [ -z "$${!name:-}" ]; then \
				echo "Missing variable in $(RELEASE_ENV_FILE): $$name"; \
				missing=1; \
			fi; \
		done; \
		if [ "$$missing" -eq 1 ]; then \
			exit 1; \
		fi; \
		echo "$$RELEASE_KEYSTORE_BASE64" | base64 --decode > app/android/release-keystore.jks; \
		printf "storeFile=release-keystore.jks\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n" \
			"$$RELEASE_KEYSTORE_PASSWORD" "$$RELEASE_KEY_ALIAS" "$$RELEASE_KEY_PASSWORD" \
			> app/android/key.properties; \
		echo "Prepared app/android/key.properties and app/android/release-keystore.jks"; \
	'

ci-android-check-signing: ci-android-prepare-signing
	cd app/android && ./gradlew :app:validateSigningRelease :wear:validateSigningRelease --no-daemon

ci-android-build-release: ci-android-prepare-signing
	@bash -ec '\
		$(EXPORT_JAVA_HOME_FROM_JAVAC) \
		(cd app && $(FLUTTER) pub get); \
		(cd app && $(FLUTTER) build appbundle --release); \
		(cd app/android && ./gradlew :wear:bundleRelease --no-daemon); \
	'
	@echo "Phone AAB: app/build/app/outputs/bundle/release/app-release.aab"
	@echo "Wear AAB:  app/build/wear/outputs/bundle/release/wear-release.aab"

# Local alias that mirrors the GitHub Android release workflow build steps.
build-aabs-release: ci-android-build-release
	@mkdir -p "$(AAB_OUT_DIR)"
	@set -e; \
		DATE_TAG=$$(date +%Y%m%d); \
		PHONE_SRC="app/build/app/outputs/bundle/release/app-release.aab"; \
		WEAR_SRC="app/build/wear/outputs/bundle/release/wear-release.aab"; \
		ALT_WEAR_SRC="app/android/wear/build/outputs/bundle/release/wear-release.aab"; \
		if [ ! -f "$$PHONE_SRC" ]; then \
			echo "Phone AAB not found: $$PHONE_SRC"; \
			exit 1; \
		fi; \
		if [ ! -f "$$WEAR_SRC" ] && [ -f "$$ALT_WEAR_SRC" ]; then \
			WEAR_SRC="$$ALT_WEAR_SRC"; \
		fi; \
		if [ ! -f "$$WEAR_SRC" ]; then \
			echo "Wear AAB not found at $$WEAR_SRC (or $$ALT_WEAR_SRC)"; \
			exit 1; \
		fi; \
		PHONE_HASH=$$(sha256sum "$$PHONE_SRC" | awk '{print substr($$1,1,8)}'); \
		WEAR_HASH=$$(sha256sum "$$WEAR_SRC" | awk '{print substr($$1,1,8)}'); \
		PHONE_OUT="$(AAB_OUT_DIR)/app-release-$$DATE_TAG-$$PHONE_HASH.aab"; \
		WEAR_OUT="$(AAB_OUT_DIR)/wear-release-$$DATE_TAG-$$WEAR_HASH.aab"; \
		mv "$$PHONE_SRC" "$$PHONE_OUT"; \
		mv "$$WEAR_SRC" "$$WEAR_OUT"; \
		echo "Moved AABs to $(AAB_OUT_DIR)/"; \
		echo "Phone: $$PHONE_OUT"; \
		echo "Wear:  $$WEAR_OUT"

ci-android-release-local: ci-android-check-signing ci-android-build-release

ci-android-clean-signing:
	@rm -f app/android/key.properties app/android/release-keystore.jks
	@echo "Removed local signing files."

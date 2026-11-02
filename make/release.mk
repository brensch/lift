# Signing certificate hashes, for the passkey Android origins.
# Split from the top-level Makefile; variables live there.

.PHONY: print-cert-hashes

print-cert-hashes:
	@echo "=== Debug keystore ==="
	@echo "SHA256 (colon-separated):"
	@keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: /  /'
	@echo "APK key hash (base64url):"
	@echo -n "  android:apk-key-hash:" && keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
	@echo ""
	@echo "To get release keystore hashes, run:"
	@echo "  make print-cert-hashes DEBUG_KEYSTORE=/path/to/release.keystore DEBUG_ALIAS=myalias DEBUG_STOREPASS=mypass"

# Backend: run, agent background instance, load and fuzz harnesses.
# Split from the top-level Makefile; variables live there.

run-backend:
	@pkill -f "[/]target/debug/schlift" || true
	@pkill -f "[/]target/release/schlift" || true
	RUST_LOG=info \
	WEBAUTHN_RP_ID=schlift.com \
	WEBAUTHN_RP_ORIGIN=https://schlift.com \
	TEST_AUTH_ENABLED=1 \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='),android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo watch -x "run --bin schlift --features test-auth"

run-backend-release:
	@pkill -f "[/]target/debug/schlift" || true
	@pkill -f "[/]target/release/schlift" || true
	RUST_LOG=info \
	WEBAUTHN_RP_ID=schlift.com \
	WEBAUTHN_RP_ORIGIN=https://schlift.com \
	TEST_AUTH_ENABLED=1 \
	WEBAUTHN_ANDROID_ORIGIN=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=') \
	WEBAUTHN_ANDROID_ORIGINS=android:apk-key-hash:$$(keytool -exportcert -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='),android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk \
	ANDROID_CERT_SHA256=$$(keytool -list -v -keystore $(DEBUG_KEYSTORE) -alias $(DEBUG_ALIAS) -storepass $(DEBUG_STOREPASS) 2>/dev/null | grep SHA256 | head -1 | sed 's/.*SHA256: //') \
	cargo run --release --bin schlift --features test-auth

run-backend-scratch:
	@pkill -f "[/]target/release/schlift" || true
	@rm -f data/scratch.sqlite data/scratch.sqlite-wal data/scratch.sqlite-shm
	RUST_LOG=info TEST_AUTH_ENABLED=1 cargo run --release --bin schlift --features test-auth

agent-backend-start:
	@bash -ec '\
		mkdir -p "$(AGENT_TMP_DIR)" "$(AGENT_BACKEND_DATA_DIR)"; \
		if [ -f "$(AGENT_TMP_DIR)/backend.pid" ]; then \
			pid=$$(cat "$(AGENT_TMP_DIR)/backend.pid" 2>/dev/null || true); \
			if [ -n "$$pid" ] && kill -0 "$$pid" >/dev/null 2>&1; then \
				echo "Backend already running with pid $$pid"; \
				exit 0; \
			fi; \
		fi; \
		APK_HASH=$$(keytool -exportcert -keystore "$(DEBUG_KEYSTORE)" -alias "$(DEBUG_ALIAS)" -storepass "$(DEBUG_STOREPASS)" 2>/dev/null | openssl dgst -sha256 -binary | base64 | tr "+/" "-_" | tr -d "=" || true); \
		CERT_SHA=$$(keytool -list -v -keystore "$(DEBUG_KEYSTORE)" -alias "$(DEBUG_ALIAS)" -storepass "$(DEBUG_STOREPASS)" 2>/dev/null | grep SHA256 | head -1 | sed "s/.*SHA256: //" || true); \
		echo "Starting backend on localhost:50051"; \
		DATA_DIR="$(AGENT_BACKEND_DATA_DIR)" \
		RUST_LOG=info \
		TEST_AUTH_ENABLED=1 \
		WEBAUTHN_RP_ID=schlift.com \
		WEBAUTHN_RP_ORIGIN=https://schlift.com \
		WEBAUTHN_ANDROID_ORIGIN="android:apk-key-hash:$$APK_HASH" \
		WEBAUTHN_ANDROID_ORIGINS="android:apk-key-hash:$$APK_HASH,android:apk-key-hash:Hwxr_adafRh6rlMbMzDNEX8x9QWOBakh_yOw6HTCIew,android:apk-key-hash:_AqWk4iSMELh5t8IwmPW1iGNdIAfVV3D6wThyTRJGgk" \
		ANDROID_CERT_SHA256="$$CERT_SHA" \
		cargo run --bin schlift --features test-auth > "$(AGENT_BACKEND_LOG)" 2>&1 & \
		echo $$! > "$(AGENT_TMP_DIR)/backend.pid"; \
		for i in $$(seq 1 120); do \
			if curl -fsS http://127.0.0.1:50051/api/health >/dev/null 2>&1; then \
				echo "Backend ready: http://127.0.0.1:50051/api/health"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "Backend did not become healthy. Tail of $(AGENT_BACKEND_LOG):"; \
		tail -80 "$(AGENT_BACKEND_LOG)" || true; \
		exit 1; \
	'

agent-backend-stop:
	@bash -ec '\
		if [ -f "$(AGENT_TMP_DIR)/backend.pid" ]; then \
			pid=$$(cat "$(AGENT_TMP_DIR)/backend.pid" 2>/dev/null || true); \
			[ -n "$$pid" ] && kill "$$pid" >/dev/null 2>&1 || true; \
			rm -f "$(AGENT_TMP_DIR)/backend.pid"; \
		fi; \
	'

load-test:
	cargo run --release --example load_simulation -- --duration 3000

# Randomised API sequences against a throwaway backend, with invariant checks
# after every mutation. Spawns its own server on its own port and SQLite file,
# so it never touches a dev database. Non-zero exit on any violation.
fuzz-api:
	cargo run --release --example api_invariant_fuzz -- \
		--users $(or $(FUZZ_USERS),10) \
		--sessions $(or $(FUZZ_SESSIONS),14) \
		--seed $(or $(FUZZ_SEED),$(shell date +%s))

# A fixed-seed run small enough for CI.
fuzz-api-ci:
	cargo run --release --example api_invariant_fuzz -- \
		--users 6 --sessions 8 --seed 20240101

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && npm run build

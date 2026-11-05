# Backend: run, agent background instance, the fuzz harness.
# Split from the top-level Makefile; variables live there.

.PHONY: run-backend run-backend-release run-backend-scratch seed-workouts agent-backend-start agent-backend-stop \
	fuzz-api fuzz-api-ci progression-explorer check

STOP_LOCAL_BACKENDS = pkill -f "[t]arget/(debug|release)/schlift" || true

# Dev server on :50051 with dev login, rebuilt and restarted when a Rust
# input is saved (an incremental debug build is a second or two). Only the
# backend's own inputs are watched, so app and web edits do not restart it.
BACKEND_WATCH = -w src -w core -w proto -w templates -w build.rs -w Cargo.toml -w Cargo.lock
run-backend:
	@$(STOP_LOCAL_BACKENDS)
	$(BACKEND_DEV_ENV) cargo watch $(BACKEND_WATCH) -x "run --bin schlift --features test-auth"

run-backend-release:
	@$(STOP_LOCAL_BACKENDS)
	$(BACKEND_DEV_ENV) cargo run --release --bin schlift --features test-auth

# Same as run-backend, on an empty database that is wiped every start.
SCRATCH_BACKEND_DATA_DIR ?= .tmp/scratch-backend
run-backend-scratch:
	@$(STOP_LOCAL_BACKENDS)
	@rm -rf "$(SCRATCH_BACKEND_DATA_DIR)" && mkdir -p "$(SCRATCH_BACKEND_DATA_DIR)"
	DATA_DIR="$(SCRATCH_BACKEND_DATA_DIR)" $(BACKEND_DEV_ENV) cargo run --bin schlift --features test-auth

# Test workouts for any account on a running dev backend (it needs dev
# login, so never production): a seeded lifter's WEEKS of history through
# the phone's own core, ending yesterday, at irregular days and times in
# this machine's timezone, time off included (weeks away, breaks of a month
# or two), added as history imports. A phone signed in as that user gets
# them live. The same SEED makes the same workouts. Each run adds them
# again; REPLACE=1 first discards what earlier imports brought in.
#   make seed-workouts ACCOUNT=ya [WEEKS=16] [PER_WEEK=3] [SEED=1] [REPLACE=1]
seed-workouts:
	@test -n "$(ACCOUNT)" || { echo "usage: make seed-workouts ACCOUNT=<name> [WEEKS=16] [PER_WEEK=3] [SEED=1] [REPLACE=1]"; exit 1; }
	cargo run -q -p schlift-load --bin seed -- --user "$(ACCOUNT)" \
		--weeks $(or $(WEEKS),16) --per-week $(or $(PER_WEEK),3) --seed $(or $(SEED),1) \
		--utc-offset "$$(date +%z)" $(if $(REPLACE),--replace)

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
		if (exec 3<>/dev/tcp/127.0.0.1/50051) 2>/dev/null; then echo "port 50051 is in use (make dev?): stop it first"; exit 1; fi; \
		echo "Starting backend on localhost:50051"; \
		DATA_DIR="$(AGENT_BACKEND_DATA_DIR)" $(BACKEND_DEV_ENV) \
		cargo run --bin schlift --features test-auth > "$(AGENT_BACKEND_LOG)" 2>&1 & \
		pid=$$!; \
		echo $$pid > "$(AGENT_TMP_DIR)/backend.pid"; \
		for i in $$(seq 1 120); do \
			if ! kill -0 $$pid 2>/dev/null; then break; fi; \
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

# Randomised API sequences through the core, in-process as the phone runs it,
# with invariant checks after every mutation and a replay of every user's
# event log. Non-zero exit on any violation.
fuzz-api:
	cargo run --release -p schlift-core --example fuzz -- \
		--users $(or $(FUZZ_USERS),10) \
		--sessions $(or $(FUZZ_SESSIONS),14) \
		--seed $(or $(FUZZ_SEED),$(shell date +%s))

# A fixed-seed run small enough for CI.
fuzz-api-ci:
	cargo run --release -p schlift-core --example fuzz -- \
		--users 6 --sessions 8 --seed 20240101

# What the planning rules tell scripted lifters: rewrite the snapshot
# (testdata/progression_scenarios.json) from the core and build the page
# from it. Review the snapshot's diff before committing it.
PROGRESSION_EXPLORER_OUT ?= .tmp/progression-explorer.html
progression-explorer:
	UPDATE_SCENARIOS=1 cargo test -p schlift-core --test progression_scenarios
	node scripts/build_progression_explorer.mjs $(PROGRESSION_EXPLORER_OUT)

check:
	cargo check
	cd web && npm run build

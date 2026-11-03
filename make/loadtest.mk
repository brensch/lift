# Load test: lightweight clients running the phone's own core against a fresh
# release server, then every account checked against the server's copy. See
# docs/testing/load.md.
#
#   make loadtest                      smoke: 40 clients, about a minute
#   make loadtest LOAD_PROFILE=scale   1000 clients, about four minutes
#
# A committed loadtest/baseline-<profile>.json fails the run when it is clearly
# slower; LOAD_ARGS passes anything else (--clients, --seconds, --server).
#
#   make loadtest-profile              the server under samply, then where
#                                      its CPU went (LOAD_PROFILE as above)

.PHONY: loadtest loadtest-profile

LOAD_PROFILE ?= smoke
LOAD_BASELINE = loadtest/baseline-$(LOAD_PROFILE).json

loadtest:
	cargo build --release -p schlift --bin schlift
	cargo build --release -p schlift-load
	./target/release/schlift-load --profile $(LOAD_PROFILE) \
		$(if $(wildcard $(LOAD_BASELINE)),--baseline $(LOAD_BASELINE)) $(LOAD_ARGS)

loadtest-profile:
	python3 scripts/profile_load.py --profile $(LOAD_PROFILE) $(LOAD_ARGS)

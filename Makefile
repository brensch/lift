.PHONY: run-dev check

run-dev:
	# Start backend (with watch) and frontend in parallel
	# Use a subshell and trap to kill background processes on Ctrl+C
	@bash -c 'trap "kill %1 %2" SIGINT; \
	cargo watch -x "run --bin lift" & \
	(cd web && bun run dev) & \
	wait'

check:
	cargo check
	cd web && bun run build

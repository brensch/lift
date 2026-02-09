.PHONY: run-dev check

run-dev:
	@pkill -x lift || true
	@echo "Starting services... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; cargo watch -x "run --bin lift" & (cd web && bun run dev) & wait'

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && bun run build

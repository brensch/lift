.PHONY: run-dev run-backend run-frontend run-prod check

run-dev:
	@echo "Starting backend and frontend... Press Ctrl+C to stop."
	@bash -c 'trap "kill 0" SIGINT SIGTERM EXIT; make run-backend & make run-frontend & wait'

run-backend:
	@pkill -x lift || true
	cargo watch -x "run --bin lift"

run-frontend:
	cd web && bun run dev

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && bun run build

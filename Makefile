.PHONY: run-dev check

run-dev:
	docker-compose -f docker-compose.dev.yml up --build

run-prod:
	docker-compose up --build

check:
	cargo check
	cd web && bun run build

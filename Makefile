.PHONY: run-frontend run-backend install-air

# Run frontend with hot reload (Vite dev server)
run-frontend:
	cd frontend && npm run dev

# Run backend with hot reload using air
# Install air first: go install github.com/air-verse/air@latest
run-backend:
	cd backend && air

# Install air if not present
install-air:
	go install github.com/air-verse/air@latest

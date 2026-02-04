.PHONY: generate build-server build-frontend build dev dev-server dev-frontend clean

generate:
	buf generate

build-server: generate
	cd server && go build -o ../bin/server ./cmd/server

build-frontend: generate
	cd frontend && npm install && npm run build

build: build-server build-frontend

dev-server:
	cd server && air

dev-frontend:
	cd frontend && npm run dev

dev:
	$(MAKE) dev-server & $(MAKE) dev-frontend & wait

clean:
	rm -rf bin/ server/gen/ frontend/src/gen/ frontend/dist/ data/ server/tmp/

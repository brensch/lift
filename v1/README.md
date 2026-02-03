# Lift - Workout Tracking App

A workout tracking application with a Go backend and React frontend.

## Quick Start with Docker

### Build the Docker image

```bash
docker build -t lift .
```

### Run the container

Run with a persistent data volume mounted to preserve your workout data:

```bash
docker run -d \
  --name lift \
  -p 8080:8080 \
  -v $(pwd)/data:/app/data \
  lift
```

The app will be available at http://localhost:8080

### Docker Compose (Alternative)

Create a `docker-compose.yml`:

```yaml
services:
  lift:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
    restart: unless-stopped
```

Then run:

```bash
docker compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Port the server listens on |
| `DATA_PATH` | `/app/data` | Path to SQLite database files |
| `STATIC_PATH` | `static` | Path to static frontend files |

## Development Setup

### Backend

```bash
cd backend
go run ./cmd/server/
```

The API server starts on http://localhost:8080

### Frontend

```bash
cd frontend
npm install
npm run dev
```

The dev server starts on http://localhost:5173

## Data Persistence

The application stores per-user SQLite databases in the data directory. When running with Docker, mount a host directory to `/app/data` to persist data across container restarts:

```bash
-v /path/on/host:/app/data
```

## Architecture

- **Backend**: Go with Connect RPC (gRPC-compatible), SQLite for storage
- **Frontend**: React + TypeScript + Vite + Tailwind CSS
- **Protocol**: Protocol Buffers with Connect RPC

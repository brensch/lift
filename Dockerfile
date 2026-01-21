# Build stage for frontend
FROM node:22-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy package files first for better caching
COPY frontend/package.json frontend/package-lock.json* ./

# Install dependencies
RUN npm install

# Copy frontend source
COPY frontend/ ./

# Build frontend
RUN npm run build

# Build stage for backend
FROM golang:1.25-alpine AS backend-builder

WORKDIR /app/backend

# Install build dependencies for CGO (required for SQLite)
RUN apk add --no-cache gcc musl-dev

# Copy go mod files first for better caching
COPY backend/go.mod backend/go.sum* ./

# Download dependencies
RUN go mod download

# Copy backend source
COPY backend/ ./

# Build the Go binary with CGO enabled for SQLite
RUN CGO_ENABLED=1 go build -o server ./cmd/server

# Production stage
FROM alpine:latest

WORKDIR /app

# Install runtime dependencies for SQLite
RUN apk add --no-cache libc6-compat ca-certificates

# Copy built frontend assets
COPY --from=frontend-builder /app/frontend/dist ./static

# Copy built backend binary
COPY --from=backend-builder /app/backend/server ./server

# Create data directory
RUN mkdir -p /app/data

# Environment variables
ENV DATA_PATH=/app/data
ENV PORT=8080

# Expose port
EXPOSE 8080

# Run the server
CMD ["./server"]

# Stage 1: Build the frontend with Bun
FROM oven/bun:1.3.8-debian AS frontend-builder
WORKDIR /app

# Install buf (binary only) - pinned to 1.50.0
RUN apt-get update && apt-get install -y curl && \
    BIN="/usr/local/bin" && \
    VERSION="1.50.0" && \
    curl -sSL "https://github.com/bufbuild/buf/releases/download/v${VERSION}/buf-$(uname -s)-$(uname -m)" -o "${BIN}/buf" && \
    chmod +x "${BIN}/buf" && \
    rm -rf /var/lib/apt/lists/*

COPY web/package.json web/bun.lockb* web/bun.lock* ./web/
RUN cd web && bun install --frozen-lockfile

COPY proto/ ./proto/
COPY web/ ./web/

# Generate proto files and build frontend
RUN cd web && bun run generate && bun run build && bun build --compile --target=bun-linux-x64 ./serve.ts --outfile server

# Stage 2: Build the backend
FROM rust:1.93.0-bookworm AS backend-builder
WORKDIR /app
RUN apt-get update && apt-get install -y protobuf-compiler && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY proto/ ./proto/
COPY build.rs ./

# Create dummy project structure to cache dependencies
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    echo 'pub mod workout { pub mod v1 { tonic::include_proto!("workout.v1"); } }' > src/lib.rs && \
    cargo build --release

# Copy real source and build
COPY src/ ./src/
RUN touch src/main.rs src/lib.rs && cargo build --release

# Stage 3: Final image
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Copy backend binary
COPY --from=backend-builder /app/target/release/lift /app/lift
# Copy frontend assets
COPY --from=frontend-builder /app/web/dist /app/dist
# Copy frontend server
COPY --from=frontend-builder /app/web/server /app/frontend-server

# Create directory for SQLite databases
RUN mkdir -p /app/user_dbs && chmod 777 /app/user_dbs

# Expose the ports
EXPOSE 50051 4173

# Persistent storage
VOLUME /app/user_dbs

# Create start script
RUN echo '#!/bin/bash\n/app/lift & \n/app/frontend-server' > /app/start.sh && chmod +x /app/start.sh

# Start the application
CMD ["/app/start.sh"]

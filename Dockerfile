# Stage 1: Build the frontend
FROM node:20-bookworm AS frontend-builder
WORKDIR /app
# Install dependencies for buf and npm
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
# Install buf
RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/bufbuild/buf/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && 
    curl -sSL "https://github.com/bufbuild/buf/releases/download/${LATEST_VERSION}/buf-$(uname -s)-$(uname -m)" -o /usr/local/bin/buf && 
    chmod +x /usr/local/bin/buf

COPY web/package*.json ./web/
RUN cd web && npm install
COPY proto/ ./proto/
COPY web/ ./web/
# Generate proto files and build
RUN cd web && npm run generate && npm run build

# Stage 2: Build the backend
FROM rust:1.81-bookworm AS backend-builder
WORKDIR /app
RUN apt-get update && apt-get install -y protobuf-compiler && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY proto/ ./proto/
COPY build.rs ./
# Create dummy main.rs to build dependencies and cache them
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release
# Copy real source and build
COPY src/ ./src/
RUN touch src/main.rs && cargo build --release

# Stage 3: Final image
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y nginx supervisor curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Copy backend binary
COPY --from=backend-builder /app/target/release/lift /app/lift
# Copy frontend assets
COPY --from=frontend-builder /app/web/dist /var/www/html
# Copy configurations
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create directory for SQLite databases
RUN mkdir -p /app/user_dbs && chmod 777 /app/user_dbs

# Expose port 80 for the web application
EXPOSE 80

# Use a volume for persistent database storage
VOLUME /app/user_dbs

# Start both backend and frontend via supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

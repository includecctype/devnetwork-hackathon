# Multi-stage Dockerfile for DEVNETWORK-HACKATHON

# Stage 1: Build Go services
FROM golang:1.21-alpine AS go-builder

WORKDIR /app

# Copy Go modules
COPY backend/gateway/go.mod backend/gateway/go.sum ./gateway/
COPY backend/real-time/go.mod backend/real-time/go.sum ./real-time/
COPY backend/service/go.mod backend/service/go.sum ./service/

# Download dependencies
RUN cd gateway && go mod download
RUN cd real-time && go mod download  
RUN cd service && go mod download

# Copy source code
COPY backend/ ./

# Build Go services
RUN cd gateway && go build -o ../bin/gateway .
RUN cd real-time && go build -o ../bin/real-time .
RUN cd service && go build -o ../bin/service .

# Stage 2: Build Frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /app

# Copy package files
COPY frontend/package.json frontend/package-lock.json ./

# Install dependencies
RUN npm ci

# Copy frontend source
COPY frontend/ ./

# Build frontend
RUN npm run build

# Stage 3: Production image
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy Go binaries
COPY --from=go-builder /app/bin/ ./bin/

# Copy frontend build
COPY --from=frontend-builder /app/dist/ ./frontend/dist/
# Copy frontend static files if needed
COPY --from=frontend-builder /app/public/ ./frontend/public/

# Copy any config files
COPY backend/gateway/Cargo.lock ./config/ 2>/dev/null || true
COPY backend/real-time/Cargo.toml ./config/ 2>/dev/null || true
COPY backend/service/poetry.lock ./config/ 2>/dev/null || true

# Create start script
RUN echo '#!/bin/sh' > start.sh && \
    echo 'echo "Starting all services..."' >> start.sh && \
    echo './bin/gateway &' >> start.sh && \
    echo './bin/real-time &' >> start.sh && \
    echo './bin/service &' >> start.sh && \
    echo 'wait' >> start.sh && \
    chmod +x start.sh

# Expose ports (adjust as needed)
EXPOSE 8080 8081 8082 3000

# Start all services
CMD ["./start.sh"]

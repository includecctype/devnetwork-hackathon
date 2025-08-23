FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-pip \
    python3.11-venv \
    python3.11-dev \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz \
    && rm go1.21.6.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV GOROOT="/usr/local/go"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup component add clippy rustfmt
RUN cargo install cargo-audit

RUN go install golang.org/x/tools/cmd/goimports@latest
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

RUN pip3 install ruff poetry

RUN npm install -g eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin typescript ts-node prettier

WORKDIR /app

COPY . .

RUN if [ -f "backend/service/pyproject.toml" ]; then cd backend/service && uv sync; fi

RUN if [ -f "frontend/package.json" ]; then cd frontend && npm install; fi

RUN if [ -f "backend/gateway/go.mod" ]; then cd backend/gateway && go mod download && go build -o ../../bin/gateway .; fi
RUN if [ -f "backend/real-time/go.mod" ]; then cd backend/real-time && go mod download && go build -o ../../bin/real-time .; fi

RUN if [ -f "backend/gateway/Cargo.toml" ]; then cd backend/gateway && cargo build --release; fi
RUN if [ -f "backend/real-time/Cargo.toml" ]; then cd backend/real-time && cargo build --release; fi

RUN if [ -f "frontend/package.json" ]; then cd frontend && npm run build; fi

RUN echo '#!/bin/bash' > lint-all.sh && \
    echo 'echo "=== LINTING ALL SERVICES ==="' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -d "backend/service" ]; then' >> lint-all.sh && \
    echo '  echo "🐍 Linting Python service..."' >> lint-all.sh && \
    echo '  cd backend/service && ruff check . && ruff format --check .' >> lint-all.sh && \
    echo '  cd ../..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -d "backend/gateway" ] && [ -f "backend/gateway/go.mod" ]; then' >> lint-all.sh && \
    echo '  echo "🐹 Linting Go gateway..."' >> lint-all.sh && \
    echo '  cd backend/gateway && golangci-lint run && goimports -d .' >> lint-all.sh && \
    echo '  cd ../..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -d "backend/real-time" ] && [ -f "backend/real-time/go.mod" ]; then' >> lint-all.sh && \
    echo '  echo "🐹 Linting Go real-time..."' >> lint-all.sh && \
    echo '  cd backend/real-time && golangci-lint run && goimports -d .' >> lint-all.sh && \
    echo '  cd ../..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -d "backend/gateway" ] && [ -f "backend/gateway/Cargo.toml" ]; then' >> lint-all.sh && \
    echo '  echo "🦀 Linting Rust gateway..."' >> lint-all.sh && \
    echo '  cd backend/gateway && cargo clippy -- -D warnings && cargo fmt --check' >> lint-all.sh && \
    echo '  cd ../..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -d "backend/real-time" ] && [ -f "backend/real-time/Cargo.toml" ]; then' >> lint-all.sh && \
    echo '  echo "🦀 Linting Rust real-time..."' >> lint-all.sh && \
    echo '  cd backend/real-time && cargo clippy -- -D warnings && cargo fmt --check' >> lint-all.sh && \
    echo '  cd ../..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'if [ -f "frontend/package.json" ]; then' >> lint-all.sh && \
    echo '  echo "📦 Linting Frontend..."' >> lint-all.sh && \
    echo '  cd frontend && npx eslint . && npx prettier --check .' >> lint-all.sh && \
    echo '  cd ..' >> lint-all.sh && \
    echo 'fi' >> lint-all.sh && \
    echo '' >> lint-all.sh && \
    echo 'echo "✅ All linting completed!"' >> lint-all.sh && \
    chmod +x lint-all.sh

RUN echo '#!/bin/bash' > start-dev.sh && \
    echo 'echo "🚀 Starting DEVNETWORK-HACKATHON (Development Mode)"' >> start-dev.sh && \
    echo '' >> start-dev.sh && \
    echo 'if [ -f "./bin/gateway" ]; then' >> start-dev.sh && \
    echo '  echo "🌐 Starting Gateway service on :8080"' >> start-dev.sh && \
    echo '  ./bin/gateway &' >> start-dev.sh && \
    echo 'fi' >> start-dev.sh && \
    echo '' >> start-dev.sh && \
    echo 'if [ -f "./bin/real-time" ]; then' >> start-dev.sh && \
    echo '  echo "⚡ Starting Real-time service on :8081"' >> start-dev.sh && \
    echo '  ./bin/real-time &' >> start-dev.sh && \
    echo 'fi' >> start-dev.sh && \
    echo '' >> start-dev.sh && \
    echo 'if [ -f "backend/service/main.py" ]; then' >> start-dev.sh && \
    echo '  echo "🐍 Starting Python service on :8082"' >> start-dev.sh && \
    echo '  cd backend/service && uv run python main.py &' >> start-dev.sh && \
    echo '  cd ../..' >> start-dev.sh && \
    echo 'fi' >> start-dev.sh && \
    echo '' >> start-dev.sh && \
    echo 'if [ -f "frontend/package.json" ]; then' >> start-dev.sh && \
    echo '  echo "⚛️ Starting Frontend dev server on :3000"' >> start-dev.sh && \
    echo '  cd frontend && npm start &' >> start-dev.sh && \
    echo '  cd ..' >> start-dev.sh && \
    echo 'fi' >> start-dev.sh && \
    echo '' >> start-dev.sh && \
    echo 'echo "🎯 All services started! Check:"' >> start-dev.sh && \
    echo 'echo "  - Gateway: http://localhost:8080"' >> start-dev.sh && \
    echo 'echo "  - Real-time: http://localhost:8081"' >> start-dev.sh && \
    echo 'echo "  - Service: http://localhost:8082"' >> start-dev.sh && \
    echo 'echo "  - Frontend: http://localhost:3000"' >> start-dev.sh && \
    echo 'wait' >> start-dev.sh && \
    chmod +x start-dev.sh

RUN echo '#!/bin/bash' > start-prod.sh && \
    echo 'echo "🏭 Starting DEVNETWORK-HACKATHON (Production Mode)"' >> start-prod.sh && \
    echo 'export NODE_ENV=production' >> start-prod.sh && \
    echo 'export PYTHONPATH=/app/backend/service' >> start-prod.sh && \
    echo '' >> start-prod.sh && \
    echo './bin/gateway &' >> start-prod.sh && \
    echo './bin/real-time &' >> start-prod.sh && \
    echo 'cd backend/service && uv run python main.py &' >> start-prod.sh && \
    echo 'cd ../..' >> start-prod.sh && \
    echo '' >> start-prod.sh && \
    echo 'wait' >> start-prod.sh && \
    chmod +x start-prod.sh

EXPOSE 3000 8000 8080 8081 8082 5000 9000

CMD ["./start-dev.sh"]
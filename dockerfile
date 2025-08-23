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

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g typescript ts-node @types/node

RUN wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz \
    && rm go1.21.6.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV GOROOT="/usr/local/go"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN echo "=== Verifying installations ===" \
    && python3 --version \
    && pip3 --version \
    && node --version \
    && npm --version \
    && npx tsc --version \
    && go version \
    && rustc --version \
    && cargo --version

WORKDIR /app

COPY . .

RUN if [ -f "requirements.txt" ]; then pip3 install -r requirements.txt; fi
RUN if [ -f "backend/service/requirements.txt" ]; then pip3 install -r backend/service/requirements.txt; fi
RUN if [ -f "backend/service/pyproject.toml" ]; then pip3 install -e backend/service/; fi

RUN if [ -f "frontend/package.json" ]; then cd frontend && npm install; fi
RUN if [ -f "package.json" ]; then npm install; fi

RUN if [ -f "backend/gateway/go.mod" ]; then cd backend/gateway && go mod download && go build -o ../../bin/gateway .; fi
RUN if [ -f "backend/real-time/go.mod" ]; then cd backend/real-time && go mod download && go build -o ../../bin/real-time .; fi
RUN if [ -f "backend/service/go.mod" ]; then cd backend/service && go mod download && go build -o ../../bin/service .; fi

RUN if [ -f "backend/gateway/Cargo.toml" ]; then cd backend/gateway && cargo build --release; fi
RUN if [ -f "backend/real-time/Cargo.toml" ]; then cd backend/real-time && cargo build --release; fi

RUN if [ -f "frontend/package.json" ]; then cd frontend && npm run build; fi

RUN echo '#!/bin/bash' > start-all.sh && \
    echo 'echo "Starting DEVNETWORK-HACKATHON services..."' >> start-all.sh && \
    echo 'if [ -f "./bin/gateway" ]; then' >> start-all.sh && \
    echo '  echo "Starting Gateway service..."' >> start-all.sh && \
    echo '  ./bin/gateway &' >> start-all.sh && \
    echo 'fi' >> start-all.sh && \
    echo 'if [ -f "./bin/real-time" ]; then' >> start-all.sh && \
    echo '  echo "Starting Real-time service..."' >> start-all.sh && \
    echo '  ./bin/real-time &' >> start-all.sh && \
    echo 'fi' >> start-all.sh && \
    echo 'if [ -f "./bin/service" ]; then' >> start-all.sh && \
    echo '  echo "Starting Main service..."' >> start-all.sh && \
    echo '  ./bin/service &' >> start-all.sh && \
    echo 'fi' >> start-all.sh && \
    echo 'if [ -f "app.py" ]; then' >> start-all.sh && \
    echo '  echo "Starting Python app..."' >> start-all.sh && \
    echo '  python3 app.py &' >> start-all.sh && \
    echo 'fi' >> start-all.sh && \
    echo 'if [ -f "frontend/package.json" ] && [ "$NODE_ENV" = "development" ]; then' >> start-all.sh && \
    echo '  echo "Starting frontend dev server..."' >> start-all.sh && \
    echo '  cd frontend && npm start &' >> start-all.sh && \
    echo '  cd ..' >> start-all.sh && \
    echo 'fi' >> start-all.sh && \
    echo 'echo "All services started. Waiting..."' >> start-all.sh && \
    echo 'wait' >> start-all.sh && \
    chmod +x start-all.sh

EXPOSE 3000 8000 8080 8081 8082 5000 9000

CMD ["./start-all.sh"]
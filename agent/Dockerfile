# syntax=docker/dockerfile:1
# Image LiveKit Cloud builds and runs for the agent (`lk agent create`).
ARG PYTHON_VERSION=3.12
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim

ENV PYTHONUNBUFFERED=1

# Run as an unprivileged user.
ARG UID=10001
RUN adduser --disabled-password --gecos "" --home "/app" --shell "/sbin/nologin" \
    --uid "${UID}" appuser

# Build tools some wheels need.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first so they are cached between code changes.
COPY pyproject.toml uv.lock ./
RUN mkdir -p src && touch src/__init__.py
RUN uv sync --locked --no-dev

COPY . .
RUN chown -R appuser:appuser /app
USER appuser

# Download the VAD and turn-detector models at build time, not on first call.
RUN uv run src/agent.py download-files

CMD ["uv", "run", "src/agent.py", "start"]

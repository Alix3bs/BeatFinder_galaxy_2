# BeatFinder backend: Node HTTP API + Python retrieval engine.
# Build:  docker build -t beatfinder-backend .
# Run:    docker run -p 8787:8787 -v beatfinder-state:/data beatfinder-backend

FROM node:24-bookworm-slim

# Python runtime for the retrieval engine, ffmpeg for non-WAV uploads,
# curl for the container health check.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        ffmpeg \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

COPY backend ./backend
COPY models ./models
COPY scripts ./scripts
COPY data ./data
COPY supabase/migrations ./supabase/migrations

# Non-root runtime user; state lives on a mounted volume at /data.
RUN useradd --create-home --uid 10001 beatfinder \
    && mkdir -p /data \
    && chown -R beatfinder:beatfinder /app /data
USER beatfinder

ENV PORT=8787 \
    BEATFINDER_PYTHON_BIN=python3 \
    BEATFINDER_STATE_DIR=/data \
    BEATFINDER_SUPABASE_MODE=local \
    PYTHONPYCACHEPREFIX=/tmp/beatfinder_pycache \
    NODE_ENV=production

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

# server.ts handles SIGTERM for graceful shutdown; node runs as PID 1 with
# --experimental-strip-types kept for compatibility across Node 22/24.
CMD ["node", "--experimental-strip-types", "backend/api/server.ts"]

# BeatFinder backend: Node HTTP API + Python retrieval engine.
# Build:  docker build -t beatfinder-backend .
# Run:    docker run -p 8787:8787 -v beatfinder-state:/data beatfinder-backend

FROM node:24-bookworm-slim

# Python runtime for the retrieval engine, ffmpeg for non-WAV uploads,
# curl for the container health check, gosu for the privilege-dropping
# entrypoint.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        ffmpeg \
        curl \
        gosu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

COPY backend ./backend
COPY models ./models
COPY scripts ./scripts
COPY data ./data
COPY supabase/migrations ./supabase/migrations

# Non-root runtime user; state lives on a mounted volume at /data. Hosts
# (e.g. Render) mount the disk at runtime owned by root, so the entrypoint
# fixes ownership on start and drops privileges — the container must start
# as root for that to work, but the server never runs as root.
COPY scripts/deploy/entrypoint.sh /usr/local/bin/beatfinder-entrypoint
RUN chmod +x /usr/local/bin/beatfinder-entrypoint \
    && useradd --create-home --uid 10001 beatfinder \
    && mkdir -p /data \
    && chown -R beatfinder:beatfinder /app /data

ENV PORT=8787 \
    BEATFINDER_PYTHON_BIN=python3 \
    BEATFINDER_STATE_DIR=/data \
    BEATFINDER_SUPABASE_MODE=local \
    PYTHONPYCACHEPREFIX=/tmp/beatfinder_pycache \
    NODE_ENV=production

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

# server.ts handles SIGTERM for graceful shutdown; the entrypoint execs the
# command so node stays PID 1. --experimental-strip-types kept for
# compatibility across Node 22/24.
ENTRYPOINT ["/usr/local/bin/beatfinder-entrypoint"]
CMD ["node", "--experimental-strip-types", "backend/api/server.ts"]

#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
PYTHON_BIN="${BEATFINDER_PYTHON_BIN:-/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
NODE_BIN="${BEATFINDER_NODE_BIN:-/Users/traytray/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
export BEATFINDER_STATE_DIR="${BEATFINDER_STATE_DIR:-$ROOT_DIR/.beatfinder_state}"

exec "$NODE_BIN" --experimental-strip-types "$ROOT_DIR/backend/api/server.ts"

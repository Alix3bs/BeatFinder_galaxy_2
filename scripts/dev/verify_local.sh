#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
PYTHON_BIN="${BEATFINDER_PYTHON_BIN:-python3}"

export BEATFINDER_PYTHON_BIN="$PYTHON_BIN"
export BEATFINDER_NODE_BIN="${BEATFINDER_NODE_BIN:-node}"
export BEATFINDER_STATE_DIR="${BEATFINDER_STATE_DIR:-$ROOT_DIR/.beatfinder_state}"
export BEATFINDER_SUPABASE_MODE="${BEATFINDER_SUPABASE_MODE:-local}"

cd "$ROOT_DIR"

"$PYTHON_BIN" scripts/dev/lint.py
"$PYTHON_BIN" -m unittest discover -s backend/tests -p 'test_*.py' -v
"$PYTHON_BIN" scripts/eval/run_eval.py

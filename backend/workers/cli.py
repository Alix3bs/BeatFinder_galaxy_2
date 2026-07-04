from __future__ import annotations

import argparse
import json
import os
import sys
import traceback
from pathlib import Path

from backend.core.upload_validation import UploadValidationError
from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService, query_audio_retention_enabled
from backend.storage.runtime import build_runtime_store
from models.metadata.gemma_adapter import GemmaReasoner

# Exit codes consumed by backend/api/server.ts:
# 0 success, 4 client error (safe message on stdout), 5 internal error.
EXIT_CLIENT_ERROR = 4
EXIT_INTERNAL_ERROR = 5


def main() -> int:
    parser = argparse.ArgumentParser(description="BeatFinder hybrid retrieval CLI")
    parser.add_argument(
        "command",
        choices=[
            "ingest",
            "search-text",
            "search-audio",
            "search-hybrid",
            "feedback",
            "health",
        ],
    )
    parser.add_argument("--state-dir", default=None)
    args = parser.parse_args()

    try:
        payload = read_json_from_stdin()
    except json.JSONDecodeError:
        print(json.dumps({"error": "invalid_json", "message": "Request body is not valid JSON."}))
        return EXIT_CLIENT_ERROR

    try:
        result = run_command(args.command, payload, state_dir=args.state_dir)
    except UploadValidationError as error:
        print(
            json.dumps(
                {
                    "error": error.code,
                    "message": str(error),
                    "http_status": error.http_status,
                }
            )
        )
        return EXIT_CLIENT_ERROR
    except ValueError as error:
        print(json.dumps({"error": "invalid_request", "message": str(error), "http_status": 400}))
        return EXIT_CLIENT_ERROR
    except Exception:
        traceback.print_exc(file=sys.stderr)
        print(
            json.dumps(
                {
                    "error": "internal_error",
                    "message": "BeatFinder backend hit an internal error.",
                    "http_status": 500,
                }
            )
        )
        return EXIT_INTERNAL_ERROR

    print(json.dumps(result, indent=2))
    return 0


def run_command(command: str, payload: dict[str, object], *, state_dir: str | None) -> dict[str, object]:
    store = build_runtime_store(state_dir)
    discovery_store = ProducerDiscoveryStore(state_dir or getattr(store, "root", None))
    reasoner = GemmaReasoner()
    ingest_service = IngestService(store, reasoner=reasoner)
    retrieval_service = RetrievalService(store, reasoner=reasoner, discovery_store=discovery_store)

    if command == "ingest":
        return ingest_service.ingest_beat(payload)
    if command == "search-text":
        return retrieval_service.search_text(payload)
    if command == "search-audio":
        return retrieval_service.search_audio(payload)
    if command == "search-hybrid":
        return retrieval_service.search_hybrid(payload)
    if command == "feedback":
        return retrieval_service.record_feedback(payload)
    return {
        "status": "ok",
        "state_dir": str(Path(store.root).resolve()),
        "beats_indexed": len(store.list_beats()),
        "storage_mode": os.getenv("BEATFINDER_SUPABASE_MODE", "local").strip().lower() or "local",
        "query_audio_retention": "retain" if query_audio_retention_enabled() else "delete_after_processing",
    }


def read_json_from_stdin() -> dict[str, object]:
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    return json.loads(raw)


if __name__ == "__main__":
    raise SystemExit(main())

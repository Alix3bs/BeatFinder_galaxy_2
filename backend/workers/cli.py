from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.runtime import build_runtime_store
from models.metadata.gemma_adapter import GemmaReasoner


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

    payload = read_json_from_stdin()
    store = build_runtime_store(args.state_dir)
    reasoner = GemmaReasoner()
    ingest_service = IngestService(store, reasoner=reasoner)
    retrieval_service = RetrievalService(store, reasoner=reasoner)

    if args.command == "ingest":
        result = ingest_service.ingest_beat(payload)
    elif args.command == "search-text":
        result = retrieval_service.search_text(payload)
    elif args.command == "search-audio":
        result = retrieval_service.search_audio(payload)
    elif args.command == "search-hybrid":
        result = retrieval_service.search_hybrid(payload)
    elif args.command == "feedback":
        result = retrieval_service.record_feedback(payload)
    else:
        result = {
            "status": "ok",
            "state_dir": str(Path(store.root).resolve()),
            "beats_indexed": len(store.list_beats()),
        }

    print(json.dumps(result, indent=2))
    return 0


def read_json_from_stdin() -> dict[str, object]:
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    return json.loads(raw)


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures, write_clip
from models.metadata.gemma_adapter import GemmaReasoner


def main() -> int:
    state_dir = Path(os.getenv("BEATFINDER_STATE_DIR", REPO_ROOT / ".beatfinder_eval_state"))
    fixture_dir = REPO_ROOT / "backend" / "tests" / "generated_audio_eval"
    clip_path = fixture_dir / "late_nights_clip.wav"

    store = LocalStateStore(state_dir)
    store.reset()
    reasoner = GemmaReasoner()
    ingest = IngestService(store, reasoner=reasoner)
    retrieval = RetrievalService(store, reasoner=reasoner)

    fixtures = materialize_fixtures(fixture_dir)
    for payload in fixtures:
        ingest.ingest_beat(payload)

    exact_audio = retrieval.search_audio({"audio_path": fixtures[0]["audio_path"], "top_n": 3})
    write_clip(fixtures[0]["audio_path"], clip_path, start_seconds=1.0, duration_seconds=3.5)
    clip_audio = retrieval.search_audio({"audio_path": str(clip_path), "top_n": 3})
    text_query = retrieval.search_text({"query": "sza x summer walker type beat", "top_n": 5})
    hybrid_query = retrieval.search_hybrid(
        {
            "query": "sza x summer walker type beat",
            "audio_path": fixtures[0]["audio_path"],
            "top_n": 5,
        }
    )

    report = {
        "fixtures_ingested": len(fixtures),
        "exact_audio_top": exact_audio["results"][0]["beat"]["raw_title"] if exact_audio["results"] else None,
        "clip_audio_top": clip_audio["results"][0]["beat"]["raw_title"] if clip_audio["results"] else None,
        "text_top_titles": [row["beat"]["raw_title"] for row in text_query["results"]],
        "hybrid_top_titles": [row["beat"]["raw_title"] for row in hybrid_query["results"]],
        "exact_audio": exact_audio,
        "clip_audio": clip_audio,
        "text_query": text_query,
        "hybrid_query": hybrid_query,
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

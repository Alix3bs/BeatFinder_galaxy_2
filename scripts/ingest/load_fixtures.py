from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.ingest.service import IngestService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures
from models.metadata.gemma_adapter import GemmaReasoner


def main() -> int:
    state_dir = Path(os.getenv("BEATFINDER_STATE_DIR", REPO_ROOT / ".beatfinder_state"))
    fixture_audio_dir = REPO_ROOT / "backend" / "tests" / "generated_audio"

    store = LocalStateStore(state_dir)
    ingest = IngestService(store, reasoner=GemmaReasoner())

    fixtures = materialize_fixtures(fixture_audio_dir)
    results = [ingest.ingest_beat(payload) for payload in fixtures]
    print(json.dumps({"fixtures_loaded": len(results), "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

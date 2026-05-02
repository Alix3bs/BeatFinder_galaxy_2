from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.supabase_store import SupabasePrimaryStore
from backend.tests.fixture_builder import materialize_fixtures, write_clip
from models.metadata.gemma_adapter import GemmaReasoner


REQUIRED_ENV_VARS = ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")


@unittest.skipUnless(
    os.getenv("BEATFINDER_RUN_SUPABASE_INTEGRATION") == "1"
    and all(os.getenv(name) for name in REQUIRED_ENV_VARS),
    "Set BEATFINDER_RUN_SUPABASE_INTEGRATION=1 plus Supabase credentials to run live integration coverage.",
)
class SupabasePrimaryIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.temp_dir.name) / "state"
        self.fixture_dir = Path(self.temp_dir.name) / "fixtures"
        self.store = SupabasePrimaryStore.from_env(self.state_dir)
        if self.store is None:
            self.skipTest("Supabase primary store is unavailable.")
        self.reasoner = GemmaReasoner()
        self.ingest_service = IngestService(self.store, reasoner=self.reasoner)
        self.retrieval_service = RetrievalService(self.store, reasoner=self.reasoner)
        self.fixtures = materialize_fixtures(self.fixture_dir)
        for payload in self.fixtures:
            self.ingest_service.ingest_beat(payload)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_live_supabase_primary_flow(self) -> None:
        exact_audio = self.retrieval_service.search_audio({"audio_path": self.fixtures[0]["audio_path"], "top_n": 3})
        clip_path = self.fixture_dir / "late_nights_clip.wav"
        write_clip(self.fixtures[0]["audio_path"], clip_path, start_seconds=1.0, duration_seconds=3.5)
        clip_audio = self.retrieval_service.search_audio({"audio_path": str(clip_path), "top_n": 3})
        text_query = self.retrieval_service.search_text({"query": "sza x summer walker type beat", "top_n": 5})
        hybrid_query = self.retrieval_service.search_hybrid(
            {
                "query": "sza x summer walker type beat",
                "audio_path": self.fixtures[0]["audio_path"],
                "top_n": 5,
            }
        )

        self.assertEqual(exact_audio["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])
        self.assertIn(self.fixtures[0]["title"], [row["beat"]["raw_title"] for row in clip_audio["results"][:2]])
        self.assertIn(self.fixtures[0]["title"], [row["beat"]["raw_title"] for row in text_query["results"][:3]])
        self.assertEqual(hybrid_query["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])

        feedback = self.retrieval_service.record_feedback(
            {
                "query_id": hybrid_query["query_id"],
                "beat_id": hybrid_query["results"][0]["beat"]["id"],
                "event_type": "confirmed_match",
            }
        )
        self.assertEqual(feedback["status"], "recorded")


if __name__ == "__main__":
    unittest.main()

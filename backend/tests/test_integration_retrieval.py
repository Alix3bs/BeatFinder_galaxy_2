from __future__ import annotations

import base64
import tempfile
import unittest
from pathlib import Path

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures, write_clip
from models.metadata.gemma_adapter import GemmaReasoner


class IntegrationRetrievalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.temp_dir.name) / "state"
        self.fixture_dir = Path(self.temp_dir.name) / "fixtures"
        self.store = LocalStateStore(self.state_dir)
        self.reasoner = GemmaReasoner()
        self.ingest_service = IngestService(self.store, reasoner=self.reasoner)
        self.retrieval_service = RetrievalService(self.store, reasoner=self.reasoner)
        self.fixtures = materialize_fixtures(self.fixture_dir)
        for payload in self.fixtures:
            self.ingest_service.ingest_beat(payload)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_exact_audio_query_ranks_same_beat_first(self) -> None:
        response = self.retrieval_service.search_audio({"audio_path": self.fixtures[0]["audio_path"], "top_n": 3})
        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])
        self.assertIn("score_breakdown", response["results"][0])

    def test_short_clip_ranks_original_beat_highly(self) -> None:
        clip_path = self.fixture_dir / "late_nights_clip.wav"
        write_clip(self.fixtures[0]["audio_path"], clip_path, start_seconds=1.0, duration_seconds=3.5)
        response = self.retrieval_service.search_audio({"audio_path": str(clip_path), "top_n": 3})
        top_titles = [row["beat"]["raw_title"] for row in response["results"]]
        self.assertIn(self.fixtures[0]["title"], top_titles[:2])

    def test_audio_query_accepts_base64(self) -> None:
        audio_bytes = Path(self.fixtures[0]["audio_path"]).read_bytes()
        response = self.retrieval_service.search_audio(
            {
                "audio_base64": base64.b64encode(audio_bytes).decode("ascii"),
                "audio_file_name": "late_nights.wav",
                "audio_mime_type": "audio/wav",
                "top_n": 3,
            }
        )
        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])

    def test_ingest_accepts_base64(self) -> None:
        with tempfile.TemporaryDirectory() as ingest_dir:
            payload = dict(self.fixtures[0])
            payload["title"] = "Custom Base64 Fixture"
            payload["source_url"] = "https://example.com/beats/custom-base64"
            payload.pop("audio_path", None)
            payload["audio_base64"] = base64.b64encode(Path(self.fixtures[0]["audio_path"]).read_bytes()).decode("ascii")
            payload["audio_file_name"] = "custom_base64.wav"
            payload["audio_mime_type"] = "audio/wav"
            base64_store = LocalStateStore(Path(ingest_dir) / "state")
            base64_ingest = IngestService(base64_store, reasoner=self.reasoner)
            result = base64_ingest.ingest_beat(payload)
            self.assertEqual(result["status"], "ingested")
            self.assertTrue(result["audio_storage_path"].endswith(".wav"))

    def test_metadata_query_returns_matching_family(self) -> None:
        response = self.retrieval_service.search_text({"query": "sza x summer walker type beat", "top_n": 5})
        top_titles = [row["beat"]["raw_title"] for row in response["results"]]
        self.assertIn(self.fixtures[0]["title"], top_titles[:3])
        self.assertIn(self.fixtures[1]["title"], top_titles[:4])

    def test_hybrid_query_improves_rank_for_exact_audio_match(self) -> None:
        text_response = self.retrieval_service.search_text({"query": "sza x summer walker type beat", "top_n": 5})
        hybrid_response = self.retrieval_service.search_hybrid(
            {
                "query": "sza x summer walker type beat",
                "audio_path": self.fixtures[0]["audio_path"],
                "top_n": 5,
            }
        )
        text_titles = [row["beat"]["raw_title"] for row in text_response["results"]]
        hybrid_titles = [row["beat"]["raw_title"] for row in hybrid_response["results"]]
        self.assertLessEqual(hybrid_titles.index(self.fixtures[0]["title"]), text_titles.index(self.fixtures[0]["title"]))
        self.assertEqual(hybrid_titles[0], self.fixtures[0]["title"])


if __name__ == "__main__":
    unittest.main()

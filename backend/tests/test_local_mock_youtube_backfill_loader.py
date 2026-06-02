from __future__ import annotations

import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures
from models.metadata.gemma_adapter import GemmaReasoner
from scripts.discovery.load_mock_youtube_backfill import load_mock_youtube_backfill


class LocalMockYouTubeBackfillLoaderTests(unittest.TestCase):
    def test_loader_indexes_mock_videos_for_prod_salishan(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_dir = Path(tmp) / "state"

            summary = load_mock_youtube_backfill(state_dir=state_dir)
            store = ProducerDiscoveryStore(state_dir)
            channel = store.get_channel("prod.salishan")

            self.assertIsNotNone(channel)
            self.assertEqual(summary["channels_backfilled"], 1)
            self.assertTrue(summary["completed"])
            self.assertGreaterEqual(summary["videos_created_or_refreshed"], 1)
            self.assertEqual(summary["videos_skipped"], 0)

            videos = store.list_videos(channel.id)
            self.assertTrue(videos)
            self.assertEqual(videos[0].title, "SZA x Summer Walker Type Beat - Late Nights")
            self.assertIn("#phillytypebeat", videos[0].hashtags)
            self.assertIn("sza x summer walker", videos[0].artist_combo_refs)
            self.assertIn("sza x summer walker type beat", videos[0].type_beat_phrases)

    def test_search_enrichment_returns_found_candidate_after_loader_runs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_dir = Path(tmp) / "state"
            reasoner = GemmaReasoner()
            beat_store = LocalStateStore(state_dir)
            discovery_store = ProducerDiscoveryStore(state_dir)
            ingest_service = IngestService(beat_store, reasoner=reasoner)
            for payload in materialize_fixtures(Path(tmp) / "fixtures"):
                ingest_service.ingest_beat(payload)
            load_mock_youtube_backfill(state_dir=state_dir)
            retrieval_service = RetrievalService(
                beat_store,
                reasoner=reasoner,
                discovery_store=discovery_store,
            )

            response = retrieval_service.search_text(
                {
                    "query": "sza x summer walker type beat",
                    "detected_producer_tag": "prod by salishan",
                    "top_n": 3,
                }
            )

            discovery = response["discovery"]
            self.assertEqual(discovery["discovery_status"], "found_candidate")
            self.assertIsNotNone(discovery["youtube_video_match"])
            self.assertIn("SZA x Summer Walker Type Beat", discovery["youtube_video_match"]["title"])

    def test_running_loader_twice_does_not_duplicate_videos(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_dir = Path(tmp) / "state"

            first = load_mock_youtube_backfill(state_dir=state_dir)
            second = load_mock_youtube_backfill(state_dir=state_dir)
            store = ProducerDiscoveryStore(state_dir)
            channel = store.get_channel("prod.salishan")

            self.assertGreater(first["videos_created_or_refreshed"], 0)
            self.assertEqual(second["videos_created_or_refreshed"], 0)
            self.assertEqual(second["videos_skipped"], len(store.list_videos(channel.id)))
            self.assertEqual(len(store.list_videos(channel.id)), len({video.video_id for video in store.list_videos(channel.id)}))

    def test_loader_does_not_call_live_network(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(socket, "create_connection", side_effect=AssertionError("live network call")):
                summary = load_mock_youtube_backfill(state_dir=Path(tmp) / "state")

            self.assertTrue(summary["completed"])


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.producer_channels import ProducerBeatVideo, ProducerDiscoveryStore
from backend.discovery.search_enrichment import enrich_search_discovery
from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures
from models.metadata.gemma_adapter import GemmaReasoner


class SearchDiscoveryEnrichmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.tmp.name) / "state"
        self.fixture_dir = Path(self.tmp.name) / "fixtures"
        self.beat_store = LocalStateStore(self.state_dir)
        self.discovery_store = ProducerDiscoveryStore(self.state_dir)
        self.reasoner = GemmaReasoner()
        self.ingest_service = IngestService(self.beat_store, reasoner=self.reasoner)
        self.retrieval_service = RetrievalService(
            self.beat_store,
            reasoner=self.reasoner,
            discovery_store=self.discovery_store,
        )
        self.fixtures = materialize_fixtures(self.fixture_dir)
        for payload in self.fixtures:
            self.ingest_service.ingest_beat(payload)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _add_salishan_channel(self) -> str:
        channel = self.discovery_store.upsert_channel(
            "https://youtube.com/@prod.salishan",
            producer_name="prod.salishan",
            aliases=["prod.salishan"],
        )
        return channel.id

    def test_audio_search_with_matched_producer_tag_enriches_response(self) -> None:
        self._add_salishan_channel()

        response = self.retrieval_service.search_audio(
            {
                "audio_path": self.fixtures[0]["audio_path"],
                "top_n": 3,
                "detected_producer_tag": "prod by salishan",
            }
        )

        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])
        self.assertIn("discovery", response)
        discovery = response["discovery"]
        self.assertEqual(discovery["detected_producer_tag"], "prod by salishan")
        self.assertEqual(discovery["matched_producer_channel"]["channel_id"], "prod.salishan")
        self.assertGreaterEqual(discovery["producer_tag_confidence"], 0.7)

    def test_producer_tag_matched_but_no_indexed_video_returns_possible_sold_or_deleted(self) -> None:
        self._add_salishan_channel()

        response = self.retrieval_service.search_text(
            {
                "query": "milwaukee x detroit type beat",
                "detected_producer_tag": "prod by salishan",
                "top_n": 3,
            }
        )

        discovery = response["discovery"]
        self.assertEqual(discovery["discovery_status"], "possible_sold_or_deleted")
        self.assertIsNone(discovery["youtube_video_match"])
        self.assertIn("not_yet_indexed", discovery["possible_reasons"])
        self.assertTrue(any("no visible matching" in item for item in discovery["evidence"]))

    def test_found_indexed_youtube_beat_returns_found_candidate(self) -> None:
        channel_id = self._add_salishan_channel()
        self.discovery_store.upsert_video(
            ProducerBeatVideo(
                producer_channel_id=channel_id,
                video_id="salishan-late-nights",
                video_url="https://www.youtube.com/watch?v=salishan-late-nights",
                title="SZA x Summer Walker Type Beat - Late Nights",
                hashtags=["#phillytypebeat"],
                normalized_search_phrases=["sza x summer walker type beat", "late nights", "philly type beat"],
                artist_combo_refs=["sza x summer walker"],
                type_beat_phrases=["sza x summer walker type beat"],
                city_tags=["philly"],
                region_tags=["philly"],
                style_tags=["type_beat"],
            )
        )

        response = self.retrieval_service.search_hybrid(
            {
                "query": "sza x summer walker type beat",
                "audio_path": self.fixtures[0]["audio_path"],
                "detected_producer_tag": "prod by salishan",
                "top_n": 3,
            }
        )

        discovery = response["discovery"]
        self.assertEqual(discovery["discovery_status"], "found_candidate")
        self.assertEqual(discovery["youtube_video_match"]["video_id"], "salishan-late-nights")
        self.assertEqual(discovery["possible_reasons"], [])

    def test_no_producer_tag_returns_not_applicable(self) -> None:
        response = self.retrieval_service.search_text({"query": "sza type beat", "top_n": 3})

        self.assertEqual(response["discovery"]["discovery_status"], "not_applicable")
        self.assertIsNone(response["discovery"]["detected_producer_tag"])

    def test_weak_producer_tag_returns_insufficient_evidence(self) -> None:
        self._add_salishan_channel()

        response = self.retrieval_service.search_text(
            {
                "query": "sza type beat",
                "detected_producer_tag": "prod by",
                "top_n": 3,
            }
        )

        discovery = response["discovery"]
        self.assertEqual(discovery["discovery_status"], "insufficient_evidence")
        self.assertIsNone(discovery["matched_producer_channel"])
        self.assertEqual(discovery["possible_reasons"], [])

    def test_recommended_next_searches_include_hashtags_artist_combos_and_city_combos(self) -> None:
        channel_id = self._add_salishan_channel()
        video = ProducerBeatVideo(
            producer_channel_id=channel_id,
            video_id="salishan-motion",
            video_url="https://www.youtube.com/watch?v=salishan-motion",
            title="Philly x Dallas Type Beat - Motion",
            hashtags=["#phillytypebeat"],
            normalized_search_phrases=["philly x dallas type beat", "motion"],
            artist_combo_refs=["sza x summer walker"],
            type_beat_phrases=["philly x dallas type beat"],
            city_tags=["philly", "dallas"],
            region_tags=["philly", "dallas"],
            style_tags=["type_beat"],
        )
        self.discovery_store.upsert_video(video)

        enrichment = enrich_search_discovery(
            query_metadata={"normalized_query_phrases": ["philly x dallas type beat"]},
            detected_producer_tag="prod by salishan",
            matched_candidates=[
                {
                    "beat": {
                        "raw_title": "SZA x Summer Walker Type Beat - Late Nights",
                        "hashtags": ["#phillytypebeat"],
                        "artist_combo_refs": ["sza x summer walker"],
                        "region_tags": ["milwaukee", "detroit"],
                        "type_beat_phrases": ["sza x summer walker type beat"],
                    }
                }
            ],
            producer_discovery_store=self.discovery_store,
        )

        searches = set(enrichment.to_dict()["recommended_next_searches"])
        self.assertIn("philly type beat", searches)
        self.assertIn("sza summer walker type beat", searches)
        self.assertIn("milwaukee detroit type beat", searches)
        self.assertIn("philly dallas type beat", searches)

    def test_existing_search_behavior_still_works_with_optional_discovery(self) -> None:
        response = self.retrieval_service.search_text({"query": "sza x summer walker type beat", "top_n": 3})

        self.assertTrue(response["results"])
        self.assertIn("score_breakdown", response["results"][0])
        self.assertIn("candidate_pool_sizes", response)
        self.assertEqual(response["discovery"]["discovery_status"], "not_applicable")

    def test_no_live_network_call_happens_in_discovery_enrichment(self) -> None:
        self._add_salishan_channel()

        with patch.object(socket, "create_connection", side_effect=AssertionError("live network call")) as create_connection:
            response = self.retrieval_service.search_audio(
                {
                    "audio_path": self.fixtures[0]["audio_path"],
                    "detected_producer_tag": "prod by salishan",
                    "top_n": 3,
                }
            )

        self.assertIn(response["discovery"]["discovery_status"], {"found_candidate", "possible_sold_or_deleted"})
        create_connection.assert_not_called()


if __name__ == "__main__":
    unittest.main()

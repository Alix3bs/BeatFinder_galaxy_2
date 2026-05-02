from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures
from models.metadata.gemma_adapter import GemmaReasoner


class ScanOnlyStore:
    def __init__(self, delegate: LocalStateStore) -> None:
        self.delegate = delegate
        self.root = delegate.root

    def __getattr__(self, name: str):
        return getattr(self.delegate, name)

    def search_embedding_candidates(self, query_embedding, *, model_name: str, limit: int):
        return []

    def search_metadata_candidates(self, query_text: str, *, limit: int):
        return []


class CandidateStore:
    def __init__(self, delegate: LocalStateStore) -> None:
        self.delegate = delegate
        self.root = delegate.root

    def __getattr__(self, name: str):
        return getattr(self.delegate, name)

    def search_embedding_candidates(self, query_embedding, *, model_name: str, limit: int):
        return self.delegate.search_embedding_candidates(query_embedding, model_name=model_name, limit=limit)

    def search_metadata_candidates(self, query_text: str, *, limit: int):
        return self.delegate.search_metadata_candidates(query_text, limit=limit)


class StorageAdapterParityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.temp_dir.name) / "state"
        self.fixture_dir = Path(self.temp_dir.name) / "fixtures"
        self.local_store = LocalStateStore(self.state_dir)
        self.reasoner = GemmaReasoner()
        ingest = IngestService(self.local_store, reasoner=self.reasoner)
        self.fixtures = materialize_fixtures(self.fixture_dir)
        for payload in self.fixtures:
            ingest.ingest_beat(payload)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_candidate_adapter_matches_scan_only_results_for_text_search(self) -> None:
        scan_service = RetrievalService(ScanOnlyStore(self.local_store), reasoner=self.reasoner)
        candidate_service = RetrievalService(CandidateStore(self.local_store), reasoner=self.reasoner)

        scan_response = scan_service.search_text({"query": "sza x summer walker type beat", "top_n": 5})
        candidate_response = candidate_service.search_text({"query": "sza x summer walker type beat", "top_n": 5})

        scan_titles = [row["beat"]["raw_title"] for row in scan_response["results"]]
        candidate_titles = [row["beat"]["raw_title"] for row in candidate_response["results"]]

        self.assertEqual(scan_titles[:3], candidate_titles[:3])
        self.assertEqual(scan_titles[0], "SZA x Summer Walker Type Beat - Afterglow")

    def test_candidate_adapter_matches_scan_only_results_for_hybrid_search(self) -> None:
        scan_service = RetrievalService(ScanOnlyStore(self.local_store), reasoner=self.reasoner)
        candidate_service = RetrievalService(CandidateStore(self.local_store), reasoner=self.reasoner)
        payload = {
            "query": "sza x summer walker type beat",
            "audio_path": self.fixtures[0]["audio_path"],
            "top_n": 5,
        }

        scan_response = scan_service.search_hybrid(payload)
        candidate_response = candidate_service.search_hybrid(payload)

        self.assertEqual(scan_response["results"][0]["beat"]["raw_title"], candidate_response["results"][0]["beat"]["raw_title"])
        self.assertEqual(candidate_response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])


if __name__ == "__main__":
    unittest.main()

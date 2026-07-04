from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.ingest.service import IngestService
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from backend.tests.fixture_builder import materialize_fixtures, write_clip
from models.metadata.gemma_adapter import GemmaReasoner
from models.metadata.query_aliases import expand_query_synonyms, normalize_query_text

# Deterministic labeled query set over the fixture catalog. relevant lists the
# titles that count as correct results for precision/recall.
TEXT_QUERY_CASES = [
    {
        "query": "sza x summer walker type beat",
        "relevant": {
            "SZA x Summer Walker Type Beat - Late Nights",
            "SZA x Summer Walker Type Beat - Afterglow",
            "SZA Type Beat - Silk Room",
            "Summer Walker Type Beat - City Lights",
        },
    },
    {
        "query": "new york drill type beat",
        "relevant": {"New York Drill Type Beat - Midnight Rush"},
    },
    {
        "query": "milwaukee x detroit type beat",
        "relevant": {
            "Milwaukee x Detroit Type Beat - Cold Motion",
            "Detroit Drill Type Beat - Tunnel Vision",
        },
    },
    {
        "query": "detroit drill type beat",
        "relevant": {
            "Detroit Drill Type Beat - Tunnel Vision",
            "Milwaukee x Detroit Type Beat - Cold Motion",
        },
    },
]


class SearchQualityMetricsTests(unittest.TestCase):
    temp_dir: tempfile.TemporaryDirectory
    retrieval: RetrievalService
    fixtures: list[dict]

    @classmethod
    def setUpClass(cls) -> None:
        cls.temp_dir = tempfile.TemporaryDirectory()
        root = Path(cls.temp_dir.name)
        store = LocalStateStore(root / "state")
        reasoner = GemmaReasoner()
        ingest = IngestService(store, reasoner=reasoner)
        cls.fixtures = materialize_fixtures(root / "fixtures")
        for payload in cls.fixtures:
            ingest.ingest_beat(payload)
        cls.retrieval = RetrievalService(store, reasoner=reasoner)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp_dir.cleanup()

    def test_text_precision_at_1_and_3(self) -> None:
        p1_hits = 0
        p3_scores = []
        for case in TEXT_QUERY_CASES:
            response = self.retrieval.search_text({"query": case["query"], "top_n": 5})
            titles = [row["beat"]["raw_title"] for row in response["results"]]
            self.assertTrue(titles, f"no results for {case['query']!r}")
            if titles[0] in case["relevant"]:
                p1_hits += 1
            top3 = titles[:3]
            relevant_in_top3 = sum(1 for title in top3 if title in case["relevant"])
            p3_scores.append(relevant_in_top3 / min(3, max(len(case["relevant"]), 1)))

        precision_at_1 = p1_hits / len(TEXT_QUERY_CASES)
        mean_p3 = sum(p3_scores) / len(p3_scores)
        self.assertEqual(precision_at_1, 1.0, f"P@1={precision_at_1}")
        self.assertGreaterEqual(mean_p3, 0.65, f"mean P@3={mean_p3:.2f}")

    def test_text_recall_at_5(self) -> None:
        recalls = []
        for case in TEXT_QUERY_CASES:
            response = self.retrieval.search_text({"query": case["query"], "top_n": 5})
            titles = set(row["beat"]["raw_title"] for row in response["results"])
            recalls.append(len(titles & case["relevant"]) / len(case["relevant"]))
        mean_recall = sum(recalls) / len(recalls)
        self.assertGreaterEqual(mean_recall, 0.75, f"mean recall@5={mean_recall:.2f}")

    def test_exact_audio_precision_at_1(self) -> None:
        response = self.retrieval.search_audio({"audio_path": self.fixtures[0]["audio_path"], "top_n": 3})
        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])

    def test_clip_audio_precision_at_1(self) -> None:
        clip_path = Path(self.temp_dir.name) / "clip.wav"
        write_clip(self.fixtures[0]["audio_path"], clip_path, start_seconds=1.0, duration_seconds=3.5)
        response = self.retrieval.search_audio({"audio_path": str(clip_path), "top_n": 3})
        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])

    def test_strong_audio_match_not_overpowered_by_metadata(self) -> None:
        # Query text describes a different family than the audio; the exact
        # audio match must still rank first.
        response = self.retrieval.search_hybrid(
            {
                "query": "new york drill type beat",
                "audio_path": self.fixtures[0]["audio_path"],
                "top_n": 5,
            }
        )
        self.assertEqual(response["results"][0]["beat"]["raw_title"], self.fixtures[0]["title"])
        breakdown = response["results"][0]["score_breakdown"]
        self.assertGreaterEqual(breakdown.get("signature_score", 0.0), 0.72)

    def test_no_match_quality_for_gibberish(self) -> None:
        response = self.retrieval.search_text({"query": "zzz qqq xyzzy flurble", "top_n": 3})
        self.assertEqual(response["confidence"], "no_confident_exact_match")
        for row in response["results"]:
            self.assertNotEqual(row["confidence_label"], "likely_exact_match")

    def test_misspelled_query_matches_corrected_query(self) -> None:
        corrected = self.retrieval.search_text({"query": "detroit drill type beat", "top_n": 3})
        misspelled = self.retrieval.search_text({"query": "detriot drill typebeat", "top_n": 3})
        self.assertEqual(
            corrected["results"][0]["beat"]["raw_title"],
            misspelled["results"][0]["beat"]["raw_title"],
        )

    def test_result_explanations_are_preserved(self) -> None:
        response = self.retrieval.search_text({"query": "sza type beat", "top_n": 3})
        for row in response["results"]:
            self.assertTrue(row["explanation"])
            self.assertIn("score_breakdown", row)


class QueryAliasUnitTests(unittest.TestCase):
    def test_word_corrections(self) -> None:
        self.assertEqual(normalize_query_text("detriot typebeat"), "detroit type beat")
        self.assertEqual(normalize_query_text("R&B slow jam"), "rnb slow jam")

    def test_unknown_words_untouched(self) -> None:
        self.assertEqual(normalize_query_text("prod salishan slide"), "prod salishan slide")

    def test_synonym_expansion_adds_variants(self) -> None:
        variants = expand_query_synonyms("philly type beat")
        self.assertIn("philadelphia type beat", variants)
        self.assertEqual(expand_query_synonyms("detroit type beat"), [])


if __name__ == "__main__":
    unittest.main()

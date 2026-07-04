from __future__ import annotations

import json
import unittest
from pathlib import Path

from backend.discovery.regional_style_classifier import (
    INFERRED_CONFIDENCE_CEILING,
    classify_regional_style,
)

CASES_PATH = Path(__file__).resolve().parent / "fixtures" / "regional_style_cases.json"


class ExplicitMatchTests(unittest.TestCase):
    def test_explicit_city_phrase_is_labeled_with_evidence(self) -> None:
        result = classify_regional_style(["philly type beat"])
        labels = {match.label for match in result.explicit_matches}
        self.assertIn("philly", labels)
        philly = next(match for match in result.explicit_matches if match.label == "philly")
        self.assertEqual(philly.source, "explicit_metadata")
        self.assertTrue(philly.evidence)
        self.assertGreater(philly.confidence, 0.5)

    def test_multiple_city_combo_yields_multiple_labels(self) -> None:
        result = classify_regional_style(["arkansas x detroit type beat"])
        labels = {match.label for match in result.explicit_matches}
        self.assertIn("arkansas", labels)
        self.assertIn("detroit", labels)

    def test_short_alias_does_not_fire_inside_other_words(self) -> None:
        # "la" must not match inside "atlanta"
        result = classify_regional_style(["atlanta type beat"])
        labels = {match.label for match in result.explicit_matches}
        self.assertIn("atlanta", labels)
        self.assertNotIn("los_angeles", labels)

    def test_hashtags_count_as_explicit_metadata(self) -> None:
        result = classify_regional_style([], hashtags=["#detroit", "#typebeat"])
        labels = {match.label for match in result.explicit_matches}
        self.assertIn("detroit", labels)


class InferredMatchTests(unittest.TestCase):
    def test_style_implies_associated_regions_as_inferred_only(self) -> None:
        result = classify_regional_style(["hard drill type beat"])
        explicit_labels = {match.label for match in result.explicit_matches}
        inferred_labels = {match.label for match in result.inferred_matches}
        self.assertIn("drill", explicit_labels)
        self.assertTrue(inferred_labels & {"new_york", "chicago", "uk"})
        for match in result.inferred_matches:
            self.assertEqual(match.source, "inferred_style_similarity")
            self.assertLessEqual(match.confidence, INFERRED_CONFIDENCE_CEILING)

    def test_tempo_inference_is_capped_and_explained(self) -> None:
        result = classify_regional_style([], tempo_bpm=144.0)
        self.assertFalse(result.explicit_matches)
        tempo_styles = {match.label for match in result.inferred_matches}
        self.assertIn("drill", tempo_styles)
        drill = next(match for match in result.inferred_matches if match.label == "drill")
        self.assertLessEqual(drill.confidence, INFERRED_CONFIDENCE_CEILING)
        self.assertTrue(any("BPM" in item for item in drill.evidence))

    def test_producer_relationship_tags_are_inferred(self) -> None:
        result = classify_regional_style([], producer_region_tags=["philly"])
        inferred_labels = {match.label for match in result.inferred_matches}
        self.assertIn("philly", inferred_labels)
        philly = next(match for match in result.inferred_matches if match.label == "philly")
        self.assertLessEqual(philly.confidence, INFERRED_CONFIDENCE_CEILING)


class SummaryPhrasingTests(unittest.TestCase):
    def test_summary_uses_similarity_phrasing_not_origin_claims(self) -> None:
        result = classify_regional_style(["philly x dallas type beat"])
        self.assertTrue(result.summary.startswith("Most similar to styles associated with"))
        self.assertNotIn("originated", result.summary.lower())
        self.assertNotIn("comes from", result.summary.lower())

    def test_no_signal_yields_no_confident_association(self) -> None:
        result = classify_regional_style(["untitled instrumental 001"])
        self.assertEqual(result.summary, "No confident regional or style association")


class EvaluationFixtureTests(unittest.TestCase):
    def test_labeled_cases_meet_accuracy_threshold(self) -> None:
        payload = json.loads(CASES_PATH.read_text(encoding="utf-8"))
        cases = payload["cases"]
        self.assertGreaterEqual(len(cases), 10)

        region_hits = 0
        region_total = 0
        style_hits = 0
        style_total = 0
        for case in cases:
            result = classify_regional_style(case["texts"])
            explicit_labels = {match.label for match in result.explicit_matches}
            for expected in case["expected_regions"]:
                region_total += 1
                if expected in explicit_labels:
                    region_hits += 1
            for expected in case["expected_styles"]:
                style_total += 1
                if expected in explicit_labels:
                    style_hits += 1

        region_recall = region_hits / max(region_total, 1)
        style_recall = style_hits / max(style_total, 1)
        self.assertGreaterEqual(region_recall, 0.9, f"region recall {region_recall:.2f}")
        self.assertGreaterEqual(style_recall, 0.9, f"style recall {style_recall:.2f}")


if __name__ == "__main__":
    unittest.main()

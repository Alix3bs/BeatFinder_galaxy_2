from __future__ import annotations

import unittest

from models.metadata.normalize import normalize_hashtag
from models.metadata.parser import parse_metadata


class MetadataParserTests(unittest.TestCase):
    def test_parser_extracts_artists_producers_and_hashtag_variants(self) -> None:
        parsed = parse_metadata("SZA x Summer Walker Type Beat - Late Nights | Era Jay x Bani #phillytypebeat")

        self.assertEqual(parsed["artist_refs"], ["sza", "summer walker"])
        self.assertEqual(parsed["artist_combo_refs"], ["sza x summer walker"])
        self.assertEqual(parsed["producer_combo_refs"], ["era jay x bani"])
        self.assertIn("sza x summer walker type beat", parsed["type_beat_phrases"])
        self.assertIn("summer walker type beat", parsed["type_beat_phrases"])
        self.assertIn("#phillytypebeat", parsed["hashtags"])
        self.assertIn("philly type beat", parsed["normalized_search_phrases"])
        self.assertIn("phillytypebeat", parsed["normalized_search_phrases"])
        self.assertEqual(parsed["canonical_title"], "late nights")

    def test_compound_hashtag_normalization(self) -> None:
        variants = normalize_hashtag("#newyorkdrilltypebeat")
        self.assertIn("#newyorkdrilltypebeat", variants)
        self.assertIn("newyorkdrilltypebeat", variants)
        self.assertIn("new york drill type beat", variants)

    def test_parser_preserves_explicit_producer_aliases(self) -> None:
        parsed = parse_metadata(
            "SZA Type Beat - Silk Room",
            producer_name="Era Jay",
            producer_aliases=["EraJay", "ERA JAY"],
        )

        self.assertEqual(parsed["producer_name"], "era jay")
        self.assertEqual(parsed["producer_aliases"], ["erajay", "era jay"])


if __name__ == "__main__":
    unittest.main()

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

    def test_philly_hashtag_normalization(self) -> None:
        variants = normalize_hashtag("#phillytypebeat")
        self.assertIn("#phillytypebeat", variants)
        self.assertIn("phillytypebeat", variants)
        self.assertIn("philly type beat", variants)

    def test_artist_combo_with_standalone_x_still_parses(self) -> None:
        parsed = parse_metadata("sza x summer walker type beat")

        self.assertEqual(parsed["artist_refs"], ["sza", "summer walker"])
        self.assertEqual(parsed["artist_combo_refs"], ["sza x summer walker"])
        self.assertIn("sza x summer walker type beat", parsed["type_beat_phrases"])
        self.assertIn("sza type beat", parsed["type_beat_phrases"])
        self.assertIn("summer walker type beat", parsed["type_beat_phrases"])

    def test_x_inside_artist_name_is_not_split(self) -> None:
        parsed = parse_metadata("maxo kream type beat")

        self.assertEqual(parsed["artist_refs"], ["maxo kream"])
        self.assertIn("maxo kream type beat", parsed["type_beat_phrases"])
        self.assertNotIn("ma", parsed["artist_refs"])
        self.assertNotIn("o kream", parsed["artist_refs"])

    def test_leading_x_inside_artist_name_is_not_split(self) -> None:
        parsed = parse_metadata("xavier wulf type beat")

        self.assertEqual(parsed["artist_refs"], ["xavier wulf"])
        self.assertIn("xavier wulf type beat", parsed["type_beat_phrases"])
        self.assertNotIn("avier wulf", parsed["artist_refs"])

    def test_x_inside_plain_word_is_not_split(self) -> None:
        for phrase in ("complex type beat", "flex type beat"):
            with self.subTest(phrase=phrase):
                parsed = parse_metadata(phrase)
                subject = phrase.replace(" type beat", "")
                self.assertEqual(parsed["artist_refs"], [subject])
                self.assertIn(phrase, parsed["type_beat_phrases"])
                self.assertNotIn(subject.replace("x", "").strip(), parsed["artist_refs"])

    def test_producer_combo_with_standalone_x_still_parses(self) -> None:
        parsed = parse_metadata("Night Drive | tse vic x shadstackz")

        self.assertEqual(parsed["producer_name"], "tse vic")
        self.assertEqual(parsed["producer_combo_refs"], ["tse vic x shadstackz"])
        self.assertIn("tse vic", parsed["normalized_search_phrases"])
        self.assertIn("shadstackz", parsed["normalized_search_phrases"])

    def test_region_style_combo_with_standalone_x_still_parses(self) -> None:
        parsed = parse_metadata("milwaukee x detroit type beat")

        self.assertEqual(parsed["artist_refs"], [])
        self.assertIn("milwaukee", parsed["region_tags"])
        self.assertIn("detroit", parsed["region_tags"])
        self.assertIn("milwaukee x detroit type beat", parsed["type_beat_phrases"])

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

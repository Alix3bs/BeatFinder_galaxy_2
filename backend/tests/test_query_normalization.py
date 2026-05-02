from __future__ import annotations

import unittest

from models.metadata.parser import expand_query_phrases


class QueryNormalizationTests(unittest.TestCase):
    def test_region_combo_is_not_forced_into_artist_refs(self) -> None:
        parsed = expand_query_phrases("milwaukee x detroit type beat")
        self.assertEqual(parsed["artist_refs"], [])
        self.assertIn("milwaukee", parsed["region_tags"])
        self.assertIn("detroit", parsed["region_tags"])
        self.assertIn("milwaukee x detroit type beat", parsed["type_beat_phrases"])

    def test_producer_combo_is_preserved(self) -> None:
        parsed = expand_query_phrases("shadstackz x tse vic")
        self.assertIn("shadstackz", parsed["normalized_query_phrases"])
        self.assertIn("shadstackz x tse vic", parsed["normalized_query_phrases"])


if __name__ == "__main__":
    unittest.main()

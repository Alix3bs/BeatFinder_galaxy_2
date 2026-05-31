from __future__ import annotations

import unittest

from backend.discovery.hashtag_expander import expand_discovery_seeds


class HashtagExpanderTests(unittest.TestCase):
    def test_compact_typebeat_hashtags_expand_to_producer_searches(self) -> None:
        seeds = expand_discovery_seeds(
            hashtags=["#phillytypebeat", "#newyorkdrilltypebeat"],
            source="test",
        )
        values = {seed.seed_value for seed in seeds}

        self.assertIn("philly type beat producers", values)
        self.assertIn("new york drill type beat producers", values)

    def test_combo_type_beat_phrases_generate_search_without_x_separator(self) -> None:
        seeds = expand_discovery_seeds(
            phrases=[
                "philly x dallas type beat",
                "burgermarty x iluvbani type beat",
                "shadstackz x tse vic",
            ],
            source="test",
        )
        values = {seed.seed_value for seed in seeds}

        self.assertIn("philly dallas type beat producers", values)
        self.assertIn("burgermarty iluvbani type beat producers", values)
        self.assertIn("shadstackz tse vic producers", values)


if __name__ == "__main__":
    unittest.main()

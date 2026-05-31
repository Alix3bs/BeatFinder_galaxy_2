from __future__ import annotations

import unittest

from backend.discovery.city_style_classifier import classify_city_style


class CityStyleClassifierTests(unittest.TestCase):
    def test_city_and_scene_tags_are_classified_with_evidence(self) -> None:
        result = classify_city_style(["#newyorkdrilltypebeat", "NY drill beat", "Detroit flow"])

        self.assertIn("new_york", result.city_tags)
        self.assertIn("detroit", result.city_tags)
        self.assertIn("new_york_drill", result.region_tags)
        self.assertIn("drill", result.style_tags)
        self.assertGreater(result.confidence, 0.5)
        self.assertTrue(result.evidence)

    def test_philly_and_milwaukee_region_combo(self) -> None:
        result = classify_city_style(["Milwaukee x Philadelphia Type Beat"])

        self.assertIn("milwaukee", result.city_tags)
        self.assertIn("philly", result.city_tags)
        self.assertIn("type_beat", result.style_tags)


if __name__ == "__main__":
    unittest.main()

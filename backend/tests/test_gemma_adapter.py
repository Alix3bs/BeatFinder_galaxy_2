from __future__ import annotations

import unittest

from models.metadata.gemma_adapter import GemmaReasoner


class GemmaAdapterTests(unittest.TestCase):
    def test_local_fallback_normalizes_metadata(self) -> None:
        reasoner = GemmaReasoner(provider="local-fallback", endpoint=None)
        parsed = reasoner.normalize_metadata("SZA x Summer Walker Type Beat - Late Nights | Era Jay x Bani #phillytypebeat")

        self.assertIn("sza", parsed["artist_refs"])
        self.assertIn("era jay x bani", parsed["producer_combo_refs"])
        self.assertIn("philly type beat", parsed["normalized_search_phrases"])

    def test_remote_provider_falls_back_when_endpoint_is_missing(self) -> None:
        reasoner = GemmaReasoner(provider="remote-http", endpoint="http://127.0.0.1:9", allow_fallback=True)
        parsed = reasoner.expand_query("milwaukee x detroit type beat")

        self.assertIn("milwaukee x detroit type beat", parsed["type_beat_phrases"])
        self.assertIn("milwaukee", parsed["region_tags"])
        self.assertIn("detroit", parsed["region_tags"])


if __name__ == "__main__":
    unittest.main()

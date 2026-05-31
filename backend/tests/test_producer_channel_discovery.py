from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.discovery.producer_channels import ProducerDiscoveryStore, parse_youtube_channel_ref


class ProducerChannelDiscoveryTests(unittest.TestCase):
    def test_profile_ingest_accepts_channel_urls_and_aliases(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")

            first = store.upsert_channel(
                "https://www.youtube.com/channel/UCSTACKZ",
                producer_name="Shadstackz",
                aliases=["stackz", "shadstackz tag"],
                discovered_from="user_seed",
            )
            second = store.upsert_channel(
                "UCSTACKZ",
                producer_name="Shadstackz",
                aliases=["stackz"],
                city_tags=["new_york"],
            )

            self.assertEqual(first.id, second.id)
            self.assertEqual(second.channel_id, "UCSTACKZ")
            self.assertIn("stackz", second.aliases)
            self.assertIn("shadstackz tag", second.aliases)
            self.assertIn("new_york", second.city_tags)
            self.assertEqual(len(store.list_channels()), 1)

    def test_youtube_handle_is_preserved_as_channel_identifier(self) -> None:
        parsed = parse_youtube_channel_ref("https://www.youtube.com/@erajay")

        self.assertEqual(parsed["platform"], "youtube")
        self.assertEqual(parsed["channel_id"], "erajay")
        self.assertEqual(parsed["channel_url"], "https://www.youtube.com/@erajay")


if __name__ == "__main__":
    unittest.main()

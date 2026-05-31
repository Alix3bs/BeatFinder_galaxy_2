from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.producer_seed_loader import load_producer_seed_file, normalize_producer_profile_url
from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_discovery import YouTubeBeatBackfill


class ProducerSeedLoaderTests(unittest.TestCase):
    def test_duplicate_urls_are_deduped_and_tracking_params_removed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            seed_file = Path(tmp) / "producer_youtube_profiles.txt"
            seed_file.write_text(
                "\n".join(
                    [
                        "https://youtube.com/@Prod.Salishan?si=abc123",
                        "https://www.youtube.com/@prod.salishan",
                        "https://m.youtube.com/@beatsbyslimy?feature=shared",
                    ]
                ),
                encoding="utf-8",
            )
            store = ProducerDiscoveryStore(Path(tmp) / "state")

            result = load_producer_seed_file(seed_file, store=store)

            self.assertEqual(result.raw_count, 3)
            self.assertEqual(result.unique_count, 2)
            self.assertEqual(len(store.list_channels()), 2)
            channel_urls = {channel.channel_url for channel in result.channels}
            self.assertIn("https://youtube.com/@prod.salishan", channel_urls)
            self.assertIn("https://youtube.com/@beatsbyslimy", channel_urls)

    def test_handle_is_extracted_correctly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            seed_file = Path(tmp) / "seeds.txt"
            seed_file.write_text("https://youtube.com/@Prod.ByYoungTM?si=tracking", encoding="utf-8")

            result = load_producer_seed_file(seed_file, store=store)

            self.assertEqual(result.channels[0].channel_id, "prod.byyoungtm")
            self.assertEqual(result.channels[0].channel_url, "https://youtube.com/@prod.byyoungtm")

    def test_committed_seed_list_loads_successfully(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            seed_file = Path(__file__).resolve().parents[2] / "data" / "seeds" / "producer_youtube_profiles.txt"

            result = load_producer_seed_file(seed_file, store=store)

            self.assertEqual(result.raw_count, 103)
            self.assertEqual(result.unique_count, 103)
            self.assertEqual(len(store.list_channels()), 103)
            self.assertIn("prod.salishan", {channel.channel_id for channel in result.channels})
            self.assertIn("beatsbyconcrete", {channel.channel_id for channel in result.channels})

    def test_seed_loader_does_not_call_live_youtube_backfill(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            seed_file = Path(tmp) / "seeds.txt"
            seed_file.write_text("https://youtube.com/@prod.salishan", encoding="utf-8")
            store = ProducerDiscoveryStore(Path(tmp) / "state")

            with patch.object(YouTubeBeatBackfill, "backfill_channel", side_effect=AssertionError("live call")):
                result = load_producer_seed_file(seed_file, store=store)

            self.assertEqual(result.unique_count, 1)

    def test_normalize_producer_profile_url_strips_query_and_fragment(self) -> None:
        normalized = normalize_producer_profile_url("https://www.youtube.com/@Prod.Salishan?si=abc#fragment")

        self.assertEqual(normalized, "https://youtube.com/@prod.salishan")


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.producer_tag_matcher import match_producer_tag
from scripts.discovery.load_producer_seeds import build_channel_aliases, load_producer_seeds


class LocalProducerSeedScriptTests(unittest.TestCase):
    def test_seed_script_loads_channels_and_dedupes_duplicate_urls(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            seed_file = Path(tmp) / "producer_youtube_profiles.txt"
            seed_file.write_text(
                "\n".join(
                    [
                        "https://youtube.com/@Prod.Salishan?si=tracking",
                        "https://www.youtube.com/@prod.salishan",
                        "https://m.youtube.com/@beatsbyslimy?feature=shared",
                    ]
                ),
                encoding="utf-8",
            )
            state_dir = Path(tmp) / "state"

            summary = load_producer_seeds(seed_file=seed_file, state_dir=state_dir)
            store = ProducerDiscoveryStore(state_dir)

            self.assertEqual(summary["total_urls"], 3)
            self.assertEqual(summary["unique_channels"], 2)
            self.assertEqual(summary["channels_created"], 2)
            self.assertEqual(summary["channels_updated"], 0)
            self.assertEqual(len(store.list_channels()), 2)

    def test_seed_aliases_match_detected_producer_tags(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            seed_file = Path(tmp) / "producer_youtube_profiles.txt"
            seed_file.write_text(
                "\n".join(
                    [
                        "https://youtube.com/@prod.salishan",
                        "https://youtube.com/@beatsbyslimy",
                        "https://youtube.com/@babyonthetrack",
                    ]
                ),
                encoding="utf-8",
            )
            state_dir = Path(tmp) / "state"

            load_producer_seeds(seed_file=seed_file, state_dir=state_dir)
            channels = ProducerDiscoveryStore(state_dir).list_channels()

            salishan = next(channel for channel in channels if channel.channel_id == "prod.salishan")
            self.assertIn("prod.salishan", salishan.aliases)
            self.assertIn("prod salishan", salishan.aliases)
            self.assertIn("salishan", salishan.aliases)
            self.assertEqual(match_producer_tag("prod by salishan", channels).channel.channel_id, "prod.salishan")

            slimy = next(channel for channel in channels if channel.channel_id == "beatsbyslimy")
            self.assertIn("beats by slimy", slimy.aliases)
            self.assertIn("slimy", slimy.aliases)
            self.assertEqual(match_producer_tag("beats by slimy", channels).channel.channel_id, "beatsbyslimy")

            baby = next(channel for channel in channels if channel.channel_id == "babyonthetrack")
            self.assertIn("baby on the track", baby.aliases)

    def test_build_channel_aliases_creates_handle_variants(self) -> None:
        self.assertIn("prod salishan", build_channel_aliases("prod.salishan"))
        self.assertIn("salishan", build_channel_aliases("prod.salishan"))
        self.assertIn("beats by slimy", build_channel_aliases("beatsbyslimy"))
        self.assertIn("slimy", build_channel_aliases("beatsbyslimy"))
        self.assertIn("baby on the track", build_channel_aliases("babyonthetrack"))

    def test_seed_script_does_not_call_live_youtube_or_network(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            seed_file = Path(tmp) / "producer_youtube_profiles.txt"
            seed_file.write_text("https://youtube.com/@prod.salishan", encoding="utf-8")

            with patch.object(socket, "create_connection", side_effect=AssertionError("live network call")):
                summary = load_producer_seeds(seed_file=seed_file, state_dir=Path(tmp) / "state")

            self.assertEqual(summary["unique_channels"], 1)


if __name__ == "__main__":
    unittest.main()

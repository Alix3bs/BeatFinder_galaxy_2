from __future__ import annotations

import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.mock_youtube_client import MockYouTubeChannelClient
from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_discovery import YouTubeBeatBackfill

FIXTURE_PATH = Path(__file__).resolve().parent / "fixtures" / "mock_youtube_channel_videos.json"


class MockYouTubeBackfillTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.store = ProducerDiscoveryStore(Path(self.tmp.name) / "state")
        self.channel = self.store.upsert_channel(
            "https://youtube.com/@mockproducer",
            producer_name="Mock Producer",
            aliases=["mock tag"],
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _backfill(self, *, page_size: int = 3) -> tuple[YouTubeBeatBackfill, MockYouTubeChannelClient]:
        client = MockYouTubeChannelClient.from_fixture(FIXTURE_PATH, page_size=page_size)
        return YouTubeBeatBackfill(store=self.store, client=client), client

    def test_mock_channel_backfills_videos_newest_to_oldest(self) -> None:
        backfill, client = self._backfill(page_size=3)

        result = backfill.backfill_channel(self.channel.id)

        self.assertTrue(result.completed)
        self.assertEqual(result.pages_scanned, 3)
        self.assertEqual(result.videos_created_or_refreshed, 7)
        self.assertEqual(client.calls, [("mockproducer", None), ("mockproducer", "offset:3"), ("mockproducer", "offset:6")])
        videos = self.store.list_videos(self.channel.id)
        self.assertEqual([video.video_id for video in videos], [f"mock-00{index}" for index in range(1, 8)])
        self.assertEqual(videos[0].title, "Burgermarty x I Luv Bani Type Beat - Slide")
        self.assertEqual(videos[-1].title, "Milwaukee x Detroit Type Beat - Fast Money")

    def test_duplicate_video_ids_do_not_create_duplicate_records(self) -> None:
        backfill, _ = self._backfill(page_size=4)

        first = backfill.backfill_channel(self.channel.id)
        second = backfill.backfill_channel(self.channel.id)

        self.assertEqual(first.videos_created_or_refreshed, 7)
        self.assertEqual(second.videos_created_or_refreshed, 0)
        self.assertEqual(second.videos_skipped, 7)
        self.assertEqual(len(self.store.list_videos(self.channel.id)), 7)

    def test_checkpoint_resumes_correctly(self) -> None:
        backfill, client = self._backfill(page_size=3)

        first = backfill.backfill_channel(self.channel.id, max_pages=1)
        second = backfill.backfill_channel(self.channel.id)

        self.assertFalse(first.completed)
        self.assertEqual(first.next_page_token, "offset:3")
        self.assertTrue(second.completed)
        self.assertEqual(len(self.store.list_videos(self.channel.id)), 7)
        self.assertEqual(client.calls, [("mockproducer", None), ("mockproducer", "offset:3"), ("mockproducer", "offset:6")])

    def test_hashtags_and_artist_combos_produce_discovery_seeds(self) -> None:
        backfill, _ = self._backfill(page_size=10)

        backfill.backfill_channel(self.channel.id)

        seed_values = {seed.seed_value for seed in self.store.list_seeds()}
        self.assertIn("philly type beat producers", seed_values)
        self.assertIn("new york drill type beat producers", seed_values)
        self.assertIn("burgermarty i luv bani type beat producers", seed_values)
        self.assertIn("sza summer walker type beat producers", seed_values)
        self.assertIn("shadstackz tse vic type beat producers", seed_values)

    def test_city_combo_titles_produce_city_region_and_style_tags(self) -> None:
        backfill, _ = self._backfill(page_size=10)

        backfill.backfill_channel(self.channel.id)

        videos = {video.video_id: video for video in self.store.list_videos(self.channel.id)}
        philly_dallas = videos["mock-002"]
        arkansas_detroit = videos["mock-003"]
        milwaukee_detroit = videos["mock-007"]
        new_york_drill = videos["mock-006"]

        self.assertIn("philly", philly_dallas.city_tags)
        self.assertIn("dallas", philly_dallas.city_tags)
        self.assertIn("type_beat", philly_dallas.style_tags)
        self.assertIn("arkansas", arkansas_detroit.region_tags)
        self.assertIn("detroit", arkansas_detroit.region_tags)
        self.assertIn("milwaukee", milwaukee_detroit.city_tags)
        self.assertIn("detroit", milwaukee_detroit.city_tags)
        self.assertIn("new_york_drill", new_york_drill.region_tags)
        self.assertIn("drill", new_york_drill.style_tags)

    def test_no_live_youtube_call_happens_in_tests(self) -> None:
        backfill, _ = self._backfill(page_size=10)

        with patch.object(socket, "create_connection", side_effect=AssertionError("live network call")):
            result = backfill.backfill_channel(self.channel.id)

        self.assertEqual(result.videos_created_or_refreshed, 7)


if __name__ == "__main__":
    unittest.main()

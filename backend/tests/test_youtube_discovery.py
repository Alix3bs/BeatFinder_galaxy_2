from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_discovery import YouTubeBeatBackfill, YouTubeVideoItem, YouTubeVideoPage


class FakeYouTubeClient:
    def __init__(self, pages: dict[str | None, YouTubeVideoPage]) -> None:
        self.pages = pages
        self.calls: list[str | None] = []

    def list_channel_videos(self, channel_id: str, *, page_token: str | None = None) -> YouTubeVideoPage:
        self.calls.append(page_token)
        return self.pages[page_token]


class YouTubeDiscoveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.store = ProducerDiscoveryStore(Path(self.tmp.name) / "state")
        self.channel = self.store.upsert_channel(
            "https://www.youtube.com/channel/UCERAJAY",
            producer_name="Era Jay",
            aliases=["era jay tag"],
        )
        self.pages = {
            None: YouTubeVideoPage(
                videos=[
                    YouTubeVideoItem(
                        video_id="vid-late",
                        title="SZA x Summer Walker Type Beat - Late Nights",
                        description="Buy: https://beatstars.com/erajay/late #phillytypebeat",
                        upload_date="2026-05-01",
                    ),
                    YouTubeVideoItem(
                        video_id="vid-burger",
                        title="Burgermarty x I Luv Bani Type Beat - Bounce",
                        description="#newyorkdrilltypebeat",
                        upload_date="2026-04-28",
                    ),
                ],
                next_page_token="page-2",
            ),
            "page-2": YouTubeVideoPage(
                videos=[
                    YouTubeVideoItem(
                        video_id="vid-region",
                        title="Arkansas x Detroit Type Beat - Backroad Motion",
                        description="More beats on https://traktrain.com/erajay",
                        upload_date="2026-04-01",
                    )
                ],
                next_page_token=None,
            ),
        }

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_backfill_ingests_three_videos_and_extracts_metadata(self) -> None:
        backfill = YouTubeBeatBackfill(store=self.store, client=FakeYouTubeClient(self.pages))

        result = backfill.backfill_channel(self.channel.id)

        self.assertTrue(result.completed)
        self.assertEqual(result.pages_scanned, 2)
        self.assertEqual(result.videos_created_or_refreshed, 3)
        videos = self.store.list_videos(self.channel.id)
        self.assertEqual(len(videos), 3)
        late_nights = next(video for video in videos if video.video_id == "vid-late")
        self.assertIn("#phillytypebeat", late_nights.hashtags)
        self.assertIn("sza x summer walker", late_nights.artist_combo_refs)
        self.assertIn("philly", late_nights.city_tags)
        self.assertEqual(late_nights.beat_store_links, ["https://beatstars.com/erajay/late"])

        region_video = next(video for video in videos if video.video_id == "vid-region")
        self.assertIn("arkansas", region_video.city_tags)
        self.assertIn("detroit", region_video.city_tags)
        self.assertIn("arkansas x detroit type beat", region_video.type_beat_phrases)

        seed_values = {seed.seed_value for seed in self.store.list_seeds()}
        self.assertIn("philly type beat producers", seed_values)
        self.assertIn("new york drill type beat producers", seed_values)
        self.assertIn("burgermarty i luv bani type beat producers", seed_values)

    def test_channel_scan_resumes_from_checkpoint(self) -> None:
        client = FakeYouTubeClient(self.pages)
        backfill = YouTubeBeatBackfill(store=self.store, client=client)

        first = backfill.backfill_channel(self.channel.id, max_pages=1)
        second = backfill.backfill_channel(self.channel.id)

        self.assertFalse(first.completed)
        self.assertEqual(first.next_page_token, "page-2")
        self.assertTrue(second.completed)
        self.assertEqual(client.calls, [None, "page-2"])
        self.assertEqual(len(self.store.list_videos(self.channel.id)), 3)

    def test_duplicate_videos_do_not_create_duplicate_records(self) -> None:
        client = FakeYouTubeClient(self.pages)
        backfill = YouTubeBeatBackfill(store=self.store, client=client)

        backfill.backfill_channel(self.channel.id)
        second = backfill.backfill_channel(self.channel.id)

        self.assertEqual(second.videos_created_or_refreshed, 0)
        self.assertEqual(second.videos_skipped, 3)
        self.assertEqual(len(self.store.list_videos(self.channel.id)), 3)


if __name__ == "__main__":
    unittest.main()

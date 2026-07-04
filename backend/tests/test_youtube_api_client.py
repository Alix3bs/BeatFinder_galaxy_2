from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_api_client import (
    YouTubeAPIError,
    YouTubeDataAPIClient,
    YouTubeQuotaExceededError,
)
from backend.discovery.youtube_discovery import YouTubeBeatBackfill

CHANNEL_ID = "UC0123456789abcdefghij"
UPLOADS_ID = "UU0123456789abcdefghij"


def playlist_item(video_id: str, title: str, *, privacy: str = "public") -> dict:
    return {
        "snippet": {
            "resourceId": {"videoId": video_id},
            "title": title,
            "description": f"{title} description #phillytypebeat",
            "publishedAt": "2026-06-01T00:00:00Z",
        },
        "status": {"privacyStatus": privacy},
    }


class FakeTransport:
    """Scripted transport keyed by endpoint; records requests."""

    def __init__(self) -> None:
        self.requests: list[tuple[str, dict[str, list[str]]]] = []
        self.responses: list[tuple[int, dict]] = []

    def queue(self, status: int, body: dict) -> None:
        self.responses.append((status, body))

    def __call__(self, url: str) -> tuple[int, dict]:
        split = urlsplit(url)
        endpoint = split.path.rsplit("/", 1)[-1]
        self.requests.append((endpoint, parse_qs(split.query)))
        if not self.responses:
            raise AssertionError(f"Unexpected request: {url}")
        return self.responses.pop(0)


def make_client(transport: FakeTransport, **kwargs) -> YouTubeDataAPIClient:
    sleeps: list[float] = []
    client = YouTubeDataAPIClient(
        "test-api-key",
        transport=transport,
        sleeper=sleeps.append,
        **kwargs,
    )
    client._test_sleeps = sleeps  # type: ignore[attr-defined]
    return client


class ChannelResolutionTests(unittest.TestCase):
    def test_uc_id_passes_through_without_request(self) -> None:
        transport = FakeTransport()
        client = make_client(transport)
        self.assertEqual(client.resolve_channel_id(CHANNEL_ID), CHANNEL_ID)
        self.assertEqual(transport.requests, [])

    def test_handle_resolves_via_for_handle(self) -> None:
        transport = FakeTransport()
        transport.queue(200, {"items": [{"id": CHANNEL_ID}]})
        client = make_client(transport)
        self.assertEqual(client.resolve_channel_id("@prod.salishan"), CHANNEL_ID)
        endpoint, params = transport.requests[0]
        self.assertEqual(endpoint, "channels")
        self.assertEqual(params["forHandle"], ["@prod.salishan"])

    def test_unknown_handle_raises_clear_error(self) -> None:
        transport = FakeTransport()
        transport.queue(200, {"items": []})
        transport.queue(200, {"items": []})
        client = make_client(transport)
        with self.assertRaises(YouTubeAPIError):
            client.resolve_channel_id("@nobody-here")


class PaginationTests(unittest.TestCase):
    def _queue_channel_lookup(self, transport: FakeTransport) -> None:
        transport.queue(
            200,
            {"items": [{"contentDetails": {"relatedPlaylists": {"uploads": UPLOADS_ID}}}]},
        )

    def test_lists_videos_and_page_tokens(self) -> None:
        transport = FakeTransport()
        self._queue_channel_lookup(transport)
        transport.queue(
            200,
            {
                "items": [playlist_item("vid-1", "Beat One"), playlist_item("vid-2", "Beat Two")],
                "nextPageToken": "page-2",
            },
        )
        client = make_client(transport)
        page = client.list_channel_videos(CHANNEL_ID)
        self.assertEqual([video.video_id for video in page.videos], ["vid-1", "vid-2"])
        self.assertEqual(page.next_page_token, "page-2")

        transport.queue(200, {"items": [playlist_item("vid-3", "Beat Three")]})
        second = client.list_channel_videos(CHANNEL_ID, page_token="page-2")
        self.assertEqual([video.video_id for video in second.videos], ["vid-3"])
        self.assertIsNone(second.next_page_token)

        endpoint, params = transport.requests[-1]
        self.assertEqual(endpoint, "playlistItems")
        self.assertEqual(params["pageToken"], ["page-2"])
        # uploads playlist lookup is cached across pages
        channel_lookups = [req for req in transport.requests if req[0] == "channels"]
        self.assertEqual(len(channel_lookups), 1)

    def test_visibility_status_is_captured(self) -> None:
        transport = FakeTransport()
        self._queue_channel_lookup(transport)
        transport.queue(200, {"items": [playlist_item("vid-9", "Hidden", privacy="unlisted")]})
        client = make_client(transport)
        page = client.list_channel_videos(CHANNEL_ID)
        self.assertEqual(page.videos[0].visibility_status, "unlisted")


class QuotaAndRetryTests(unittest.TestCase):
    def test_rate_limit_retries_then_succeeds(self) -> None:
        transport = FakeTransport()
        transport.queue(403, {"error": {"errors": [{"reason": "rateLimitExceeded"}], "message": "slow down"}})
        transport.queue(200, {"items": [{"id": CHANNEL_ID}]})
        client = make_client(transport)
        self.assertEqual(client.resolve_channel_id("@retry-me"), CHANNEL_ID)
        self.assertEqual(len(client._test_sleeps), 1)  # type: ignore[attr-defined]

    def test_server_errors_retry_up_to_limit(self) -> None:
        transport = FakeTransport()
        for _ in range(3):
            transport.queue(503, {"error": {"message": "unavailable"}})
        client = make_client(transport, max_retries=2)
        with self.assertRaises(YouTubeAPIError):
            client.resolve_channel_id("@flaky")
        self.assertEqual(len(client._test_sleeps), 2)  # type: ignore[attr-defined]

    def test_quota_exhaustion_raises_immediately_without_retry(self) -> None:
        transport = FakeTransport()
        transport.queue(403, {"error": {"errors": [{"reason": "quotaExceeded"}], "message": "quota"}})
        client = make_client(transport)
        with self.assertRaises(YouTubeQuotaExceededError):
            client.resolve_channel_id("@quota-out")
        self.assertEqual(len(client._test_sleeps), 0)  # type: ignore[attr-defined]


class BackfillIntegrationTests(unittest.TestCase):
    def test_backfill_engine_consumes_api_client_pages(self) -> None:
        transport = FakeTransport()
        # uploads playlist lookup once, then two pages
        transport.queue(
            200,
            {"items": [{"contentDetails": {"relatedPlaylists": {"uploads": UPLOADS_ID}}}]},
        )
        transport.queue(
            200,
            {
                "items": [playlist_item("vid-1", "SZA Type Beat - One")],
                "nextPageToken": "page-2",
            },
        )
        transport.queue(200, {"items": [playlist_item("vid-2", "SZA Type Beat - Two")]})
        client = make_client(transport)

        with tempfile.TemporaryDirectory() as temp_dir:
            store = ProducerDiscoveryStore(Path(temp_dir) / "state")
            channel = store.upsert_channel(CHANNEL_ID, producer_name="test producer")
            backfill = YouTubeBeatBackfill(store=store, client=client)
            result = backfill.backfill_channel(CHANNEL_ID, max_pages=5)

            self.assertTrue(result.completed)
            self.assertEqual(result.videos_seen, 2)
            videos = store.list_videos(channel.id)
            self.assertEqual(sorted(video.video_id for video in videos), ["vid-1", "vid-2"])

    def test_from_env_requires_key(self) -> None:
        import os
        from unittest.mock import patch

        with patch.dict(os.environ, {"BEATFINDER_YOUTUBE_API_KEY": ""}):
            self.assertIsNone(YouTubeDataAPIClient.from_env())
        with patch.dict(os.environ, {"BEATFINDER_YOUTUBE_API_KEY": "abc"}):
            client = YouTubeDataAPIClient.from_env(transport=FakeTransport())
            self.assertIsNotNone(client)


if __name__ == "__main__":
    unittest.main()

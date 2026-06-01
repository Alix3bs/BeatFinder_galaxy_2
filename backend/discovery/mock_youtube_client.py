from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from backend.discovery.youtube_discovery import YouTubeVideoItem, YouTubeVideoPage


@dataclass(slots=True)
class MockYouTubeChannelClient:
    """Fixture-backed YouTube client for local tests.

    It never calls YouTube or any network API. Videos are returned in the order
    provided by the fixture, which should be newest to oldest.
    """

    videos_by_channel: dict[str, list[YouTubeVideoItem]]
    page_size: int = 3
    calls: list[tuple[str, str | None]] | None = None

    @classmethod
    def from_fixture(cls, fixture_path: str | Path, *, page_size: int = 3) -> "MockYouTubeChannelClient":
        payload = json.loads(Path(fixture_path).read_text(encoding="utf-8"))
        videos_by_channel: dict[str, list[YouTubeVideoItem]] = {}
        for channel in payload.get("channels", []):
            channel_id = str(channel["channel_id"])
            videos_by_channel[channel_id] = [
                _video_from_payload(item) for item in channel.get("videos", [])
            ]
        return cls(videos_by_channel=videos_by_channel, page_size=page_size, calls=[])

    def list_channel_videos(self, channel_id: str, *, page_token: str | None = None) -> YouTubeVideoPage:
        if self.calls is not None:
            self.calls.append((channel_id, page_token))

        videos = self.videos_by_channel.get(channel_id, [])
        start = _offset_from_page_token(page_token)
        end = start + max(1, self.page_size)
        next_page_token = f"offset:{end}" if end < len(videos) else None
        return YouTubeVideoPage(videos=videos[start:end], next_page_token=next_page_token)


def _video_from_payload(payload: dict[str, Any]) -> YouTubeVideoItem:
    return YouTubeVideoItem(
        video_id=str(payload["video_id"]),
        title=str(payload["title"]),
        description=str(payload.get("description") or ""),
        upload_date=str(payload["upload_date"]) if payload.get("upload_date") else None,
        visibility_status=str(payload.get("visibility_status") or "public"),
    )


def _offset_from_page_token(page_token: str | None) -> int:
    if not page_token:
        return 0
    prefix, _, value = page_token.partition(":")
    if prefix != "offset":
        raise ValueError(f"Unsupported mock page token: {page_token}")
    return max(0, int(value))

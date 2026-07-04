from __future__ import annotations

import json
import os
import time
from collections.abc import Callable
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from backend.discovery.youtube_discovery import YouTubeVideoItem, YouTubeVideoPage

YOUTUBE_API_BASE_URL = "https://www.googleapis.com/youtube/v3"
DEFAULT_PAGE_SIZE = 50
DEFAULT_MAX_RETRIES = 4

# Transport signature: (url) -> (http_status, parsed_json_body)
Transport = Callable[[str], tuple[int, dict[str, Any]]]

RETRYABLE_REASONS = {
    "rateLimitExceeded",
    "userRateLimitExceeded",
    "backendError",
    "internalError",
}
QUOTA_REASONS = {"quotaExceeded", "dailyLimitExceeded"}


class YouTubeAPIError(RuntimeError):
    """A YouTube Data API request failed after applicable retries."""

    def __init__(self, message: str, *, reason: str | None = None) -> None:
        super().__init__(message)
        self.reason = reason


class YouTubeQuotaExceededError(YouTubeAPIError):
    """Daily quota is exhausted; retrying now cannot succeed."""


class YouTubeDataAPIClient:
    """Official YouTube Data API v3 client for channel metadata backfill.

    Metadata only: this client never downloads media, never bypasses access
    restrictions, and only reads public channel/video listings. It satisfies
    the YouTubeChannelClient protocol used by YouTubeBeatBackfill, so the
    existing backfill engine (pagination, checkpoints, dedupe) works
    unchanged against live data once an API key is configured.
    """

    def __init__(
        self,
        api_key: str,
        *,
        transport: Transport | None = None,
        sleeper: Callable[[float], None] = time.sleep,
        max_retries: int = DEFAULT_MAX_RETRIES,
        page_size: int = DEFAULT_PAGE_SIZE,
        base_url: str = YOUTUBE_API_BASE_URL,
    ) -> None:
        if not api_key.strip():
            raise ValueError("A YouTube Data API key is required.")
        self.api_key = api_key.strip()
        self.transport = transport or _default_transport
        self.sleeper = sleeper
        self.max_retries = max(0, max_retries)
        self.page_size = min(max(1, page_size), 50)
        self.base_url = base_url.rstrip("/")
        self._uploads_playlist_cache: dict[str, str] = {}

    @classmethod
    def from_env(cls, **kwargs: Any) -> "YouTubeDataAPIClient | None":
        api_key = os.getenv("BEATFINDER_YOUTUBE_API_KEY", "").strip()
        if not api_key:
            return None
        return cls(api_key, **kwargs)

    def resolve_channel_id(self, channel_ref: str) -> str:
        """Resolve a handle, custom name, or UC id to a canonical channel id."""

        ref = channel_ref.strip().lstrip("@")
        if ref.startswith("UC") and len(ref) >= 20:
            return ref

        payload = self._request(
            "channels",
            {"part": "id", "forHandle": f"@{ref}"},
        )
        items = payload.get("items") or []
        if items:
            return str(items[0]["id"])

        payload = self._request(
            "channels",
            {"part": "id", "forUsername": ref},
        )
        items = payload.get("items") or []
        if items:
            return str(items[0]["id"])

        raise YouTubeAPIError(f"No YouTube channel found for reference {channel_ref!r}.", reason="not_found")

    def uploads_playlist_id(self, channel_id: str) -> str:
        cached = self._uploads_playlist_cache.get(channel_id)
        if cached:
            return cached
        payload = self._request(
            "channels",
            {"part": "contentDetails", "id": channel_id},
        )
        items = payload.get("items") or []
        if not items:
            raise YouTubeAPIError(f"YouTube channel {channel_id!r} was not found.", reason="not_found")
        uploads = (
            items[0].get("contentDetails", {}).get("relatedPlaylists", {}).get("uploads")
        )
        if not uploads:
            raise YouTubeAPIError(
                f"YouTube channel {channel_id!r} has no uploads playlist.", reason="no_uploads_playlist"
            )
        self._uploads_playlist_cache[channel_id] = str(uploads)
        return str(uploads)

    def list_channel_videos(self, channel_id: str, *, page_token: str | None = None) -> YouTubeVideoPage:
        """List public uploads newest-to-oldest, one page per call."""

        resolved_id = self.resolve_channel_id(channel_id)
        playlist_id = self.uploads_playlist_id(resolved_id)
        params: dict[str, str] = {
            "part": "snippet,status",
            "playlistId": playlist_id,
            "maxResults": str(self.page_size),
        }
        if page_token:
            params["pageToken"] = page_token
        payload = self._request("playlistItems", params)

        videos: list[YouTubeVideoItem] = []
        for item in payload.get("items") or []:
            snippet = item.get("snippet") or {}
            status = item.get("status") or {}
            video_id = (snippet.get("resourceId") or {}).get("videoId") or (
                item.get("contentDetails") or {}
            ).get("videoId")
            if not video_id:
                continue
            videos.append(
                YouTubeVideoItem(
                    video_id=str(video_id),
                    title=str(snippet.get("title") or ""),
                    description=str(snippet.get("description") or ""),
                    upload_date=snippet.get("publishedAt"),
                    visibility_status=str(status.get("privacyStatus") or "public"),
                )
            )
        return YouTubeVideoPage(videos=videos, next_page_token=payload.get("nextPageToken"))

    def _request(self, endpoint: str, params: dict[str, str]) -> dict[str, Any]:
        query = urlencode({**params, "key": self.api_key})
        url = f"{self.base_url}/{endpoint}?{query}"

        attempt = 0
        while True:
            status, body = self.transport(url)
            if status == 200:
                return body

            reason = _extract_error_reason(body)
            message = _extract_error_message(body) or f"HTTP {status}"

            if reason in QUOTA_REASONS:
                raise YouTubeQuotaExceededError(
                    "YouTube Data API daily quota is exhausted. "
                    "Resume the backfill after the quota resets; checkpoints preserve progress.",
                    reason=reason,
                )

            retryable = status in {429, 500, 502, 503, 504} or reason in RETRYABLE_REASONS
            if not retryable or attempt >= self.max_retries:
                raise YouTubeAPIError(
                    f"YouTube Data API request to {endpoint!r} failed: {message}",
                    reason=reason,
                )

            self.sleeper(min(2.0**attempt, 30.0))
            attempt += 1


def _default_transport(url: str) -> tuple[int, dict[str, Any]]:
    request = Request(url, headers={"Accept": "application/json"})
    try:
        with urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        try:
            body = json.loads(error.read().decode("utf-8"))
        except (ValueError, OSError):
            body = {}
        return error.code, body
    except URLError as error:
        raise YouTubeAPIError(f"YouTube Data API is unreachable: {error.reason}") from error


def _extract_error_reason(body: dict[str, Any]) -> str | None:
    errors = ((body.get("error") or {}).get("errors")) or []
    if errors and isinstance(errors, list):
        return errors[0].get("reason")
    return None


def _extract_error_message(body: dict[str, Any]) -> str | None:
    return (body.get("error") or {}).get("message")

#!/usr/bin/env python3
"""Run the official YouTube Data API producer backfill.

Requires BEATFINDER_YOUTUBE_API_KEY. Fetches public channel-upload metadata
only (no media downloads), resumes from per-channel checkpoints, and respects
the API quota by stopping cleanly when it is exhausted.

Usage:
  BEATFINDER_YOUTUBE_API_KEY=... python3 scripts/discovery/run_youtube_backfill.py
  ... --channel @prod.salishan          # limit to one channel
  ... --max-pages 5                     # cap pages per channel this run
  ... --refresh                         # re-extract metadata for known videos
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_api_client import (
    YouTubeDataAPIClient,
    YouTubeQuotaExceededError,
)
from backend.discovery.youtube_discovery import YouTubeBeatBackfill

DEFAULT_STATE_DIR = REPO_ROOT / ".beatfinder_state"


def run_backfill(
    *,
    state_dir: str | Path | None = None,
    channel: str | None = None,
    max_pages: int = 5,
    refresh: bool = False,
    client: YouTubeDataAPIClient | None = None,
) -> dict[str, Any]:
    api_client = client or YouTubeDataAPIClient.from_env()
    if api_client is None:
        raise SystemExit(
            "BEATFINDER_YOUTUBE_API_KEY is not set. Create an API key in the "
            "Google Cloud console with the YouTube Data API v3 enabled, then "
            "export BEATFINDER_YOUTUBE_API_KEY before running this backfill. "
            "Only public metadata is fetched; no audio is downloaded."
        )

    state_path = Path(state_dir or os.getenv("BEATFINDER_STATE_DIR", DEFAULT_STATE_DIR))
    store = ProducerDiscoveryStore(state_path)
    backfill = YouTubeBeatBackfill(store=store, client=api_client)

    channels = store.list_channels()
    if channel:
        wanted = channel.strip().lstrip("@").lower()
        channels = [
            item
            for item in channels
            if wanted in {item.channel_id.lower(), item.producer_name.lower(), *(alias.lower() for alias in item.aliases)}
        ]
        if not channels:
            raise SystemExit(
                f"No stored producer channel matches {channel!r}. "
                "Load seeds first: python3 scripts/discovery/load_producer_seeds.py"
            )
    if not channels:
        raise SystemExit(
            "No producer channels in the discovery store. "
            "Load seeds first: python3 scripts/discovery/load_producer_seeds.py"
        )

    summary: dict[str, Any] = {"state_dir": str(state_path), "channels": [], "quota_exhausted": False}
    for item in channels:
        entry: dict[str, Any] = {"channel_id": item.channel_id, "producer_name": item.producer_name}
        try:
            resolved_id = api_client.resolve_channel_id(item.channel_id)
            if resolved_id != item.channel_id:
                # Persist the canonical UC id while keeping the handle as an alias.
                store.upsert_channel(
                    f"https://www.youtube.com/channel/{resolved_id}",
                    producer_name=item.producer_name,
                    aliases=[*item.aliases, item.channel_id],
                    discovered_from=item.discovered_from,
                    confidence=item.confidence,
                )
            result = backfill.backfill_channel(resolved_id, refresh=refresh, max_pages=max_pages)
            entry.update(
                {
                    "resolved_channel_id": resolved_id,
                    "pages_scanned": result.pages_scanned,
                    "videos_seen": result.videos_seen,
                    "videos_created_or_refreshed": result.videos_created_or_refreshed,
                    "videos_skipped": result.videos_skipped,
                    "completed": result.completed,
                }
            )
        except YouTubeQuotaExceededError as error:
            entry["error"] = str(error)
            summary["channels"].append(entry)
            summary["quota_exhausted"] = True
            break
        except Exception as error:  # keep going: one bad channel must not stop the run
            entry["error"] = str(error)
        summary["channels"].append(entry)

    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", default=None)
    parser.add_argument("--channel", default=None, help="Backfill only this handle/channel id")
    parser.add_argument("--max-pages", type=int, default=5)
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    summary = run_backfill(
        state_dir=args.state_dir,
        channel=args.channel,
        max_pages=args.max_pages,
        refresh=args.refresh,
    )
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

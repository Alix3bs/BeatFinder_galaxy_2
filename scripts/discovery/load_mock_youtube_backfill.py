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

from backend.discovery.mock_youtube_client import MockYouTubeChannelClient
from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.youtube_discovery import YouTubeBeatBackfill
from scripts.discovery.load_producer_seeds import build_channel_aliases

DEFAULT_FIXTURE_PATH = REPO_ROOT / "backend" / "tests" / "fixtures" / "mock_youtube_channel_videos.json"
DEFAULT_STATE_DIR = REPO_ROOT / ".beatfinder_state"
LOCAL_TEST_CHANNEL_URL = "https://youtube.com/@prod.salishan"
LOCAL_TEST_CHANNEL_ID = "prod.salishan"


def load_mock_youtube_backfill(
    *,
    state_dir: str | Path | None = None,
    fixture_path: str | Path = DEFAULT_FIXTURE_PATH,
    refresh: bool = False,
) -> dict[str, Any]:
    """Load fixture-backed producer YouTube videos into local discovery state."""

    state_path = Path(state_dir or os.getenv("BEATFINDER_STATE_DIR", DEFAULT_STATE_DIR))
    store = ProducerDiscoveryStore(state_path)
    client = MockYouTubeChannelClient.from_fixture(fixture_path, page_size=3)
    backfill = YouTubeBeatBackfill(store=store, client=client)
    channel = store.upsert_channel(
        LOCAL_TEST_CHANNEL_URL,
        producer_name=LOCAL_TEST_CHANNEL_ID,
        aliases=build_channel_aliases(LOCAL_TEST_CHANNEL_ID),
        discovered_from="local_mock_youtube_backfill",
        confidence=1.0,
    )

    result = backfill.backfill_channel(channel.id, refresh=refresh)
    return {
        "state_dir": str(state_path.resolve()),
        "channels_backfilled": 1,
        "videos_created_or_refreshed": result.videos_created_or_refreshed,
        "videos_skipped": result.videos_skipped,
        "completed": result.completed,
        "discovery_seed_count": len(store.list_seeds()),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Load local fixture-backed YouTube beat videos.")
    parser.add_argument("--state-dir", default=None)
    parser.add_argument("--fixture-path", default=str(DEFAULT_FIXTURE_PATH))
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    summary = load_mock_youtube_backfill(
        state_dir=args.state_dir,
        fixture_path=args.fixture_path,
        refresh=args.refresh,
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

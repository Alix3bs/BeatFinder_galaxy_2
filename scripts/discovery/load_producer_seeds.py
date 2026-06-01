from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.discovery.producer_channels import ProducerDiscoveryStore, parse_youtube_channel_ref
from backend.discovery.producer_seed_loader import normalize_producer_profile_url
from models.metadata.normalize import clean_phrase

DEFAULT_SEED_FILE = REPO_ROOT / "data" / "seeds" / "producer_youtube_profiles.txt"
DEFAULT_STATE_DIR = REPO_ROOT / ".beatfinder_state"


def load_producer_seeds(
    *,
    seed_file: str | Path = DEFAULT_SEED_FILE,
    state_dir: str | Path | None = None,
) -> dict[str, Any]:
    """Load manual producer YouTube seeds into the local discovery store."""

    seed_path = Path(seed_file)
    state_path = Path(state_dir or os.getenv("BEATFINDER_STATE_DIR", DEFAULT_STATE_DIR))
    raw_urls = _read_seed_urls(seed_path)
    normalized_urls = _dedupe_preserve_order(normalize_producer_profile_url(url) for url in raw_urls)
    store = ProducerDiscoveryStore(state_path)

    channels_created = 0
    channels_updated = 0
    for url in normalized_urls:
        parsed = parse_youtube_channel_ref(url)
        existing = store.get_channel(parsed["channel_id"])
        aliases = build_channel_aliases(parsed["channel_id"])
        store.upsert_channel(
            url,
            aliases=aliases,
            discovered_from="manual_seed_file",
            confidence=1.0,
        )
        if existing:
            channels_updated += 1
        else:
            channels_created += 1

    return {
        "total_urls": len(raw_urls),
        "unique_channels": len(normalized_urls),
        "channels_created": channels_created,
        "channels_updated": channels_updated,
        "state_dir": str(state_path.resolve()),
    }


def build_channel_aliases(channel_id: str) -> list[str]:
    """Create local matching aliases from a YouTube handle/channel id."""

    handle = channel_id.strip().strip("@").lower().strip(" ._-")
    if not handle:
        return []
    if handle.startswith("uc") and len(handle) >= 10:
        return [handle]

    spaced = clean_phrase(re.sub(r"[._-]+", " ", handle))
    compact = re.sub(r"[^a-z0-9]", "", handle)
    aliases = [handle, spaced, compact]

    aliases.extend(_producer_prefix_aliases(handle, spaced, compact))
    aliases.extend(_beats_by_aliases(compact))
    aliases.extend(_on_the_track_aliases(compact))

    return _dedupe_preserve_order(alias for alias in aliases if alias)


def main() -> int:
    parser = argparse.ArgumentParser(description="Load producer YouTube seed channels into local BeatFinder state.")
    parser.add_argument("--seed-file", default=str(DEFAULT_SEED_FILE))
    parser.add_argument("--state-dir", default=None)
    args = parser.parse_args()

    summary = load_producer_seeds(seed_file=args.seed_file, state_dir=args.state_dir)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


def _read_seed_urls(seed_path: Path) -> list[str]:
    return [
        line.strip()
        for line in seed_path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def _producer_prefix_aliases(handle: str, spaced: str, compact: str) -> list[str]:
    aliases: list[str] = []
    if spaced.startswith("prod ") and len(spaced.split()) > 1:
        aliases.append(spaced.removeprefix("prod ").strip())
    if spaced.startswith("produced by ") and len(spaced.split()) > 2:
        aliases.append(spaced.removeprefix("produced by ").strip())
    if compact.startswith("prodby") and len(compact) > len("prodby"):
        tail = compact.removeprefix("prodby")
        aliases.extend([f"prod by {tail}", tail])
    if compact.startswith("producedby") and len(compact) > len("producedby"):
        tail = compact.removeprefix("producedby")
        aliases.extend([f"produced by {tail}", tail])
    return aliases


def _beats_by_aliases(compact: str) -> list[str]:
    if not compact.startswith("beatsby") or len(compact) <= len("beatsby"):
        return []
    producer = compact.removeprefix("beatsby")
    return [f"beats by {producer}", producer]


def _on_the_track_aliases(compact: str) -> list[str]:
    suffix = "onthetrack"
    if not compact.endswith(suffix) or len(compact) <= len(suffix):
        return []
    producer = compact.removesuffix(suffix)
    return [f"{producer} on the track", producer]


def _dedupe_preserve_order(values: object) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = str(value).strip()
        if not literal or literal in seen:
            continue
        seen.add(literal)
        output.append(literal)
    return output


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import json
import os
import re
from dataclasses import asdict, dataclass, field, fields
from pathlib import Path
from typing import Any, TypeVar
from urllib.parse import urlsplit, urlunsplit

from backend.core.types import new_id, utc_now_iso
from models.metadata.normalize import clean_phrase, dedupe_preserve_order

YOUTUBE_CHANNEL_RE = re.compile(r"(?:youtube\.com/(?:channel/|@|c/|user/))([^/?#]+)", re.IGNORECASE)

T = TypeVar("T")


@dataclass(slots=True)
class ProducerChannel:
    platform: str
    channel_id: str
    channel_url: str
    producer_name: str
    aliases: list[str] = field(default_factory=list)
    city_tags: list[str] = field(default_factory=list)
    style_tags: list[str] = field(default_factory=list)
    discovered_from: str | None = None
    confidence: float = 1.0
    first_seen_at: str = field(default_factory=utc_now_iso)
    last_scanned_at: str | None = None
    id: str = field(default_factory=new_id)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class ProducerBeatVideo:
    producer_channel_id: str
    video_id: str
    video_url: str
    title: str
    description: str | None = None
    upload_date: str | None = None
    hashtags: list[str] = field(default_factory=list)
    normalized_search_phrases: list[str] = field(default_factory=list)
    artist_refs: list[str] = field(default_factory=list)
    artist_combo_refs: list[str] = field(default_factory=list)
    producer_refs: list[str] = field(default_factory=list)
    producer_combo_refs: list[str] = field(default_factory=list)
    city_tags: list[str] = field(default_factory=list)
    region_tags: list[str] = field(default_factory=list)
    style_tags: list[str] = field(default_factory=list)
    type_beat_phrases: list[str] = field(default_factory=list)
    beat_store_links: list[str] = field(default_factory=list)
    audio_signature_status: str = "not_processed"
    visibility_status: str = "public"
    last_seen_at: str = field(default_factory=utc_now_iso)
    id: str = field(default_factory=new_id)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class DiscoverySeed:
    seed_type: str
    seed_value: str
    source: str
    priority: int = 50
    status: str = "pending"
    created_at: str = field(default_factory=utc_now_iso)
    id: str = field(default_factory=new_id)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class DiscoveryEdge:
    from_type: str
    from_id: str
    to_type: str
    to_id: str
    relation: str
    confidence: float
    evidence: dict[str, Any] = field(default_factory=dict)
    id: str = field(default_factory=new_id)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class PossibleSoldOrDeletedBeat:
    detected_producer_tag: str
    matched_producer_channel_id: str
    query_audio_id: str | None
    nearest_candidates: list[dict[str, Any]] = field(default_factory=list)
    evidence: dict[str, Any] = field(default_factory=dict)
    confidence: float = 0.0
    possible_reasons: list[str] = field(default_factory=list)
    created_at: str = field(default_factory=utc_now_iso)
    id: str = field(default_factory=new_id)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class DiscoveryCheckpoint:
    producer_channel_id: str
    page_token: str | None
    completed: bool
    updated_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class ProducerDiscoveryStore:
    """Local JSON store for discovery state.

    This intentionally mirrors BeatFinder's local verification style and does
    not require Supabase or live YouTube credentials.
    """

    def __init__(self, root: str | Path | None = None) -> None:
        base = Path(root or os.getenv("BEATFINDER_STATE_DIR", ".beatfinder_state"))
        self.root = base
        self.db_dir = base / "db"
        self.db_dir.mkdir(parents=True, exist_ok=True)

    def upsert_channel(
        self,
        channel_ref: str,
        *,
        producer_name: str | None = None,
        aliases: list[str] | None = None,
        city_tags: list[str] | None = None,
        style_tags: list[str] | None = None,
        discovered_from: str | None = None,
        confidence: float = 1.0,
    ) -> ProducerChannel:
        parsed = parse_youtube_channel_ref(channel_ref)
        channels = self._load_table("producer_channels")
        existing = next(
            (
                row
                for row in channels
                if row.get("platform") == parsed["platform"] and row.get("channel_id") == parsed["channel_id"]
            ),
            None,
        )
        normalized_aliases = dedupe_preserve_order([*(aliases or []), producer_name or ""])
        if existing:
            channel = _from_dict(ProducerChannel, existing)
            channel.producer_name = clean_phrase(producer_name or channel.producer_name) or channel.producer_name
            channel.aliases = dedupe_preserve_order([*channel.aliases, *normalized_aliases])
            channel.city_tags = dedupe_tags([*channel.city_tags, *(city_tags or [])])
            channel.style_tags = dedupe_tags([*channel.style_tags, *(style_tags or [])])
            channel.discovered_from = discovered_from or channel.discovered_from
            channel.confidence = max(channel.confidence, confidence)
        else:
            channel = ProducerChannel(
                platform=parsed["platform"],
                channel_id=parsed["channel_id"],
                channel_url=parsed["channel_url"],
                producer_name=clean_phrase(producer_name or parsed["producer_name"]) or parsed["producer_name"],
                aliases=normalized_aliases,
                city_tags=dedupe_tags(city_tags or []),
                style_tags=dedupe_tags(style_tags or []),
                discovered_from=discovered_from,
                confidence=confidence,
            )
        self._upsert_dataclass("producer_channels", channel, key="id")
        return channel

    def get_channel(self, channel_id: str) -> ProducerChannel | None:
        for row in self._load_table("producer_channels"):
            if row.get("id") == channel_id or row.get("channel_id") == channel_id:
                return _from_dict(ProducerChannel, row)
        return None

    def list_channels(self) -> list[ProducerChannel]:
        return [_from_dict(ProducerChannel, row) for row in self._load_table("producer_channels")]

    def touch_channel_scanned(self, producer_channel_id: str) -> None:
        channel = self.get_channel(producer_channel_id)
        if channel is None:
            return
        channel.last_scanned_at = utc_now_iso()
        self._upsert_dataclass("producer_channels", channel, key="id")

    def get_video(self, producer_channel_id: str, video_id: str) -> ProducerBeatVideo | None:
        for row in self._load_table("producer_beat_videos"):
            if row.get("producer_channel_id") == producer_channel_id and row.get("video_id") == video_id:
                return _from_dict(ProducerBeatVideo, row)
        return None

    def upsert_video(self, video: ProducerBeatVideo, *, refresh: bool = False) -> tuple[ProducerBeatVideo, bool]:
        existing = self.get_video(video.producer_channel_id, video.video_id)
        if existing and not refresh:
            return existing, False
        if existing:
            video.id = existing.id
        video.last_seen_at = utc_now_iso()
        self._upsert_dataclass("producer_beat_videos", video, key="id")
        return video, True

    def list_videos(self, producer_channel_id: str | None = None) -> list[ProducerBeatVideo]:
        videos = [_from_dict(ProducerBeatVideo, row) for row in self._load_table("producer_beat_videos")]
        if producer_channel_id is None:
            return videos
        return [video for video in videos if video.producer_channel_id == producer_channel_id]

    def save_seed(self, seed: DiscoverySeed) -> DiscoverySeed:
        seeds = self._load_table("discovery_seeds")
        for row in seeds:
            if row.get("seed_type") == seed.seed_type and row.get("seed_value") == seed.seed_value:
                existing = _from_dict(DiscoverySeed, row)
                existing.priority = min(existing.priority, seed.priority)
                existing.status = existing.status if existing.status != "pending" else seed.status
                self._upsert_dataclass("discovery_seeds", existing, key="id")
                return existing
        self._upsert_dataclass("discovery_seeds", seed, key="id")
        return seed

    def list_seeds(self, *, status: str | None = None) -> list[DiscoverySeed]:
        seeds = [_from_dict(DiscoverySeed, row) for row in self._load_table("discovery_seeds")]
        if status is None:
            return seeds
        return [seed for seed in seeds if seed.status == status]

    def update_seed_status(self, seed_id: str, status: str) -> None:
        seed = next((item for item in self.list_seeds() if item.id == seed_id), None)
        if seed is None:
            return
        seed.status = status
        self._upsert_dataclass("discovery_seeds", seed, key="id")

    def save_edge(self, edge: DiscoveryEdge) -> DiscoveryEdge:
        self._upsert_dataclass("discovery_edges", edge, key="id")
        return edge

    def save_possible_sold_deleted(self, record: PossibleSoldOrDeletedBeat) -> PossibleSoldOrDeletedBeat:
        self._upsert_dataclass("possible_sold_or_deleted_beats", record, key="id")
        return record

    def list_possible_sold_deleted(self) -> list[PossibleSoldOrDeletedBeat]:
        return [
            _from_dict(PossibleSoldOrDeletedBeat, row)
            for row in self._load_table("possible_sold_or_deleted_beats")
        ]

    def get_checkpoint(self, producer_channel_id: str) -> DiscoveryCheckpoint | None:
        for row in self._load_table("discovery_checkpoints"):
            if row.get("producer_channel_id") == producer_channel_id:
                return _from_dict(DiscoveryCheckpoint, row)
        return None

    def save_checkpoint(
        self,
        producer_channel_id: str,
        *,
        page_token: str | None,
        completed: bool,
    ) -> DiscoveryCheckpoint:
        checkpoint = DiscoveryCheckpoint(
            producer_channel_id=producer_channel_id,
            page_token=page_token,
            completed=completed,
        )
        checkpoints = self._load_table("discovery_checkpoints")
        checkpoints = [row for row in checkpoints if row.get("producer_channel_id") != producer_channel_id]
        checkpoints.append(checkpoint.to_dict())
        self._save_table("discovery_checkpoints", checkpoints)
        return checkpoint

    def _table_path(self, table_name: str) -> Path:
        return self.db_dir / f"{table_name}.json"

    def _load_table(self, table_name: str) -> list[dict[str, Any]]:
        path = self._table_path(table_name)
        if not path.exists():
            return []
        return json.loads(path.read_text(encoding="utf-8"))

    def _save_table(self, table_name: str, rows: list[dict[str, Any]]) -> None:
        path = self._table_path(table_name)
        path.write_text(json.dumps(rows, indent=2, sort_keys=True), encoding="utf-8")

    def _upsert_dataclass(self, table_name: str, record: Any, *, key: str) -> None:
        rows = self._load_table(table_name)
        rows = [row for row in rows if row.get(key) != getattr(record, key)]
        rows.append(record.to_dict())
        self._save_table(table_name, rows)


def parse_youtube_channel_ref(channel_ref: str) -> dict[str, str]:
    raw = _strip_url_tracking(channel_ref.strip())
    match = YOUTUBE_CHANNEL_RE.search(raw)
    if match:
        channel_id = match.group(1).strip("@")
        parsed_path = urlsplit(raw).path
        if "/@" in parsed_path:
            channel_id = channel_id.lower()
        return {
            "platform": "youtube",
            "channel_id": channel_id,
            "channel_url": raw,
            "producer_name": clean_phrase(channel_id.replace("-", " ").replace("_", " ")),
        }
    channel_id = raw.strip("@")
    if not channel_id.startswith("UC"):
        channel_id = channel_id.lower()
    channel_url = f"https://www.youtube.com/channel/{channel_id}" if channel_id.startswith("UC") else f"https://www.youtube.com/@{channel_id}"
    return {
        "platform": "youtube",
        "channel_id": channel_id,
        "channel_url": channel_url,
        "producer_name": clean_phrase(channel_id.replace("-", " ").replace("_", " ")),
    }


def dedupe_tags(values: list[str] | tuple[str, ...]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        tag = str(value).strip().lower().replace(" ", "_")
        if not tag or tag in seen:
            continue
        seen.add(tag)
        output.append(tag)
    return output


def _strip_url_tracking(value: str) -> str:
    if "://" not in value:
        return value
    parsed = urlsplit(value)
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path.rstrip("/"), "", ""))


def _from_dict(cls: type[T], row: dict[str, Any]) -> T:
    allowed = {field.name for field in fields(cls)}
    return cls(**{key: value for key, value in row.items() if key in allowed})

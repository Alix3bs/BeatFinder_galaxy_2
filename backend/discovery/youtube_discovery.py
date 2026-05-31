from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Protocol

from backend.discovery.city_style_classifier import classify_city_style
from backend.discovery.hashtag_expander import expand_discovery_seeds
from backend.discovery.producer_channels import (
    DiscoveryEdge,
    ProducerBeatVideo,
    ProducerChannel,
    ProducerDiscoveryStore,
    dedupe_tags,
)
from models.metadata.normalize import clean_phrase, dedupe_preserve_order, extract_hashtags
from models.metadata.parser import parse_metadata

URL_RE = re.compile(r"https?://[^\s)>\"]+", re.IGNORECASE)
BEAT_STORE_DOMAINS = ("beatstars.com", "traktrain.com", "airbit.com", "bsta.rs")


@dataclass(slots=True)
class YouTubeVideoItem:
    video_id: str
    title: str
    description: str = ""
    upload_date: str | None = None
    visibility_status: str = "public"


@dataclass(slots=True)
class YouTubeVideoPage:
    videos: list[YouTubeVideoItem]
    next_page_token: str | None = None


class YouTubeChannelClient(Protocol):
    def list_channel_videos(self, channel_id: str, *, page_token: str | None = None) -> YouTubeVideoPage:
        raise NotImplementedError


@dataclass(slots=True)
class ChannelBackfillResult:
    producer_channel_id: str
    pages_scanned: int = 0
    videos_seen: int = 0
    videos_created_or_refreshed: int = 0
    videos_skipped: int = 0
    completed: bool = False
    next_page_token: str | None = None
    generated_seed_ids: list[str] = field(default_factory=list)


class YouTubeBeatBackfill:
    def __init__(self, *, store: ProducerDiscoveryStore, client: YouTubeChannelClient) -> None:
        self.store = store
        self.client = client

    def ingest_producer_profile(
        self,
        channel_ref: str,
        *,
        producer_name: str | None = None,
        aliases: list[str] | None = None,
        discovered_from: str | None = None,
        confidence: float = 1.0,
    ) -> ProducerChannel:
        return self.store.upsert_channel(
            channel_ref,
            producer_name=producer_name,
            aliases=aliases,
            discovered_from=discovered_from,
            confidence=confidence,
        )

    def backfill_channel(
        self,
        channel_ref_or_id: str,
        *,
        refresh: bool = False,
        max_pages: int = 25,
    ) -> ChannelBackfillResult:
        channel = self.store.get_channel(channel_ref_or_id)
        if channel is None:
            channel = self.store.upsert_channel(channel_ref_or_id)

        checkpoint = self.store.get_checkpoint(channel.id)
        page_token = None if refresh or checkpoint is None or checkpoint.completed else checkpoint.page_token
        result = ChannelBackfillResult(producer_channel_id=channel.id)

        for _ in range(max(1, max_pages)):
            page = self.client.list_channel_videos(channel.channel_id, page_token=page_token)
            result.pages_scanned += 1
            result.videos_seen += len(page.videos)
            for video_item in page.videos:
                video = extract_video_metadata(channel=channel, video=video_item)
                existing = self.store.get_video(channel.id, video.video_id)
                saved_video, changed = self.store.upsert_video(video, refresh=refresh)
                if existing and not refresh and not changed:
                    result.videos_skipped += 1
                    continue
                result.videos_created_or_refreshed += 1
                result.generated_seed_ids.extend(self._enqueue_discovery_seeds(saved_video))

            page_token = page.next_page_token
            result.next_page_token = page_token
            result.completed = page_token is None
            self.store.save_checkpoint(channel.id, page_token=page_token, completed=result.completed)
            if result.completed:
                break

        self.store.touch_channel_scanned(channel.id)
        return result

    def _enqueue_discovery_seeds(self, video: ProducerBeatVideo) -> list[str]:
        seeds = expand_discovery_seeds(
            hashtags=video.hashtags,
            phrases=[*video.artist_combo_refs, *video.type_beat_phrases, *video.region_tags],
            source=f"producer_beat_video:{video.id}",
            priority=60,
        )
        seed_ids: list[str] = []
        for seed in seeds:
            saved = self.store.save_seed(seed)
            self.store.save_edge(
                DiscoveryEdge(
                    from_type="producer_beat_video",
                    from_id=video.id,
                    to_type="discovery_seed",
                    to_id=saved.id,
                    relation="generated_search_seed",
                    confidence=0.7,
                    evidence={"seed_value": saved.seed_value},
                )
            )
            seed_ids.append(saved.id)
        return seed_ids


def extract_video_metadata(*, channel: ProducerChannel, video: YouTubeVideoItem) -> ProducerBeatVideo:
    combined_text = f"{video.title} {video.description or ''}"
    hashtags = extract_hashtags(combined_text)
    parsed = parse_metadata(video.title, producer_name=channel.producer_name, hashtags=hashtags)
    classification = classify_city_style(
        [
            video.title,
            video.description or "",
            *hashtags,
            *(parsed.get("type_beat_phrases") if isinstance(parsed.get("type_beat_phrases"), list) else []),
        ]
    )
    beat_store_links = extract_beat_store_links(video.description or "")
    producer_refs = dedupe_preserve_order(
        [
            channel.producer_name,
            *channel.aliases,
            parsed.get("producer_name") if isinstance(parsed.get("producer_name"), str) else "",
        ]
    )
    normalized_search_phrases = dedupe_preserve_order(
        [
            video.title,
            video.description or "",
            *(parsed.get("normalized_search_phrases") if isinstance(parsed.get("normalized_search_phrases"), list) else []),
            *classification.city_tags,
            *classification.region_tags,
            *classification.style_tags,
            *beat_store_links,
        ]
    )
    return ProducerBeatVideo(
        producer_channel_id=channel.id,
        video_id=video.video_id,
        video_url=f"https://www.youtube.com/watch?v={video.video_id}",
        title=video.title,
        description=video.description,
        upload_date=video.upload_date,
        hashtags=list(parsed.get("hashtags") or []),
        normalized_search_phrases=normalized_search_phrases,
        artist_refs=list(parsed.get("artist_refs") or []),
        artist_combo_refs=list(parsed.get("artist_combo_refs") or []),
        producer_refs=producer_refs,
        producer_combo_refs=list(parsed.get("producer_combo_refs") or []),
        city_tags=dedupe_tags([*channel.city_tags, *classification.city_tags]),
        region_tags=dedupe_tags([*(parsed.get("region_tags") or []), *classification.region_tags]),
        style_tags=classification.style_tags,
        type_beat_phrases=list(parsed.get("type_beat_phrases") or []),
        beat_store_links=beat_store_links,
        visibility_status=clean_phrase(video.visibility_status) or "public",
    )


def extract_beat_store_links(description: str) -> list[str]:
    links: list[str] = []
    for match in URL_RE.finditer(description):
        link = match.group(0).rstrip(".,)")
        if any(domain in link.lower() for domain in BEAT_STORE_DOMAINS):
            links.append(link)
    return _dedupe_literals(links)


def _dedupe_literals(values: list[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = value.strip()
        key = literal.lower()
        if not literal or key in seen:
            continue
        seen.add(key)
        output.append(literal)
    return output

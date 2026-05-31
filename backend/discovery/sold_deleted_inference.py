from __future__ import annotations

from collections.abc import Iterable
from typing import Any

from backend.discovery.producer_channels import PossibleSoldOrDeletedBeat, ProducerChannel, ProducerDiscoveryStore
from models.metadata.normalize import clean_phrase

POSSIBLE_REASONS = [
    "sold_and_deleted",
    "unlisted",
    "private",
    "renamed",
    "hosted_on_beatstars",
    "hosted_on_traktrain",
    "not_yet_indexed",
    "producer_tag_false_positive",
]


def infer_possible_sold_or_deleted(
    *,
    detected_producer_tag: str,
    store: ProducerDiscoveryStore,
    query_audio_id: str | None = None,
    candidate_title: str | None = None,
    nearest_candidates: Iterable[dict[str, Any]] = (),
) -> PossibleSoldOrDeletedBeat | None:
    matched_channel = _match_channel_by_alias(detected_producer_tag, store.list_channels())
    if matched_channel is None:
        return None

    indexed_videos = store.list_videos(matched_channel.id)
    normalized_title = clean_phrase(candidate_title or "")
    if normalized_title and any(_title_matches_video(normalized_title, video.title) for video in indexed_videos):
        return None

    reasons = ["sold_and_deleted", "unlisted", "private", "renamed", "hosted_on_beatstars", "hosted_on_traktrain"]
    if not indexed_videos:
        reasons.append("not_yet_indexed")
    reasons.append("producer_tag_false_positive")

    confidence = 0.72 if indexed_videos else 0.52
    record = PossibleSoldOrDeletedBeat(
        detected_producer_tag=clean_phrase(detected_producer_tag),
        matched_producer_channel_id=matched_channel.id,
        query_audio_id=query_audio_id,
        nearest_candidates=list(nearest_candidates),
        evidence={
            "producer_tag_detected": detected_producer_tag,
            "producer_channel_matched": matched_channel.channel_url,
            "indexed_video_count": len(indexed_videos),
            "matching_visible_upload_found": False,
            "note": "This is a possible status only; the beat may be sold, deleted, unlisted, private, renamed, not indexed, or hosted elsewhere.",
        },
        confidence=confidence,
        possible_reasons=reasons,
    )
    return store.save_possible_sold_deleted(record)


def _match_channel_by_alias(tag: str, channels: Iterable[ProducerChannel]) -> ProducerChannel | None:
    normalized_tag = clean_phrase(tag)
    if not normalized_tag:
        return None
    for channel in channels:
        aliases = [channel.producer_name, *channel.aliases]
        for alias in aliases:
            normalized_alias = clean_phrase(alias)
            if normalized_alias and (normalized_alias == normalized_tag or normalized_alias in normalized_tag):
                return channel
    return None


def _title_matches_video(candidate_title: str, video_title: str) -> bool:
    candidate_tokens = set(candidate_title.split())
    video_tokens = set(clean_phrase(video_title).split())
    if not candidate_tokens or not video_tokens:
        return False
    overlap = len(candidate_tokens & video_tokens) / max(len(candidate_tokens), 1)
    return overlap >= 0.75

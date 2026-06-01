from __future__ import annotations

from collections.abc import Iterable
from dataclasses import asdict, dataclass, field
from typing import Any

from backend.discovery.producer_channels import ProducerBeatVideo, ProducerChannel, ProducerDiscoveryStore
from backend.discovery.producer_tag_matcher import match_producer_tag
from backend.discovery.sold_deleted_inference import (
    INSUFFICIENT_EVIDENCE_STATUS,
    SoldDeletedInferenceResult,
    infer_sold_deleted_status,
)
from models.metadata.normalize import clean_phrase, dedupe_preserve_order, normalize_hashtag, split_combo_phrase

NOT_APPLICABLE_STATUS = "not_applicable"


@dataclass(slots=True)
class SearchDiscoveryEnrichment:
    detected_producer_tag: str | None = None
    matched_producer_channel: dict[str, Any] | None = None
    producer_tag_confidence: float | None = None
    youtube_video_match: dict[str, Any] | None = None
    discovery_status: str = NOT_APPLICABLE_STATUS
    possible_reasons: list[str] = field(default_factory=list)
    evidence: list[str] = field(default_factory=list)
    recommended_next_searches: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def enrich_search_discovery(
    *,
    query_metadata: dict[str, Any] | None = None,
    detected_producer_tag: str | None = None,
    matched_candidates: Iterable[Any] = (),
    producer_discovery_store: ProducerDiscoveryStore | None = None,
    indexed_producer_videos: Iterable[ProducerBeatVideo] | None = None,
    query_text: str | None = None,
) -> SearchDiscoveryEnrichment:
    candidate_list = list(matched_candidates)
    provided_videos = list(indexed_producer_videos) if indexed_producer_videos is not None else None
    recommended_next_searches = _recommended_next_searches(
        detected_producer_tag=detected_producer_tag,
        matched_candidates=candidate_list,
        videos=provided_videos or (),
        matched_channel=None,
    )
    normalized_tag = clean_phrase(detected_producer_tag or "")
    if not normalized_tag:
        return SearchDiscoveryEnrichment(
            discovery_status=NOT_APPLICABLE_STATUS,
            evidence=["no detected producer tag supplied"],
            recommended_next_searches=recommended_next_searches,
        )

    if producer_discovery_store is None:
        return SearchDiscoveryEnrichment(
            detected_producer_tag=normalized_tag,
            discovery_status=INSUFFICIENT_EVIDENCE_STATUS,
            evidence=["producer discovery store is not configured"],
            recommended_next_searches=recommended_next_searches,
        )

    producer_match = match_producer_tag(normalized_tag, producer_discovery_store.list_channels(), min_confidence=0.0)
    if producer_match is None:
        return SearchDiscoveryEnrichment(
            detected_producer_tag=normalized_tag,
            discovery_status=INSUFFICIENT_EVIDENCE_STATUS,
            evidence=["detected producer tag did not match a known producer alias"],
            recommended_next_searches=recommended_next_searches,
        )

    videos = provided_videos if provided_videos is not None else producer_discovery_store.list_videos(producer_match.channel.id)
    query_phrases = _query_phrases(query_metadata, candidate_list)
    query_title = clean_phrase(query_text or "") or _top_candidate_title(candidate_list)
    nearest_candidates = _nearest_candidate_summaries(candidate_list)
    inference = infer_sold_deleted_status(
        detected_producer_tag=normalized_tag,
        store=producer_discovery_store,
        producer_match=producer_match,
        indexed_video_candidates=videos,
        query_title=query_title,
        query_phrases=query_phrases,
        nearest_candidates=nearest_candidates,
    )
    video_match = _matched_video_to_dict(inference, videos)
    return SearchDiscoveryEnrichment(
        detected_producer_tag=normalized_tag,
        matched_producer_channel=_channel_to_dict(producer_match.channel),
        producer_tag_confidence=round(producer_match.confidence, 3),
        youtube_video_match=video_match,
        discovery_status=inference.status,
        possible_reasons=inference.possible_reasons,
        evidence=inference.evidence,
        recommended_next_searches=_recommended_next_searches(
            detected_producer_tag=normalized_tag,
            matched_candidates=candidate_list,
            videos=videos,
            matched_channel=producer_match.channel,
        ),
    )


def _channel_to_dict(channel: ProducerChannel) -> dict[str, Any]:
    return {
        "id": channel.id,
        "channel_id": channel.channel_id,
        "channel_url": channel.channel_url,
        "producer_name": channel.producer_name,
        "aliases": list(channel.aliases),
    }


def _matched_video_to_dict(
    inference: SoldDeletedInferenceResult,
    videos: Iterable[ProducerBeatVideo],
) -> dict[str, Any] | None:
    if inference.matched_video_id is None:
        return None
    matched = next((video for video in videos if video.video_id == inference.matched_video_id), None)
    if matched is None:
        return {"video_id": inference.matched_video_id}
    return {
        "id": matched.id,
        "video_id": matched.video_id,
        "video_url": matched.video_url,
        "title": matched.title,
        "visibility_status": matched.visibility_status,
    }


def _query_phrases(query_metadata: dict[str, Any] | None, matched_candidates: list[Any]) -> list[str]:
    phrases: list[str] = []
    if query_metadata:
        for key in (
            "normalized_query_phrases",
            "normalized_search_phrases",
            "type_beat_phrases",
            "artist_combo_refs",
            "region_tags",
            "genre_tags",
        ):
            values = query_metadata.get(key)
            if isinstance(values, list):
                phrases.extend(str(value) for value in values)
            elif isinstance(values, str):
                phrases.append(values)
    for beat in _candidate_beats(matched_candidates):
        phrases.extend(str(value) for value in beat.get("normalized_search_phrases") or [])
        phrases.extend(str(value) for value in beat.get("type_beat_phrases") or [])
        phrases.extend(str(value) for value in beat.get("artist_combo_refs") or [])
    return dedupe_preserve_order(phrases)


def _top_candidate_title(matched_candidates: list[Any]) -> str | None:
    for beat in _candidate_beats(matched_candidates):
        title = clean_phrase(str(beat.get("raw_title") or beat.get("title") or ""))
        if title:
            return title
    return None


def _nearest_candidate_summaries(matched_candidates: list[Any]) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for candidate in matched_candidates:
        if not isinstance(candidate, dict):
            continue
        beat = candidate.get("beat")
        if not isinstance(beat, dict):
            continue
        summaries.append(
            {
                "title": beat.get("raw_title") or beat.get("title"),
                "raw_title": beat.get("raw_title") or beat.get("title"),
                "score": float(candidate.get("rerank_score") or 0.0),
            }
        )
    return summaries


def _candidate_beats(matched_candidates: Iterable[Any]) -> list[dict[str, Any]]:
    beats: list[dict[str, Any]] = []
    for candidate in matched_candidates:
        if isinstance(candidate, dict) and isinstance(candidate.get("beat"), dict):
            beats.append(candidate["beat"])
        elif hasattr(candidate, "beat") and hasattr(candidate.beat, "to_dict"):
            beats.append(candidate.beat.to_dict())
    return beats


def _recommended_next_searches(
    *,
    detected_producer_tag: str | None,
    matched_candidates: Iterable[Any],
    videos: Iterable[ProducerBeatVideo],
    matched_channel: ProducerChannel | None,
) -> list[str]:
    searches: list[str] = []
    producer_phrase = _producer_search_phrase(matched_channel, detected_producer_tag)
    if producer_phrase:
        searches.append(producer_phrase)

    beats = _candidate_beats(matched_candidates)
    for beat in beats:
        searches.extend(_searches_from_hashtags(beat.get("hashtags") or []))
        searches.extend(_searches_from_combos(beat.get("artist_combo_refs") or []))
        searches.extend(_searches_from_combos(beat.get("type_beat_phrases") or []))
        searches.extend(_searches_from_regions(beat.get("region_tags") or []))
    for video in videos:
        searches.extend(_searches_from_hashtags(video.hashtags))
        searches.extend(_searches_from_combos(video.artist_combo_refs))
        searches.extend(_searches_from_combos(video.type_beat_phrases))
        searches.extend(_searches_from_regions([*video.city_tags, *video.region_tags]))
    return dedupe_preserve_order(searches)[:10]


def _producer_search_phrase(channel: ProducerChannel | None, detected_producer_tag: str | None) -> str:
    value = channel.producer_name if channel is not None else detected_producer_tag or ""
    normalized = clean_phrase(value.replace(".", " "))
    if not normalized:
        return ""
    tokens = [token for token in normalized.split() if token != "by"]
    subject = clean_phrase(" ".join(tokens))
    if not subject:
        return ""
    return clean_phrase(f"{subject} type beat")


def _searches_from_hashtags(hashtags: Iterable[str]) -> list[str]:
    searches: list[str] = []
    for hashtag in hashtags:
        variants = normalize_hashtag(str(hashtag))
        spaced = [variant for variant in variants if " type beat" in variant and " " in variant]
        value = max(spaced, key=lambda item: len(item.split()), default="")
        if value:
            searches.append(value)
    return searches


def _searches_from_combos(values: Iterable[str]) -> list[str]:
    searches: list[str] = []
    for value in values:
        normalized = clean_phrase(str(value))
        if not normalized:
            continue
        subject = normalized.removesuffix(" type beat").strip()
        parts = split_combo_phrase(subject)
        if len(parts) > 1:
            searches.append(clean_phrase(f"{' '.join(parts)} type beat"))
        elif normalized.endswith("type beat"):
            searches.append(normalized)
    return searches


def _searches_from_regions(values: Iterable[str]) -> list[str]:
    regions = dedupe_preserve_order(str(value) for value in values)
    if len(regions) >= 2:
        return [clean_phrase(f"{' '.join(regions[:2])} type beat")]
    if len(regions) == 1:
        return [clean_phrase(f"{regions[0]} type beat")]
    return []

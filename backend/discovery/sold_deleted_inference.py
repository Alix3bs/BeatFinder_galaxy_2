from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Any

from backend.discovery.producer_channels import PossibleSoldOrDeletedBeat, ProducerBeatVideo, ProducerChannel, ProducerDiscoveryStore
from backend.discovery.producer_tag_matcher import ProducerTagMatch, match_producer_tag
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
FOUND_CANDIDATE_STATUS = "found_candidate"
INSUFFICIENT_EVIDENCE_STATUS = "insufficient_evidence"
POSSIBLE_SOLD_OR_DELETED_STATUS = "possible_sold_or_deleted"


@dataclass(slots=True)
class SoldDeletedInferenceResult:
    status: str
    confidence: float
    evidence: list[str] = field(default_factory=list)
    possible_reasons: list[str] = field(default_factory=list)
    matched_channel_id: str | None = None
    detected_producer_tag: str | None = None
    nearest_candidates: list[dict[str, Any]] = field(default_factory=list)
    matched_video_id: str | None = None
    record_id: str | None = None


def infer_possible_sold_or_deleted(
    *,
    detected_producer_tag: str,
    store: ProducerDiscoveryStore,
    query_audio_id: str | None = None,
    candidate_title: str | None = None,
    nearest_candidates: Iterable[dict[str, Any]] = (),
) -> PossibleSoldOrDeletedBeat | None:
    result = infer_sold_deleted_status(
        detected_producer_tag=detected_producer_tag,
        store=store,
        query_audio_id=query_audio_id,
        query_title=candidate_title,
        nearest_candidates=nearest_candidates,
        persist=True,
    )
    if result.status != POSSIBLE_SOLD_OR_DELETED_STATUS or result.record_id is None:
        return None
    return next((record for record in store.list_possible_sold_deleted() if record.id == result.record_id), None)


def infer_sold_deleted_status(
    *,
    detected_producer_tag: str,
    store: ProducerDiscoveryStore | None = None,
    producer_match: ProducerTagMatch | None = None,
    matched_channel: ProducerChannel | None = None,
    indexed_video_candidates: Iterable[ProducerBeatVideo] | None = None,
    query_audio_id: str | None = None,
    query_title: str | None = None,
    query_phrases: Iterable[str] = (),
    nearest_candidates: Iterable[dict[str, Any]] = (),
    min_tag_confidence: float = 0.7,
    persist: bool = False,
) -> SoldDeletedInferenceResult:
    nearest_candidate_list = list(nearest_candidates)
    if producer_match is None:
        if matched_channel is not None:
            producer_match = ProducerTagMatch(
                channel=matched_channel,
                confidence=matched_channel.confidence,
                match_type="provided_channel",
                detected_producer_tag=detected_producer_tag,
                normalized_tag=clean_phrase(detected_producer_tag),
                matched_alias=matched_channel.producer_name,
                evidence=[f"producer channel provided directly: {matched_channel.channel_id}"],
            )
        elif store is not None:
            producer_match = match_producer_tag(detected_producer_tag, store.list_channels(), min_confidence=0.0)

    if producer_match is None:
        return SoldDeletedInferenceResult(
            status=INSUFFICIENT_EVIDENCE_STATUS,
            confidence=0.0,
            evidence=["no known producer channel matched the detected producer tag"],
            detected_producer_tag=detected_producer_tag,
            nearest_candidates=nearest_candidate_list,
        )

    if producer_match.confidence < min_tag_confidence:
        return SoldDeletedInferenceResult(
            status=INSUFFICIENT_EVIDENCE_STATUS,
            confidence=producer_match.confidence,
            evidence=[
                *producer_match.evidence,
                f"producer tag confidence {producer_match.confidence:.2f} is below threshold {min_tag_confidence:.2f}",
            ],
            matched_channel_id=producer_match.channel.id,
            detected_producer_tag=detected_producer_tag,
            nearest_candidates=nearest_candidate_list,
        )

    indexed_videos = list(indexed_video_candidates) if indexed_video_candidates is not None else []
    if indexed_video_candidates is None and store is not None:
        indexed_videos = store.list_videos(producer_match.channel.id)

    query_values = [query_title or "", *query_phrases]
    found_video, found_score = _find_matching_video(query_values, indexed_videos, nearest_candidate_list)
    base_evidence = [
        *producer_match.evidence,
        f"matched producer channel '{producer_match.channel.channel_id}'",
        f"indexed visible video candidates checked: {len(indexed_videos)}",
    ]
    if found_video is not None:
        return SoldDeletedInferenceResult(
            status=FOUND_CANDIDATE_STATUS,
            confidence=round(min(0.96, (producer_match.confidence * 0.65) + (found_score * 0.35)), 3),
            evidence=[
                *base_evidence,
                f"visible matching beat candidate found: {found_video.video_id}",
                f"candidate title: {found_video.title}",
            ],
            matched_channel_id=producer_match.channel.id,
            detected_producer_tag=detected_producer_tag,
            nearest_candidates=nearest_candidate_list,
            matched_video_id=found_video.video_id,
        )

    fully_backfilled = _is_channel_fully_backfilled(store, producer_match.channel.id)
    reasons = _possible_reasons(fully_backfilled=fully_backfilled)
    result = SoldDeletedInferenceResult(
        status=POSSIBLE_SOLD_OR_DELETED_STATUS,
        confidence=round(min(0.86, producer_match.confidence * (0.86 if indexed_videos else 0.68)), 3),
        evidence=[
            *base_evidence,
            "producer tag matched a known channel",
            "no visible matching beat upload found in indexed candidates",
            "status is possible only, not certain",
        ],
        possible_reasons=reasons,
        matched_channel_id=producer_match.channel.id,
        detected_producer_tag=detected_producer_tag,
        nearest_candidates=nearest_candidate_list,
    )
    if persist and store is not None:
        record = store.save_possible_sold_deleted(
            PossibleSoldOrDeletedBeat(
                detected_producer_tag=clean_phrase(detected_producer_tag),
                matched_producer_channel_id=producer_match.channel.id,
                query_audio_id=query_audio_id,
                nearest_candidates=nearest_candidate_list,
                evidence={
                    "status": result.status,
                    "items": result.evidence,
                    "producer_tag_detected": detected_producer_tag,
                    "producer_channel_matched": producer_match.channel.channel_url,
                    "indexed_video_count": len(indexed_videos),
                    "matching_visible_upload_found": False,
                    "note": "This is a possible status only; the beat may be sold, deleted, unlisted, private, renamed, not indexed, hosted elsewhere, or a producer-tag false positive.",
                },
                confidence=result.confidence,
                possible_reasons=reasons,
            )
        )
        result.record_id = record.id
    return result


def _possible_reasons(*, fully_backfilled: bool) -> list[str]:
    reasons = [
        "sold_and_deleted",
        "unlisted",
        "private",
        "renamed",
        "hosted_on_beatstars",
        "hosted_on_traktrain",
    ]
    if not fully_backfilled:
        reasons.append("not_yet_indexed")
    reasons.append("producer_tag_false_positive")
    return reasons


def _is_channel_fully_backfilled(store: ProducerDiscoveryStore | None, channel_id: str) -> bool:
    if store is None:
        return False
    checkpoint = store.get_checkpoint(channel_id)
    return bool(checkpoint and checkpoint.completed)


def _find_matching_video(
    query_values: Iterable[str],
    videos: Iterable[ProducerBeatVideo],
    nearest_candidates: Iterable[dict[str, Any]],
) -> tuple[ProducerBeatVideo | None, float]:
    query_phrases = [clean_phrase(value) for value in query_values if clean_phrase(value)]
    nearest_titles = [
        clean_phrase(str(candidate.get("title") or candidate.get("raw_title") or ""))
        for candidate in nearest_candidates
        if isinstance(candidate, dict) and float(candidate.get("score") or 0.0) >= 0.68
    ]
    video_by_id = {video.video_id: video for video in videos}
    for candidate in nearest_candidates:
        if not isinstance(candidate, dict):
            continue
        candidate_video_id = str(candidate.get("video_id") or "")
        candidate_score = float(candidate.get("score") or 0.0)
        if candidate_video_id in video_by_id and candidate_score >= 0.68:
            return video_by_id[candidate_video_id], candidate_score

    best_video: ProducerBeatVideo | None = None
    best_score = 0.0
    for video in videos:
        searchable_values = [
            video.title,
            *video.normalized_search_phrases,
            *video.artist_refs,
            *video.artist_combo_refs,
            *video.type_beat_phrases,
            *video.hashtags,
        ]
        score = _best_phrase_score([*query_phrases, *nearest_titles], searchable_values)
        if score > best_score:
            best_video = video
            best_score = score
    if best_video is not None and best_score >= 0.68:
        return best_video, best_score
    return None, 0.0


def _best_phrase_score(query_values: Iterable[str], video_values: Iterable[str]) -> float:
    best_score = 0.0
    normalized_video_values = [clean_phrase(value) for value in video_values if clean_phrase(value)]
    for query_value in query_values:
        query = clean_phrase(query_value)
        if not query:
            continue
        for video_value in normalized_video_values:
            best_score = max(best_score, _phrase_similarity(query, video_value))
    return best_score


def _phrase_similarity(query: str, candidate: str) -> float:
    if query == candidate:
        return 1.0
    if query in candidate or candidate in query:
        return 0.9
    return _title_overlap(query, candidate)


def _title_overlap(query: str, candidate: str) -> float:
    query_tokens = set(query.split())
    candidate_tokens = set(candidate.split())
    if not query_tokens or not candidate_tokens:
        return 0.0
    return len(query_tokens & candidate_tokens) / max(len(query_tokens), 1)

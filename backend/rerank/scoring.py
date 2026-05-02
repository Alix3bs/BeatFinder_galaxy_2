from __future__ import annotations

from collections.abc import Iterable

from backend.core.types import BeatRecord, SearchResult

RERANK_WEIGHTS = {
    "audio_embedding_score": 0.28,
    "metadata_embedding_score": 0.12,
    "signature_score": 0.26,
    "title_phrase_overlap": 0.06,
    "hashtag_overlap": 0.05,
    "producer_overlap": 0.06,
    "artist_overlap": 0.06,
    "artist_combo_overlap": 0.04,
    "producer_combo_overlap": 0.03,
    "region_style_overlap": 0.03,
    "bpm_closeness": 0.01,
}


def build_metadata_breakdown(query_metadata: dict[str, object], beat: BeatRecord) -> dict[str, float]:
    query_phrases = as_string_set(query_metadata.get("normalized_query_phrases") or query_metadata.get("normalized_search_phrases"))
    query_hashtags = as_string_set(query_metadata.get("hashtags"))
    query_producers = as_string_set([*(query_metadata.get("producer_aliases") or []), query_metadata.get("producer_name") or ""])
    query_artists = as_string_set(query_metadata.get("artist_refs"))
    query_artist_combos = as_string_set(query_metadata.get("artist_combo_refs"))
    query_producer_combos = as_string_set(query_metadata.get("producer_combo_refs"))
    query_regions = as_string_set([*(query_metadata.get("region_tags") or []), *(query_metadata.get("genre_tags") or [])])

    title_search_space = as_string_set([beat.raw_title, beat.canonical_title or "", *beat.type_beat_phrases, *beat.normalized_search_phrases])
    beat_hashtags = as_string_set(beat.hashtags)
    beat_producers = as_string_set([beat.producer_name or "", *beat.producer_aliases])
    beat_regions = as_string_set([*beat.region_tags, *beat.genre_tags])

    breakdown = {
        "title_phrase_overlap": overlap_score(query_phrases, title_search_space),
        "hashtag_overlap": overlap_score(query_hashtags, beat_hashtags),
        "producer_overlap": overlap_score(query_producers, beat_producers),
        "artist_overlap": overlap_score(query_artists, beat.artist_refs),
        "artist_combo_overlap": overlap_score(query_artist_combos, beat.artist_combo_refs),
        "producer_combo_overlap": overlap_score(query_producer_combos, beat.producer_combo_refs),
        "region_style_overlap": overlap_score(query_regions, beat_regions),
    }
    breakdown["metadata_score"] = round(
        (
            breakdown["title_phrase_overlap"] * 0.24
            + breakdown["hashtag_overlap"] * 0.12
            + breakdown["producer_overlap"] * 0.16
            + breakdown["artist_overlap"] * 0.16
            + breakdown["artist_combo_overlap"] * 0.12
            + breakdown["producer_combo_overlap"] * 0.08
            + breakdown["region_style_overlap"] * 0.12
        ),
        6,
    )
    return breakdown


def fuse_scores(
    beat: BeatRecord,
    *,
    audio_embedding_score: float | None,
    metadata_embedding_score: float | None,
    signature_score: float | None,
    metadata_breakdown: dict[str, float],
    query_bpm: float | None,
    has_audio_query: bool,
    has_metadata_query: bool,
) -> tuple[float, dict[str, float]]:
    bpm_closeness = bpm_score(query_bpm, beat.bpm)
    breakdown = {
        "audio_embedding_score": clamp01(audio_embedding_score or 0.0),
        "metadata_embedding_score": clamp01(metadata_embedding_score or 0.0),
        "signature_score": clamp01(signature_score or 0.0),
        "title_phrase_overlap": clamp01(metadata_breakdown.get("title_phrase_overlap", 0.0)),
        "hashtag_overlap": clamp01(metadata_breakdown.get("hashtag_overlap", 0.0)),
        "producer_overlap": clamp01(metadata_breakdown.get("producer_overlap", 0.0)),
        "artist_overlap": clamp01(metadata_breakdown.get("artist_overlap", 0.0)),
        "artist_combo_overlap": clamp01(metadata_breakdown.get("artist_combo_overlap", 0.0)),
        "producer_combo_overlap": clamp01(metadata_breakdown.get("producer_combo_overlap", 0.0)),
        "region_style_overlap": clamp01(metadata_breakdown.get("region_style_overlap", 0.0)),
        "bpm_closeness": bpm_closeness,
        "metadata_score": clamp01(metadata_breakdown.get("metadata_score", 0.0)),
    }
    active_weights = dict(RERANK_WEIGHTS)
    if not has_audio_query:
        for name in ("audio_embedding_score", "signature_score", "bpm_closeness"):
            active_weights[name] = 0.0
    if not has_metadata_query:
        for name in (
            "metadata_embedding_score",
            "title_phrase_overlap",
            "hashtag_overlap",
            "producer_overlap",
            "artist_overlap",
            "artist_combo_overlap",
            "producer_combo_overlap",
            "region_style_overlap",
        ):
            active_weights[name] = 0.0

    denominator = sum(active_weights.values()) or 1.0
    weighted_sum = sum(breakdown[name] * weight for name, weight in active_weights.items())
    score = weighted_sum / denominator
    return clamp01(round(score, 6)), breakdown


def confidence_label(score: float, *, signature_score: float | None, audio_embedding_score: float | None) -> str:
    exact_hint = (signature_score or 0.0) >= 0.72 or (audio_embedding_score or 0.0) >= 0.97
    if score >= 0.75 and exact_hint:
        return "likely_exact_match"
    if score >= 0.56:
        return "likely_candidates"
    return "no_confident_exact_match"


def build_search_result(
    beat: BeatRecord,
    *,
    rerank_score: float,
    confidence: str,
    embedding_score: float | None,
    signature_score: float | None,
    metadata_score: float | None,
    breakdown: dict[str, float],
    explanation: str,
) -> SearchResult:
    return SearchResult(
        beat=beat,
        rerank_score=rerank_score,
        confidence_label=confidence,
        embedding_score=embedding_score,
        signature_score=signature_score,
        metadata_score=metadata_score,
        score_breakdown=breakdown,
        explanation=explanation,
    )


def overlap_score(left: Iterable[str], right: Iterable[str]) -> float:
    left_set = as_string_set(left)
    right_set = as_string_set(right)
    if not left_set or not right_set:
        return 0.0
    return round(len(left_set & right_set) / len(left_set), 6)


def bpm_score(query_bpm: float | None, beat_bpm: float | None) -> float:
    if query_bpm is None or beat_bpm is None:
        return 0.0
    delta = abs(query_bpm - beat_bpm)
    return clamp01(1.0 - min(delta, 50.0) / 50.0)


def as_string_set(value: object) -> set[str]:
    if isinstance(value, set):
        return {str(item).strip().lower() for item in value if str(item).strip()}
    if isinstance(value, list):
        return {str(item).strip().lower() for item in value if str(item).strip()}
    if isinstance(value, tuple):
        return {str(item).strip().lower() for item in value if str(item).strip()}
    if isinstance(value, str) and value.strip():
        return {value.strip().lower()}
    return set()


def clamp01(value: float) -> float:
    if value < 0:
        return 0.0
    if value > 1:
        return 1.0
    return float(value)

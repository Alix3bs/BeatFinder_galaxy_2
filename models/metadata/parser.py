from __future__ import annotations

import re
from collections.abc import Iterable

from .normalize import (
    build_combo_phrase,
    clean_phrase,
    dedupe_preserve_order,
    detect_genre_terms,
    detect_region_terms,
    extract_hashtags,
    is_style_phrase,
    normalize_hashtag,
    split_combo_phrase,
)

PIPE_SPLIT_RE = re.compile(r"\s*\|\s*")
TITLE_SEPARATOR_RE = re.compile(r"\s[-–—:]\s")


def parse_metadata(
    raw_text: str,
    *,
    producer_name: str | None = None,
    producer_aliases: Iterable[str] | None = None,
    hashtags: Iterable[str] | None = None,
    artist_refs: Iterable[str] | None = None,
    region_tags: Iterable[str] | None = None,
    genre_tags: Iterable[str] | None = None,
) -> dict[str, list[str] | str | None]:
    text = raw_text.strip()
    explicit_hashtags = list(hashtags or [])
    inline_hashtags = extract_hashtags(text)
    all_hashtags = dedupe_literal([*explicit_hashtags, *inline_hashtags])

    text_without_hashtags = re.sub(r"#\w+", " ", text, flags=re.IGNORECASE)

    pipe_segments = [segment.strip() for segment in PIPE_SPLIT_RE.split(text_without_hashtags) if segment.strip()]
    lead_segment = pipe_segments[0] if pipe_segments else text_without_hashtags
    trailing_segments = pipe_segments[1:]

    parsed_artists, artist_combos, type_phrases, title_hint, generic_combo_parts, generic_combo_phrase = _parse_lead_segment(lead_segment)
    parsed_producers, producer_combos = _parse_producer_segments(
        [*trailing_segments, producer_name or ""],
    )

    artist_list = dedupe_preserve_order([*(artist_refs or []), *parsed_artists])
    producer_list = dedupe_preserve_order(parsed_producers)
    producer_alias_list = dedupe_preserve_order(producer_aliases or [])

    hashtag_variants = _expand_hashtags(all_hashtags, artist_list + producer_list)
    all_region_tags = dedupe_preserve_order([*(region_tags or []), *detect_region_terms(type_phrases + hashtag_variants + artist_list)])
    all_genre_tags = dedupe_preserve_order([*(genre_tags or []), *detect_genre_terms(type_phrases + hashtag_variants)])

    normalized_search_phrases = dedupe_preserve_order(
        [
            raw_text,
            text_without_hashtags,
            title_hint or "",
            *generic_combo_parts,
            generic_combo_phrase or "",
            *artist_list,
            *artist_combos,
            *producer_list,
            *producer_combos,
            *type_phrases,
            *all_hashtags,
            *hashtag_variants,
            *all_region_tags,
            *all_genre_tags,
        ]
    )
    normalized_search_phrases = dedupe_literal([*normalized_search_phrases, *hashtag_variants])

    canonical_title = title_hint or _fallback_title(raw_text)

    return {
        "canonical_title": canonical_title,
        "producer_name": producer_list[0] if producer_list else clean_phrase(producer_name or ""),
        "producer_aliases": producer_alias_list,
        "hashtags": all_hashtags,
        "artist_refs": artist_list,
        "artist_combo_refs": artist_combos,
        "producer_combo_refs": producer_combos,
        "region_tags": all_region_tags,
        "genre_tags": all_genre_tags,
        "type_beat_phrases": type_phrases,
        "normalized_search_phrases": normalized_search_phrases,
    }


def expand_query_phrases(raw_text: str) -> dict[str, list[str] | str | None]:
    parsed = parse_metadata(raw_text)
    normalized_query = dedupe_preserve_order(
        [
            raw_text,
            *(parsed["normalized_search_phrases"] if isinstance(parsed["normalized_search_phrases"], list) else []),
        ]
    )
    parsed["normalized_query_phrases"] = normalized_query
    return parsed


def _parse_lead_segment(lead_segment: str) -> tuple[list[str], list[str], list[str], str | None, list[str], str | None]:
    normalized = clean_phrase(lead_segment)
    if not normalized:
        return [], [], [], None, [], None

    if "type beat" not in normalized:
        generic_parts = split_combo_phrase(normalized)
        generic_combo = build_combo_phrase(generic_parts) if len(generic_parts) > 1 else None
        return [], [], [], _fallback_title(lead_segment), generic_parts, generic_combo

    subject, _, remainder = normalized.partition("type beat")
    subject = clean_phrase(subject)
    subject_parts = split_combo_phrase(subject)
    title_hint = None
    if remainder:
        title_pieces = [clean_phrase(piece) for piece in TITLE_SEPARATOR_RE.split(remainder) if clean_phrase(piece)]
        title_hint = title_pieces[-1] if title_pieces else None

    if is_style_phrase(subject_parts) or not subject_parts:
        type_phrases = [clean_phrase(f"{subject} type beat")]
        return [], [], dedupe_preserve_order(type_phrases), title_hint, subject_parts, build_combo_phrase(subject_parts)

    combo_phrase = build_combo_phrase(subject_parts)
    type_phrases = [f"{combo_phrase} type beat", *(f"{part} type beat" for part in subject_parts)]
    return subject_parts, [combo_phrase], dedupe_preserve_order(type_phrases), title_hint, subject_parts, combo_phrase


def _parse_producer_segments(segments: Iterable[str]) -> tuple[list[str], list[str]]:
    producer_parts: list[str] = []
    combos: list[str] = []
    for segment in segments:
        normalized = clean_phrase(segment)
        if not normalized:
            continue
        parts = split_combo_phrase(normalized)
        if len(parts) > 1:
            combos.append(build_combo_phrase(parts))
        producer_parts.extend(parts or [normalized])
    return dedupe_preserve_order(producer_parts), dedupe_preserve_order(combos)


def _expand_hashtags(hashtags: Iterable[str], additional_terms: Iterable[str]) -> list[str]:
    variants: list[str] = []
    for hashtag in hashtags:
        variants.extend(normalize_hashtag(hashtag, additional_terms=additional_terms))
    return dedupe_literal(variants)


def _fallback_title(raw_text: str) -> str | None:
    stripped = raw_text
    for hashtag in extract_hashtags(raw_text):
        stripped = stripped.replace(hashtag, " ")
    parts = [clean_phrase(piece) for piece in PIPE_SPLIT_RE.split(stripped) if clean_phrase(piece)]
    if not parts:
        return None
    lead = parts[0]
    if "type beat" in lead:
        _, _, tail = lead.partition("type beat")
        tail_parts = [clean_phrase(piece) for piece in TITLE_SEPARATOR_RE.split(tail) if clean_phrase(piece)]
        return tail_parts[-1] if tail_parts else None
    title_parts = [clean_phrase(piece) for piece in TITLE_SEPARATOR_RE.split(lead) if clean_phrase(piece)]
    return title_parts[-1] if title_parts else lead


def dedupe_literal(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = str(value).strip().lower()
        if not literal or literal in seen:
            continue
        seen.add(literal)
        output.append(literal)
    return output

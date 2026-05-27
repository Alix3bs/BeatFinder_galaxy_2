from __future__ import annotations

import re
import string
from collections.abc import Iterable

REGION_TERMS = {
    "philly",
    "philadelphia",
    "new york",
    "ny",
    "brooklyn",
    "bronx",
    "queens",
    "jersey",
    "detroit",
    "milwaukee",
    "chicago",
    "atlanta",
    "memphis",
    "miami",
    "houston",
    "la",
    "los angeles",
}
GENRE_TERMS = {
    "drill",
    "trap",
    "pluggnb",
    "rnb",
    "soul",
    "melodic",
    "jerk",
    "boom bap",
    "rage",
    "afrobeats",
}
SEGMENTATION_MAP = {
    **{term.replace(" ", ""): term for term in REGION_TERMS},
    **{term.replace(" ", ""): term for term in GENRE_TERMS},
    "type": "type",
    "beat": "beat",
}
SEGMENTATION_TERMS = sorted(SEGMENTATION_MAP, key=len, reverse=True)

NON_WORD_RE = re.compile(r"[^a-z0-9#&x,+|/\- ]+")
MULTISPACE_RE = re.compile(r"\s+")
HASHTAG_RE = re.compile(r"#([a-z0-9_]+)")
COMBO_SPLIT_RE = re.compile(r"\s+(?:x|&)\s+|\s*,\s*")


def normalize_text(value: str) -> str:
    lowered = value.strip().lower()
    lowered = lowered.replace("_", " ")
    lowered = NON_WORD_RE.sub(" ", lowered)
    lowered = lowered.replace("typebeat", " type beat ")
    lowered = MULTISPACE_RE.sub(" ", lowered)
    return lowered.strip()


def clean_phrase(value: str) -> str:
    normalized = normalize_text(value)
    return normalized.strip(string.punctuation + " ").strip()


def dedupe_preserve_order(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        cleaned = clean_phrase(value)
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        output.append(cleaned)
    return output


def normalize_hashtag(tag: str, additional_terms: Iterable[str] | None = None) -> list[str]:
    compact = re.sub(r"[^a-z0-9]", "", tag.strip().lower().replace("#", ""))
    if not compact:
        return []

    variants = [f"#{compact}", compact]
    if "typebeat" in compact:
        variants.append(clean_phrase(compact.replace("typebeat", " type beat ")))
    segmented = segment_compound(compact, additional_terms=additional_terms)
    if segmented:
        variants.append(segmented)
    if segmented.endswith("type beat"):
        variants.append(segmented.replace(" type beat", ""))
    return dedupe_literals(variants)


def segment_compound(value: str, additional_terms: Iterable[str] | None = None) -> str:
    compact = clean_phrase(value).replace(" ", "")
    if not compact:
        return ""

    term_map = dict(SEGMENTATION_MAP)
    if additional_terms:
        for term in additional_terms:
            cleaned = clean_phrase(term)
            if cleaned:
                term_map[cleaned.replace(" ", "")] = cleaned
    terms = sorted(term_map, key=len, reverse=True)

    output: list[str] = []
    cursor = 0
    while cursor < len(compact):
        matched = None
        for term in terms:
            if compact.startswith(term, cursor):
                matched = term
                break
        if matched is None:
            output.append(compact[cursor])
            cursor += 1
            continue
        output.append(term_map.get(matched, matched))
        cursor += len(matched)

    expanded = " ".join(output).replace("type beat", "type beat")
    expanded = MULTISPACE_RE.sub(" ", expanded).strip()
    return clean_phrase(expanded)


def split_combo_phrase(value: str) -> list[str]:
    normalized = clean_phrase(value)
    if not normalized:
        return []
    segments = COMBO_SPLIT_RE.split(normalized)
    return dedupe_preserve_order(segments)


def build_combo_phrase(parts: Iterable[str]) -> str:
    cleaned = [clean_phrase(part) for part in parts if clean_phrase(part)]
    return " x ".join(cleaned)


def is_style_phrase(parts: Iterable[str]) -> bool:
    cleaned_parts = [clean_phrase(part) for part in parts if clean_phrase(part)]
    if not cleaned_parts:
        return False
    known_terms = REGION_TERMS | GENRE_TERMS
    return all(part in known_terms for part in cleaned_parts)


def extract_hashtags(text: str) -> list[str]:
    return dedupe_literals(f"#{match.group(1)}" for match in HASHTAG_RE.finditer(text.lower()))


def detect_region_terms(values: Iterable[str]) -> list[str]:
    hits: list[str] = []
    for value in values:
        normalized = clean_phrase(value)
        for term in REGION_TERMS:
            if term in normalized:
                hits.append(term)
    return dedupe_preserve_order(hits)


def detect_genre_terms(values: Iterable[str]) -> list[str]:
    hits: list[str] = []
    for value in values:
        normalized = clean_phrase(value)
        for term in GENRE_TERMS:
            if term in normalized:
                hits.append(term)
    return dedupe_preserve_order(hits)


def dedupe_literals(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = str(value).strip().lower()
        if not literal or literal in seen:
            continue
        seen.add(literal)
        output.append(literal)
    return output

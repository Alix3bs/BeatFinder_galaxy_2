from __future__ import annotations

from collections.abc import Iterable

from backend.discovery.producer_channels import DiscoverySeed
from models.metadata.normalize import clean_phrase, dedupe_preserve_order, normalize_hashtag, split_combo_phrase


def expand_discovery_seeds(
    *,
    hashtags: Iterable[str] = (),
    phrases: Iterable[str] = (),
    source: str,
    priority: int = 50,
) -> list[DiscoverySeed]:
    seed_values: list[str] = []
    for hashtag in hashtags:
        variants = normalize_hashtag(hashtag)
        spaced_variants = [variant for variant in variants if " type beat" in variant and " " in variant]
        spaced_variant = max(spaced_variants, key=lambda variant: len(variant.split()), default="")
        seed_values.append(_to_producer_search(spaced_variant or hashtag))

    for phrase in phrases:
        seed_values.append(_to_producer_search(phrase))

    return [
        DiscoverySeed(seed_type="youtube_search", seed_value=value, source=source, priority=priority)
        for value in dedupe_preserve_order(seed_values)
        if value
    ]


def _to_producer_search(value: str) -> str:
    normalized = clean_phrase(value.replace("#", " "))
    if not normalized:
        return ""

    if normalized.endswith("type beat"):
        subject = clean_phrase(normalized[: -len("type beat")])
        parts = split_combo_phrase(subject)
        if len(parts) > 1:
            normalized = f"{' '.join(parts)} type beat"
        else:
            normalized = f"{subject} type beat" if subject else "type beat"
    else:
        parts = split_combo_phrase(normalized)
        if len(parts) > 1:
            normalized = " ".join(parts)

    if normalized.endswith("producers"):
        return normalized
    return clean_phrase(f"{normalized} producers")

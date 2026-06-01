from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass

from backend.discovery.producer_channels import ProducerChannel
from models.metadata.normalize import clean_phrase

COMMON_TAG_TOKENS = {
    "a",
    "an",
    "and",
    "beat",
    "beats",
    "by",
    "instrumental",
    "music",
    "official",
    "on",
    "prod",
    "produced",
    "producer",
    "tag",
    "the",
    "track",
    "type",
}
JOINER_TOKENS = {"by"}
COMMON_TAG_COMPACTS = {
    "beatsby",
    "beattag",
    "producedby",
    "producer",
    "producertag",
    "prodby",
    "prodtag",
    "thetrack",
}


@dataclass(slots=True)
class ProducerTagMatch:
    channel: ProducerChannel
    confidence: float
    match_type: str
    detected_producer_tag: str
    normalized_tag: str
    matched_alias: str
    evidence: list[str]


def match_producer_tag(
    detected_producer_tag: str,
    channels: Iterable[ProducerChannel],
    *,
    min_confidence: float = 0.7,
) -> ProducerTagMatch | None:
    tag_forms = _build_match_forms(detected_producer_tag)
    if not _has_meaningful_signal(tag_forms):
        return None

    best_match: ProducerTagMatch | None = None
    for channel in channels:
        for alias in _channel_aliases(channel):
            alias_forms = _build_match_forms(alias)
            score, match_type, evidence = _score_forms(tag_forms, alias_forms)
            if score < min_confidence:
                continue
            candidate = ProducerTagMatch(
                channel=channel,
                confidence=score,
                match_type=match_type,
                detected_producer_tag=detected_producer_tag,
                normalized_tag=tag_forms.phrase,
                matched_alias=alias,
                evidence=[
                    f"detected producer tag normalized to '{tag_forms.phrase}'",
                    f"matched alias '{alias_forms.phrase}' from channel '{channel.channel_id}'",
                    *evidence,
                ],
            )
            if best_match is None or candidate.confidence > best_match.confidence:
                best_match = candidate
    return best_match


@dataclass(slots=True)
class _MatchForms:
    phrase: str
    compact: str
    compact_without_joiners: str
    tokens: list[str]
    meaningful_tokens: list[str]


def _channel_aliases(channel: ProducerChannel) -> list[str]:
    aliases = [
        channel.channel_id,
        channel.producer_name,
        *channel.aliases,
    ]
    if channel.channel_url:
        _, _, tail = channel.channel_url.rstrip("/").rpartition("/")
        if tail:
            aliases.append(tail.strip("@"))

    seen: set[str] = set()
    output: list[str] = []
    for alias in aliases:
        normalized = str(alias).strip()
        key = normalized.lower()
        if not normalized or key in seen:
            continue
        seen.add(key)
        output.append(normalized)
    return output


def _build_match_forms(value: str) -> _MatchForms:
    phrase = clean_phrase(value.replace(".", " ").replace("_", " "))
    tokens = phrase.split()
    meaningful_tokens = [token for token in tokens if token not in COMMON_TAG_TOKENS]
    compact = _compact(phrase)
    compact_without_joiners = _compact(" ".join(token for token in tokens if token not in JOINER_TOKENS))
    return _MatchForms(
        phrase=phrase,
        compact=compact,
        compact_without_joiners=compact_without_joiners,
        tokens=tokens,
        meaningful_tokens=meaningful_tokens,
    )


def _score_forms(tag: _MatchForms, alias: _MatchForms) -> tuple[float, str, list[str]]:
    if tag.phrase and tag.phrase == alias.phrase:
        return 0.98, "exact_alias", ["exact normalized alias match"]
    if tag.compact and tag.compact == alias.compact:
        return 0.94, "normalized_alias", ["compact normalized alias match"]
    if tag.compact_without_joiners and tag.compact_without_joiners == alias.compact_without_joiners:
        return 0.9, "loose_normalized", ["joiner-insensitive compact alias match"]

    tag_tokens = set(tag.meaningful_tokens)
    alias_tokens = set(alias.meaningful_tokens)
    if not tag_tokens or not alias_tokens:
        return 0.0, "no_match", []
    overlap = tag_tokens & alias_tokens
    if not overlap:
        return 0.0, "no_match", []
    token_score = len(overlap) / max(len(tag_tokens | alias_tokens), 1)
    if token_score >= 0.75 and len(overlap) >= 2:
        return 0.78, "token_overlap", [f"meaningful token overlap: {', '.join(sorted(overlap))}"]
    return 0.0, "no_match", []


def _has_meaningful_signal(forms: _MatchForms) -> bool:
    if not forms.compact or len(forms.compact) < 4:
        return False
    if forms.compact in COMMON_TAG_COMPACTS:
        return False
    if forms.meaningful_tokens:
        return True
    return False


def _compact(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())

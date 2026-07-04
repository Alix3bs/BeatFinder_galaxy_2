from __future__ import annotations

import json
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable

from models.metadata.normalize import clean_phrase, dedupe_preserve_order

TAXONOMY_PATH = Path(__file__).resolve().parents[2] / "data" / "taxonomy" / "regions.json"

# Inferred (non-explicit) signals can never push a label past this ceiling:
# sound alone is similarity evidence, not proof of origin.
INFERRED_CONFIDENCE_CEILING = 0.6


@dataclass(slots=True)
class RegionalStyleMatch:
    label: str
    display: str
    kind: str  # "region" | "scene" | "style"
    source: str  # "explicit_metadata" | "inferred_style_similarity"
    confidence: float
    evidence: list[str] = field(default_factory=list)
    score_components: dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "label": self.label,
            "display": self.display,
            "kind": self.kind,
            "source": self.source,
            "confidence": self.confidence,
            "evidence": self.evidence,
            "score_components": self.score_components,
        }


@dataclass(slots=True)
class RegionalStyleClassification:
    explicit_matches: list[RegionalStyleMatch] = field(default_factory=list)
    inferred_matches: list[RegionalStyleMatch] = field(default_factory=list)
    summary: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "explicit_matches": [match.to_dict() for match in self.explicit_matches],
            "inferred_matches": [match.to_dict() for match in self.inferred_matches],
            "summary": self.summary,
        }


@lru_cache(maxsize=1)
def load_taxonomy() -> dict[str, Any]:
    return json.loads(TAXONOMY_PATH.read_text(encoding="utf-8"))


def classify_regional_style(
    texts: Iterable[str],
    *,
    hashtags: Iterable[str] | None = None,
    producer_region_tags: Iterable[str] | None = None,
    tempo_bpm: float | None = None,
    max_labels: int = 5,
) -> RegionalStyleClassification:
    """Classify likely regional/style associations with explainable evidence.

    Explicit metadata matches (a phrase or hashtag naming the region/style)
    are separated from inferred similarity (tempo range, producer
    relationships). Inferred confidence is capped: audio characteristics
    alone never claim a city of origin, only stylistic similarity.
    """

    taxonomy = load_taxonomy()
    normalized_texts = [clean_phrase(value) for value in texts if clean_phrase(value)]
    normalized_hashtags = [clean_phrase(tag.lstrip("#")) for tag in (hashtags or []) if clean_phrase(tag.lstrip("#"))]
    joined = " ".join([*normalized_texts, *normalized_hashtags])

    explicit: dict[str, RegionalStyleMatch] = {}
    inferred: dict[str, RegionalStyleMatch] = {}

    for scene in taxonomy.get("scenes", []):
        hits = _alias_hits(joined, scene["aliases"])
        if hits:
            confidence = min(0.95, 0.6 + 0.1 * len(hits))
            explicit[scene["label"]] = RegionalStyleMatch(
                label=scene["label"],
                display=scene.get("display", scene["label"]),
                kind="scene",
                source="explicit_metadata",
                confidence=round(confidence, 3),
                evidence=[f"matched scene phrase '{hit}'" for hit in hits],
                score_components={"phrase_matches": float(len(hits))},
            )

    for region in taxonomy.get("regions", []):
        hits = _alias_hits(joined, region["aliases"])
        if hits:
            confidence = min(0.95, 0.55 + 0.1 * len(hits))
            explicit[region["label"]] = RegionalStyleMatch(
                label=region["label"],
                display=region.get("display", region["label"]),
                kind="region",
                source="explicit_metadata",
                confidence=round(confidence, 3),
                evidence=[f"matched region phrase '{hit}'" for hit in hits],
                score_components={"phrase_matches": float(len(hits))},
            )

    matched_styles: list[dict[str, Any]] = []
    for style in taxonomy.get("styles", []):
        hits = _alias_hits(joined, style["aliases"])
        if hits:
            matched_styles.append(style)
            confidence = min(0.9, 0.5 + 0.1 * len(hits))
            explicit[style["label"]] = RegionalStyleMatch(
                label=style["label"],
                display=style["label"].replace("_", " "),
                kind="style",
                source="explicit_metadata",
                confidence=round(confidence, 3),
                evidence=[f"matched style phrase '{hit}'" for hit in hits],
                score_components={"phrase_matches": float(len(hits))},
            )

    # Inference 1: explicitly-matched styles suggest associated regions.
    for style in matched_styles:
        for region_label in style.get("regions", []):
            if region_label in explicit or region_label in inferred:
                continue
            region = _region_by_label(taxonomy, region_label)
            if region is None:
                continue
            inferred[region_label] = RegionalStyleMatch(
                label=region_label,
                display=region.get("display", region_label),
                kind="region",
                source="inferred_style_similarity",
                confidence=round(min(INFERRED_CONFIDENCE_CEILING, 0.35), 3),
                evidence=[f"style '{style['label']}' is associated with {region.get('display', region_label)}"],
                score_components={"style_association": 0.35},
            )

    # Inference 2: tempo range similarity (audio evidence, similarity only).
    if tempo_bpm is not None and tempo_bpm > 0:
        for style in taxonomy.get("styles", []):
            tempo_range = style.get("tempo_bpm")
            if not tempo_range or style["label"] in explicit:
                continue
            low, high = float(tempo_range[0]), float(tempo_range[1])
            if low <= tempo_bpm <= high:
                closeness = 1.0 - abs(tempo_bpm - (low + high) / 2) / max((high - low) / 2, 1.0)
                confidence = round(min(INFERRED_CONFIDENCE_CEILING, 0.2 + 0.2 * max(closeness, 0.0)), 3)
                existing = inferred.get(style["label"])
                if existing is None or existing.confidence < confidence:
                    inferred[style["label"]] = RegionalStyleMatch(
                        label=style["label"],
                        display=style["label"].replace("_", " "),
                        kind="style",
                        source="inferred_style_similarity",
                        confidence=confidence,
                        evidence=[
                            f"tempo {tempo_bpm:.0f} BPM falls in the {style['label'].replace('_', ' ')} range "
                            f"{low:.0f}-{high:.0f} BPM"
                        ],
                        score_components={"tempo_closeness": round(max(closeness, 0.0), 3)},
                    )

    # Inference 3: producer relationship tags carry their known regions.
    for tag in producer_region_tags or []:
        label = clean_phrase(str(tag)).replace(" ", "_")
        if not label or label in explicit or label in inferred:
            continue
        region = _region_by_label(taxonomy, label)
        if region is None:
            continue
        inferred[label] = RegionalStyleMatch(
            label=label,
            display=region.get("display", label),
            kind="region",
            source="inferred_style_similarity",
            confidence=round(min(INFERRED_CONFIDENCE_CEILING, 0.45), 3),
            evidence=["matched producer channel is associated with this region"],
            score_components={"producer_relationship": 0.45},
        )

    explicit_matches = sorted(explicit.values(), key=lambda match: match.confidence, reverse=True)[:max_labels]
    inferred_matches = sorted(inferred.values(), key=lambda match: match.confidence, reverse=True)[:max_labels]

    return RegionalStyleClassification(
        explicit_matches=explicit_matches,
        inferred_matches=inferred_matches,
        summary=_build_summary(explicit_matches, inferred_matches),
    )


def _alias_hits(joined_text: str, aliases: Iterable[str]) -> list[str]:
    hits = []
    for alias in aliases:
        normalized = clean_phrase(alias)
        if normalized and _contains_token_phrase(joined_text, normalized):
            hits.append(alias)
    return dedupe_preserve_order(hits)


def _contains_token_phrase(text: str, phrase: str) -> bool:
    """Whole-token phrase match so 'la' doesn't fire inside 'atlanta'."""

    padded_text = f" {text} "
    padded_phrase = f" {phrase} "
    return padded_phrase in padded_text


def _region_by_label(taxonomy: dict[str, Any], label: str) -> dict[str, Any] | None:
    for region in taxonomy.get("regions", []):
        if region["label"] == label:
            return region
    return None


def _build_summary(
    explicit_matches: list[RegionalStyleMatch],
    inferred_matches: list[RegionalStyleMatch],
) -> str:
    regions = [match.display for match in explicit_matches if match.kind in {"region", "scene"}]
    if not regions:
        regions = [match.display for match in inferred_matches if match.kind in {"region", "scene"}]
        if regions:
            return f"Most similar to styles associated with {_join_names(regions)}"
        styles = [match.display for match in explicit_matches + inferred_matches if match.kind == "style"]
        if styles:
            return f"Most similar to {_join_names(styles)} styles"
        return "No confident regional or style association"
    return f"Most similar to styles associated with {_join_names(regions)}"


def _join_names(names: list[str]) -> str:
    unique = dedupe_preserve_order(names)[:3]
    if len(unique) == 1:
        return unique[0]
    return ", ".join(unique[:-1]) + f" and {unique[-1]}"

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from backend.discovery.producer_channels import dedupe_tags
from models.metadata.normalize import clean_phrase, dedupe_preserve_order

CITY_ALIASES = {
    "philly": ["philly", "philadelphia"],
    "detroit": ["detroit"],
    "milwaukee": ["milwaukee"],
    "dallas": ["dallas"],
    "arkansas": ["arkansas"],
    "new_york": ["new york", "nyc", "ny"],
}

SCENE_ALIASES = {
    "new_york_drill": ["new york drill", "ny drill", "nyc drill"],
}

STYLE_ALIASES = {
    "drill": ["drill"],
    "rnb": ["rnb", "r&b"],
    "trap": ["trap"],
    "pluggnb": ["pluggnb", "plug n b"],
    "jerk": ["jerk"],
    "type_beat": ["type beat"],
}


@dataclass(slots=True)
class CityStyleClassification:
    city_tags: list[str] = field(default_factory=list)
    region_tags: list[str] = field(default_factory=list)
    style_tags: list[str] = field(default_factory=list)
    confidence: float = 0.0
    evidence: list[str] = field(default_factory=list)


def classify_city_style(values: Iterable[str]) -> CityStyleClassification:
    normalized_values = [clean_phrase(value) for value in values if clean_phrase(value)]
    joined = " ".join(normalized_values)
    city_tags: list[str] = []
    region_tags: list[str] = []
    style_tags: list[str] = []
    evidence: list[str] = []

    for scene_tag, aliases in SCENE_ALIASES.items():
        for alias in aliases:
            if alias in joined:
                region_tags.append(scene_tag)
                evidence.append(f"matched scene phrase '{alias}'")
                break

    for city_tag, aliases in CITY_ALIASES.items():
        for alias in aliases:
            if alias in joined:
                city_tags.append(city_tag)
                region_tags.append(city_tag)
                evidence.append(f"matched city phrase '{alias}'")
                break

    for style_tag, aliases in STYLE_ALIASES.items():
        for alias in aliases:
            if alias in joined:
                style_tags.append(style_tag)
                evidence.append(f"matched style phrase '{alias}'")
                break

    signal_count = len(set(city_tags + region_tags + style_tags))
    confidence = min(0.95, 0.35 + signal_count * 0.15) if signal_count else 0.0
    return CityStyleClassification(
        city_tags=dedupe_tags(city_tags),
        region_tags=dedupe_tags(region_tags),
        style_tags=dedupe_tags(style_tags),
        confidence=round(confidence, 3),
        evidence=dedupe_preserve_order(evidence),
    )

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

VECTOR_DIMENSION = 384
AUDIO_EMBEDDING_MODEL = "beatfinder-local-audio-summary-384-v1"
METADATA_EMBEDDING_MODEL = "beatfinder-local-metadata-hash-384-v1"
SIGNATURE_TYPE = "beatfinder-perceptual-signature-v1"
SIGNATURE_VERSION = "v1"


def utc_now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


def new_id() -> str:
    return str(uuid4())


@dataclass(slots=True)
class AudioFeatures:
    duration_seconds: float
    sample_rate: int
    tempo_bpm: float | None
    rms_energy: float
    zero_crossing_rate: float
    spectral_centroid: float
    spectral_bandwidth: float
    silence_ratio: float
    peak_amplitude: float
    chroma: list[float]
    band_energies: list[float]
    onset_pattern: list[float]
    envelope_pattern: list[float]
    spectral_shape: list[float]
    spectral_flux_pattern: list[float]
    summary_vector: list[float]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class BeatRecord:
    raw_title: str
    canonical_title: str | None
    producer_name: str | None
    source_url: str | None
    source_platform: str | None
    cover_art_url: str | None
    bpm: float | None
    musical_key: str | None
    duration_seconds: float | None
    genre_tags: list[str] = field(default_factory=list)
    region_tags: list[str] = field(default_factory=list)
    hashtags: list[str] = field(default_factory=list)
    artist_refs: list[str] = field(default_factory=list)
    artist_combo_refs: list[str] = field(default_factory=list)
    producer_combo_refs: list[str] = field(default_factory=list)
    type_beat_phrases: list[str] = field(default_factory=list)
    normalized_search_phrases: list[str] = field(default_factory=list)
    producer_aliases: list[str] = field(default_factory=list)
    audio_storage_path: str | None = None
    audio_features: dict[str, Any] = field(default_factory=dict)
    created_by: str | None = None
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)
    updated_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class BeatEmbeddingRecord:
    beat_id: str
    model_name: str
    embedding: list[float]
    embedding_version: str
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class BeatSignatureRecord:
    beat_id: str
    signature_type: str
    signature_payload: dict[str, Any]
    signature_version: str
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class QueryRecord:
    query_type: str
    raw_text: str | None
    audio_storage_path: str | None
    created_by: str | None = None
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class QueryResultRecord:
    query_id: str
    beat_id: str
    embedding_score: float | None
    signature_score: float | None
    metadata_score: float | None
    rerank_score: float
    score_breakdown: dict[str, Any]
    rank: int
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class FeedbackEvent:
    query_id: str
    beat_id: str
    event_type: str
    user_id: str | None = None
    id: str = field(default_factory=new_id)
    created_at: str = field(default_factory=utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class SearchResult:
    beat: BeatRecord
    rerank_score: float
    confidence_label: str
    embedding_score: float | None
    signature_score: float | None
    metadata_score: float | None
    score_breakdown: dict[str, Any]
    explanation: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "beat": self.beat.to_dict(),
            "rerank_score": self.rerank_score,
            "confidence_label": self.confidence_label,
            "embedding_score": self.embedding_score,
            "signature_score": self.signature_score,
            "metadata_score": self.metadata_score,
            "score_breakdown": self.score_breakdown,
            "explanation": self.explanation,
        }

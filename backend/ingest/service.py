from __future__ import annotations

from pathlib import Path
from typing import Any

from backend.core.audio_input import persist_audio_payload
from backend.core.types import (
    AUDIO_EMBEDDING_MODEL,
    METADATA_EMBEDDING_MODEL,
    SIGNATURE_TYPE,
    SIGNATURE_VERSION,
    BeatEmbeddingRecord,
    BeatRecord,
    BeatSignatureRecord,
)
from backend.storage.base import BeatStore
from models.audio.features import audio_features_to_embedding, extract_audio_features
from models.audio.signature import build_audio_signature
from models.embedding.providers import build_text_embedding_provider
from models.metadata.gemma_adapter import GemmaReasoner


class IngestService:
    def __init__(self, store: BeatStore, reasoner: GemmaReasoner | None = None) -> None:
        self.store = store
        self.reasoner = reasoner or GemmaReasoner()
        self.text_embedder = build_text_embedding_provider()

    def ingest_beat(self, payload: dict[str, Any]) -> dict[str, Any]:
        raw_title = str(payload.get("title") or payload.get("raw_title") or "").strip()
        if not raw_title:
            raise ValueError("title is required")

        stored_audio_path, processing_audio_path = persist_audio_payload(
            self.store,
            payload,
            category="beats",
            default_name="beat-input",
        )

        normalized = self.reasoner.normalize_metadata(
            f"{raw_title} | {payload.get('producer_name', '')} {' '.join(payload.get('hashtags', []))}".strip()
        )
        audio_features = extract_audio_features(processing_audio_path)
        audio_signature = build_audio_signature(audio_features)

        beat = BeatRecord(
            raw_title=raw_title,
            canonical_title=as_optional_string(normalized.get("canonical_title")),
            producer_name=as_optional_string(payload.get("producer_name") or normalized.get("producer_name")),
            source_url=as_optional_string(payload.get("source_url")),
            source_platform=as_optional_string(payload.get("source_platform")),
            cover_art_url=as_optional_string(payload.get("cover_art_url")),
            bpm=payload.get("bpm") or audio_features.tempo_bpm,
            musical_key=as_optional_string(payload.get("musical_key")),
            duration_seconds=audio_features.duration_seconds,
            genre_tags=as_string_list(payload.get("genre_tags")) or as_string_list(normalized.get("genre_tags")),
            region_tags=as_string_list(payload.get("region_tags")) or as_string_list(normalized.get("region_tags")),
            hashtags=as_string_list(payload.get("hashtags")) or as_string_list(normalized.get("hashtags")),
            artist_refs=as_string_list(payload.get("artist_refs")) or as_string_list(normalized.get("artist_refs")),
            artist_combo_refs=as_string_list(normalized.get("artist_combo_refs")),
            producer_combo_refs=as_string_list(normalized.get("producer_combo_refs")),
            type_beat_phrases=as_string_list(normalized.get("type_beat_phrases")),
            normalized_search_phrases=as_string_list(normalized.get("normalized_search_phrases")),
            producer_aliases=as_string_list(payload.get("producer_aliases")) or as_string_list(normalized.get("producer_aliases")),
            audio_storage_path=stored_audio_path,
            audio_features=audio_features.to_dict(),
            created_by=as_optional_string(payload.get("created_by")),
        )

        metadata_text = build_metadata_embedding_text(beat)
        embeddings = [
            BeatEmbeddingRecord(
                beat_id=beat.id,
                model_name=AUDIO_EMBEDDING_MODEL,
                embedding=audio_features_to_embedding(audio_features),
                embedding_version="v1",
            ),
            BeatEmbeddingRecord(
                beat_id=beat.id,
                model_name=self.text_embedder.model_name if hasattr(self.text_embedder, "model_name") else METADATA_EMBEDDING_MODEL,
                embedding=self.text_embedder.embed(metadata_text),
                embedding_version="v1",
            ),
        ]
        signatures = [
            BeatSignatureRecord(
                beat_id=beat.id,
                signature_type=SIGNATURE_TYPE,
                signature_payload=audio_signature,
                signature_version=SIGNATURE_VERSION,
            )
        ]
        self.store.save_beat(beat, embeddings, signatures)
        return {
            "beat_id": beat.id,
            "status": "ingested",
            "audio_storage_path": beat.audio_storage_path,
            "embedding_models": [record.model_name for record in embeddings],
            "signature_type": SIGNATURE_TYPE,
        }


def build_metadata_embedding_text(beat: BeatRecord) -> str:
    fields = [
        beat.raw_title,
        beat.canonical_title or "",
        beat.producer_name or "",
        *beat.hashtags,
        *beat.artist_refs,
        *beat.artist_combo_refs,
        *beat.producer_combo_refs,
        *beat.type_beat_phrases,
        *beat.region_tags,
        *beat.genre_tags,
        *beat.normalized_search_phrases,
    ]
    return " | ".join(field for field in fields if field).strip()


def as_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item).strip().lower() for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip().lower()]
    return []


def as_optional_string(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None

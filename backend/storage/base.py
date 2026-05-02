from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol

from backend.core.types import (
    BeatEmbeddingRecord,
    BeatRecord,
    BeatSignatureRecord,
    FeedbackEvent,
    QueryRecord,
    QueryResultRecord,
)


@dataclass(slots=True)
class CandidateMatch:
    beat_id: str
    score: float
    model_name: str | None = None


class BeatStore(Protocol):
    root: Path

    def reset(self) -> None:
        raise NotImplementedError

    def store_audio_file(self, source_path: str | Path, *, category: str) -> str:
        raise NotImplementedError

    def store_audio_bytes(self, data: bytes, *, category: str, file_name: str) -> str:
        raise NotImplementedError

    def resolve_storage_path(self, relative_path: str | Path) -> Path:
        raise NotImplementedError

    def save_beat(
        self,
        beat: BeatRecord,
        embeddings: list[BeatEmbeddingRecord],
        signatures: list[BeatSignatureRecord],
    ) -> BeatRecord:
        raise NotImplementedError

    def list_beats(self) -> list[dict[str, Any]]:
        raise NotImplementedError

    def get_joined_beats(self) -> list[dict[str, Any]]:
        raise NotImplementedError

    def get_joined_beats_by_ids(self, beat_ids: list[str]) -> list[dict[str, Any]]:
        raise NotImplementedError

    def search_embedding_candidates(
        self,
        query_embedding: list[float],
        *,
        model_name: str,
        limit: int,
    ) -> list[CandidateMatch]:
        raise NotImplementedError

    def search_metadata_candidates(self, query_text: str, *, limit: int) -> list[CandidateMatch]:
        raise NotImplementedError

    def save_query(self, query: QueryRecord, results: list[QueryResultRecord]) -> None:
        raise NotImplementedError

    def save_feedback(self, event: FeedbackEvent) -> FeedbackEvent:
        raise NotImplementedError

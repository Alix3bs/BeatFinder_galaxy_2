from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

from backend.storage.base import CandidateMatch
from backend.core.types import (
    BeatEmbeddingRecord,
    BeatRecord,
    BeatSignatureRecord,
    FeedbackEvent,
    QueryRecord,
    QueryResultRecord,
    new_id,
)
from models.embedding.providers import cosine_similarity
from models.metadata.normalize import clean_phrase


class LocalStateStore:
    def __init__(self, root: str | Path | None = None) -> None:
        base = Path(root or os.getenv("BEATFINDER_STATE_DIR", ".beatfinder_state"))
        self.root = base
        self.db_dir = base / "db"
        self.storage_dir = base / "storage"
        self.db_dir.mkdir(parents=True, exist_ok=True)
        self.storage_dir.mkdir(parents=True, exist_ok=True)

    def reset(self) -> None:
        if self.root.exists():
            shutil.rmtree(self.root)
        self.db_dir.mkdir(parents=True, exist_ok=True)
        self.storage_dir.mkdir(parents=True, exist_ok=True)

    def store_audio_file(self, source_path: str | Path, *, category: str) -> str:
        source = Path(source_path)
        if not source.exists():
            raise FileNotFoundError(f"Audio file does not exist: {source}")
        destination = self.storage_dir / category / f"{new_id()}-{source.name}"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        return str(destination.relative_to(self.root))

    def store_audio_bytes(self, data: bytes, *, category: str, file_name: str) -> str:
        destination = self.storage_dir / category / f"{new_id()}-{file_name}"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return str(destination.relative_to(self.root))

    def resolve_storage_path(self, relative_path: str | Path) -> Path:
        relative = Path(relative_path)
        if relative.is_absolute():
            return relative
        return self.root / relative

    def save_beat(
        self,
        beat: BeatRecord,
        embeddings: list[BeatEmbeddingRecord],
        signatures: list[BeatSignatureRecord],
    ) -> BeatRecord:
        beats = self._load_table("beats")
        beat_embeddings = self._load_table("beat_embeddings")
        beat_signatures = self._load_table("beat_signatures")

        beats = [row for row in beats if row["id"] != beat.id]
        beats.append(beat.to_dict())
        beat_embeddings = [row for row in beat_embeddings if row["beat_id"] != beat.id]
        beat_embeddings.extend(record.to_dict() for record in embeddings)
        beat_signatures = [row for row in beat_signatures if row["beat_id"] != beat.id]
        beat_signatures.extend(record.to_dict() for record in signatures)

        self._save_table("beats", beats)
        self._save_table("beat_embeddings", beat_embeddings)
        self._save_table("beat_signatures", beat_signatures)
        return beat

    def list_beats(self) -> list[dict[str, Any]]:
        return self._load_table("beats")

    def list_beat_embeddings(self) -> list[dict[str, Any]]:
        return self._load_table("beat_embeddings")

    def list_beat_signatures(self) -> list[dict[str, Any]]:
        return self._load_table("beat_signatures")

    def get_joined_beats(self) -> list[dict[str, Any]]:
        beats = {row["id"]: row for row in self._load_table("beats")}
        embeddings_by_beat: dict[str, list[dict[str, Any]]] = {}
        for record in self._load_table("beat_embeddings"):
            embeddings_by_beat.setdefault(record["beat_id"], []).append(record)
        signatures_by_beat: dict[str, list[dict[str, Any]]] = {}
        for record in self._load_table("beat_signatures"):
            signatures_by_beat.setdefault(record["beat_id"], []).append(record)

        joined: list[dict[str, Any]] = []
        for beat_id, beat in beats.items():
            joined.append(
                {
                    "beat": beat,
                    "embeddings": embeddings_by_beat.get(beat_id, []),
                    "signatures": signatures_by_beat.get(beat_id, []),
                }
            )
        return joined

    def get_joined_beats_by_ids(self, beat_ids: list[str]) -> list[dict[str, Any]]:
        if not beat_ids:
            return []
        requested = set(beat_ids)
        return [row for row in self.get_joined_beats() if row["beat"]["id"] in requested]

    def search_embedding_candidates(
        self,
        query_embedding: list[float],
        *,
        model_name: str,
        limit: int,
    ) -> list[CandidateMatch]:
        candidates: list[CandidateMatch] = []
        for row in self._load_table("beat_embeddings"):
            if row.get("model_name") != model_name:
                continue
            score = cosine_similarity(query_embedding, row.get("embedding") or [])
            if score <= 0:
                continue
            candidates.append(
                CandidateMatch(
                    beat_id=str(row["beat_id"]),
                    score=score,
                    model_name=str(row.get("model_name") or model_name),
                )
            )
        candidates.sort(key=lambda item: item.score, reverse=True)
        return candidates[: max(limit, 1)]

    def search_metadata_candidates(self, query_text: str, *, limit: int) -> list[CandidateMatch]:
        normalized_query = clean_phrase(query_text)
        if not normalized_query:
            return []

        query_tokens = set(normalized_query.split())
        candidates: list[CandidateMatch] = []
        for beat in self._load_table("beats"):
            fields = [
                beat.get("raw_title") or "",
                beat.get("canonical_title") or "",
                *(beat.get("normalized_search_phrases") or []),
            ]
            joined = " ".join(str(value) for value in fields if str(value).strip())
            normalized_fields = clean_phrase(joined)
            if not normalized_fields:
                continue
            field_tokens = set(normalized_fields.split())
            if not field_tokens:
                continue
            overlap = len(query_tokens & field_tokens) / max(len(query_tokens), 1)
            if normalized_query in normalized_fields:
                overlap = max(overlap, 0.95)
            if overlap <= 0:
                continue
            candidates.append(CandidateMatch(beat_id=str(beat["id"]), score=round(overlap, 6)))
        candidates.sort(key=lambda item: item.score, reverse=True)
        return candidates[: max(limit, 1)]

    def save_query(self, query: QueryRecord, results: list[QueryResultRecord]) -> None:
        queries = self._load_table("queries")
        query_results = self._load_table("query_results")
        queries.append(query.to_dict())
        query_results.extend(result.to_dict() for result in results)
        self._save_table("queries", queries)
        self._save_table("query_results", query_results)

    def save_feedback(self, event: FeedbackEvent) -> FeedbackEvent:
        events = self._load_table("feedback_events")
        events.append(event.to_dict())
        self._save_table("feedback_events", events)
        return event

    def _table_path(self, table_name: str) -> Path:
        return self.db_dir / f"{table_name}.json"

    def _load_table(self, table_name: str) -> list[dict[str, Any]]:
        path = self._table_path(table_name)
        if not path.exists():
            return []
        return json.loads(path.read_text(encoding="utf-8"))

    def _save_table(self, table_name: str, rows: list[dict[str, Any]]) -> None:
        path = self._table_path(table_name)
        path.write_text(json.dumps(rows, indent=2, sort_keys=True), encoding="utf-8")

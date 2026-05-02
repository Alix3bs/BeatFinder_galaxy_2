from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from backend.core.types import (
    BeatEmbeddingRecord,
    BeatRecord,
    BeatSignatureRecord,
    FeedbackEvent,
    QueryRecord,
    QueryResultRecord,
)
from backend.storage.base import CandidateMatch
from backend.storage.local_store import LocalStateStore


@dataclass(slots=True)
class SupabaseRESTClient:
    base_url: str
    service_role_key: str
    beat_bucket: str = "beat-audio"
    query_bucket: str = "query-audio"

    @classmethod
    def from_env(cls) -> "SupabaseRESTClient | None":
        base_url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
        service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not base_url or not service_role_key:
            return None
        return cls(base_url=base_url, service_role_key=service_role_key)

    def list_rows(self, table: str, *, select: str = "*", filter_expression: str | None = None) -> list[dict[str, Any]]:
        path = f"/rest/v1/{table}?select={quote(select, safe='*,()')}"
        if filter_expression:
            path += f"&{filter_expression}"
        return self.request_json("GET", path)

    def rpc(self, name: str, payload: dict[str, Any]) -> list[dict[str, Any]]:
        body = json.dumps(payload).encode("utf-8")
        return self.request_json("POST", f"/rest/v1/rpc/{name}", body=body)

    def upsert_rows(self, table: str, rows: list[dict[str, Any]]) -> None:
        if not rows:
            return
        self.request_json(
            "POST",
            f"/rest/v1/{table}",
            body=json.dumps(rows).encode("utf-8"),
            extra_headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        )

    def upload_audio(self, *, local_root: Path, relative_path: str, bucket: str) -> None:
        absolute_path = local_root / relative_path
        if not absolute_path.exists():
            return
        object_path = relative_path.removeprefix("storage/").lstrip("/")
        path = f"/storage/v1/object/{bucket}/{quote(object_path, safe='/')}"
        self.request_json(
            "POST",
            path,
            body=absolute_path.read_bytes(),
            content_type="audio/wav",
            extra_headers={"x-upsert": "true"},
        )

    def request_json(
        self,
        method: str,
        path: str,
        *,
        body: bytes | None = None,
        content_type: str = "application/json",
        extra_headers: dict[str, str] | None = None,
    ) -> Any:
        headers = {
            "Authorization": f"Bearer {self.service_role_key}",
            "apikey": self.service_role_key,
            "Content-Type": content_type,
            **(extra_headers or {}),
        }
        request = Request(f"{self.base_url}{path}", data=body, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                payload = response.read()
        except (HTTPError, URLError) as exc:
            raise RuntimeError(f"Supabase request failed for {path}: {exc}") from exc
        if not payload:
            return []
        return json.loads(payload.decode("utf-8"))


class MirroredStateStore:
    def __init__(self, local_store: LocalStateStore, client: SupabaseRESTClient) -> None:
        self.local_store = local_store
        self.client = client
        self.root = local_store.root

    def reset(self) -> None:
        self.local_store.reset()

    def store_audio_file(self, source_path: str | Path, *, category: str) -> str:
        return self.local_store.store_audio_file(source_path, category=category)

    def store_audio_bytes(self, data: bytes, *, category: str, file_name: str) -> str:
        return self.local_store.store_audio_bytes(data, category=category, file_name=file_name)

    def resolve_storage_path(self, relative_path: str | Path) -> Path:
        return self.local_store.resolve_storage_path(relative_path)

    def save_beat(
        self,
        beat: BeatRecord,
        embeddings: list[BeatEmbeddingRecord],
        signatures: list[BeatSignatureRecord],
    ) -> BeatRecord:
        saved = self.local_store.save_beat(beat, embeddings, signatures)
        sync_beat_bundle(self.client, self.root, beat=beat, embeddings=embeddings, signatures=signatures)
        return saved

    def list_beats(self) -> list[dict[str, Any]]:
        return self.local_store.list_beats()

    def get_joined_beats(self) -> list[dict[str, Any]]:
        return self.local_store.get_joined_beats()

    def get_joined_beats_by_ids(self, beat_ids: list[str]) -> list[dict[str, Any]]:
        return self.local_store.get_joined_beats_by_ids(beat_ids)

    def search_embedding_candidates(
        self,
        query_embedding: list[float],
        *,
        model_name: str,
        limit: int,
    ) -> list[CandidateMatch]:
        return self.local_store.search_embedding_candidates(query_embedding, model_name=model_name, limit=limit)

    def search_metadata_candidates(self, query_text: str, *, limit: int) -> list[CandidateMatch]:
        return self.local_store.search_metadata_candidates(query_text, limit=limit)

    def save_query(self, query: QueryRecord, results: list[QueryResultRecord]) -> None:
        self.local_store.save_query(query, results)
        sync_query_bundle(self.client, self.root, query=query, results=results)

    def save_feedback(self, event: FeedbackEvent) -> FeedbackEvent:
        saved = self.local_store.save_feedback(event)
        sync_feedback_event(self.client, event)
        return saved


class SupabasePrimaryStore:
    def __init__(self, scratch_store: LocalStateStore, client: SupabaseRESTClient) -> None:
        self.scratch_store = scratch_store
        self.client = client
        self.root = scratch_store.root

    @classmethod
    def from_env(cls, root: str | Path | None = None) -> "SupabasePrimaryStore | None":
        client = SupabaseRESTClient.from_env()
        if client is None:
            return None
        return cls(LocalStateStore(root), client)

    def reset(self) -> None:
        self.scratch_store.reset()

    def store_audio_file(self, source_path: str | Path, *, category: str) -> str:
        return self.scratch_store.store_audio_file(source_path, category=category)

    def store_audio_bytes(self, data: bytes, *, category: str, file_name: str) -> str:
        return self.scratch_store.store_audio_bytes(data, category=category, file_name=file_name)

    def resolve_storage_path(self, relative_path: str | Path) -> Path:
        return self.scratch_store.resolve_storage_path(relative_path)

    def save_beat(
        self,
        beat: BeatRecord,
        embeddings: list[BeatEmbeddingRecord],
        signatures: list[BeatSignatureRecord],
    ) -> BeatRecord:
        sync_beat_bundle(self.client, self.root, beat=beat, embeddings=embeddings, signatures=signatures)
        return beat

    def list_beats(self) -> list[dict[str, Any]]:
        return self.client.list_rows("beats", select="id,raw_title,created_at")

    def get_joined_beats(self) -> list[dict[str, Any]]:
        beats = self.client.list_rows("beats")
        if not beats:
            return []
        beat_ids = [str(row["id"]) for row in beats]
        embeddings = self.client.list_rows("beat_embeddings", filter_expression=in_filter("beat_id", beat_ids))
        signatures = self.client.list_rows("beat_signatures", filter_expression=in_filter("beat_id", beat_ids))
        return join_remote_rows(beats=beats, embeddings=embeddings, signatures=signatures)

    def get_joined_beats_by_ids(self, beat_ids: list[str]) -> list[dict[str, Any]]:
        if not beat_ids:
            return []
        beats = self.client.list_rows("beats", filter_expression=in_filter("id", beat_ids))
        if not beats:
            return []
        canonical_ids = [str(row["id"]) for row in beats]
        embeddings = self.client.list_rows("beat_embeddings", filter_expression=in_filter("beat_id", canonical_ids))
        signatures = self.client.list_rows("beat_signatures", filter_expression=in_filter("beat_id", canonical_ids))
        return join_remote_rows(beats=beats, embeddings=embeddings, signatures=signatures)

    def search_embedding_candidates(
        self,
        query_embedding: list[float],
        *,
        model_name: str,
        limit: int,
    ) -> list[CandidateMatch]:
        rows = self.client.rpc(
            "match_beat_embeddings",
            {
                "query_embedding": query_embedding,
                "embedding_model": model_name,
                "match_count": max(limit, 1),
            },
        )
        return [
            CandidateMatch(
                beat_id=str(row["beat_id"]),
                model_name=str(row.get("model_name") or model_name),
                score=float(row.get("similarity") or 0.0),
            )
            for row in rows
            if row.get("beat_id")
        ]

    def search_metadata_candidates(self, query_text: str, *, limit: int) -> list[CandidateMatch]:
        rows = self.client.rpc(
            "search_beats_by_metadata_term",
            {
                "query_text": query_text,
                "match_count": max(limit, 1),
            },
        )
        return [
            CandidateMatch(beat_id=str(row["beat_id"]), score=float(row.get("metadata_score") or 0.0))
            for row in rows
            if row.get("beat_id")
        ]

    def save_query(self, query: QueryRecord, results: list[QueryResultRecord]) -> None:
        sync_query_bundle(self.client, self.root, query=query, results=results)

    def save_feedback(self, event: FeedbackEvent) -> FeedbackEvent:
        sync_feedback_event(self.client, event)
        return event


def sync_beat_bundle(
    client: SupabaseRESTClient,
    local_root: Path,
    *,
    beat: BeatRecord,
    embeddings: list[BeatEmbeddingRecord],
    signatures: list[BeatSignatureRecord],
) -> None:
    if beat.audio_storage_path:
        client.upload_audio(local_root=local_root, relative_path=beat.audio_storage_path, bucket=client.beat_bucket)

    beat_row = {
        "id": beat.id,
        "created_by": beat.created_by,
        "raw_title": beat.raw_title,
        "canonical_title": beat.canonical_title,
        "producer_name": beat.producer_name,
        "source_url": beat.source_url,
        "source_platform": beat.source_platform,
        "cover_art_url": beat.cover_art_url,
        "bpm": beat.bpm,
        "musical_key": beat.musical_key,
        "duration_seconds": beat.duration_seconds,
        "genre_tags": beat.genre_tags,
        "region_tags": beat.region_tags,
        "hashtags": beat.hashtags,
        "artist_refs": beat.artist_refs,
        "artist_combo_refs": beat.artist_combo_refs,
        "producer_combo_refs": beat.producer_combo_refs,
        "type_beat_phrases": beat.type_beat_phrases,
        "normalized_search_phrases": beat.normalized_search_phrases,
        "producer_aliases": beat.producer_aliases,
        "audio_storage_path": beat.audio_storage_path,
        "audio_features": beat.audio_features,
        "created_at": beat.created_at,
        "updated_at": beat.updated_at,
    }
    embedding_rows = [
        {
            "id": record.id,
            "beat_id": record.beat_id,
            "model_name": record.model_name,
            "embedding": vector_literal(record.embedding),
            "embedding_version": record.embedding_version,
            "created_at": record.created_at,
        }
        for record in embeddings
    ]
    signature_rows = [record.to_dict() for record in signatures]

    client.upsert_rows("beats", [beat_row])
    client.upsert_rows("beat_embeddings", embedding_rows)
    client.upsert_rows("beat_signatures", signature_rows)


def sync_query_bundle(
    client: SupabaseRESTClient,
    local_root: Path,
    *,
    query: QueryRecord,
    results: list[QueryResultRecord],
) -> None:
    if query.audio_storage_path:
        client.upload_audio(local_root=local_root, relative_path=query.audio_storage_path, bucket=client.query_bucket)

    query_row = query.to_dict()
    result_rows = [result.to_dict() for result in results]
    client.upsert_rows("queries", [query_row])
    client.upsert_rows("query_results", result_rows)


def sync_feedback_event(client: SupabaseRESTClient, event: FeedbackEvent) -> None:
    client.upsert_rows(
        "feedback_events",
        [
            {
                "id": event.id,
                "created_by": event.user_id,
                "query_id": event.query_id,
                "beat_id": event.beat_id,
                "event_type": event.event_type,
                "created_at": event.created_at,
            }
        ],
    )


def join_remote_rows(
    *,
    beats: list[dict[str, Any]],
    embeddings: list[dict[str, Any]],
    signatures: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    embeddings_by_beat: dict[str, list[dict[str, Any]]] = {}
    for row in embeddings:
        normalized = dict(row)
        normalized["embedding"] = parse_embedding_value(row.get("embedding"))
        embeddings_by_beat.setdefault(str(row["beat_id"]), []).append(normalized)

    signatures_by_beat: dict[str, list[dict[str, Any]]] = {}
    for row in signatures:
        signatures_by_beat.setdefault(str(row["beat_id"]), []).append(dict(row))

    output: list[dict[str, Any]] = []
    for beat_row in beats:
        normalized_beat = {
            "raw_title": beat_row.get("raw_title"),
            "canonical_title": beat_row.get("canonical_title"),
            "producer_name": beat_row.get("producer_name"),
            "source_url": beat_row.get("source_url"),
            "source_platform": beat_row.get("source_platform"),
            "cover_art_url": beat_row.get("cover_art_url"),
            "bpm": beat_row.get("bpm"),
            "musical_key": beat_row.get("musical_key"),
            "duration_seconds": beat_row.get("duration_seconds"),
            "genre_tags": beat_row.get("genre_tags") or [],
            "region_tags": beat_row.get("region_tags") or [],
            "hashtags": beat_row.get("hashtags") or [],
            "artist_refs": beat_row.get("artist_refs") or [],
            "artist_combo_refs": beat_row.get("artist_combo_refs") or [],
            "producer_combo_refs": beat_row.get("producer_combo_refs") or [],
            "type_beat_phrases": beat_row.get("type_beat_phrases") or [],
            "normalized_search_phrases": beat_row.get("normalized_search_phrases") or [],
            "producer_aliases": beat_row.get("producer_aliases") or [],
            "audio_storage_path": beat_row.get("audio_storage_path"),
            "audio_features": beat_row.get("audio_features") or {},
            "created_by": beat_row.get("created_by"),
            "id": beat_row.get("id"),
            "created_at": beat_row.get("created_at"),
            "updated_at": beat_row.get("updated_at"),
        }
        beat_id = str(beat_row["id"])
        output.append(
            {
                "beat": normalized_beat,
                "embeddings": embeddings_by_beat.get(beat_id, []),
                "signatures": signatures_by_beat.get(beat_id, []),
            }
        )
    return output


def parse_embedding_value(value: Any) -> list[float]:
    if isinstance(value, list):
        return [float(item) for item in value]
    if not isinstance(value, str):
        return []
    literal = value.strip()
    if literal.startswith("[") and literal.endswith("]"):
        literal = literal[1:-1]
    if not literal:
        return []
    return [float(item) for item in literal.split(",") if str(item).strip()]


def in_filter(column_name: str, values: list[str]) -> str:
    escaped = ",".join(quote(str(value), safe="-_") for value in values)
    return f"{column_name}=in.({escaped})"


def vector_literal(values: list[float]) -> str:
    return "[" + ",".join(f"{float(value):.8f}" for value in values) + "]"

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from backend.core.audio_input import persist_audio_payload
from backend.core.types import (
    AUDIO_EMBEDDING_MODEL,
    SIGNATURE_TYPE,
    BeatRecord,
    QueryRecord,
    QueryResultRecord,
)
from backend.discovery.producer_channels import ProducerDiscoveryStore
from backend.discovery.search_enrichment import enrich_search_discovery
from backend.rerank.scoring import build_metadata_breakdown, build_search_result, confidence_label, fuse_scores
from backend.storage.base import BeatStore
from models.audio.features import audio_features_to_embedding, extract_audio_features
from models.audio.signature import build_audio_signature, score_signature_match
from models.embedding.providers import build_text_embedding_provider, cosine_similarity
from models.metadata.gemma_adapter import GemmaReasoner


class RetrievalService:
    def __init__(
        self,
        store: BeatStore,
        reasoner: GemmaReasoner | None = None,
        discovery_store: ProducerDiscoveryStore | None = None,
    ) -> None:
        self.store = store
        self.reasoner = reasoner or GemmaReasoner()
        self.text_embedder = build_text_embedding_provider()
        self.discovery_store = discovery_store

    def search_text(self, payload: dict[str, Any]) -> dict[str, Any]:
        query_text = str(payload.get("query") or payload.get("raw_text") or "").strip()
        if not query_text:
            raise ValueError("query is required")
        query_metadata = self.reasoner.expand_query(query_text)
        query_embedding = self.text_embedder.embed(" | ".join(query_metadata.get("normalized_query_phrases", [])))
        return self._search(
            query_type="text",
            raw_text=query_text,
            audio_storage_path=None,
            query_metadata=query_metadata,
            query_metadata_embedding=query_embedding,
            query_audio_embedding=None,
            query_signature=None,
            query_bpm=None,
            top_n=int(payload.get("top_n", 5)),
            detected_producer_tag=extract_detected_producer_tag(payload),
        )

    def search_audio(self, payload: dict[str, Any]) -> dict[str, Any]:
        stored_audio_path, processing_audio_path = persist_audio_payload(
            self.store,
            payload,
            category="queries",
            default_name="query-audio",
        )
        try:
            audio_features = extract_audio_features(processing_audio_path)
        finally:
            stored_audio_path = self._apply_query_audio_retention(stored_audio_path)
        query_signature = build_audio_signature(audio_features)
        return self._search(
            query_type="audio",
            raw_text=None,
            audio_storage_path=stored_audio_path,
            query_metadata={},
            query_metadata_embedding=None,
            query_audio_embedding=audio_features_to_embedding(audio_features),
            query_signature=query_signature,
            query_bpm=audio_features.tempo_bpm,
            top_n=int(payload.get("top_n", 5)),
            detected_producer_tag=extract_detected_producer_tag(payload),
        )

    def search_hybrid(self, payload: dict[str, Any]) -> dict[str, Any]:
        audio_requested = bool(payload.get("audio_path") or payload.get("audio_base64"))
        query_text = str(payload.get("query") or payload.get("raw_text") or "").strip()
        if not audio_requested and not query_text:
            raise ValueError("audio_path, audio_base64, or query is required for hybrid search")

        query_metadata = self.reasoner.expand_query(query_text) if query_text else {}
        metadata_embedding = (
            self.text_embedder.embed(" | ".join(query_metadata.get("normalized_query_phrases", [])))
            if query_metadata
            else None
        )

        query_audio_embedding = None
        query_signature = None
        query_bpm = None
        stored_audio_path = None
        if audio_requested:
            stored_audio_path, processing_audio_path = persist_audio_payload(
                self.store,
                payload,
                category="queries",
                default_name="query-hybrid-audio",
            )
            try:
                audio_features = extract_audio_features(processing_audio_path)
            finally:
                stored_audio_path = self._apply_query_audio_retention(stored_audio_path)
            query_audio_embedding = audio_features_to_embedding(audio_features)
            query_signature = build_audio_signature(audio_features)
            query_bpm = audio_features.tempo_bpm

        return self._search(
            query_type="hybrid",
            raw_text=query_text or None,
            audio_storage_path=stored_audio_path,
            query_metadata=query_metadata,
            query_metadata_embedding=metadata_embedding,
            query_audio_embedding=query_audio_embedding,
            query_signature=query_signature,
            query_bpm=query_bpm,
            top_n=int(payload.get("top_n", 5)),
            detected_producer_tag=extract_detected_producer_tag(payload),
        )

    def record_feedback(self, payload: dict[str, Any]) -> dict[str, Any]:
        from backend.core.types import FeedbackEvent

        query_id = str(payload.get("query_id") or "").strip()
        beat_id = str(payload.get("beat_id") or "").strip()
        event_type = str(payload.get("event_type") or "").strip()
        if not query_id or not beat_id or not event_type:
            raise ValueError("query_id, beat_id, and event_type are required")
        event = FeedbackEvent(
            query_id=query_id,
            beat_id=beat_id,
            event_type=event_type,
            user_id=str(payload.get("user_id") or "").strip() or None,
        )
        self.store.save_feedback(event)
        return {"status": "recorded", "event": event.to_dict()}

    def _search(
        self,
        *,
        query_type: str,
        raw_text: str | None,
        audio_storage_path: str | None,
        query_metadata: dict[str, Any],
        query_metadata_embedding: list[float] | None,
        query_audio_embedding: list[float] | None,
        query_signature: dict[str, object] | None,
        query_bpm: float | None,
        top_n: int,
        detected_producer_tag: str | None,
    ) -> dict[str, Any]:
        joined_beats, candidate_pool_sizes = self._load_candidate_beats(
            raw_text=raw_text,
            query_audio_embedding=query_audio_embedding,
            query_metadata_embedding=query_metadata_embedding,
        )
        if not joined_beats:
            return {
                "query_type": query_type,
                "query_id": None,
                "results": [],
                "confidence": "no_confident_exact_match",
                "candidate_pool_sizes": candidate_pool_sizes,
                "discovery": enrich_search_discovery(
                    query_metadata=query_metadata,
                    detected_producer_tag=detected_producer_tag,
                    matched_candidates=[],
                    producer_discovery_store=self.discovery_store,
                    query_text=raw_text,
                ).to_dict(),
            }

        embedding_candidates: list[dict[str, Any]] = []
        metadata_candidates: list[dict[str, Any]] = []
        signature_candidates: list[dict[str, Any]] = []
        merged_by_beat: dict[str, dict[str, Any]] = {}

        for joined in joined_beats:
            beat = BeatRecord(**joined["beat"])
            embeddings = {record["model_name"]: record["embedding"] for record in joined["embeddings"]}
            signatures = {record["signature_type"]: record["signature_payload"] for record in joined["signatures"]}

            audio_embedding_score = (
                cosine_similarity(query_audio_embedding, embeddings.get(AUDIO_EMBEDDING_MODEL))
                if query_audio_embedding is not None and embeddings.get(AUDIO_EMBEDDING_MODEL) is not None
                else 0.0
            )
            metadata_model_name = next((name for name in embeddings if name != AUDIO_EMBEDDING_MODEL), None)
            metadata_embedding_score = (
                cosine_similarity(query_metadata_embedding, embeddings.get(metadata_model_name))
                if metadata_model_name and query_metadata_embedding is not None
                else 0.0
            )
            metadata_breakdown = build_metadata_breakdown(query_metadata, beat) if query_metadata else {"metadata_score": 0.0}
            signature_score = (
                score_signature_match(query_signature, signatures.get(SIGNATURE_TYPE))
                if query_signature and signatures.get(SIGNATURE_TYPE)
                else 0.0
            )

            candidate = {
                "beat": beat,
                "audio_embedding_score": audio_embedding_score,
                "metadata_embedding_score": metadata_embedding_score,
                "signature_score": signature_score,
                "metadata_breakdown": metadata_breakdown,
            }
            if audio_embedding_score > 0:
                embedding_candidates.append(candidate)
            if metadata_breakdown.get("metadata_score", 0.0) > 0 or metadata_embedding_score > 0:
                metadata_candidates.append(candidate)
            if signature_score > 0:
                signature_candidates.append(candidate)
            merged_by_beat[beat.id] = candidate

        ranked_embedding = sorted(
            embedding_candidates,
            key=lambda item: max(item["audio_embedding_score"], item["metadata_embedding_score"]),
            reverse=True,
        )[:25]
        ranked_metadata = sorted(
            metadata_candidates,
            key=lambda item: max(item["metadata_breakdown"].get("metadata_score", 0.0), item["metadata_embedding_score"]),
            reverse=True,
        )[:25]
        ranked_signature = sorted(signature_candidates, key=lambda item: item["signature_score"], reverse=True)[:25]

        merged_ids = {
            *(item["beat"].id for item in ranked_embedding),
            *(item["beat"].id for item in ranked_metadata),
            *(item["beat"].id for item in ranked_signature),
        } or set(merged_by_beat.keys())

        final_results = []
        query_record = QueryRecord(
            query_type=query_type,
            raw_text=raw_text,
            audio_storage_path=audio_storage_path,
        )
        query_result_records: list[QueryResultRecord] = []

        for beat_id in merged_ids:
            candidate = merged_by_beat[beat_id]
            rerank_score, breakdown = fuse_scores(
                candidate["beat"],
                audio_embedding_score=candidate["audio_embedding_score"],
                metadata_embedding_score=candidate["metadata_embedding_score"],
                signature_score=candidate["signature_score"],
                metadata_breakdown=candidate["metadata_breakdown"],
                query_bpm=query_bpm,
                has_audio_query=query_audio_embedding is not None or query_signature is not None,
                has_metadata_query=bool(query_metadata),
            )
            confidence = confidence_label(
                rerank_score,
                signature_score=candidate["signature_score"],
                audio_embedding_score=candidate["audio_embedding_score"],
            )
            explanation = self.reasoner.explain_candidate(breakdown, candidate["beat"].raw_title)
            final_results.append(
                build_search_result(
                    candidate["beat"],
                    rerank_score=rerank_score,
                    confidence=confidence,
                    embedding_score=max(candidate["audio_embedding_score"], candidate["metadata_embedding_score"]),
                    signature_score=candidate["signature_score"],
                    metadata_score=breakdown.get("metadata_score"),
                    breakdown=breakdown,
                    explanation=explanation,
                )
            )

        final_results.sort(key=lambda result: result.rerank_score, reverse=True)
        final_results = final_results[: max(top_n, 1)]
        for index, result in enumerate(final_results, start=1):
            query_result_records.append(
                QueryResultRecord(
                    query_id=query_record.id,
                    beat_id=result.beat.id,
                    embedding_score=result.embedding_score,
                    signature_score=result.signature_score,
                    metadata_score=result.metadata_score,
                    rerank_score=result.rerank_score,
                    score_breakdown=result.score_breakdown,
                    rank=index,
                )
            )

        self.store.save_query(query_record, query_result_records)
        overall_confidence = final_results[0].confidence_label if final_results else "no_confident_exact_match"
        result_payloads = [result.to_dict() for result in final_results]
        discovery = enrich_search_discovery(
            query_metadata=query_metadata,
            detected_producer_tag=detected_producer_tag,
            matched_candidates=result_payloads,
            producer_discovery_store=self.discovery_store,
            query_text=raw_text,
        ).to_dict()
        return {
            "query_id": query_record.id,
            "query_type": query_type,
            "confidence": overall_confidence,
            "results": result_payloads,
            "candidate_pool_sizes": {
                "embedding": candidate_pool_sizes["embedding"],
                "metadata": candidate_pool_sizes["metadata"],
                "signature": len(ranked_signature),
                "merged": candidate_pool_sizes["merged"],
            },
            "discovery": discovery,
        }

    def _apply_query_audio_retention(self, stored_audio_path: str | None) -> str | None:
        """Delete query audio after feature extraction unless retention is on.

        Uploaded query audio is only needed to compute features. By default it
        is removed immediately so user audio is not retained; set
        BEATFINDER_RETAIN_QUERY_AUDIO=1 to keep files for debugging.
        """

        if stored_audio_path is None or query_audio_retention_enabled():
            return stored_audio_path
        try:
            resolved = Path(self.store.resolve_storage_path(stored_audio_path))
            resolved.unlink(missing_ok=True)
        except OSError:
            pass
        return None

    def _load_candidate_beats(
        self,
        *,
        raw_text: str | None,
        query_audio_embedding: list[float] | None,
        query_metadata_embedding: list[float] | None,
    ) -> tuple[list[dict[str, Any]], dict[str, int]]:
        embedding_ids: set[str] = set()
        metadata_ids: set[str] = set()

        if query_audio_embedding is not None:
            for match in self.store.search_embedding_candidates(
                query_audio_embedding,
                model_name=AUDIO_EMBEDDING_MODEL,
                limit=25,
            ):
                embedding_ids.add(match.beat_id)

        if query_metadata_embedding is not None:
            for match in self.store.search_embedding_candidates(
                query_metadata_embedding,
                model_name=getattr(self.text_embedder, "model_name", AUDIO_EMBEDDING_MODEL),
                limit=25,
            ):
                metadata_ids.add(match.beat_id)

        if raw_text:
            for match in self.store.search_metadata_candidates(raw_text, limit=25):
                metadata_ids.add(match.beat_id)

        merged_ids = list(dict.fromkeys([*embedding_ids, *metadata_ids]))
        if merged_ids:
            joined_beats = self.store.get_joined_beats_by_ids(merged_ids)
        else:
            joined_beats = self.store.get_joined_beats()
            merged_ids = [str(row["beat"]["id"]) for row in joined_beats]

        return joined_beats, {
            "embedding": len(embedding_ids),
            "metadata": len(metadata_ids),
            "signature": 0,
            "merged": len(merged_ids),
        }


def query_audio_retention_enabled() -> bool:
    return os.getenv("BEATFINDER_RETAIN_QUERY_AUDIO", "").strip().lower() in {"1", "true", "yes"}


def extract_detected_producer_tag(payload: dict[str, Any]) -> str | None:
    for key in ("detected_producer_tag", "producer_tag", "producer_tag_text"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value
    return None

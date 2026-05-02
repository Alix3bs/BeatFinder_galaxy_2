from __future__ import annotations

import base64
from pathlib import Path
from typing import Any

from backend.storage.base import BeatStore


def persist_audio_payload(
    store: BeatStore,
    payload: dict[str, Any],
    *,
    category: str,
    default_name: str,
) -> tuple[str, str]:
    audio_path = payload.get("audio_path")
    if audio_path:
        relative_path = store.store_audio_file(audio_path, category=category)
        return relative_path, str(store.resolve_storage_path(relative_path))

    audio_base64 = payload.get("audio_base64")
    if audio_base64:
        file_name = build_audio_file_name(payload, default_name=default_name)
        relative_path = store.store_audio_bytes(
            decode_audio_base64(audio_base64),
            category=category,
            file_name=file_name,
        )
        return relative_path, str(store.resolve_storage_path(relative_path))

    raise ValueError("audio_path or audio_base64 is required")


def decode_audio_base64(value: str) -> bytes:
    text = value.strip()
    if text.startswith("data:") and "," in text:
        _, text = text.split(",", 1)
    return base64.b64decode(text)


def build_audio_file_name(payload: dict[str, Any], *, default_name: str) -> str:
    preferred_name = str(payload.get("audio_file_name") or "").strip()
    if preferred_name:
        suffix = Path(preferred_name).suffix or guess_extension(payload.get("audio_mime_type"))
        return f"{Path(preferred_name).stem}{suffix}"
    return f"{default_name}{guess_extension(payload.get('audio_mime_type'))}"


def guess_extension(mime_type: object) -> str:
    normalized = str(mime_type or "").strip().lower()
    if normalized in {"audio/wav", "audio/x-wav", "audio/wave"}:
        return ".wav"
    if normalized == "audio/mpeg":
        return ".mp3"
    if normalized in {"audio/mp4", "audio/m4a", "audio/x-m4a"}:
        return ".m4a"
    return ".wav"

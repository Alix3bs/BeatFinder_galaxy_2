from __future__ import annotations

import base64
import binascii
import os
from pathlib import Path
from typing import Any

from backend.core.upload_validation import (
    UploadValidationError,
    sanitize_audio_file_name,
    validate_audio_bytes,
)
from backend.storage.base import BeatStore


def local_audio_paths_allowed() -> bool:
    """Whether `audio_path` payloads referencing server-side files are accepted.

    Local paths are a trusted-caller convenience for fixture loading and
    development. The HTTP API strips them by default; this flag is a second
    layer of defense for deployments that must never read arbitrary paths.
    """

    return os.getenv("BEATFINDER_DISALLOW_AUDIO_PATHS", "").strip() not in {"1", "true", "yes"}


def persist_audio_payload(
    store: BeatStore,
    payload: dict[str, Any],
    *,
    category: str,
    default_name: str,
) -> tuple[str, str]:
    audio_path = payload.get("audio_path")
    if audio_path:
        if not local_audio_paths_allowed():
            raise UploadValidationError(
                "audio_path_not_allowed",
                "audio_path is not accepted here. Upload the audio file instead.",
            )
        relative_path = store.store_audio_file(audio_path, category=category)
        return relative_path, str(store.resolve_storage_path(relative_path))

    audio_base64 = payload.get("audio_base64")
    if audio_base64:
        data = decode_audio_base64(audio_base64)
        validate_audio_bytes(data)
        file_name = build_audio_file_name(payload, default_name=default_name)
        relative_path = store.store_audio_bytes(
            data,
            category=category,
            file_name=file_name,
        )
        return relative_path, str(store.resolve_storage_path(relative_path))

    raise ValueError("audio_path or audio_base64 is required")


def decode_audio_base64(value: str) -> bytes:
    text = value.strip()
    if text.startswith("data:") and "," in text:
        _, text = text.split(",", 1)
    try:
        return base64.b64decode(text, validate=False)
    except (binascii.Error, ValueError) as error:
        raise UploadValidationError(
            "invalid_audio_encoding",
            "audio_base64 is not valid base64 data.",
        ) from error


def build_audio_file_name(payload: dict[str, Any], *, default_name: str) -> str:
    preferred_name = str(payload.get("audio_file_name") or "").strip()
    mime_type = payload.get("audio_mime_type")
    if preferred_name:
        return sanitize_audio_file_name(preferred_name, mime_type)
    return sanitize_audio_file_name(f"{default_name}", mime_type)

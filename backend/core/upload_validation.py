from __future__ import annotations

import os
import re
from pathlib import Path

DEFAULT_MAX_UPLOAD_BYTES = 25 * 1024 * 1024
MAX_FILE_NAME_LENGTH = 80

ALLOWED_AUDIO_EXTENSIONS = {".wav", ".mp3", ".m4a"}
ALLOWED_AUDIO_MIME_TYPES = {
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/wave": ".wav",
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/m4a": ".m4a",
    "audio/x-m4a": ".m4a",
}

_SAFE_NAME_RE = re.compile(r"[^A-Za-z0-9._ -]+")


class UploadValidationError(ValueError):
    """A client-facing upload problem with a stable error code."""

    def __init__(self, code: str, message: str, *, http_status: int = 400) -> None:
        super().__init__(message)
        self.code = code
        self.http_status = http_status


def max_upload_bytes() -> int:
    raw = os.getenv("BEATFINDER_MAX_UPLOAD_BYTES", "").strip()
    if not raw:
        return DEFAULT_MAX_UPLOAD_BYTES
    try:
        parsed = int(raw)
    except ValueError:
        return DEFAULT_MAX_UPLOAD_BYTES
    return parsed if parsed > 0 else DEFAULT_MAX_UPLOAD_BYTES


def validate_audio_bytes(data: bytes) -> None:
    if not data:
        raise UploadValidationError("empty_audio", "The uploaded audio file is empty.")
    limit = max_upload_bytes()
    if len(data) > limit:
        raise UploadValidationError(
            "upload_too_large",
            f"The uploaded audio file exceeds the {limit} byte limit.",
            http_status=413,
        )


def sanitize_audio_file_name(raw_name: object, mime_type: object = None) -> str:
    """Return a safe file name with an allowed audio extension.

    Strips any directory components, removes unsafe characters, caps the
    length, and forces the extension to a supported audio type.
    """

    name = Path(str(raw_name or "")).name.strip()
    stem = _SAFE_NAME_RE.sub("-", Path(name).stem).strip(" .-") or "upload"
    stem = stem[:MAX_FILE_NAME_LENGTH]

    suffix = Path(name).suffix.lower()
    if suffix in ALLOWED_AUDIO_EXTENSIONS:
        return f"{stem}{suffix}"

    mime_suffix = extension_for_mime_type(mime_type)
    if mime_suffix is not None:
        return f"{stem}{mime_suffix}"

    declared_type = str(mime_type or "").strip()
    if not suffix and not declared_type:
        # No format signal at all: keep the historical WAV default used by
        # trusted local callers (fixture loaders, tests).
        return f"{stem}.wav"

    raise UploadValidationError(
        "unsupported_audio_format",
        "Unsupported audio format. Upload a .wav, .mp3, or .m4a file.",
        http_status=415,
    )


def extension_for_mime_type(mime_type: object) -> str | None:
    normalized = str(mime_type or "").split(";")[0].strip().lower()
    return ALLOWED_AUDIO_MIME_TYPES.get(normalized)

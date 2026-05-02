from __future__ import annotations

import hashlib

import numpy as np

from backend.core.types import AudioFeatures


def build_audio_signature(features: AudioFeatures) -> dict[str, object]:
    chroma = quantize(features.chroma, 16)
    bands = quantize(features.band_energies, 16)
    onset = quantize(features.onset_pattern, 16)
    envelope = quantize(features.envelope_pattern, 16)
    tempo_bucket = int(round((features.tempo_bpm or 0.0) / 2.0))
    duration_bucket = int(round(features.duration_seconds * 2.0))

    tokens = [
        *(f"ch:{index}:{value}" for index, value in enumerate(chroma)),
        *(f"band:{index}:{value}" for index, value in enumerate(bands)),
        *(f"on:{index}:{value}" for index, value in enumerate(onset)),
        *(f"env:{index}:{value}" for index, value in enumerate(envelope)),
        f"tempo:{tempo_bucket}",
        f"dur:{duration_bucket}",
    ]
    payload = {
        "hash": hashlib.sha256("|".join(tokens).encode("utf-8")).hexdigest(),
        "tokens": tokens,
        "tempo_bucket": tempo_bucket,
        "duration_bucket": duration_bucket,
        "quantized_chroma": chroma,
        "quantized_bands": bands,
        "quantized_onset": onset,
        "quantized_envelope": envelope,
    }
    return payload


def score_signature_match(query_signature: dict[str, object], candidate_signature: dict[str, object]) -> float:
    if not query_signature or not candidate_signature:
        return 0.0
    if query_signature.get("hash") == candidate_signature.get("hash"):
        return 1.0

    query_tokens = set(as_string_list(query_signature.get("tokens")))
    candidate_tokens = set(as_string_list(candidate_signature.get("tokens")))
    union = query_tokens | candidate_tokens
    token_score = len(query_tokens & candidate_tokens) / len(union) if union else 0.0

    chroma_score = _array_score(
        as_int_list(query_signature.get("quantized_chroma")),
        as_int_list(candidate_signature.get("quantized_chroma")),
    )
    band_score = _array_score(
        as_int_list(query_signature.get("quantized_bands")),
        as_int_list(candidate_signature.get("quantized_bands")),
    )
    onset_score = _array_score(
        as_int_list(query_signature.get("quantized_onset")),
        as_int_list(candidate_signature.get("quantized_onset")),
    )
    tempo_delta = abs(int(query_signature.get("tempo_bucket", 0)) - int(candidate_signature.get("tempo_bucket", 0)))
    tempo_score = max(0.0, 1.0 - min(tempo_delta, 40) / 40.0)
    return float(0.4 * token_score + 0.2 * chroma_score + 0.15 * band_score + 0.15 * onset_score + 0.1 * tempo_score)


def quantize(values: list[float], levels: int) -> list[int]:
    array = np.asarray(values, dtype=np.float32)
    if array.size == 0:
        return []
    clipped = np.clip(array, 0.0, 1.0)
    return np.rint(clipped * (levels - 1)).astype(int).tolist()


def as_string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value]


def as_int_list(value: object) -> list[int]:
    if not isinstance(value, list):
        return []
    ints: list[int] = []
    for item in value:
        try:
            ints.append(int(item))
        except (TypeError, ValueError):
            continue
    return ints


def _array_score(left: list[int], right: list[int]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    array_left = np.asarray(left, dtype=np.float32)
    array_right = np.asarray(right, dtype=np.float32)
    diff = np.abs(array_left - array_right).mean()
    return float(max(0.0, 1.0 - diff / 15.0))

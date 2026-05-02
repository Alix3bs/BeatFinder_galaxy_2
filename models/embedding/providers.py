from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from typing import Protocol
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import numpy as np

from backend.core.types import METADATA_EMBEDDING_MODEL, VECTOR_DIMENSION
from models.metadata.normalize import clean_phrase


class TextEmbeddingProvider(Protocol):
    model_name: str

    def embed(self, text: str) -> list[float]:
        raise NotImplementedError


@dataclass(slots=True)
class HashingTextEmbeddingProvider:
    model_name: str = METADATA_EMBEDDING_MODEL
    dimension: int = VECTOR_DIMENSION

    def embed(self, text: str) -> list[float]:
        vector = np.zeros(self.dimension, dtype=np.float32)
        normalized = clean_phrase(text)
        if not normalized:
            return vector.tolist()
        tokens = _tokenize(normalized)
        for token in tokens:
            digest = hashlib.sha256(token.encode("utf-8")).digest()
            index = int.from_bytes(digest[:4], "big") % self.dimension
            sign = 1.0 if digest[4] % 2 == 0 else -1.0
            vector[index] += sign
        norm = float(np.linalg.norm(vector))
        if norm > 1e-8:
            vector /= norm
        return vector.tolist()


@dataclass(slots=True)
class HuggingFaceTextEmbeddingProvider:
    model_name: str
    endpoint_url: str
    api_token: str
    dimension: int = VECTOR_DIMENSION

    def embed(self, text: str) -> list[float]:
        payload = {"inputs": text}
        request = Request(
            self.endpoint_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.api_token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=30) as response:
                body = json.loads(response.read().decode("utf-8"))
        except (HTTPError, URLError) as exc:
            raise RuntimeError(f"Hugging Face embedding request failed: {exc}") from exc

        vector = body[0] if isinstance(body, list) and body and isinstance(body[0], list) else body
        if not isinstance(vector, list):
            raise RuntimeError("Hugging Face embedding response did not contain a vector.")
        floats = [float(item) for item in vector]
        if len(floats) != self.dimension:
            raise RuntimeError(
                f"Configured dimension {self.dimension} does not match Hugging Face response dimension {len(floats)}."
            )
        return floats


def build_text_embedding_provider() -> TextEmbeddingProvider:
    endpoint_url = os.getenv("BEATFINDER_HF_TEXT_ENDPOINT")
    api_token = os.getenv("HF_API_TOKEN")
    model_name = os.getenv("BEATFINDER_HF_TEXT_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
    if endpoint_url and api_token:
        return HuggingFaceTextEmbeddingProvider(
            model_name=model_name,
            endpoint_url=endpoint_url,
            api_token=api_token,
            dimension=int(os.getenv("BEATFINDER_TEXT_EMBEDDING_DIM", VECTOR_DIMENSION)),
        )
    return HashingTextEmbeddingProvider()


def cosine_similarity(left: list[float], right: list[float]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    left_array = np.asarray(left, dtype=np.float32)
    right_array = np.asarray(right, dtype=np.float32)
    denom = float(np.linalg.norm(left_array) * np.linalg.norm(right_array))
    if denom <= 1e-8:
        return 0.0
    return float(np.dot(left_array, right_array) / denom)


def _tokenize(value: str) -> list[str]:
    tokens = value.split()
    bigrams = [" ".join(tokens[index : index + 2]) for index in range(max(len(tokens) - 1, 0))]
    trigrams = [" ".join(tokens[index : index + 3]) for index in range(max(len(tokens) - 2, 0))]
    return [*tokens, *bigrams, *trigrams]

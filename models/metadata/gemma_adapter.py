from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .parser import expand_query_phrases, parse_metadata


@dataclass(slots=True)
class GemmaReasoner:
    """
    Gemma-facing metadata layer with a deterministic local fallback.

    Preferred runtime:
    - provider: remote-http
    - model: Gemma 3 family

    Verified runtime in this environment:
    - provider: local-fallback
    - parser/expansion: deterministic heuristics
    """

    model_name: str = field(default_factory=lambda: os.getenv("BEATFINDER_GEMMA_MODEL", "gemma-3"))
    provider: str = field(default_factory=lambda: os.getenv("BEATFINDER_GEMMA_PROVIDER", "local-fallback"))
    endpoint: str | None = field(default_factory=lambda: env_or_none("BEATFINDER_GEMMA_ENDPOINT"))
    api_token: str | None = field(default_factory=lambda: env_or_none("BEATFINDER_GEMMA_API_TOKEN"))
    allow_fallback: bool = field(default_factory=lambda: env_bool("BEATFINDER_GEMMA_ALLOW_FALLBACK", True))

    def normalize_metadata(self, raw_text: str) -> dict[str, list[str] | str | None]:
        fallback = parse_metadata(raw_text)
        return self._maybe_remote(
            task="normalize_metadata",
            raw_text=raw_text,
            fallback=fallback,
        )

    def expand_query(self, raw_text: str) -> dict[str, list[str] | str | None]:
        fallback = expand_query_phrases(raw_text)
        return self._maybe_remote(
            task="expand_query",
            raw_text=raw_text,
            fallback=fallback,
        )

    def explain_candidate(self, breakdown: dict[str, float], beat_title: str) -> str:
        ordered = sorted(breakdown.items(), key=lambda item: item[1], reverse=True)
        top_reasons = [name.replace("_", " ") for name, value in ordered if value > 0][:3]
        if not top_reasons:
            return f"No confident exact match found for {beat_title}."
        joined = ", ".join(top_reasons)
        return f"{beat_title} scored highest on {joined}."

    def _maybe_remote(
        self,
        *,
        task: str,
        raw_text: str,
        fallback: dict[str, list[str] | str | None],
    ) -> dict[str, list[str] | str | None]:
        if self.provider != "remote-http" or not self.endpoint:
            return fallback

        payload = {
            "task": task,
            "model": self.model_name,
            "input": raw_text,
            "fallback": fallback,
        }
        headers = {"Content-Type": "application/json"}
        if self.api_token:
            headers["Authorization"] = f"Bearer {self.api_token}"
        request = Request(
            self.endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urlopen(request, timeout=20) as response:
                body = json.loads(response.read().decode("utf-8"))
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
            if self.allow_fallback:
                return fallback
            raise

        candidate = body.get("output") if isinstance(body, dict) else None
        if not isinstance(candidate, dict):
            return fallback
        return merge_reasoner_output(fallback, candidate)


def merge_reasoner_output(
    fallback: dict[str, list[str] | str | None],
    candidate: dict[str, Any],
) -> dict[str, list[str] | str | None]:
    merged: dict[str, list[str] | str | None] = dict(fallback)
    for key, value in candidate.items():
        if isinstance(fallback.get(key), list):
            normalized = [str(item).strip().lower() for item in value or [] if str(item).strip()]
            merged[key] = dedupe_literals([*(fallback.get(key) or []), *normalized])
        elif value is None:
            merged[key] = fallback.get(key)
        else:
            merged[key] = str(value).strip().lower() or fallback.get(key)
    return merged


def dedupe_literals(values: list[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = str(value).strip().lower()
        if not literal or literal in seen:
            continue
        seen.add(literal)
        output.append(literal)
    return output


def env_or_none(name: str) -> str | None:
    value = os.getenv(name, "").strip()
    return value or None


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() not in {"0", "false", "no", "off"}

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlsplit

from backend.discovery.producer_channels import ProducerChannel, ProducerDiscoveryStore


@dataclass(slots=True)
class ProducerSeedLoadResult:
    raw_count: int
    unique_count: int
    channels: list[ProducerChannel] = field(default_factory=list)


def load_producer_seed_file(
    seed_file: str | Path,
    *,
    store: ProducerDiscoveryStore,
    source: str = "manual_seed_file",
) -> ProducerSeedLoadResult:
    path = Path(seed_file)
    raw_urls = [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    normalized_urls = _dedupe_literals(normalize_producer_profile_url(url) for url in raw_urls)
    channels = [
        store.upsert_channel(url, discovered_from=source, confidence=1.0)
        for url in normalized_urls
    ]
    return ProducerSeedLoadResult(raw_count=len(raw_urls), unique_count=len(normalized_urls), channels=channels)


def normalize_producer_profile_url(value: str) -> str:
    raw = value.strip()
    if not raw:
        return ""

    if "://" not in raw:
        raw = f"https://{raw}"

    parsed = urlsplit(raw)
    netloc = parsed.netloc.lower()
    if netloc.startswith("www."):
        netloc = netloc[4:]
    if netloc in {"m.youtube.com", "music.youtube.com"}:
        netloc = "youtube.com"

    path = parsed.path.strip("/")
    if path.startswith("@"):
        path = f"@{path[1:].lower()}"
    elif path.lower().startswith("channel/"):
        prefix, _, channel_id = path.partition("/")
        path = f"{prefix.lower()}/{channel_id}"
    else:
        path = path.lower()

    return f"https://{netloc}/{path}" if path else f"https://{netloc}"


def _dedupe_literals(values: object) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        literal = str(value).strip()
        if not literal or literal in seen:
            continue
        seen.add(literal)
        output.append(literal)
    return output

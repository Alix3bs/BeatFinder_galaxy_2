from __future__ import annotations

from collections.abc import Iterable

from backend.discovery.producer_channels import DiscoverySeed, ProducerDiscoveryStore


class DiscoveryQueue:
    def __init__(self, store: ProducerDiscoveryStore) -> None:
        self.store = store

    def enqueue(self, seeds: Iterable[DiscoverySeed]) -> list[DiscoverySeed]:
        return [self.store.save_seed(seed) for seed in seeds]

    def next_pending(self, *, limit: int = 10) -> list[DiscoverySeed]:
        pending = self.store.list_seeds(status="pending")
        pending.sort(key=lambda seed: (seed.priority, seed.created_at))
        return pending[: max(1, limit)]

    def mark_done(self, seed_id: str) -> None:
        self.store.update_seed_status(seed_id, "done")

    def mark_failed(self, seed_id: str) -> None:
        self.store.update_seed_status(seed_id, "failed")

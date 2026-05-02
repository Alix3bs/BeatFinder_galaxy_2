from __future__ import annotations

import os
from pathlib import Path

from backend.storage.base import BeatStore
from backend.storage.local_store import LocalStateStore
from backend.storage.supabase_store import MirroredStateStore, SupabasePrimaryStore, SupabaseRESTClient

VALID_SUPABASE_MODES = {"local", "mirror", "primary"}


def build_runtime_store(root: str | Path | None = None) -> BeatStore:
    mode = os.getenv("BEATFINDER_SUPABASE_MODE", "local").strip().lower() or "local"
    if mode not in VALID_SUPABASE_MODES:
        raise ValueError(
            f"Unsupported BEATFINDER_SUPABASE_MODE={mode!r}. Expected one of {sorted(VALID_SUPABASE_MODES)}."
        )

    local_store = LocalStateStore(root)
    if mode == "local":
        return local_store

    client = SupabaseRESTClient.from_env()
    if client is None:
        if mode == "primary":
            raise RuntimeError(
                "BEATFINDER_SUPABASE_MODE=primary requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
            )
        return local_store

    if mode == "mirror":
        return MirroredStateStore(local_store, client)

    primary_store = SupabasePrimaryStore.from_env(root)
    if primary_store is None:
        raise RuntimeError(
            "BEATFINDER_SUPABASE_MODE=primary requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
        )
    return primary_store

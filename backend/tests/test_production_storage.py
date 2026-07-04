from __future__ import annotations

import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.core.types import QueryRecord
from backend.storage.local_store import LocalStateStore
from backend.storage.runtime import build_runtime_store
from backend.storage.supabase_store import (
    SupabasePrimaryStore,
    SupabaseRESTClient,
    query_audio_ttl_days,
    sync_query_bundle,
)
from backend.workers.cli import run_command

MIGRATIONS_DIR = Path(__file__).resolve().parents[2] / "supabase" / "migrations"

REQUIRED_TABLES = {
    "beats",
    "beat_embeddings",
    "beat_signatures",
    "queries",
    "query_results",
    "feedback_events",
    "producer_channels",
    "producer_beat_videos",
    "discovery_seeds",
    "discovery_edges",
    "discovery_checkpoints",
    "possible_sold_or_deleted_beats",
    "uploaded_audio_assets",
}


class RuntimeModeTests(unittest.TestCase):
    def test_local_mode_returns_local_store(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.dict(os.environ, {"BEATFINDER_SUPABASE_MODE": "local"}):
                store = build_runtime_store(Path(temp_dir) / "state")
            self.assertIsInstance(store, LocalStateStore)

    def test_invalid_mode_raises(self) -> None:
        with patch.dict(os.environ, {"BEATFINDER_SUPABASE_MODE": "cloud"}):
            with self.assertRaises(ValueError):
                build_runtime_store(None)

    def test_primary_mode_without_credentials_raises(self) -> None:
        env = {"BEATFINDER_SUPABASE_MODE": "primary", "SUPABASE_URL": "", "SUPABASE_SERVICE_ROLE_KEY": ""}
        with patch.dict(os.environ, env):
            with self.assertRaises(RuntimeError):
                build_runtime_store(None)

    def test_mirror_mode_without_credentials_falls_back_to_local(self) -> None:
        env = {"BEATFINDER_SUPABASE_MODE": "mirror", "SUPABASE_URL": "", "SUPABASE_SERVICE_ROLE_KEY": ""}
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.dict(os.environ, env):
                store = build_runtime_store(Path(temp_dir) / "state")
            self.assertIsInstance(store, LocalStateStore)

    def test_primary_store_from_env_requires_credentials(self) -> None:
        env = {"SUPABASE_URL": "", "SUPABASE_SERVICE_ROLE_KEY": ""}
        with patch.dict(os.environ, env):
            self.assertIsNone(SupabasePrimaryStore.from_env())
            self.assertIsNone(SupabaseRESTClient.from_env())


class HealthDiagnosticsTests(unittest.TestCase):
    def test_health_reports_storage_mode_without_secrets(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            env = {
                "BEATFINDER_SUPABASE_MODE": "local",
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_SERVICE_ROLE_KEY": "secret-key-value",
            }
            with patch.dict(os.environ, env):
                health = run_command("health", {}, state_dir=str(Path(temp_dir) / "state"))
            self.assertEqual(health["storage_mode"], "local")
            self.assertTrue(health["supabase_configured"])
            self.assertIn(health["query_audio_retention"], {"retain", "delete_after_processing"})
            flattened = str(health)
            self.assertNotIn("secret-key-value", flattened)
            self.assertNotIn("example.supabase.co", flattened)


class MigrationStructureTests(unittest.TestCase):
    def test_migrations_exist(self) -> None:
        migrations = sorted(MIGRATIONS_DIR.glob("*.sql"))
        self.assertGreaterEqual(len(migrations), 4)

    def test_create_table_statements_are_idempotent(self) -> None:
        pattern = re.compile(r"create table\s+(?!if not exists)", re.IGNORECASE)
        for migration in MIGRATIONS_DIR.glob("*.sql"):
            content = migration.read_text(encoding="utf-8")
            self.assertIsNone(
                pattern.search(content),
                f"{migration.name} contains a non-idempotent CREATE TABLE",
            )

    def test_required_tables_are_covered(self) -> None:
        combined = "\n".join(
            migration.read_text(encoding="utf-8").lower() for migration in MIGRATIONS_DIR.glob("*.sql")
        )
        for table in REQUIRED_TABLES:
            self.assertIn(f"public.{table}", combined, f"No migration creates public.{table}")

    def test_vector_columns_use_384_dimensions(self) -> None:
        combined = "\n".join(
            migration.read_text(encoding="utf-8").lower() for migration in MIGRATIONS_DIR.glob("*.sql")
        )
        self.assertIn("vector(384)", combined)


class RecordingClient:
    """Minimal stand-in for SupabaseRESTClient capturing writes."""

    beat_bucket = "beat-audio"
    query_bucket = "query-audio"

    def __init__(self) -> None:
        self.upserts: list[tuple[str, list[dict[str, object]]]] = []
        self.uploads: list[tuple[str, str]] = []

    def upsert_rows(self, table: str, rows: list[dict[str, object]]) -> None:
        self.upserts.append((table, rows))

    def upload_audio(self, *, local_root: Path, relative_path: str, bucket: str) -> None:
        self.uploads.append((bucket, relative_path))


class UploadedAssetRegistryTests(unittest.TestCase):
    def test_retained_query_audio_registers_asset_row(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            audio_relative = "storage/queries/test-query.wav"
            audio_file = root / audio_relative
            audio_file.parent.mkdir(parents=True, exist_ok=True)
            audio_file.write_bytes(b"RIFF-fake")

            client = RecordingClient()
            query = QueryRecord(query_type="audio", raw_text=None, audio_storage_path=audio_relative)
            sync_query_bundle(client, root, query=query, results=[])

            self.assertEqual(client.uploads, [("query-audio", audio_relative)])
            tables = [table for table, _ in client.upserts]
            self.assertIn("uploaded_audio_assets", tables)
            self.assertIn("queries", tables)

            asset_rows = next(rows for table, rows in client.upserts if table == "uploaded_audio_assets")
            self.assertEqual(asset_rows[0]["object_path"], "queries/test-query.wav")
            self.assertEqual(asset_rows[0]["byte_size"], len(b"RIFF-fake"))
            self.assertIsNotNone(asset_rows[0]["expires_at"])

    def test_query_without_audio_registers_nothing(self) -> None:
        client = RecordingClient()
        query = QueryRecord(query_type="text", raw_text="test", audio_storage_path=None)
        sync_query_bundle(client, Path("/nonexistent"), query=query, results=[])
        self.assertEqual(client.uploads, [])
        tables = [table for table, _ in client.upserts]
        self.assertNotIn("uploaded_audio_assets", tables)

    def test_ttl_default_and_override(self) -> None:
        with patch.dict(os.environ, {"BEATFINDER_QUERY_AUDIO_TTL_DAYS": ""}):
            self.assertEqual(query_audio_ttl_days(), 7)
        with patch.dict(os.environ, {"BEATFINDER_QUERY_AUDIO_TTL_DAYS": "30"}):
            self.assertEqual(query_audio_ttl_days(), 30)
        with patch.dict(os.environ, {"BEATFINDER_QUERY_AUDIO_TTL_DAYS": "-1"}):
            self.assertEqual(query_audio_ttl_days(), 7)


if __name__ == "__main__":
    unittest.main()

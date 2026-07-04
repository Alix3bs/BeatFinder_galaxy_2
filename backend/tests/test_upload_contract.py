from __future__ import annotations

import base64
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np

from backend.core.audio_input import decode_audio_base64, persist_audio_payload
from backend.core.upload_validation import (
    UploadValidationError,
    max_upload_bytes,
    sanitize_audio_file_name,
    validate_audio_bytes,
)
from backend.retrieval.service import RetrievalService
from backend.storage.local_store import LocalStateStore
from models.audio.io import (
    UnsupportedAudioFormatError,
    load_audio_mono,
    write_wav_mono,
)


def synth_wav_bytes(path: Path, seconds: float = 1.0) -> bytes:
    sample_rate = 16_000
    t = np.arange(int(sample_rate * seconds)) / sample_rate
    samples = 0.4 * np.sin(2 * np.pi * 220.0 * t).astype(np.float32)
    write_wav_mono(path, samples, sample_rate=sample_rate)
    return path.read_bytes()


class SanitizeFileNameTests(unittest.TestCase):
    def test_strips_directory_traversal(self) -> None:
        self.assertEqual(sanitize_audio_file_name("../../etc/passwd.wav"), "passwd.wav")
        self.assertEqual(sanitize_audio_file_name("/tmp/evil/../beat.mp3"), "beat.mp3")

    def test_removes_unsafe_characters(self) -> None:
        cleaned = sanitize_audio_file_name('be<at>|;"name.wav')
        self.assertNotIn("<", cleaned)
        self.assertNotIn(";", cleaned)
        self.assertTrue(cleaned.endswith(".wav"))

    def test_caps_length(self) -> None:
        cleaned = sanitize_audio_file_name(("x" * 300) + ".wav")
        self.assertLessEqual(len(cleaned), 84 + len(".wav"))

    def test_mime_type_supplies_extension(self) -> None:
        self.assertEqual(sanitize_audio_file_name("clip", "audio/mpeg"), "clip.mp3")
        self.assertEqual(sanitize_audio_file_name("clip", "audio/x-m4a"), "clip.m4a")

    def test_defaults_to_wav_without_any_format_signal(self) -> None:
        self.assertEqual(sanitize_audio_file_name("query-audio"), "query-audio.wav")

    def test_rejects_unsupported_formats(self) -> None:
        with self.assertRaises(UploadValidationError) as ctx:
            sanitize_audio_file_name("beat.ogg")
        self.assertEqual(ctx.exception.code, "unsupported_audio_format")
        with self.assertRaises(UploadValidationError):
            sanitize_audio_file_name("clip", "audio/ogg")


class UploadSizeTests(unittest.TestCase):
    def test_default_limit(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("BEATFINDER_MAX_UPLOAD_BYTES", None)
            self.assertEqual(max_upload_bytes(), 25 * 1024 * 1024)

    def test_rejects_oversized_payload(self) -> None:
        with patch.dict(os.environ, {"BEATFINDER_MAX_UPLOAD_BYTES": "10"}):
            with self.assertRaises(UploadValidationError) as ctx:
                validate_audio_bytes(b"x" * 11)
            self.assertEqual(ctx.exception.code, "upload_too_large")
            self.assertEqual(ctx.exception.http_status, 413)

    def test_rejects_empty_payload(self) -> None:
        with self.assertRaises(UploadValidationError) as ctx:
            validate_audio_bytes(b"")
        self.assertEqual(ctx.exception.code, "empty_audio")


class Base64DecodingTests(unittest.TestCase):
    def test_rejects_invalid_base64(self) -> None:
        with self.assertRaises(UploadValidationError) as ctx:
            decode_audio_base64("!!!not-base64!!!")
        self.assertEqual(ctx.exception.code, "invalid_audio_encoding")

    def test_accepts_data_url_prefix(self) -> None:
        encoded = base64.b64encode(b"abc").decode("ascii")
        self.assertEqual(decode_audio_base64(f"data:audio/wav;base64,{encoded}"), b"abc")


class LocalPathPolicyTests(unittest.TestCase):
    def test_audio_path_rejected_when_disallowed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            store = LocalStateStore(Path(temp_dir) / "state")
            with patch.dict(os.environ, {"BEATFINDER_DISALLOW_AUDIO_PATHS": "1"}):
                with self.assertRaises(UploadValidationError) as ctx:
                    persist_audio_payload(
                        store,
                        {"audio_path": "/etc/passwd"},
                        category="queries",
                        default_name="query-audio",
                    )
            self.assertEqual(ctx.exception.code, "audio_path_not_allowed")


class AudioDecodeTests(unittest.TestCase):
    def test_non_wav_without_ffmpeg_raises_clear_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            fake = Path(temp_dir) / "clip.m4a"
            fake.write_bytes(b"not-audio")
            missing_ffmpeg = str(Path(temp_dir) / "missing-ffmpeg")
            with patch.dict(os.environ, {"BEATFINDER_FFMPEG_BIN": missing_ffmpeg}):
                with self.assertRaises(UnsupportedAudioFormatError):
                    load_audio_mono(fake)

    def test_non_wav_decodes_through_ffmpeg_stub(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template_wav = root / "template.wav"
            synth_wav_bytes(template_wav)

            stub = root / "ffmpeg-stub.py"
            stub.write_text(
                "#!/usr/bin/env python3\n"
                "import shutil, sys\n"
                f"shutil.copyfile({json.dumps(str(template_wav))}, sys.argv[-1])\n",
                encoding="utf-8",
            )
            stub.chmod(stub.stat().st_mode | stat.S_IXUSR)

            fake_m4a = root / "clip.m4a"
            fake_m4a.write_bytes(b"pretend-m4a")
            with patch.dict(os.environ, {"BEATFINDER_FFMPEG_BIN": str(stub)}):
                samples, sample_rate = load_audio_mono(fake_m4a)
            self.assertEqual(sample_rate, 16_000)
            self.assertGreater(samples.size, 0)


class QueryAudioRetentionTests(unittest.TestCase):
    def _run_audio_search(self, extra_env: dict[str, str]) -> tuple[LocalStateStore, dict[str, object]]:
        temp_dir = tempfile.mkdtemp(prefix="beatfinder-retention-")
        store = LocalStateStore(Path(temp_dir) / "state")
        wav_bytes = synth_wav_bytes(Path(temp_dir) / "query.wav")

        from backend.ingest.service import IngestService
        from backend.tests.fixture_builder import materialize_fixtures

        fixtures = materialize_fixtures(Path(temp_dir) / "fixtures")
        IngestService(store).ingest_beat(fixtures[0])

        service = RetrievalService(store)
        payload = {
            "audio_base64": base64.b64encode(wav_bytes).decode("ascii"),
            "audio_file_name": "query.wav",
            "audio_mime_type": "audio/wav",
            "top_n": 3,
        }
        with patch.dict(os.environ, extra_env):
            response = service.search_audio(payload)
        return store, response

    def _stored_query_files(self, store: LocalStateStore) -> list[Path]:
        queries_dir = store.storage_dir / "queries"
        if not queries_dir.exists():
            return []
        return [path for path in queries_dir.rglob("*") if path.is_file()]

    def test_query_audio_deleted_by_default(self) -> None:
        store, _ = self._run_audio_search({"BEATFINDER_RETAIN_QUERY_AUDIO": ""})
        self.assertEqual(self._stored_query_files(store), [])
        queries = store._load_table("queries")
        self.assertTrue(queries)
        self.assertIsNone(queries[-1]["audio_storage_path"])

    def test_query_audio_kept_when_retention_enabled(self) -> None:
        store, _ = self._run_audio_search({"BEATFINDER_RETAIN_QUERY_AUDIO": "1"})
        self.assertEqual(len(self._stored_query_files(store)), 1)
        queries = store._load_table("queries")
        self.assertTrue(queries)
        self.assertIsNotNone(queries[-1]["audio_storage_path"])


if __name__ == "__main__":
    unittest.main()

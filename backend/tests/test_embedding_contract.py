from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.core.types import AUDIO_EMBEDDING_MODEL, METADATA_EMBEDDING_MODEL, VECTOR_DIMENSION
from backend.storage.supabase_store import parse_embedding_value, vector_literal
from backend.tests.fixture_builder import load_fixture_specs, synthesize_audio
from models.audio.features import audio_features_to_embedding, extract_audio_features
from models.audio.io import write_wav_mono
from models.embedding.providers import HashingTextEmbeddingProvider


class EmbeddingContractTests(unittest.TestCase):
    def test_audio_embedding_matches_shared_dimension(self) -> None:
        spec = load_fixture_specs()[0]
        with tempfile.TemporaryDirectory() as temp_dir:
            audio_path = Path(temp_dir) / "fixture.wav"
            write_wav_mono(audio_path, synthesize_audio(spec))
            features = extract_audio_features(audio_path)
            embedding = audio_features_to_embedding(features)

        self.assertEqual(len(embedding), VECTOR_DIMENSION)
        self.assertEqual(AUDIO_EMBEDDING_MODEL, "beatfinder-local-audio-summary-384-v1")

    def test_text_embedding_matches_shared_dimension(self) -> None:
        provider = HashingTextEmbeddingProvider()
        embedding = provider.embed("sza x summer walker type beat")

        self.assertEqual(len(embedding), VECTOR_DIMENSION)
        self.assertEqual(METADATA_EMBEDDING_MODEL, "beatfinder-local-metadata-hash-384-v1")

    def test_vector_literal_round_trip_supports_384_dimensions(self) -> None:
        vector = [index / 1000.0 for index in range(VECTOR_DIMENSION)]
        literal = vector_literal(vector)
        parsed = parse_embedding_value(literal)

        self.assertEqual(len(parsed), VECTOR_DIMENSION)
        self.assertAlmostEqual(parsed[0], 0.0)
        self.assertAlmostEqual(parsed[-1], (VECTOR_DIMENSION - 1) / 1000.0, places=6)


if __name__ == "__main__":
    unittest.main()

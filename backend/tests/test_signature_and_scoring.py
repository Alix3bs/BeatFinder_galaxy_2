from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.rerank.scoring import build_metadata_breakdown, confidence_label, fuse_scores
from backend.tests.fixture_builder import load_fixture_specs, synthesize_audio
from backend.core.types import BeatRecord
from models.audio.features import extract_audio_features
from models.audio.io import write_wav_mono
from models.audio.signature import build_audio_signature, score_signature_match
from models.metadata.parser import expand_query_phrases


class SignatureAndScoringTests(unittest.TestCase):
    def test_signature_is_stable_for_same_audio(self) -> None:
        spec = load_fixture_specs()[0]
        with tempfile.TemporaryDirectory() as temp_dir:
            audio_path = Path(temp_dir) / "fixture.wav"
            write_wav_mono(audio_path, synthesize_audio(spec))
            features_one = extract_audio_features(audio_path)
            features_two = extract_audio_features(audio_path)
            signature_one = build_audio_signature(features_one)
            signature_two = build_audio_signature(features_two)

        self.assertEqual(signature_one["hash"], signature_two["hash"])
        self.assertEqual(score_signature_match(signature_one, signature_two), 1.0)

    def test_rerank_prefers_stronger_audio_and_metadata_alignment(self) -> None:
        beat = BeatRecord(
            raw_title="SZA x Summer Walker Type Beat - Late Nights",
            canonical_title="late nights",
            producer_name="era jay",
            source_url="https://example.com",
            source_platform="fixture",
            cover_art_url=None,
            bpm=92,
            musical_key=None,
            duration_seconds=8.0,
            hashtags=["#phillytypebeat"],
            artist_refs=["sza", "summer walker"],
            artist_combo_refs=["sza x summer walker"],
            producer_combo_refs=["era jay x bani"],
            type_beat_phrases=["sza x summer walker type beat", "sza type beat", "summer walker type beat"],
            normalized_search_phrases=["sza x summer walker type beat", "late nights", "philly type beat"],
            region_tags=["philly"],
            genre_tags=["rnb"],
        )
        query_metadata = expand_query_phrases("sza x summer walker type beat #phillytypebeat")
        metadata_breakdown = build_metadata_breakdown(query_metadata, beat)
        score, breakdown = fuse_scores(
            beat,
            audio_embedding_score=0.96,
            metadata_embedding_score=0.81,
            signature_score=0.88,
            metadata_breakdown=metadata_breakdown,
            query_bpm=92.0,
            has_audio_query=True,
            has_metadata_query=True,
        )
        self.assertGreater(score, 0.74)
        self.assertEqual(confidence_label(score, signature_score=0.88, audio_embedding_score=0.96), "likely_exact_match")
        self.assertGreater(breakdown["metadata_score"], 0.4)


if __name__ == "__main__":
    unittest.main()

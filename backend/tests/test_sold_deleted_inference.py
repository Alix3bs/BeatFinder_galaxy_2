from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.discovery.producer_channels import ProducerBeatVideo, ProducerDiscoveryStore
from backend.discovery.sold_deleted_inference import infer_possible_sold_or_deleted


class SoldDeletedInferenceTests(unittest.TestCase):
    def test_producer_tag_without_visible_video_creates_possible_record(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            channel = store.upsert_channel(
                "UCERABANI",
                producer_name="Era Jay x Bani",
                aliases=["era jay", "bani", "era jay tag"],
            )
            store.upsert_video(
                ProducerBeatVideo(
                    producer_channel_id=channel.id,
                    video_id="visible-1",
                    video_url="https://www.youtube.com/watch?v=visible-1",
                    title="SZA x Summer Walker Type Beat - Afterglow",
                )
            )

            record = infer_possible_sold_or_deleted(
                detected_producer_tag="Era Jay Tag",
                store=store,
                query_audio_id="query-audio-1",
                candidate_title="Late Nights",
                nearest_candidates=[{"title": "Afterglow", "score": 0.4}],
            )

            self.assertIsNotNone(record)
            assert record is not None
            self.assertEqual(record.matched_producer_channel_id, channel.id)
            self.assertIn("producer_tag_detected", record.evidence)
            self.assertIn("sold_and_deleted", record.possible_reasons)
            self.assertIn("producer_tag_false_positive", record.possible_reasons)
            self.assertGreaterEqual(record.confidence, 0.7)

    def test_visible_matching_upload_suppresses_possible_sold_deleted_record(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            channel = store.upsert_channel("UCERABANI", producer_name="Era Jay", aliases=["era jay tag"])
            store.upsert_video(
                ProducerBeatVideo(
                    producer_channel_id=channel.id,
                    video_id="visible-2",
                    video_url="https://www.youtube.com/watch?v=visible-2",
                    title="Late Nights Type Beat",
                )
            )

            record = infer_possible_sold_or_deleted(
                detected_producer_tag="Era Jay Tag",
                store=store,
                candidate_title="Late Nights Type Beat",
            )

            self.assertIsNone(record)
            self.assertEqual(store.list_possible_sold_deleted(), [])


if __name__ == "__main__":
    unittest.main()

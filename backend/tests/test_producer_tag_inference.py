from __future__ import annotations

import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend.discovery.producer_channels import ProducerBeatVideo, ProducerChannel, ProducerDiscoveryStore
from backend.discovery.producer_tag_matcher import ProducerTagMatch, match_producer_tag
from backend.discovery.sold_deleted_inference import (
    FOUND_CANDIDATE_STATUS,
    INSUFFICIENT_EVIDENCE_STATUS,
    POSSIBLE_SOLD_OR_DELETED_STATUS,
    infer_sold_deleted_status,
)


class ProducerTagMatcherTests(unittest.TestCase):
    def test_exact_producer_tag_alias_matches_known_channel(self) -> None:
        channel = ProducerChannel(
            platform="youtube",
            channel_id="slimybeats",
            channel_url="https://www.youtube.com/@slimybeats",
            producer_name="Slimy Beats",
            aliases=["beats by slimy"],
        )

        match = match_producer_tag("beats by slimy", [channel])

        self.assertIsNotNone(match)
        assert match is not None
        self.assertEqual(match.channel.id, channel.id)
        self.assertEqual(match.match_type, "exact_alias")
        self.assertGreaterEqual(match.confidence, 0.95)

    def test_normalized_producer_tag_matches_known_channel(self) -> None:
        salishan = ProducerChannel(
            platform="youtube",
            channel_id="prodsalishan",
            channel_url="https://www.youtube.com/@prod.salishan",
            producer_name="prod.salishan",
            aliases=["prod.salishan"],
        )
        baby = ProducerChannel(
            platform="youtube",
            channel_id="babyonthetrack",
            channel_url="https://www.youtube.com/@babyonthetrack",
            producer_name="babyonthetrack",
            aliases=["babyonthetrack"],
        )

        salishan_match = match_producer_tag("prod by salishan", [salishan, baby])
        baby_match = match_producer_tag("baby on the track", [salishan, baby])

        self.assertIsNotNone(salishan_match)
        assert salishan_match is not None
        self.assertEqual(salishan_match.channel.id, salishan.id)
        self.assertIn(salishan_match.match_type, {"loose_normalized", "normalized_alias"})

        self.assertIsNotNone(baby_match)
        assert baby_match is not None
        self.assertEqual(baby_match.channel.id, baby.id)
        self.assertEqual(baby_match.match_type, "normalized_alias")

    def test_weak_common_tag_does_not_overmatch(self) -> None:
        channel = ProducerChannel(
            platform="youtube",
            channel_id="prodby",
            channel_url="https://www.youtube.com/@prodby",
            producer_name="The Track",
            aliases=["beats by slimy", "prod.salishan", "prod by", "the track"],
        )

        self.assertIsNone(match_producer_tag("beats by", [channel]))
        self.assertIsNone(match_producer_tag("prod by", [channel]))
        self.assertIsNone(match_producer_tag("the track", [channel]))


class SoldDeletedInferenceTests(unittest.TestCase):
    def test_producer_tag_matched_without_beat_video_returns_possible_sold_or_deleted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            channel = store.upsert_channel(
                "https://www.youtube.com/@salishan",
                producer_name="prod.salishan",
                aliases=["prod.salishan"],
            )
            store.upsert_video(
                ProducerBeatVideo(
                    producer_channel_id=channel.id,
                    video_id="visible-1",
                    video_url="https://www.youtube.com/watch?v=visible-1",
                    title="SZA x Summer Walker Type Beat - Rain",
                    normalized_search_phrases=["sza x summer walker type beat", "rain"],
                    artist_combo_refs=["sza x summer walker"],
                    type_beat_phrases=["sza x summer walker type beat"],
                )
            )

            result = infer_sold_deleted_status(
                detected_producer_tag="prod by salishan",
                store=store,
                query_title="Milwaukee x Detroit Type Beat - Fast Money",
            )

            self.assertEqual(result.status, POSSIBLE_SOLD_OR_DELETED_STATUS)
            self.assertEqual(result.matched_channel_id, channel.id)
            self.assertIn("not_yet_indexed", result.possible_reasons)
            self.assertIn("producer_tag_false_positive", result.possible_reasons)
            self.assertTrue(any("not certain" in item for item in result.evidence))

    def test_similar_title_phrase_candidate_returns_found_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            channel = store.upsert_channel(
                "https://www.youtube.com/@shadstackz",
                producer_name="Shadstackz",
                aliases=["shadstackz tag"],
            )
            store.upsert_video(
                ProducerBeatVideo(
                    producer_channel_id=channel.id,
                    video_id="scam-talk",
                    video_url="https://www.youtube.com/watch?v=scam-talk",
                    title="Shadstackz x TSE Vic Type Beat - Scam Talk",
                    normalized_search_phrases=["shadstackz x tse vic type beat", "scam talk"],
                    artist_combo_refs=["shadstackz x tse vic"],
                    type_beat_phrases=["shadstackz x tse vic type beat"],
                )
            )

            result = infer_sold_deleted_status(
                detected_producer_tag="shadstackz tag",
                store=store,
                query_title="Shadstackz x TSE Vic Type Beat - Scam Talk",
            )

            self.assertEqual(result.status, FOUND_CANDIDATE_STATUS)
            self.assertEqual(result.matched_video_id, "scam-talk")
            self.assertEqual(result.possible_reasons, [])

    def test_low_producer_confidence_returns_insufficient_evidence(self) -> None:
        channel = ProducerChannel(
            platform="youtube",
            channel_id="weakmatch",
            channel_url="https://www.youtube.com/@weakmatch",
            producer_name="Weak Match",
        )
        weak_match = ProducerTagMatch(
            channel=channel,
            confidence=0.42,
            match_type="token_overlap",
            detected_producer_tag="weak tag",
            normalized_tag="weak tag",
            matched_alias="weak match",
            evidence=["weak overlap only"],
        )

        result = infer_sold_deleted_status(
            detected_producer_tag="weak tag",
            producer_match=weak_match,
            indexed_video_candidates=[],
        )

        self.assertEqual(result.status, INSUFFICIENT_EVIDENCE_STATUS)
        self.assertEqual(result.matched_channel_id, channel.id)
        self.assertEqual(result.possible_reasons, [])

    def test_possible_sold_or_deleted_possible_reasons_reflect_index_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            channel = store.upsert_channel(
                "https://www.youtube.com/@beatsbyslimy",
                producer_name="beatsbyslimy",
                aliases=["beatsbyslimy"],
            )

            result = infer_sold_deleted_status(
                detected_producer_tag="beats by slimy",
                store=store,
                query_title="Arkansas x Detroit Type Beat - Trenches",
            )

            self.assertEqual(result.status, POSSIBLE_SOLD_OR_DELETED_STATUS)
            self.assertIn("sold_and_deleted", result.possible_reasons)
            self.assertIn("unlisted", result.possible_reasons)
            self.assertIn("private", result.possible_reasons)
            self.assertIn("renamed", result.possible_reasons)
            self.assertIn("hosted_on_beatstars", result.possible_reasons)
            self.assertIn("hosted_on_traktrain", result.possible_reasons)
            self.assertIn("not_yet_indexed", result.possible_reasons)
            self.assertIn("producer_tag_false_positive", result.possible_reasons)

            store.save_checkpoint(channel.id, page_token=None, completed=True)
            covered_result = infer_sold_deleted_status(
                detected_producer_tag="beats by slimy",
                store=store,
                query_title="Arkansas x Detroit Type Beat - Trenches",
            )

            self.assertNotIn("not_yet_indexed", covered_result.possible_reasons)
            self.assertIn("producer_tag_false_positive", covered_result.possible_reasons)

    def test_no_live_network_call_happens_in_inference(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = ProducerDiscoveryStore(Path(tmp) / "state")
            store.upsert_channel(
                "https://www.youtube.com/@babyonthetrack",
                producer_name="babyonthetrack",
                aliases=["babyonthetrack"],
            )

            with patch.object(socket, "create_connection", side_effect=AssertionError("network call")) as create_connection:
                result = infer_sold_deleted_status(
                    detected_producer_tag="baby on the track",
                    store=store,
                    query_title="New York Drill Type Beat - Midnight Rush",
                )

            self.assertEqual(result.status, POSSIBLE_SOLD_OR_DELETED_STATUS)
            create_connection.assert_not_called()


if __name__ == "__main__":
    unittest.main()

import Foundation
import Testing
@testable import BeatFinder

struct BeatFinderAPIModelsTests {
    @Test func decodesSearchResponseWithDiscovery() throws {
        let json = """
        {
          "query_id": "query-123",
          "query_type": "text",
          "confidence": "likely_candidates",
          "candidate_pool_sizes": {
            "metadata": 3,
            "merged": 3
          },
          "results": [
            {
              "beat": {
                "id": "beat-123",
                "raw_title": "SZA x Summer Walker Type Beat - Late Nights",
                "producer_name": "Era Jay x Bani",
                "source_url": "https://example.com/beats/late-nights",
                "bpm": 92,
                "hashtags": ["#phillytypebeat"],
                "artist_combo_refs": ["sza x summer walker"],
                "type_beat_phrases": ["sza x summer walker type beat"]
              },
              "rerank_score": 0.93,
              "confidence_label": "likely_exact_match",
              "explanation": "strong metadata and discovery match"
            }
          ],
          "discovery": {
            "detected_producer_tag": "prod by salishan",
            "matched_producer_channel": {
              "channel_id": "prod.salishan",
              "channel_url": "https://youtube.com/@prod.salishan",
              "producer_name": "prod salishan",
              "aliases": ["prod.salishan", "prod salishan", "prodsalishan", "salishan"]
            },
            "producer_tag_confidence": 0.9,
            "youtube_video_match": {
              "video_id": "salishan-001",
              "video_url": "https://www.youtube.com/watch?v=salishan-001",
              "title": "SZA x Summer Walker Type Beat - Late Nights",
              "visibility_status": "public"
            },
            "discovery_status": "found_candidate",
            "possible_reasons": [],
            "recommended_next_searches": [
              "prod salishan type beat",
              "philly type beat",
              "sza summer walker type beat"
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try BeatFinderAPIClient.makeDecoder().decode(SearchResponse.self, from: json)

        #expect(response.queryID == "query-123")
        #expect(response.results.first?.beat.rawTitle == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(response.results.first?.beat.artistComboRefs == ["sza x summer walker"])
        #expect(response.discovery?.discoveryStatus == "found_candidate")
        #expect(response.discovery?.matchedProducerChannel?.channelID == "prod.salishan")
        #expect(response.discovery?.youtubeVideoMatch?.title == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(response.discovery?.recommendedNextSearches.count == 3)
    }
}

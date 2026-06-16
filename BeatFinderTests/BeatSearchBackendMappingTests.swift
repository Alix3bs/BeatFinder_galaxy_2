import Foundation
import Testing
@testable import BeatFinder

struct BeatSearchBackendMappingTests {
    @Test func mapsFoundCandidateDiscoveryIntoProductSearchResponse() throws {
        let response = try decodeSearchResponse("""
        {
          "query_id": "query-123",
          "query_type": "text",
          "confidence": "likely_exact_match",
          "results": [
            {
              "beat": {
                "id": "E7C89CBF-3A14-4D6B-A8F8-7E9B6D20C95B",
                "raw_title": "SZA x Summer Walker Type Beat - Late Nights",
                "producer_name": "prod salishan",
                "source_url": "https://www.youtube.com/watch?v=salishan-001",
                "source_platform": "youtube",
                "bpm": 92
              },
              "rerank_score": 0.93,
              "confidence_label": "likely_exact_match",
              "explanation": "producer discovery and metadata agree"
            }
          ],
          "discovery": {
            "detected_producer_tag": "prod by salishan",
            "matched_producer_channel": {
              "channel_id": "prod.salishan",
              "channel_url": "https://youtube.com/@prod.salishan",
              "producer_name": "prod salishan",
              "aliases": ["prod.salishan", "prod salishan", "salishan"]
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
            "recommended_next_searches": ["prod salishan type beat", "philly type beat"]
          }
        }
        """)

        let mapped = BeatSearchResponse.backendAPI(
            query: "sza x summer walker type beat",
            response: response
        )

        #expect(mapped.source == .backendAPI)
        #expect(mapped.resultState == .exactMatch)
        #expect(mapped.matches.first?.title == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(mapped.matches.first?.platform == .youtube)
        #expect(mapped.matches.first?.verdict == .exact)
        #expect(mapped.discovery?.discoveryStatus == "found_candidate")
        #expect(mapped.discovery?.youtubeVideoMatch?.title == "SZA x Summer Walker Type Beat - Late Nights")

        let uploadResult = BeatResultModel.fromBackendSearch(
            response: response,
            mappedSearch: mapped,
            fallbackTitle: "uploaded-audio.m4a"
        )

        #expect(uploadResult.title == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(uploadResult.artist == "prod salishan")
        #expect(uploadResult.confidenceLabel == "likely_exact_match")
        #expect(uploadResult.discoveryStatus == "found_candidate")
        #expect(uploadResult.matchedProducerChannelName == "prod.salishan")
        #expect(uploadResult.youtubeVideoMatchTitle == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(uploadResult.recommendedNextSearches == ["prod salishan type beat", "philly type beat"])
    }

    @Test func preservesPossibleSoldDeletedDiscoveryWithoutOverclaimingExactMatch() throws {
        let response = try decodeSearchResponse("""
        {
          "query_id": "query-456",
          "query_type": "text",
          "confidence": "no_confident_exact_match",
          "results": [],
          "discovery": {
            "detected_producer_tag": "prod by salishan",
            "matched_producer_channel": {
              "channel_id": "prod.salishan",
              "channel_url": "https://youtube.com/@prod.salishan",
              "producer_name": "prod salishan",
              "aliases": ["prod.salishan", "prod salishan", "salishan"]
            },
            "producer_tag_confidence": 0.82,
            "youtube_video_match": null,
            "discovery_status": "possible_sold_or_deleted",
            "possible_reasons": ["sold_and_deleted", "unlisted", "not_yet_indexed"],
            "recommended_next_searches": ["prod salishan type beat"]
          }
        }
        """)

        let mapped = BeatSearchResponse.backendAPI(
            query: "lost salishan type beat",
            response: response
        )

        #expect(mapped.resultState == .notFound)
        #expect(mapped.likelyCustom)
        #expect(mapped.matches.isEmpty)
        #expect(mapped.summary == "Producer found, but no matching visible indexed video was found.")
        #expect(mapped.discovery?.possibleReasons.contains("not_yet_indexed") == true)

        let uploadResult = BeatResultModel.fromBackendSearch(
            response: response,
            mappedSearch: mapped,
            fallbackTitle: "uploaded-audio.m4a"
        )

        #expect(uploadResult.title == "No visible indexed beat found")
        #expect(uploadResult.artist == "prod salishan")
        #expect(uploadResult.discoveryStatus == "possible_sold_or_deleted")
        #expect(uploadResult.possibleReasons?.contains("not_yet_indexed") == true)
        #expect(uploadResult.hasBackendDiscoveryDetails)
    }

    private func decodeSearchResponse(_ json: String) throws -> SearchResponse {
        let data = json.data(using: .utf8)!
        return try BeatFinderAPIClient.makeDecoder().decode(SearchResponse.self, from: data)
    }
}

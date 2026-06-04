import Foundation

enum BeatFinderBackendAPI {
    struct Beat: Codable, Equatable {
        let id: String?
        let rawTitle: String?
        let canonicalTitle: String?
        let producerName: String?
        let sourceURL: String?
        let sourcePlatform: String?
        let bpm: Double?
        let musicalKey: String?
        let durationSeconds: Double?
        let genreTags: [String]
        let regionTags: [String]
        let hashtags: [String]
        let artistRefs: [String]
        let artistComboRefs: [String]
        let producerComboRefs: [String]
        let typeBeatPhrases: [String]
        let normalizedSearchPhrases: [String]

        var displayTitle: String {
            rawTitle ?? canonicalTitle ?? "Untitled beat"
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case rawTitle = "raw_title"
            case canonicalTitle = "canonical_title"
            case producerName = "producer_name"
            case sourceURL = "source_url"
            case sourcePlatform = "source_platform"
            case bpm
            case musicalKey = "musical_key"
            case durationSeconds = "duration_seconds"
            case genreTags = "genre_tags"
            case regionTags = "region_tags"
            case hashtags
            case artistRefs = "artist_refs"
            case artistComboRefs = "artist_combo_refs"
            case producerComboRefs = "producer_combo_refs"
            case typeBeatPhrases = "type_beat_phrases"
            case normalizedSearchPhrases = "normalized_search_phrases"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            rawTitle = try container.decodeIfPresent(String.self, forKey: .rawTitle)
            canonicalTitle = try container.decodeIfPresent(String.self, forKey: .canonicalTitle)
            producerName = try container.decodeIfPresent(String.self, forKey: .producerName)
            sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
            sourcePlatform = try container.decodeIfPresent(String.self, forKey: .sourcePlatform)
            bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)
            musicalKey = try container.decodeIfPresent(String.self, forKey: .musicalKey)
            durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
            genreTags = try container.decodeIfPresent([String].self, forKey: .genreTags) ?? []
            regionTags = try container.decodeIfPresent([String].self, forKey: .regionTags) ?? []
            hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
            artistRefs = try container.decodeIfPresent([String].self, forKey: .artistRefs) ?? []
            artistComboRefs = try container.decodeIfPresent([String].self, forKey: .artistComboRefs) ?? []
            producerComboRefs = try container.decodeIfPresent([String].self, forKey: .producerComboRefs) ?? []
            typeBeatPhrases = try container.decodeIfPresent([String].self, forKey: .typeBeatPhrases) ?? []
            normalizedSearchPhrases = try container.decodeIfPresent([String].self, forKey: .normalizedSearchPhrases) ?? []
        }
    }
}

struct HealthResponse: Codable, Equatable {
    let status: String
    let stateDir: String?
    let beatsIndexed: Int?

    private enum CodingKeys: String, CodingKey {
        case status
        case stateDir = "state_dir"
        case beatsIndexed = "beats_indexed"
    }
}

struct SearchResponse: Codable, Equatable {
    let queryID: String?
    let queryType: String?
    let confidence: String?
    let candidatePoolSizes: [String: Int]?
    let results: [BeatSearchResult]
    let discovery: DiscoveryEnrichment?

    var topBeatTitle: String? {
        results.first?.beat.displayTitle
    }

    private enum CodingKeys: String, CodingKey {
        case queryID = "query_id"
        case queryType = "query_type"
        case confidence
        case candidatePoolSizes = "candidate_pool_sizes"
        case results
        case discovery
    }
}

struct BeatSearchResult: Codable, Equatable {
    let beat: BeatFinderBackendAPI.Beat
    let rerankScore: Double?
    let confidenceLabel: String?
    let embeddingScore: Double?
    let signatureScore: Double?
    let metadataScore: Double?
    let scoreBreakdown: [String: Double]?
    let explanation: String?

    private enum CodingKeys: String, CodingKey {
        case beat
        case rerankScore = "rerank_score"
        case confidenceLabel = "confidence_label"
        case embeddingScore = "embedding_score"
        case signatureScore = "signature_score"
        case metadataScore = "metadata_score"
        case scoreBreakdown = "score_breakdown"
        case explanation
    }
}

struct DiscoveryEnrichment: Codable, Equatable {
    let detectedProducerTag: String?
    let matchedProducerChannel: MatchedProducerChannel?
    let producerTagConfidence: Double?
    let youtubeVideoMatch: YouTubeVideoMatch?
    let discoveryStatus: String?
    let possibleReasons: [String]
    let evidence: [String]
    let recommendedNextSearches: [String]

    private enum CodingKeys: String, CodingKey {
        case detectedProducerTag = "detected_producer_tag"
        case matchedProducerChannel = "matched_producer_channel"
        case producerTagConfidence = "producer_tag_confidence"
        case youtubeVideoMatch = "youtube_video_match"
        case discoveryStatus = "discovery_status"
        case possibleReasons = "possible_reasons"
        case evidence
        case recommendedNextSearches = "recommended_next_searches"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detectedProducerTag = try container.decodeIfPresent(String.self, forKey: .detectedProducerTag)
        matchedProducerChannel = try container.decodeIfPresent(MatchedProducerChannel.self, forKey: .matchedProducerChannel)
        producerTagConfidence = try container.decodeIfPresent(Double.self, forKey: .producerTagConfidence)
        youtubeVideoMatch = try container.decodeIfPresent(YouTubeVideoMatch.self, forKey: .youtubeVideoMatch)
        discoveryStatus = try container.decodeIfPresent(String.self, forKey: .discoveryStatus)
        possibleReasons = try container.decodeIfPresent([String].self, forKey: .possibleReasons) ?? []
        evidence = try container.decodeIfPresent([String].self, forKey: .evidence) ?? []
        recommendedNextSearches = try container.decodeIfPresent([String].self, forKey: .recommendedNextSearches) ?? []
    }
}

struct MatchedProducerChannel: Codable, Equatable {
    let id: String?
    let channelID: String?
    let channelURL: String?
    let producerName: String?
    let aliases: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case channelID = "channel_id"
        case channelURL = "channel_url"
        case producerName = "producer_name"
        case aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        channelURL = try container.decodeIfPresent(String.self, forKey: .channelURL)
        producerName = try container.decodeIfPresent(String.self, forKey: .producerName)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }
}

struct YouTubeVideoMatch: Codable, Equatable {
    let id: String?
    let videoID: String?
    let videoURL: String?
    let title: String?
    let visibilityStatus: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case videoURL = "video_url"
        case title
        case visibilityStatus = "visibility_status"
    }
}

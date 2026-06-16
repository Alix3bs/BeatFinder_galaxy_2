import Foundation

struct BeatResultModel: Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let bpm: Int
    let genre: String
    let releaseDate: Date
    let artworkName: String?
    let youtubeVideoID: String?
    let youtubeWatchURLString: String?
    let confidenceLabel: String?
    let matchedProducerChannelName: String?
    let producerTagConfidence: Double?
    let discoveryStatus: String?
    let youtubeVideoMatchTitle: String?
    let possibleReasons: [String]?
    let recommendedNextSearches: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case bpm
        case genre
        case releaseDate = "release_date"
        case artworkName = "artwork_name"
        case youtubeVideoID = "youtube_video_id"
        case youtubeWatchURLString = "youtube_watch_url"
        case confidenceLabel = "confidence_label"
        case matchedProducerChannelName = "matched_producer_channel_name"
        case producerTagConfidence = "producer_tag_confidence"
        case discoveryStatus = "discovery_status"
        case youtubeVideoMatchTitle = "youtube_video_match_title"
        case possibleReasons = "possible_reasons"
        case recommendedNextSearches = "recommended_next_searches"
    }

    init(
        id: String,
        title: String,
        artist: String,
        bpm: Int,
        genre: String,
        releaseDate: Date,
        artworkName: String?,
        youtubeVideoID: String? = nil,
        youtubeWatchURLString: String? = nil,
        confidenceLabel: String? = nil,
        matchedProducerChannelName: String? = nil,
        producerTagConfidence: Double? = nil,
        discoveryStatus: String? = nil,
        youtubeVideoMatchTitle: String? = nil,
        possibleReasons: [String]? = nil,
        recommendedNextSearches: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.genre = genre
        self.releaseDate = releaseDate
        self.artworkName = artworkName
        self.youtubeVideoID = youtubeVideoID
        self.youtubeWatchURLString = youtubeWatchURLString
        self.confidenceLabel = confidenceLabel
        self.matchedProducerChannelName = matchedProducerChannelName
        self.producerTagConfidence = producerTagConfidence
        self.discoveryStatus = discoveryStatus
        self.youtubeVideoMatchTitle = youtubeVideoMatchTitle
        self.possibleReasons = possibleReasons
        self.recommendedNextSearches = recommendedNextSearches
    }
}

extension BeatResultModel {
    static func fromBackendSearch(
        response: SearchResponse,
        mappedSearch: BeatSearchResponse,
        fallbackTitle: String
    ) -> BeatResultModel {
        let firstResult = response.results.first
        let beat = firstResult?.beat
        let discovery = response.discovery
        let channel = discovery?.matchedProducerChannel
        let watchURLString = discovery?.youtubeVideoMatch?.videoURL ?? beat?.sourceURL
        let status = discovery?.discoveryStatus

        let title =
            beat?.displayTitle ??
            discovery?.youtubeVideoMatch?.title ??
            (status == "possible_sold_or_deleted" ? "No visible indexed beat found" : fallbackTitle)

        let producer =
            beat?.producerName ??
            channel?.producerName ??
            channel?.channelID ??
            "Unknown producer"

        let genre =
            beat?.genreTags.first ??
            beat?.regionTags.first ??
            status?.readableBackendToken ??
            "BeatFinder match"

        return BeatResultModel(
            id: beat?.id ?? discovery?.youtubeVideoMatch?.videoID ?? UUID().uuidString,
            title: title,
            artist: producer,
            bpm: beat?.bpm.map { Int($0.rounded()) } ?? mappedSearch.matches.first?.bpm ?? 0,
            genre: genre,
            releaseDate: Date(),
            artworkName: "nest_music",
            youtubeVideoID: videoID(from: watchURLString) ?? discovery?.youtubeVideoMatch?.videoID,
            youtubeWatchURLString: watchURLString,
            confidenceLabel: mappedSearch.backendConfidence ?? firstResult?.confidenceLabel ?? mappedSearch.matches.first?.confidencePercentText,
            matchedProducerChannelName: channel?.channelID ?? channel?.producerName,
            producerTagConfidence: discovery?.producerTagConfidence,
            discoveryStatus: status,
            youtubeVideoMatchTitle: discovery?.youtubeVideoMatch?.title,
            possibleReasons: discovery?.possibleReasons,
            recommendedNextSearches: discovery?.recommendedNextSearches
        )
    }

    var youtubeThumbnailURL: URL? {
        if let youtubeVideoID, !youtubeVideoID.isEmpty {
            return URL(string: "https://i.ytimg.com/vi/\(youtubeVideoID)/hqdefault.jpg")
        }

        guard let youtubeWatchURLString, let components = URLComponents(string: youtubeWatchURLString) else {
            return nil
        }

        if let value = components.queryItems?.first(where: { $0.name == "v" })?.value, !value.isEmpty {
            return URL(string: "https://i.ytimg.com/vi/\(value)/hqdefault.jpg")
        }

        if let host = components.host, host.contains("youtu.be"), let identifier = components.path.split(separator: "/").last {
            return URL(string: "https://i.ytimg.com/vi/\(identifier)/hqdefault.jpg")
        }

        return nil
    }

    var hasBackendDiscoveryDetails: Bool {
        confidenceLabel != nil ||
        matchedProducerChannelName != nil ||
        producerTagConfidence != nil ||
        discoveryStatus != nil ||
        youtubeVideoMatchTitle != nil ||
        !(possibleReasons ?? []).isEmpty ||
        !(recommendedNextSearches ?? []).isEmpty
    }

    private static func videoID(from watchURLString: String?) -> String? {
        guard let watchURLString, let components = URLComponents(string: watchURLString) else {
            return nil
        }

        if let value = components.queryItems?.first(where: { $0.name == "v" })?.value, !value.isEmpty {
            return value
        }

        if let host = components.host, host.contains("youtu.be"), let identifier = components.path.split(separator: "/").last {
            return String(identifier)
        }

        return nil
    }
}

private extension String {
    var readableBackendToken: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}

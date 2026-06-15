import Foundation

enum BeatPlatform: String, Codable, CaseIterable, Hashable {
    case youtube
    case soundcloud
    case spotify
    case appleMusic
    case unknown

    init(rawPlatform: String?) {
        let normalized = (rawPlatform ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "youtube", "yt":
            self = .youtube
        case "soundcloud", "sc":
            self = .soundcloud
        case "spotify":
            self = .spotify
        case "applemusic", "apple_music", "apple music":
            self = .appleMusic
        default:
            self = .unknown
        }
    }

    init(rawPlatform: String?, sourceURL: String?) {
        let explicit = BeatPlatform(rawPlatform: rawPlatform)
        guard explicit == .unknown else {
            self = explicit
            return
        }

        let normalizedURL = (sourceURL ?? "").lowercased()
        if normalizedURL.contains("youtube.com") || normalizedURL.contains("youtu.be") {
            self = .youtube
        } else if normalizedURL.contains("soundcloud.com") {
            self = .soundcloud
        } else if normalizedURL.contains("spotify.com") {
            self = .spotify
        } else if normalizedURL.contains("music.apple.com") {
            self = .appleMusic
        } else {
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .youtube: return "YouTube"
        case .soundcloud: return "SoundCloud"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .unknown: return "Web"
        }
    }

    var iconName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .soundcloud: return "waveform.circle.fill"
        case .spotify: return "music.note.list"
        case .appleMusic: return "music.quarternote.3"
        case .unknown: return "globe"
        }
    }
}

enum BeatMatchVerdict: String, Codable, Hashable {
    case exact
    case similar
    case lowConfidence

    var title: String {
        switch self {
        case .exact: return "Exact"
        case .similar: return "Similar"
        case .lowConfidence: return "Low confidence"
        }
    }
}

enum BeatSearchSource: String, Codable, Hashable {
    case backendAPI = "backend_api"
    case edgeFunction
    case mockFallback

    var badgeTitle: String {
        switch self {
        case .backendAPI:
            return "API"
        case .edgeFunction:
            return "LIVE"
        case .mockFallback:
            return "MVP"
        }
    }
}

enum BeatSearchResultState: String, Codable, Hashable {
    case exactMatch = "exact_match"
    case closeMatches = "close_matches"
    case notFound = "not_found"

    var title: String {
        switch self {
        case .exactMatch:
            return "Exact match"
        case .closeMatches:
            return "Close matches"
        case .notFound:
            return "Not found"
        }
    }
}

struct BeatSearchMatch: Identifiable, Codable, Hashable {
    let id: UUID
    let remoteMatchID: UUID?
    let platform: BeatPlatform
    let url: String
    let title: String
    let similarity: Double
    let bpm: Int?
    let key: String?
    let verdict: BeatMatchVerdict
    let note: String?

    init(
        id: UUID = UUID(),
        remoteMatchID: UUID? = nil,
        platform: BeatPlatform,
        url: String,
        title: String,
        similarity: Double,
        bpm: Int? = nil,
        key: String? = nil,
        verdict: BeatMatchVerdict,
        note: String? = nil
    ) {
        self.id = id
        self.remoteMatchID = remoteMatchID
        self.platform = platform
        self.url = url
        self.title = title
        self.similarity = max(0, min(1, similarity))
        self.bpm = bpm
        self.key = key
        self.verdict = verdict
        self.note = note
    }

    var confidencePercentText: String {
        "\(Int((similarity * 100).rounded()))%"
    }

    func withRemoteMatchID(_ remoteMatchID: UUID?) -> BeatSearchMatch {
        BeatSearchMatch(
            id: id,
            remoteMatchID: remoteMatchID,
            platform: platform,
            url: url,
            title: title,
            similarity: similarity,
            bpm: bpm,
            key: key,
            verdict: verdict,
            note: note
        )
    }
}

struct BeatSearchResponse: Codable {
    let query: String
    let source: BeatSearchSource
    let resultState: BeatSearchResultState
    let likelyCustom: Bool
    let summary: String
    let matches: [BeatSearchMatch]
    let backendQueryID: String?
    let backendConfidence: String?
    let discovery: DiscoveryEnrichment?

    init(
        query: String,
        source: BeatSearchSource,
        resultState: BeatSearchResultState,
        likelyCustom: Bool,
        summary: String,
        matches: [BeatSearchMatch],
        backendQueryID: String? = nil,
        backendConfidence: String? = nil,
        discovery: DiscoveryEnrichment? = nil
    ) {
        self.query = query
        self.source = source
        self.resultState = resultState
        self.likelyCustom = likelyCustom
        self.summary = summary
        self.matches = matches
        self.backendQueryID = backendQueryID
        self.backendConfidence = backendConfidence
        self.discovery = discovery
    }
}

extension BeatSearchResponse {
    static func backendAPI(query: String, response: SearchResponse) -> BeatSearchResponse {
        let matches = response.results.map { result in
            let beat = result.beat
            let url = beat.sourceURL ?? response.discovery?.youtubeVideoMatch?.videoURL ?? ""
            let similarity = result.rerankScore ?? result.signatureScore ?? result.embeddingScore ?? result.metadataScore ?? 0

            return BeatSearchMatch(
                id: UUID(uuidString: beat.id ?? "") ?? UUID(),
                remoteMatchID: UUID(uuidString: beat.id ?? ""),
                platform: BeatPlatform(rawPlatform: beat.sourcePlatform, sourceURL: url),
                url: url,
                title: beat.displayTitle,
                similarity: similarity,
                bpm: beat.bpm.map { Int($0.rounded()) },
                key: beat.musicalKey,
                verdict: BeatMatchVerdict.backendVerdict(
                    confidenceLabel: result.confidenceLabel ?? response.confidence,
                    score: similarity
                ),
                note: result.explanation ?? beat.producerName
            )
        }

        let resultState = BeatSearchResultState.backendState(
            confidence: response.confidence,
            matches: matches,
            discovery: response.discovery
        )

        return BeatSearchResponse(
            query: query,
            source: .backendAPI,
            resultState: resultState,
            likelyCustom: resultState == .notFound,
            summary: backendSummary(for: resultState, discovery: response.discovery),
            matches: matches,
            backendQueryID: response.queryID,
            backendConfidence: response.confidence,
            discovery: response.discovery
        )
    }

    private static func backendSummary(
        for resultState: BeatSearchResultState,
        discovery: DiscoveryEnrichment?
    ) -> String {
        switch discovery?.discoveryStatus {
        case "found_candidate":
            return "Possible match found through indexed producer discovery."
        case "possible_sold_or_deleted":
            return "Producer found, but no matching visible indexed video was found."
        case "insufficient_evidence":
            return "Producer evidence is weak. Review candidates before calling this a match."
        default:
            switch resultState {
            case .exactMatch:
                return "Likely exact match found by the BeatFinder backend."
            case .closeMatches:
                return "Strong candidates found. Review the ranked results."
            case .notFound:
                return "No confident exact match found in the current backend index."
            }
        }
    }
}

private extension BeatMatchVerdict {
    static func backendVerdict(confidenceLabel: String?, score: Double) -> BeatMatchVerdict {
        let normalized = (confidenceLabel ?? "").lowercased()
        if normalized.contains("exact") || score >= 0.9 {
            return .exact
        }
        if normalized.contains("candidate") || score >= 0.7 {
            return .similar
        }
        return .lowConfidence
    }
}

private extension BeatSearchResultState {
    static func backendState(
        confidence: String?,
        matches: [BeatSearchMatch],
        discovery: DiscoveryEnrichment?
    ) -> BeatSearchResultState {
        let normalized = (confidence ?? "").lowercased()
        if normalized.contains("exact") || matches.first?.verdict == .exact {
            return .exactMatch
        }
        if discovery?.discoveryStatus == "found_candidate" {
            return .closeMatches
        }
        if matches.contains(where: { $0.verdict == .similar }) {
            return .closeMatches
        }
        return matches.isEmpty ? .notFound : .closeMatches
    }
}

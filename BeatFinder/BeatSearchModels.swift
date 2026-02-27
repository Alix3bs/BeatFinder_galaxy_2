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
    case edgeFunction
    case mockFallback
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
}

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
        youtubeWatchURLString: String? = nil
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
    }
}

extension BeatResultModel {
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
}

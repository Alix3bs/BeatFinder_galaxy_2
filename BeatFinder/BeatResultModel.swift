import Foundation

struct BeatResultModel: Codable {
    let id: String
    let title: String
    let artist: String
    let bpm: Int
    let genre: String
    let releaseDate: Date
    let artworkName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case bpm
        case genre
        case releaseDate = "release_date"
        case artworkName = "artwork_name"
    }
}


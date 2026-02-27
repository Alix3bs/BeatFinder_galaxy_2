import Foundation

/// Shared lightweight model used across Feed + Explore UI.
///
/// Over time, different screens were written against slightly different mock models.
/// This struct intentionally supports both:
/// - "artist / bpm / artworkName" (used in Explore hero + result screens)
/// - "producer / plays / likes / audioFileName" (used in feed/explore cards)
///
/// That keeps the project compiling even if some mock data was authored
/// with a different initializer signature.
struct FeedBeat: Identifiable, Hashable {
    let id: UUID

    // Core display fields
    let title: String
    let genre: String
    let price: String

    // "Artist" style fields
    let artist: String
    let bpm: Int
    let artworkName: String?

    // "Producer" style fields (used by cards)
    let producer: String
    let plays: String
    let likes: String
    let audioFileName: String?

    /// Bundle URL for an mp3 named `audioFileName` (without extension).
    var audioURL: URL? {
        guard let audioFileName, !audioFileName.isEmpty else { return nil }
        return Bundle.main.url(forResource: audioFileName, withExtension: "mp3")
    }

    /// Flexible initializer with sensible defaults.
    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        genre: String,
        bpm: Int = 0,
        price: String,
        artworkName: String? = nil,
        producer: String? = nil,
        plays: String = "0",
        likes: String = "0",
        audioFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.genre = genre
        self.bpm = bpm
        self.price = price
        self.artworkName = artworkName

        // If producer not provided, use artist.
        self.producer = producer ?? artist
        self.plays = plays
        self.likes = likes
        self.audioFileName = audioFileName
    }
}

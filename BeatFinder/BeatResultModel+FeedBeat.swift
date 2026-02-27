import Foundation

extension BeatResultModel {
    init(from beat: FeedBeat) {
        self.init(
            id: beat.id.uuidString,
            title: beat.title,
            artist: beat.artist,
            bpm: beat.bpm,
            genre: beat.genre,
            releaseDate: Date(),
            artworkName: beat.artworkName
        )
    }
}

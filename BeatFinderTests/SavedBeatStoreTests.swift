import Foundation
import Testing
@testable import BeatFinder

@MainActor
struct SavedBeatStoreTests {
    @Test func savesResultLocally() {
        let store = makeStore()
        let result = makeResult(id: "beat-1", title: "SZA x Summer Walker Type Beat - Late Nights")

        let didSave = store.save(result)

        #expect(didSave)
        #expect(store.savedBeats.count == 1)
        #expect(store.savedBeats.first?.result.title == "SZA x Summer Walker Type Beat - Late Nights")
    }

    @Test func duplicateResultDoesNotSaveTwiceByIDYouTubeOrTitleFallback() {
        let store = makeStore()
        let first = makeResult(id: "beat-1", title: "Late Nights", youtubeVideoID: "salishan-001")
        let sameID = makeResult(id: "beat-1", title: "Late Nights Alt", youtubeVideoID: "salishan-002")
        let sameYouTube = makeResult(id: "beat-2", title: "Different Title", youtubeVideoID: "salishan-001")
        let sameTitleFallback = makeResult(id: "beat-3", title: "Late Nights", youtubeVideoID: nil)

        #expect(store.save(first))
        #expect(!store.save(sameID))
        #expect(!store.save(sameYouTube))
        #expect(!store.save(sameTitleFallback))
        #expect(store.savedBeats.count == 1)
    }

    @Test func removesSavedResult() {
        let store = makeStore()
        let result = makeResult(id: "beat-1", title: "Late Nights")
        store.save(result)

        store.remove(result)

        #expect(store.savedBeats.isEmpty)
        #expect(!store.isSaved(result))
    }

    @Test func loadsPersistedResults() {
        let defaults = makeDefaults()
        let key = "saved-beat-store-tests"
        let result = makeResult(id: "beat-1", title: "Late Nights")

        let firstStore = SavedBeatStore(defaults: defaults, storageKey: key)
        firstStore.save(result)

        let reloadedStore = SavedBeatStore(defaults: defaults, storageKey: key)

        #expect(reloadedStore.savedBeats.count == 1)
        #expect(reloadedStore.savedBeats.first?.result.id == "beat-1")
    }

    @Test func savedMappingKeepsDiscoveryAndYouTubeMatchInfo() {
        let store = makeStore()
        let result = makeResult(
            id: "beat-1",
            title: "SZA x Summer Walker Type Beat - Late Nights",
            youtubeVideoID: "salishan-001",
            discoveryStatus: "found_candidate",
            youtubeVideoMatchTitle: "SZA x Summer Walker Type Beat - Late Nights"
        )

        store.save(result)
        let saved = store.savedBeats.first

        #expect(saved?.result.discoveryStatus == "found_candidate")
        #expect(saved?.result.youtubeVideoMatchTitle == "SZA x Summer Walker Type Beat - Late Nights")
        #expect(saved?.result.matchedProducerChannelName == "prod.salishan")
        #expect(saved?.result.recommendedNextSearches == ["prod salishan type beat", "philly type beat"])
    }

    private func makeStore() -> SavedBeatStore {
        SavedBeatStore(defaults: makeDefaults(), storageKey: UUID().uuidString)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "beatfinder.saved-beat-store-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeResult(
        id: String,
        title: String,
        youtubeVideoID: String? = "salishan-001",
        discoveryStatus: String? = "found_candidate",
        youtubeVideoMatchTitle: String? = "SZA x Summer Walker Type Beat - Late Nights"
    ) -> BeatResultModel {
        BeatResultModel(
            id: id,
            title: title,
            artist: "prod salishan",
            bpm: 92,
            genre: "rnb",
            releaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            artworkName: "nest_music",
            youtubeVideoID: youtubeVideoID,
            youtubeWatchURLString: youtubeVideoID.map { "https://www.youtube.com/watch?v=\($0)" },
            confidenceLabel: "likely_exact_match",
            matchedProducerChannelName: "prod.salishan",
            producerTagConfidence: 0.9,
            discoveryStatus: discoveryStatus,
            youtubeVideoMatchTitle: youtubeVideoMatchTitle,
            possibleReasons: [],
            recommendedNextSearches: ["prod salishan type beat", "philly type beat"]
        )
    }
}

import Foundation
import Testing
@testable import BeatFinder

@MainActor
struct SearchHistoryStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "beatfinder.tests.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func recordsAndPersistsEntries() {
        let defaults = makeDefaults()
        let store = SearchHistoryStore(defaults: defaults)
        store.record(query: "philly type beat", mode: "Text", topResultTitle: "Late Nights")

        #expect(store.entries.count == 1)
        #expect(store.entries[0].query == "philly type beat")
        #expect(store.entries[0].topResultTitle == "Late Nights")

        let reloaded = SearchHistoryStore(defaults: defaults)
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries[0].query == "philly type beat")
    }

    @Test func duplicateQueriesMoveToTopWithoutDuplication() {
        let store = SearchHistoryStore(defaults: makeDefaults())
        store.record(query: "detroit type beat", mode: "Text", topResultTitle: nil)
        store.record(query: "philly type beat", mode: "Text", topResultTitle: nil)
        store.record(query: "Detroit Type Beat", mode: "Text", topResultTitle: "Tunnel Vision")

        #expect(store.entries.count == 2)
        #expect(store.entries[0].query == "Detroit Type Beat")
        #expect(store.entries[0].topResultTitle == "Tunnel Vision")
    }

    @Test func capsEntriesAtMaximum() {
        let store = SearchHistoryStore(defaults: makeDefaults())
        for index in 0..<40 {
            store.record(query: "query \(index)", mode: "Text", topResultTitle: nil)
        }
        #expect(store.entries.count == SearchHistoryStore.maxEntries)
        #expect(store.entries[0].query == "query 39")
    }

    @Test func ignoresEmptyQueries() {
        let store = SearchHistoryStore(defaults: makeDefaults())
        store.record(query: "   ", mode: "Text", topResultTitle: nil)
        #expect(store.entries.isEmpty)
    }

    @Test func clearRemovesEverything() {
        let defaults = makeDefaults()
        let store = SearchHistoryStore(defaults: defaults)
        store.record(query: "philly type beat", mode: "Text", topResultTitle: nil)
        store.clear()
        #expect(store.entries.isEmpty)
        #expect(SearchHistoryStore(defaults: defaults).entries.isEmpty)
    }

    @Test func salvagesDecodableEntriesFromCorruptedData() throws {
        let defaults = makeDefaults()
        let good: [String: Any] = [
            "id": UUID().uuidString,
            "query": "philly type beat",
            "mode": "Text",
            "searchedAt": Date().timeIntervalSinceReferenceDate,
        ]
        let bad: [String: Any] = ["unexpected": "shape"]
        let data = try JSONSerialization.data(withJSONObject: [good, bad])
        defaults.set(data, forKey: "beatfinder.search.history.v1")

        let store = SearchHistoryStore(defaults: defaults)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].query == "philly type beat")
    }
}

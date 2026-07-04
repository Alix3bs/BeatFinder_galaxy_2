import Combine
import Foundation

struct SearchHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let query: String
    let mode: String
    let topResultTitle: String?
    let searchedAt: Date

    init(
        id: UUID = UUID(),
        query: String,
        mode: String,
        topResultTitle: String? = nil,
        searchedAt: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.mode = mode
        self.topResultTitle = topResultTitle
        self.searchedAt = searchedAt
    }
}

/// Local, offline-safe search history. Stores only what the user typed and
/// the top result title — no audio, no personal data.
@MainActor
final class SearchHistoryStore: ObservableObject {
    static let currentSchemaVersion = 1
    static let maxEntries = 25

    @Published private(set) var entries: [SearchHistoryEntry] = []

    private let defaults: UserDefaults
    private let storageKey: String
    private let versionKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "beatfinder.search.history.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.versionKey = "\(storageKey).schema"
        load()
    }

    func record(query: String, mode: String, topResultTitle: String?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Re-running the same query moves it to the top instead of duplicating.
        entries.removeAll { entry in
            entry.query.caseInsensitiveCompare(trimmed) == .orderedSame && entry.mode == mode
        }
        entries.insert(
            SearchHistoryEntry(query: trimmed, mode: mode, topResultTitle: topResultTitle),
            at: 0
        )
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        persist()
    }

    func remove(_ entry: SearchHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }
}

private extension SearchHistoryStore {
    func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
        defaults.set(Self.currentSchemaVersion, forKey: versionKey)
    }

    func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = []
            return
        }
        if let decoded = try? JSONDecoder().decode([SearchHistoryEntry].self, from: data) {
            entries = decoded
            return
        }
        // Schema changed or data corrupted: salvage decodable entries
        // individually rather than silently losing the whole history.
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            var salvaged: [SearchHistoryEntry] = []
            for element in raw {
                guard
                    let elementData = try? JSONSerialization.data(withJSONObject: element),
                    let entry = try? JSONDecoder().decode(SearchHistoryEntry.self, from: elementData)
                else { continue }
                salvaged.append(entry)
            }
            entries = Array(salvaged.prefix(Self.maxEntries))
            persist()
            return
        }
        entries = []
    }
}

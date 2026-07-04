import Combine
import Foundation

struct SavedBeat: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let result: BeatResultModel
    let savedAt: Date

    init(result: BeatResultModel, savedAt: Date = Date()) {
        self.result = result
        self.savedAt = savedAt
        self.id = SavedBeatStore.primaryDedupeKey(for: result)
    }
}

@MainActor
final class SavedBeatStore: ObservableObject {
    @Published private(set) var savedBeats: [SavedBeat] = []

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "beatfinder.safe.saved_beats.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    @discardableResult
    func save(_ result: BeatResultModel) -> Bool {
        guard !isSaved(result) else { return false }
        savedBeats.insert(SavedBeat(result: result), at: 0)
        persist()
        return true
    }

    func isSaved(_ result: BeatResultModel) -> Bool {
        let incomingKeys = Set(Self.dedupeKeys(for: result))
        return savedBeats.contains { saved in
            !incomingKeys.isDisjoint(with: Set(Self.dedupeKeys(for: saved.result)))
        }
    }

    func remove(_ result: BeatResultModel) {
        let incomingKeys = Set(Self.dedupeKeys(for: result))
        savedBeats.removeAll { saved in
            !incomingKeys.isDisjoint(with: Set(Self.dedupeKeys(for: saved.result)))
        }
        persist()
    }

    func remove(_ savedBeat: SavedBeat) {
        savedBeats.removeAll { $0.id == savedBeat.id }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where savedBeats.indices.contains(index) {
            savedBeats.remove(at: index)
        }
        persist()
    }

    nonisolated static func primaryDedupeKey(for result: BeatResultModel) -> String {
        dedupeKeys(for: result).first ?? "title:\(normalized(result.title))"
    }

    nonisolated static func dedupeKeys(for result: BeatResultModel) -> [String] {
        var keys: [String] = []

        let beatID = normalized(result.id)
        if !beatID.isEmpty {
            keys.append("beat:\(beatID)")
        }

        if let youtubeVideoID = result.youtubeVideoID.map(normalized), !youtubeVideoID.isEmpty {
            keys.append("youtube:\(youtubeVideoID)")
        }

        if let watchURLVideoID = videoID(from: result.youtubeWatchURLString).map(normalized), !watchURLVideoID.isEmpty {
            keys.append("youtube:\(watchURLVideoID)")
        }

        let title = normalized(result.title)
        let artist = normalized(result.artist)
        if !title.isEmpty {
            keys.append("title:\(title)|artist:\(artist)")
        }

        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}

private extension SavedBeatStore {
    func persist() {
        guard let data = try? JSONEncoder().encode(savedBeats) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            savedBeats = []
            return
        }
        if let decoded = try? JSONDecoder().decode([SavedBeat].self, from: data) {
            savedBeats = decoded
            return
        }
        // Migration/corruption path: salvage every decodable element instead
        // of dropping the entire Safe when one entry no longer decodes.
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            var salvaged: [SavedBeat] = []
            for element in raw {
                guard
                    let elementData = try? JSONSerialization.data(withJSONObject: element),
                    let beat = try? JSONDecoder().decode(SavedBeat.self, from: elementData)
                else { continue }
                salvaged.append(beat)
            }
            savedBeats = salvaged
            persist()
            return
        }
        savedBeats = []
    }

    nonisolated static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    nonisolated static func videoID(from watchURLString: String?) -> String? {
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

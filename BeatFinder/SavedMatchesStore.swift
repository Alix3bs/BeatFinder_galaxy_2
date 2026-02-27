import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
final class SavedMatchesStore: ObservableObject {
    @Published private(set) var savedMatches: [BeatSearchMatch] = []

    private let defaultsKey = "beatfinder.saved_matches.v1"

    init() {
        load()
    }

    func isSaved(_ match: BeatSearchMatch) -> Bool {
        savedMatches.contains(where: { $0.id == match.id || ($0.url == match.url && $0.title == match.title) })
    }

    func save(_ match: BeatSearchMatch, userId: UUID? = nil) {
        guard !isSaved(match) else { return }
        savedMatches.insert(match, at: 0)
        persist()

        Task {
            await insertRemoteSavedMatch(match, userId: userId)
        }
    }

    func remove(_ match: BeatSearchMatch, userId: UUID? = nil) {
        savedMatches.removeAll { $0.id == match.id || ($0.url == match.url && $0.title == match.title) }
        persist()

        Task {
            await deleteRemoteSavedMatch(match, userId: userId)
        }
    }

    func toggle(_ match: BeatSearchMatch, userId: UUID? = nil) {
        if isSaved(match) {
            remove(match, userId: userId)
        } else {
            save(match, userId: userId)
        }
    }

    func remove(at offsets: IndexSet, userId: UUID? = nil) {
        let removed = offsets.compactMap { idx in
            savedMatches.indices.contains(idx) ? savedMatches[idx] : nil
        }
        for idx in offsets.sorted(by: >) where savedMatches.indices.contains(idx) {
            savedMatches.remove(at: idx)
        }
        persist()

        guard let userId else { return }
        Task {
            for match in removed {
                await deleteRemoteSavedMatch(match, userId: userId)
            }
        }
    }

    func syncFromRemote(userId: UUID?) async {
        guard let userId else {
            savedMatches = []
            persist()
            return
        }

        do {
            let remote = try await fetchRemoteSavedMatches(userId: userId)
            savedMatches = merged(remoteMatches: remote, localMatches: savedMatches)
            persist()
        } catch {
            // Local fallback remains active when remote sync fails.
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedMatches) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([BeatSearchMatch].self, from: data) else { return }
        savedMatches = decoded
    }

    private func insertRemoteSavedMatch(_ match: BeatSearchMatch, userId: UUID?) async {
        guard let userId, let remoteMatchID = match.remoteMatchID else { return }

        do {
            let row = SavedBeatInsertRow(
                user_id: userId.uuidString,
                beat_id: remoteMatchID.uuidString,
                notes: nil
            )

            _ = try await SupabaseManager.client
                .from("saved_matches")
                .insert(row)
                .execute()
        } catch {
            // Backward compatibility for old schema where saved_matches references matches(id).
            do {
                let legacy = SavedMatchInsertRow(
                    user_id: userId.uuidString,
                    match_id: remoteMatchID.uuidString,
                    notes: nil
                )
                _ = try await SupabaseManager.client
                    .from("saved_matches")
                    .insert(legacy)
                    .execute()
            } catch {
                // Local bookmark remains source of truth if remote insert fails.
            }
        }
    }

    private func deleteRemoteSavedMatch(_ match: BeatSearchMatch, userId: UUID?) async {
        guard let userId, let remoteMatchID = match.remoteMatchID else { return }

        do {
            _ = try await SupabaseManager.client
                .from("saved_matches")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("beat_id", value: remoteMatchID.uuidString)
                .execute()
        } catch {
            // Backward compatibility for old schema where saved_matches references matches(id).
            do {
                _ = try await SupabaseManager.client
                    .from("saved_matches")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("match_id", value: remoteMatchID.uuidString)
                    .execute()
            } catch {
                // Local removal remains source of truth in MVP if remote delete fails.
            }
        }
    }

    func fetchRemoteSavedMatches(userId: UUID) async throws -> [BeatSearchMatch] {
        var beatLinked: [BeatSearchMatch] = []
        do {
            let response = try await SupabaseManager.client
                .from("saved_matches")
                .select("created_at,notes,beats!inner(id,platform,source_url,title,bpm,key)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()

            beatLinked = parseSavedRows(responseData: response.data, relationKey: "beats", defaultSimilarity: 1)
        } catch {
            // ignore and try legacy relation below
        }

        var legacyLinked: [BeatSearchMatch] = []
        do {
            let response = try await SupabaseManager.client
                .from("saved_matches")
                .select("created_at,notes,matches!inner(id,platform,url,title,similarity,bpm,key)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()

            legacyLinked = parseSavedRows(responseData: response.data, relationKey: "matches", defaultSimilarity: nil)
        } catch {
            // ignore
        }

        if beatLinked.isEmpty { return legacyLinked }
        if legacyLinked.isEmpty { return beatLinked }
        return merged(remoteMatches: beatLinked, localMatches: legacyLinked)
    }

    func parseSavedRows(responseData: Data, relationKey: String, defaultSimilarity: Double?) -> [BeatSearchMatch] {
        guard let rows = try? JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            let notes = row["notes"] as? String
            let maybePayload = row[relationKey]
            let payload = (maybePayload as? [String: Any]) ?? (maybePayload as? [[String: Any]])?.first

            guard
                let payload,
                let idRaw = payload["id"] as? String,
                let remoteMatchID = UUID(uuidString: idRaw),
                let title = payload["title"] as? String
            else {
                return nil
            }

            let platformRaw = payload["platform"] as? String
            let url = (payload["url"] as? String) ?? (payload["source_url"] as? String) ?? ""
            guard !url.isEmpty else { return nil }

            let similarity = number(from: payload["similarity"]) ?? defaultSimilarity ?? 0
            let verdict: BeatMatchVerdict
            if similarity >= 0.92 {
                verdict = .exact
            } else if similarity >= 0.72 {
                verdict = .similar
            } else {
                verdict = .lowConfidence
            }

            return BeatSearchMatch(
                remoteMatchID: remoteMatchID,
                platform: BeatPlatform(rawPlatform: platformRaw),
                url: url,
                title: title,
                similarity: similarity,
                bpm: int(from: payload["bpm"]),
                key: payload["key"] as? String,
                verdict: verdict,
                note: notes
            )
        }
    }

    func merged(remoteMatches: [BeatSearchMatch], localMatches: [BeatSearchMatch]) -> [BeatSearchMatch] {
        var merged: [BeatSearchMatch] = []
        var keys = Set<String>()

        for match in remoteMatches {
            let key = dedupeKey(for: match)
            guard !keys.contains(key) else { continue }
            merged.append(match)
            keys.insert(key)
        }

        for match in localMatches {
            let key = dedupeKey(for: match)
            guard !keys.contains(key) else { continue }
            merged.append(match)
            keys.insert(key)
        }

        return merged
    }

    func dedupeKey(for match: BeatSearchMatch) -> String {
        if let remoteMatchID = match.remoteMatchID {
            return "remote:\(remoteMatchID.uuidString)"
        }
        return "local:\(match.url.lowercased())|\(match.title.lowercased())"
    }

    func number(from value: Any?) -> Double? {
        switch value {
        case let n as Double:
            return n
        case let n as Int:
            return Double(n)
        case let n as String:
            return Double(n)
        default:
            return nil
        }
    }

    func int(from value: Any?) -> Int? {
        switch value {
        case let n as Int:
            return n
        case let n as Double:
            return Int(n.rounded())
        case let n as String:
            return Int(n)
        default:
            return nil
        }
    }
}

private struct SavedMatchInsertRow: Encodable {
    let user_id: String
    let match_id: String
    let notes: String?
}

private struct SavedBeatInsertRow: Encodable {
    let user_id: String
    let beat_id: String
    let notes: String?
}

import Foundation
import Combine
import Supabase

struct SearchBeat: Identifiable, Hashable {
    let id: UUID
    let title: String
    let producer: String
    let genre: String
    let bpm: Int?
    let sourceURL: String?
}

@MainActor
final class SearchService: ObservableObject {
    @Published var results: [SearchBeat] = []
    @Published var isLoading = false
    @Published var statusText: String = ""

    func search(_ q: String) async {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            results = []
            statusText = ""
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await SupabaseManager.client
                .from("beats")
                .select("id,title,producer,genre,bpm,source_url,visibility,producer_tag_text")
                .eq("visibility", value: "public")
                .or(makeOrFilter(query))
                .limit(50)
                .execute()

            results = parseRows(response.data)
            statusText = ""
        } catch {
            // Fallback for schemas missing producer/producer_tag_text/visibility columns.
            do {
                let fallback = try await SupabaseManager.client
                    .from("beats")
                    .select("id,title,genre,bpm,source_url")
                    .or(makeFallbackOrFilter(query))
                    .limit(50)
                    .execute()

                results = parseRows(fallback.data)
                statusText = ""
            } catch {
                statusText = "Search failed."
                results = []
            }
        }
    }

    private func makeOrFilter(_ query: String) -> String {
        let escaped = query.replacingOccurrences(of: ",", with: "\\,")
        return "title.ilike.%\(escaped)%,producer.ilike.%\(escaped)%,genre.ilike.%\(escaped)%,producer_tag_text.ilike.%\(escaped)%"
    }

    private func makeFallbackOrFilter(_ query: String) -> String {
        let escaped = query.replacingOccurrences(of: ",", with: "\\,")
        return "title.ilike.%\(escaped)%,genre.ilike.%\(escaped)%"
    }

    private func parseRows(_ data: Data) -> [SearchBeat] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard
                let idRaw = row["id"] as? String,
                let id = UUID(uuidString: idRaw),
                let title = row["title"] as? String,
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let producer = (row["producer"] as? String) ??
                (row["artist"] as? String) ??
                "Unknown"

            let genre = (row["genre"] as? String) ?? "Unknown"
            let bpm = parseInt(row["bpm"])
            let sourceURL = row["source_url"] as? String

            return SearchBeat(
                id: id,
                title: title,
                producer: producer,
                genre: genre,
                bpm: bpm,
                sourceURL: sourceURL
            )
        }
    }

    private func parseInt(_ value: Any?) -> Int? {
        switch value {
        case let n as Int:
            return n
        case let n as Double:
            return Int(n.rounded())
        case let s as String:
            return Int(s)
        default:
            return nil
        }
    }
}

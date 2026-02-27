import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
final class BeatSearchViewModel: ObservableObject {
    enum QueryInputMode: String, CaseIterable, Identifiable {
        case text = "Text"
        case link = "Link"
        case upload = "Upload"
        case record = "Record"

        var id: String { rawValue }
    }

    @Published var query: String = ""
    @Published var inputMode: QueryInputMode = .text
    @Published private(set) var isSearching = false
    @Published private(set) var isPreparingSnippet = false
    @Published private(set) var response: BeatSearchResponse?
    @Published private(set) var matches: [BeatSearchMatch] = []
    @Published private(set) var preparedSnippetLabel: String?
    @Published var errorText: String?

    private let searchService: BeatSearchService

    init(searchService: BeatSearchService? = nil) {
        self.searchService = searchService ?? .shared
    }

    func search(forceWeb: Bool, userId: UUID?) {
        let currentQuery = query
        let currentMode = inputMode
        Task {
            await executeSearch(query: currentQuery, mode: currentMode, forceWeb: forceWeb, userId: userId)
        }
    }

    func clear() {
        response = nil
        matches = []
        preparedSnippetLabel = nil
        errorText = nil
    }

    func ingestSnippetAndSearch(fileURL: URL, mode: QueryInputMode, userId: UUID?) async {
        guard mode == .upload || mode == .record else { return }
        guard let userId else {
            errorText = "Sign in to upload a snippet."
            return
        }

        errorText = nil
        isPreparingSnippet = true
        defer { isPreparingSnippet = false }

        do {
            let snippetURL = try await searchService.uploadSnippet(fileURL: fileURL, userId: userId)
            preparedSnippetLabel = fileURL.lastPathComponent
            inputMode = mode
            query = snippetURL
            await executeSearch(query: snippetURL, mode: mode, forceWeb: false, userId: userId)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private extension BeatSearchViewModel {
    func executeSearch(query: String, mode: QueryInputMode, forceWeb: Bool, userId: UUID?) async {
        errorText = nil
        guard let userId else {
            response = nil
            matches = []
            errorText = "Sign in to search indexed beats."
            return
        }
        if mode == .text || mode == .link {
            preparedSnippetLabel = nil
        }
        isSearching = true
        defer { isSearching = false }

        do {
            let result: BeatSearchResponse
            let queryType: String

            switch mode {
            case .text:
                result = try await searchService.searchText(query: query, forceWeb: forceWeb)
                queryType = forceWeb ? "text_web" : "text"
            case .link:
                result = try await searchService.matchAudio(snippetURL: nil, sourceURL: query)
                queryType = "link"
            case .upload:
                result = try await searchService.matchAudio(snippetURL: query, sourceURL: nil)
                queryType = "upload_snippet"
            case .record:
                result = try await searchService.matchAudio(snippetURL: query, sourceURL: nil)
                queryType = "record_snippet"
            }

            let persistedMatches = await persistSearch(
                query: result.query,
                queryType: queryType,
                userId: userId,
                matches: result.matches
            ) ?? result.matches

            response = BeatSearchResponse(
                query: result.query,
                source: result.source,
                resultState: result.resultState,
                likelyCustom: result.likelyCustom,
                summary: result.summary,
                matches: persistedMatches
            )
            matches = persistedMatches
        } catch {
            response = nil
            matches = []
            errorText = error.localizedDescription
        }
    }

    func persistSearch(
        query: String,
        queryType: String,
        userId: UUID?,
        matches: [BeatSearchMatch]
    ) async -> [BeatSearchMatch]? {
        guard let userId else { return matches }

        do {
            let searchInsert = SearchInsertRow(
                user_id: userId.uuidString,
                query_type: queryType,
                query_text: query
            )

            let inserted: [InsertedSearchID] = try await SupabaseManager.client
                .from("searches")
                .insert(searchInsert)
                .select("id")
                .limit(1)
                .execute()
                .value

            guard inserted.first?.id != nil else { return matches }
            return matches
        } catch {
            // Non-fatal: search UI still works if optional search logging table isn't available.
            return matches
        }
    }
}

private struct SearchInsertRow: Encodable {
    let user_id: String
    let query_type: String
    let query_text: String
}

private struct InsertedSearchID: Decodable {
    let id: UUID
}

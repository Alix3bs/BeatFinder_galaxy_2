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
    @Published var detectedProducerTag: String = ""
    @Published var inputMode: QueryInputMode = .text
    @Published private(set) var isSearching = false
    @Published private(set) var isPreparingSnippet = false
    @Published private(set) var response: BeatSearchResponse?
    @Published private(set) var matches: [BeatSearchMatch] = []
    @Published private(set) var preparedSnippetLabel: String?
    @Published var errorText: String?

    private let apiClient: BeatFinderBackendAPIClientProtocol
    private let topN: Int

    init(
        apiClient: BeatFinderBackendAPIClientProtocol? = nil,
        topN: Int = 3
    ) {
        self.apiClient = apiClient ?? BeatFinderAPIClient()
        self.topN = topN
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

        errorText = nil
        isPreparingSnippet = true
        defer { isPreparingSnippet = false }

        preparedSnippetLabel = fileURL.lastPathComponent
        inputMode = mode
        query = fileURL.lastPathComponent
        await executeSearch(query: fileURL.path, mode: mode, forceWeb: false, userId: userId, audioFileURL: fileURL)
    }
}

private extension BeatSearchViewModel {
    func executeSearch(
        query: String,
        mode: QueryInputMode,
        forceWeb: Bool,
        userId: UUID?,
        audioFileURL: URL? = nil
    ) async {
        errorText = nil
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
                let backendResponse = try await apiClient.searchText(
                    query: query,
                    detectedProducerTag: normalizedProducerTag,
                    topN: topN
                )
                result = BeatSearchResponse.backendAPI(query: query, response: backendResponse)
                queryType = forceWeb ? "text_web" : "text"
            case .link:
                let backendResponse = try await apiClient.searchText(
                    query: query,
                    detectedProducerTag: normalizedProducerTag,
                    topN: topN
                )
                result = BeatSearchResponse.backendAPI(query: query, response: backendResponse)
                queryType = "link"
            case .upload:
                let request = try makeAudioSearchRequest(fileURL: audioFileURL, fallbackPath: query)
                let backendResponse = try await apiClient.searchAudio(request)
                result = BeatSearchResponse.backendAPI(query: preparedSnippetLabel ?? query, response: backendResponse)
                queryType = "upload_snippet"
            case .record:
                let request = try makeAudioSearchRequest(fileURL: audioFileURL, fallbackPath: query)
                let backendResponse = try await apiClient.searchAudio(request)
                result = BeatSearchResponse.backendAPI(query: preparedSnippetLabel ?? query, response: backendResponse)
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

    var normalizedProducerTag: String? {
        let trimmed = detectedProducerTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeAudioSearchRequest(fileURL: URL?, fallbackPath: String) throws -> BeatFinderAudioSearchRequest {
        if let fileURL {
            let data = try readFileData(fileURL)
            let ext = normalizedAudioExtension(from: fileURL)
            return BeatFinderAudioSearchRequest(
                audioPath: nil,
                audioBase64: data.base64EncodedString(),
                audioFileName: fileURL.lastPathComponent,
                audioMimeType: mimeType(forExtension: ext),
                detectedProducerTag: normalizedProducerTag,
                topN: topN
            )
        }

        return BeatFinderAudioSearchRequest(
            audioPath: fallbackPath,
            detectedProducerTag: normalizedProducerTag,
            topN: topN
        )
    }

    func readFileData(_ url: URL) throws -> Data {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BeatSearchError.snippetReadFailed
        }
    }

    func normalizedAudioExtension(from url: URL) -> String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ext.isEmpty ? "m4a" : ext
    }

    func mimeType(forExtension ext: String) -> String {
        switch ext {
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "aac":
            return "audio/aac"
        case "caf":
            return "audio/x-caf"
        case "aif", "aiff":
            return "audio/aiff"
        case "m4a":
            return "audio/mp4"
        default:
            return "audio/m4a"
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

import Foundation
import Combine

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

    private let apiClientFactory: () throws -> BeatFinderBackendAPIClientProtocol
    private let topN: Int

    init(
        apiClient: BeatFinderBackendAPIClientProtocol? = nil,
        topN: Int = 3
    ) {
        if let apiClient {
            self.apiClientFactory = { apiClient }
        } else {
            self.apiClientFactory = {
                try BeatFinderBackendSettings.makeConfiguredClient()
            }
        }
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
            let apiClient = try apiClientFactory()
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
                let request = try await makeAudioUploadRequest(fileURL: audioFileURL)
                let backendResponse = try await apiClient.searchAudioUpload(request)
                result = BeatSearchResponse.backendAPI(query: preparedSnippetLabel ?? query, response: backendResponse)
                queryType = "upload_snippet"
            case .record:
                let request = try await makeAudioUploadRequest(fileURL: audioFileURL)
                let backendResponse = try await apiClient.searchAudioUpload(request)
                result = BeatSearchResponse.backendAPI(query: preparedSnippetLabel ?? query, response: backendResponse)
                queryType = "record_snippet"
            }

            _ = queryType
            _ = userId
            response = result
            matches = result.matches
        } catch {
            response = nil
            matches = []
            errorText = userFacingSearchError(error)
        }
    }

    func userFacingSearchError(_ error: Error) -> String {
        if error is BeatFinderBackendConfigurationError {
            return BeatFinderBackendConfiguration.backendUnavailableMessage
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                return BeatFinderBackendConfiguration.backendUnavailableMessage
            default:
                break
            }
        }

        return error.localizedDescription
    }

    var normalizedProducerTag: String? {
        let trimmed = detectedProducerTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeAudioUploadRequest(fileURL: URL?) async throws -> BeatFinderAudioUploadRequest {
        guard let fileURL else {
            throw BeatSearchViewModelError.missingSnippet
        }

        // Copy out of the security-scoped location, then normalize to the
        // 16 kHz mono WAV format the backend decodes.
        let localCopy = try copySnippetToTemporaryDirectory(fileURL)
        defer { try? FileManager.default.removeItem(at: localCopy) }

        let convertedURL: URL
        do {
            convertedURL = try await UploadAudioPreprocessor.makeBackendWAV(from: localCopy)
        } catch is UploadPreprocessingError {
            throw BeatSearchViewModelError.snippetReadFailed
        }
        defer { try? FileManager.default.removeItem(at: convertedURL) }

        let data: Data
        do {
            data = try Data(contentsOf: convertedURL)
        } catch {
            throw BeatSearchViewModelError.snippetReadFailed
        }

        let baseName = fileURL.deletingPathExtension().lastPathComponent
        return BeatFinderAudioUploadRequest(
            fileData: data,
            fileName: baseName.isEmpty ? "snippet.wav" : "\(baseName).wav",
            mimeType: UploadAudioPreprocessor.backendMIMEType,
            detectedProducerTag: normalizedProducerTag,
            topN: topN
        )
    }

    func copySnippetToTemporaryDirectory(_ url: URL) throws -> URL {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("beatfinder-snippet-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension.isEmpty ? "tmp" : url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            throw BeatSearchViewModelError.snippetReadFailed
        }
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
            throw BeatSearchViewModelError.snippetReadFailed
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

private enum BeatSearchViewModelError: LocalizedError {
    case snippetReadFailed
    case missingSnippet

    var errorDescription: String? {
        switch self {
        case .snippetReadFailed:
            return "Unable to read the selected snippet file."
        case .missingSnippet:
            return "Select or record an audio snippet before searching."
        }
    }
}

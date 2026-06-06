import Combine
import Foundation

@MainActor
final class BeatFinderBackendTestViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var health: HealthResponse?
    @Published private(set) var searchResponse: SearchResponse?

    let baseURL: URL

    private let client: BeatFinderBackendAPIClientProtocol

    init(client: BeatFinderBackendAPIClientProtocol? = nil) {
        let resolvedClient = client ?? BeatFinderAPIClient()
        self.client = resolvedClient
        self.baseURL = resolvedClient.baseURL
    }

    var isLoading: Bool {
        state == .loading
    }

    var errorMessage: String? {
        if case .failure(let message) = state {
            return message
        }
        return nil
    }

    var topBeatTitle: String {
        searchResponse?.topBeatTitle ?? "No beat result yet"
    }

    var confidence: String {
        searchResponse?.confidence ?? searchResponse?.results.first?.confidenceLabel ?? "Unknown"
    }

    var detectedProducerTag: String {
        searchResponse?.discovery?.detectedProducerTag ?? "None"
    }

    var matchedProducerChannel: String {
        let channel = searchResponse?.discovery?.matchedProducerChannel
        return channel?.channelID ?? channel?.producerName ?? "None"
    }

    var producerTagConfidenceText: String {
        guard let confidence = searchResponse?.discovery?.producerTagConfidence else {
            return "Unknown"
        }
        return "\(Int((confidence * 100).rounded()))%"
    }

    var discoveryStatus: String {
        searchResponse?.discovery?.discoveryStatus ?? "not_applicable"
    }

    var youtubeVideoMatchTitle: String {
        searchResponse?.discovery?.youtubeVideoMatch?.title ?? "No indexed YouTube match"
    }

    var possibleReasons: [String] {
        searchResponse?.discovery?.possibleReasons ?? []
    }

    var recommendedNextSearches: [String] {
        searchResponse?.discovery?.recommendedNextSearches ?? []
    }

    func runLocalSmokeTest() async {
        guard !isLoading else { return }

        state = .loading
        do {
            health = try await client.health()
            searchResponse = try await client.searchText(
                query: "sza x summer walker type beat",
                detectedProducerTag: "prod by salishan",
                topN: 3
            )
            state = .success
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}

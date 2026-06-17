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
    @Published var selectedPreset: BeatFinderBackendURLPreset {
        didSet {
            guard selectedPreset != oldValue else { return }
            saveConfiguration()
        }
    }
    @Published var customURLString: String {
        didSet {
            guard customURLString != oldValue else { return }
            saveConfiguration()
        }
    }

    private let clientOverride: BeatFinderBackendAPIClientProtocol?
    private let defaults: UserDefaults

    init(
        client: BeatFinderBackendAPIClientProtocol? = nil,
        defaults: UserDefaults = .standard
    ) {
        let configuration = BeatFinderBackendSettings.load(defaults: defaults)
        self.clientOverride = client
        self.defaults = defaults
        self.selectedPreset = configuration.preset
        self.customURLString = configuration.customURLString
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

    var activeConfiguration: BeatFinderBackendConfiguration {
        BeatFinderBackendConfiguration(
            preset: selectedPreset,
            customURLString: customURLString
        )
    }

    var baseURL: URL? {
        activeConfiguration.resolvedBaseURL
    }

    var baseURLText: String {
        let value = activeConfiguration.displayURLString
        return value.isEmpty ? "No backend URL configured" : value
    }

    var isURLValid: Bool {
        activeConfiguration.isValid
    }

    func selectPreset(_ preset: BeatFinderBackendURLPreset) {
        selectedPreset = preset
    }

    func testBackendConnection() async {
        guard !isLoading else { return }

        state = .loading
        searchResponse = nil

        do {
            health = try await configuredClient().health()
            state = .success
        } catch {
            health = nil
            state = .failure(userFacingError(error))
        }
    }

    func runLocalSmokeTest() async {
        guard !isLoading else { return }

        state = .loading
        do {
            let client = try configuredClient()
            health = try await client.health()
            searchResponse = try await client.searchText(
                query: "sza x summer walker type beat",
                detectedProducerTag: "prod by salishan",
                topN: 3
            )
            state = .success
        } catch {
            health = nil
            searchResponse = nil
            state = .failure(userFacingError(error))
        }
    }

    private func saveConfiguration() {
        BeatFinderBackendSettings.save(activeConfiguration, defaults: defaults)
    }

    private func configuredClient() throws -> BeatFinderBackendAPIClientProtocol {
        if let clientOverride {
            return clientOverride
        }
        return try activeConfiguration.makeClient()
    }

    private func userFacingError(_ error: Error) -> String {
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
}

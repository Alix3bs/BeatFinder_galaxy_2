import Foundation
import Testing
@testable import BeatFinder

struct BeatFinderBackendConfigurationTests {
    @Test func apiClientAcceptsInjectedBaseURL() async throws {
        let transport = CapturingTransport(
            responseBody: #"{"status":"ok","state_dir":".state","beats_indexed":7}"#
        )
        let client = BeatFinderAPIClient(
            baseURL: URL(string: "https://api.beatfinder.example.com/v1")!,
            transport: transport
        )

        let response = try await client.health()

        #expect(response.status == "ok")
        #expect(transport.lastRequest?.url?.absoluteString == "https://api.beatfinder.example.com/v1/health")
    }

    @Test func settingsResolveLocalDefault() {
        let defaults = makeDefaults()
        let configuration = BeatFinderBackendSettings.load(defaults: defaults)

        #expect(configuration.preset == .local)
        #expect(configuration.displayURLString == BeatFinderBackendConfiguration.localDevelopmentURLString)
        #expect(configuration.resolvedBaseURL == BeatFinderAPIClient.localDevelopmentBaseURL)
    }

    @Test func invalidCustomBackendURLThrowsCleanConfigurationError() {
        let configuration = BeatFinderBackendConfiguration(
            preset: .custom,
            customURLString: "not a backend url"
        )

        var didThrowConfigurationError = false
        do {
            _ = try configuration.makeClient()
        } catch let error as BeatFinderBackendConfigurationError {
            didThrowConfigurationError = true
            #expect(error.errorDescription == BeatFinderBackendConfiguration.backendUnavailableMessage)
        } catch {
            #expect(Bool(false), "Expected BeatFinderBackendConfigurationError, got \(error)")
        }

        #expect(didThrowConfigurationError)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "beatfinder.backend-configuration-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class CapturingTransport: BeatFinderAPITransport {
    private let responseBody: String
    private(set) var lastRequest: URLRequest?

    init(responseBody: String) {
        self.responseBody = responseBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(responseBody.utf8), response)
    }
}

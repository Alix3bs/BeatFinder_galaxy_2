import Foundation

@MainActor
final class UploadViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case analyzing
        case matched(BeatResultModel)
    }

    @Published private(set) var state: State = .idle

    private var analysisTask: Task<Void, Never>?

    deinit {
        analysisTask?.cancel()
    }

    var orbitState: UploadOrbitState {
        switch state {
        case .idle:
            return .idle
        case .analyzing:
            return .analyzing
        case .matched:
            return .matched
        }
    }

    var headline: String {
        switch state {
        case .idle:
            return "Drop a beat and let BeatFinder scan it"
        case .analyzing:
            return "Analyzing your upload"
        case .matched:
            return "Match found"
        }
    }

    var caption: String {
        switch state {
        case .idle:
            return "We’ll read the texture, tempo, and vocal space before surfacing the closest result."
        case .analyzing:
            return "Orbit speed is elevated while the match engine compares structure, tone, and rhythm."
        case .matched(let result):
            return "\(result.title) by \(result.artist) is ready. Open the result screen to preview the YouTube match."
        }
    }

    var statusLine: String {
        switch state {
        case .idle:
            return "Idle"
        case .analyzing:
            return "Analyzing"
        case .matched:
            return "Matched"
        }
    }

    var primaryActionTitle: String {
        switch state {
        case .idle:
            return "Select Beat"
        case .analyzing:
            return "Analyzing..."
        case .matched:
            return "View Result"
        }
    }

    var matchedResult: BeatResultModel? {
        guard case .matched(let result) = state else { return nil }
        return result
    }

    var showsResetAction: Bool {
        matchedResult != nil
    }

    func startAnalysis() {
        guard state != .analyzing else { return }

        analysisTask?.cancel()
        state = .analyzing

        analysisTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            state = .matched(Self.mockResult)
        }
    }

    func reset() {
        analysisTask?.cancel()
        state = .idle
    }
}

private extension UploadViewModel {
    static let mockResult = BeatResultModel(
        id: UUID().uuidString,
        title: "Neon Echo",
        artist: "Nova",
        bpm: 142,
        genre: "Trap",
        releaseDate: Date(),
        artworkName: "nest_music",
        youtubeVideoID: "dQw4w9WgXcQ",
        youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    )
}

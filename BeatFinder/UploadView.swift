import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WebKit

private enum UploadSourceOption: String, CaseIterable, Identifiable {
    case browseFile = "Browser File"
    case videoLibrary = "Video Library"
    case link = "Link"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .browseFile:
            return "folder.fill"
        case .videoLibrary:
            return "play.rectangle.on.rectangle.fill"
        case .link:
            return "link"
        }
    }

    var subtitle: String {
        switch self {
        case .browseFile:
            return "Import audio or video from Files."
        case .videoLibrary:
            return "Pick a video from Photos, then extract its audio."
        case .link:
            return "Paste a URL and run it through the analysis pipeline."
        }
    }
}

private enum SelectedUploadSource: Equatable {
    case file(URL)
    case video(URL)
    case link(String)

    var option: UploadSourceOption {
        switch self {
        case .file:
            return .browseFile
        case .video:
            return .videoLibrary
        case .link:
            return .link
        }
    }

    var displayLabel: String {
        switch self {
        case .file(let url), .video(let url):
            return url.lastPathComponent
        case .link(let value):
            return value
        }
    }

    var sourceSummary: String {
        switch self {
        case .file(let url):
            return "Files: \(url.lastPathComponent)"
        case .video(let url):
            return "Photos: \(url.lastPathComponent)"
        case .link(let value):
            return value
        }
    }

    var requiresFileRead: Bool {
        switch self {
        case .link:
            return false
        case .file, .video:
            return true
        }
    }

    var requiresExtraction: Bool {
        switch self {
        case .video:
            return true
        case .file, .link:
            return false
        }
    }
}

private enum UploadPipelineStage: Equatable {
    case readingFile
    case extractingAudio
    case analyzing
    case matching

    var title: String {
        switch self {
        case .readingFile:
            return "Reading file"
        case .extractingAudio:
            return "Extracting audio"
        case .analyzing:
            return "Analyzing"
        case .matching:
            return "Finding closest match"
        }
    }

    var detail: String {
        switch self {
        case .readingFile:
            return "Importing the selected media and checking its format."
        case .extractingAudio:
            return "Pulling an audio track out of the selected video."
        case .analyzing:
            return "Inspecting the media fingerprint, duration, and texture."
        case .matching:
            return "Comparing the fingerprint against the current match catalog."
        }
    }
}

private enum UploadProcessingError: LocalizedError, Equatable {
    case unsupportedFile
    case failedExtraction
    case invalidLink
    case backendUnavailable
    case endpointUnavailable
    case noMatchFound
    case unreadableMedia
    case failedToReadFile
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Unsupported file."
        case .failedExtraction:
            return "Failed extraction."
        case .invalidLink:
            return "Invalid link."
        case .backendUnavailable:
            return "Backend unavailable. Start local BeatFinder backend and try again."
        case .endpointUnavailable:
            return "Audio/hybrid search is not available in this backend build yet. Start the latest local backend or use text search."
        case .noMatchFound:
            return "No match found."
        case .unreadableMedia:
            return "The selected media could not be analyzed."
        case .failedToReadFile:
            return "The selected file could not be opened."
        case .unknown(let message):
            return message
        }
    }

    var failureTitle: String {
        switch self {
        case .unsupportedFile:
            return "Unsupported file"
        case .failedExtraction:
            return "Failed extraction"
        case .invalidLink:
            return "Invalid link"
        case .backendUnavailable:
            return "Backend unavailable"
        case .endpointUnavailable:
            return "Audio search unavailable"
        case .noMatchFound:
            return "No match found"
        case .unreadableMedia, .failedToReadFile, .unknown:
            return "Upload failed"
        }
    }
}

private struct UploadMediaMetadata {
    let displayName: String
    let durationSeconds: Double?
    let byteCount: Int64?
    let contentType: UTType?

    var fingerprintSeed: String {
        [
            displayName.lowercased(),
            contentType?.identifier ?? "unknown",
            durationSeconds.map { String(format: "%.3f", $0) } ?? "0",
            byteCount.map(String.init) ?? "0"
        ]
        .joined(separator: "|")
    }
}

private enum PreparedUploadInput {
    case audioFile(URL, UploadMediaMetadata)
    case link(URL)

    var fingerprintSeed: String {
        switch self {
        case .audioFile(_, let metadata):
            return metadata.fingerprintSeed
        case .link(let url):
            return url.absoluteString.lowercased()
        }
    }

    var queryLabel: String {
        switch self {
        case .audioFile(_, let metadata):
            return metadata.displayName
        case .link(let url):
            return url.absoluteString
        }
    }
}

private struct UploadAnalysisResult {
    let beatResult: BeatResultModel
    let searchResponse: BeatSearchResponse
}

private protocol UploadAnalysisServicing {
    func analyze(
        source: SelectedUploadSource,
        detectedProducerTag: String?,
        onStageChange: @escaping (UploadPipelineStage) -> Void
    ) async throws -> UploadAnalysisResult
}

private struct UploadAnalysisService: UploadAnalysisServicing {
    private let apiClient: BeatFinderBackendAPIClientProtocol
    private let topN: Int

    init(
        apiClient: BeatFinderBackendAPIClientProtocol? = nil,
        topN: Int = 3
    ) {
        self.apiClient = apiClient ?? BeatFinderAPIClient()
        self.topN = topN
    }

    func analyze(
        source: SelectedUploadSource,
        detectedProducerTag: String?,
        onStageChange: @escaping (UploadPipelineStage) -> Void
    ) async throws -> UploadAnalysisResult {
        let preparedInput = try await prepareInput(from: source, onStageChange: onStageChange)

        try await updateStage(.analyzing, onStageChange: onStageChange)
        let normalizedTag = normalizedProducerTag(detectedProducerTag)

        try await updateStage(.matching, onStageChange: onStageChange)
        let backendResponse = try await searchBackend(
            input: preparedInput,
            detectedProducerTag: normalizedTag
        )
        let mappedSearch = BeatSearchResponse.backendAPI(
            query: preparedInput.queryLabel,
            response: backendResponse
        )

        guard shouldShowResult(for: mappedSearch) else {
            throw UploadProcessingError.noMatchFound
        }

        let result = BeatResultModel.fromBackendSearch(
            response: backendResponse,
            mappedSearch: mappedSearch,
            fallbackTitle: preparedInput.queryLabel
        )

        return UploadAnalysisResult(beatResult: result, searchResponse: mappedSearch)
    }

    private func prepareInput(
        from source: SelectedUploadSource,
        onStageChange: @escaping (UploadPipelineStage) -> Void
    ) async throws -> PreparedUploadInput {
        switch source {
        case .link(let value):
            guard let validatedURL = validateLink(value) else {
                throw UploadProcessingError.invalidLink
            }
            return .link(validatedURL)

        case .file(let selectedURL), .video(let selectedURL):
            try await updateStage(.readingFile, onStageChange: onStageChange)
            let importedURL = try copyImportedFileToTemporaryDirectory(from: selectedURL)
            let contentType = try resolvedContentType(for: importedURL)

            if contentType.conforms(to: .audio) {
                let metadata = try await readMediaMetadata(from: importedURL)
                return .audioFile(importedURL, metadata)
            }

            guard contentType.conforms(to: .movie) else {
                throw UploadProcessingError.unsupportedFile
            }

            try await updateStage(.extractingAudio, onStageChange: onStageChange)
            let audioURL = try await extractAudioTrack(from: importedURL)
            let metadata = try await readMediaMetadata(from: audioURL)
            return .audioFile(audioURL, metadata)
        }
    }

    private func updateStage(
        _ stage: UploadPipelineStage,
        onStageChange: @escaping (UploadPipelineStage) -> Void
    ) async throws {
        try Task.checkCancellation()
        await MainActor.run {
            onStageChange(stage)
        }
        try await Task.sleep(for: .milliseconds(420))
    }

    private func validateLink(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            return nil
        }

        return url
    }

    private func resolvedContentType(for url: URL) throws -> UTType {
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = values.contentType {
            return type
        }

        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }

        throw UploadProcessingError.unsupportedFile
    }

    private func copyImportedFileToTemporaryDirectory(from url: URL) throws -> URL {
        let accessStarted = url.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension.isEmpty ? "tmp" : url.pathExtension)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            throw UploadProcessingError.failedToReadFile
        }
    }

    private func extractAudioTrack(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw UploadProcessingError.failedExtraction
        }

        exportSession.shouldOptimizeForNetworkUse = true
        try await exportSession.export(to: outputURL, as: .m4a)

        return outputURL
    }

    private func readMediaMetadata(from url: URL) async throws -> UploadMediaMetadata {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let durationSeconds = duration?.seconds.isFinite == true ? duration?.seconds : nil
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .nameKey])

        return UploadMediaMetadata(
            displayName: values?.name ?? url.lastPathComponent,
            durationSeconds: durationSeconds,
            byteCount: values?.fileSize.map(Int64.init),
            contentType: values?.contentType
        )
    }

    private func searchBackend(
        input: PreparedUploadInput,
        detectedProducerTag: String?
    ) async throws -> SearchResponse {
        switch input {
        case .link(let url):
            let request = BeatFinderHybridSearchRequest(
                query: url.absoluteString,
                detectedProducerTag: detectedProducerTag,
                topN: topN
            )
            return try await mapBackendErrors {
                try await apiClient.searchHybrid(request)
            }

        case .audioFile(let url, let metadata):
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw UploadProcessingError.unreadableMedia
            }

            let request = BeatFinderAudioSearchRequest(
                audioBase64: data.base64EncodedString(),
                audioFileName: metadata.displayName,
                audioMimeType: metadata.contentType?.preferredMIMEType ?? mimeType(forExtension: url.pathExtension),
                detectedProducerTag: detectedProducerTag,
                topN: topN
            )
            return try await mapBackendErrors {
                try await apiClient.searchAudio(request)
            }
        }
    }

    private func mapBackendErrors(_ operation: () async throws -> SearchResponse) async throws -> SearchResponse {
        do {
            return try await operation()
        } catch let error as BeatFinderAPIError {
            switch error {
            case .httpStatus(404), .httpStatus(405), .httpStatus(501):
                throw UploadProcessingError.endpointUnavailable
            default:
                throw UploadProcessingError.unknown(error.localizedDescription)
            }
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                throw UploadProcessingError.backendUnavailable
            default:
                throw UploadProcessingError.unknown(error.localizedDescription)
            }
        } catch {
            throw UploadProcessingError.unknown(error.localizedDescription)
        }
    }

    private func shouldShowResult(for response: BeatSearchResponse) -> Bool {
        if !response.matches.isEmpty {
            return true
        }

        switch response.discovery?.discoveryStatus {
        case "found_candidate", "possible_sold_or_deleted":
            return true
        default:
            return false
        }
    }

    private func normalizedProducerTag(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mimeType(forExtension ext: String) -> String {
        switch ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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

@MainActor
private final class UploadViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case sourceSelected(SelectedUploadSource)
        case preparing(SelectedUploadSource, UploadPipelineStage)
        case analyzing(SelectedUploadSource)
        case matching(SelectedUploadSource)
        case success(SelectedUploadSource, BeatResultModel)
        case failure(SelectedUploadSource?, UploadProcessingError)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var persistedMatchedResult: BeatResultModel?
    @Published private(set) var backendSearchResponse: BeatSearchResponse?
    @Published var detectedProducerTag: String = ""

    private let analysisService: UploadAnalysisServicing
    private var analysisTask: Task<Void, Never>?
    private var lastStage: UploadPipelineStage?
    private let persistedMatchKey = "beatfinder.upload.lastMatchedResult.v1"

    init(analysisService: UploadAnalysisServicing) {
        self.analysisService = analysisService
        self.persistedMatchedResult = Self.loadPersistedResult(forKey: persistedMatchKey)
    }

    convenience init() {
        self.init(analysisService: UploadAnalysisService())
    }

    deinit {
        analysisTask?.cancel()
    }

    var matchedResult: BeatResultModel? {
        guard case .success(_, let result) = state else { return nil }
        return result
    }

    var displayedResult: BeatResultModel? {
        matchedResult ?? persistedMatchedResult
    }

    var isProcessing: Bool {
        switch state {
        case .sourceSelected, .preparing, .analyzing, .matching:
            return true
        case .idle, .success, .failure:
            return false
        }
    }

    var activeSource: SelectedUploadSource? {
        switch state {
        case .idle:
            return nil
        case .sourceSelected(let source),
             .preparing(let source, _),
             .analyzing(let source),
             .matching(let source),
             .success(let source, _):
            return source
        case .failure(let source, _):
            return source
        }
    }

    var currentError: UploadProcessingError? {
        guard case .failure(_, let error) = state else { return nil }
        return error
    }

    var orbitState: UploadOrbitState {
        switch state {
        case .idle:
            return .idle
        case .sourceSelected:
            return .selected
        case .preparing:
            return .preparing
        case .analyzing:
            return .analyzing
        case .matching:
            return .matching
        case .success:
            return .matched
        case .failure:
            return .failed
        }
    }

    var headline: String {
        switch state {
        case .idle:
            return "Drop a beat and let BeatFinder scan it"
        case .sourceSelected:
            return "Source selected"
        case .preparing(_, let stage):
            return stage.title
        case .analyzing:
            return "Analyzing"
        case .matching:
            return "Finding closest match"
        case .success(_, let result):
            if result.discoveryStatus == "possible_sold_or_deleted" {
                return "Producer found"
            }
            return "Match found"
        case .failure(_, let error):
            return error.failureTitle
        }
    }

    var caption: String {
        switch state {
        case .idle:
            return "Import a file, pick a video, or submit a link to run the full upload analysis flow."
        case .sourceSelected(let source):
            return "\(source.option.rawValue) is queued. BeatFinder is about to start processing."
        case .preparing(_, let stage):
            return stage.detail
        case .analyzing:
            return "Encoding the selected audio for the local BeatFinder backend."
        case .matching:
            return "Calling the backend audio/hybrid search and ranking the strongest candidates."
        case .success(let source, let result):
            if result.discoveryStatus == "possible_sold_or_deleted" {
                return "\(source.option.rawValue) matched the producer, but no visible indexed beat was confirmed."
            }
            return "\(source.option.rawValue) matched to \(result.title) by \(result.artist)."
        case .failure(_, let error):
            return error.errorDescription ?? "The upload could not be processed."
        }
    }

    var progressValue: Double {
        switch state {
        case .idle:
            return 0
        case .sourceSelected:
            return 0.12
        case .preparing(_, .readingFile):
            return 0.28
        case .preparing(_, .extractingAudio), .preparing(_, .analyzing), .preparing(_, .matching):
            return 0.46
        case .analyzing:
            return 0.72
        case .matching:
            return 0.9
        case .success:
            return 1
        case .failure:
            return 0.92
        }
    }

    var progressItems: [UploadProgressItem] {
        let source = activeSource
        let failureStage = currentError == nil ? nil : lastStage

        return [
            UploadProgressItem(
                id: "selected",
                title: "Source selected",
                detail: source?.sourceSummary ?? "Choose Browser File, Video Library, or Link.",
                state: progressState(for: .sourceSelected, source: source, failureStage: failureStage)
            ),
            UploadProgressItem(
                id: "reading",
                title: source?.requiresFileRead == false ? "Link received" : "Reading file",
                detail: source?.requiresFileRead == false
                    ? "Validating the submitted URL before analysis."
                    : "Importing the selected media into a local working copy.",
                state: progressState(for: .readingFile, source: source, failureStage: failureStage)
            ),
            UploadProgressItem(
                id: "extracting",
                title: "Extracting audio",
                detail: source?.requiresExtraction == true
                    ? "Required for video uploads before beat analysis can begin."
                    : "Skipped when the source is already audio or a link.",
                state: progressState(for: .extractingAudio, source: source, failureStage: failureStage)
            ),
            UploadProgressItem(
                id: "analyzing",
                title: "Analyzing",
                detail: "Reading duration, bytes, and preparing a backend-safe audio payload.",
                state: progressState(for: .analyzing, source: source, failureStage: failureStage)
            ),
            UploadProgressItem(
                id: "matching",
                title: "Finding closest match",
                detail: "Calling BeatFinder backend audio/hybrid search.",
                state: progressState(for: .matching, source: source, failureStage: failureStage)
            )
        ]
    }

    func beginProcessing(source: SelectedUploadSource) {
        analysisTask?.cancel()
        lastStage = nil
        backendSearchResponse = nil
        state = .sourceSelected(source)
        let currentProducerTag = detectedProducerTag

        analysisTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .milliseconds(180))
                let result = try await analysisService.analyze(
                    source: source,
                    detectedProducerTag: currentProducerTag
                ) { [weak self] stage in
                    self?.apply(stage, for: source)
                }
                guard !Task.isCancelled else { return }
                self.backendSearchResponse = result.searchResponse
                self.persistMatchedResult(result.beatResult)
                self.state = .success(source, result.beatResult)
            } catch is CancellationError {
                guard !Task.isCancelled else { return }
                self.reset()
            } catch let error as UploadProcessingError {
                self.backendSearchResponse = nil
                self.state = .failure(source, error)
            } catch {
                self.backendSearchResponse = nil
                self.state = .failure(source, .unknown(error.localizedDescription))
            }
        }
    }

    func presentFailure(_ error: UploadProcessingError, source: SelectedUploadSource? = nil) {
        analysisTask?.cancel()
        backendSearchResponse = nil
        state = .failure(source ?? activeSource, error)
    }

    func reset() {
        analysisTask?.cancel()
        lastStage = nil
        backendSearchResponse = nil
        state = .idle
    }

    private func apply(_ stage: UploadPipelineStage, for source: SelectedUploadSource) {
        lastStage = stage

        switch stage {
        case .readingFile, .extractingAudio:
            state = .preparing(source, stage)
        case .analyzing:
            state = .analyzing(source)
        case .matching:
            state = .matching(source)
        }
    }

    private func progressState(
        for item: UploadProgressItem.Node,
        source: SelectedUploadSource?,
        failureStage: UploadPipelineStage?
    ) -> UploadProgressItem.ProgressState {
        if item == .extractingAudio, source?.requiresExtraction == false {
            return source == nil ? .pending : .skipped
        }

        if item == .readingFile, source?.requiresFileRead == false {
            switch state {
            case .idle:
                return .pending
            case .sourceSelected:
                return .active
            case .failure:
                return failureStage == nil ? .failed : .complete
            default:
                return .complete
            }
        }

        if case .failure = state, failureStage == item.pipelineStage {
            return .failed
        }

        let currentNode = currentProgressNode
        guard let currentNode else {
            return item == .sourceSelected && activeSource != nil ? .active : .pending
        }

        if item.rawValue < currentNode.rawValue {
            return .complete
        }
        if item == currentNode {
            switch state {
            case .success:
                return .complete
            case .failure:
                return failureStage == item.pipelineStage ? .failed : .complete
            default:
                return .active
            }
        }

        if case .success = state {
            return .complete
        }

        return .pending
    }

    private var currentProgressNode: UploadProgressItem.Node? {
        switch state {
        case .idle:
            return nil
        case .sourceSelected:
            return .sourceSelected
        case .preparing(_, let stage):
            return stage == .extractingAudio ? .extractingAudio : .readingFile
        case .analyzing:
            return .analyzing
        case .matching, .success:
            return .matching
        case .failure:
            if let lastStage {
                return lastStage == .extractingAudio ? .extractingAudio : lastStage == .readingFile ? .readingFile : lastStage == .analyzing ? .analyzing : .matching
            }
            return .sourceSelected
        }
    }

    private func persistMatchedResult(_ result: BeatResultModel) {
        persistedMatchedResult = result
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: persistedMatchKey)
    }

    private static func loadPersistedResult(forKey key: String) -> BeatResultModel? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BeatResultModel.self, from: data)
    }
}

private struct UploadProgressItem: Identifiable {
    enum Node: Int {
        case sourceSelected
        case readingFile
        case extractingAudio
        case analyzing
        case matching

        var pipelineStage: UploadPipelineStage? {
            switch self {
            case .sourceSelected:
                return nil
            case .readingFile:
                return .readingFile
            case .extractingAudio:
                return .extractingAudio
            case .analyzing:
                return .analyzing
            case .matching:
                return .matching
            }
        }
    }

    enum ProgressState {
        case pending
        case active
        case complete
        case skipped
        case failed
    }

    let id: String
    let title: String
    let detail: String
    let state: ProgressState

    var node: Node {
        switch id {
        case "selected":
            return .sourceSelected
        case "reading":
            return .readingFile
        case "extracting":
            return .extractingAudio
        case "analyzing":
            return .analyzing
        default:
            return .matching
        }
    }
}

enum UploadOrbitState: Hashable {
    case idle
    case selected
    case preparing
    case analyzing
    case matching
    case matched
    case failed

    var revolutionDuration: Double {
        switch self {
        case .idle:
            return 18
        case .selected:
            return 12
        case .preparing:
            return 8
        case .analyzing:
            return 5
        case .matching:
            return 4
        case .matched:
            return 10
        case .failed:
            return 14
        }
    }

    var centerSymbol: String {
        switch self {
        case .idle:
            return "waveform"
        case .selected:
            return "arrow.down.circle.fill"
        case .preparing:
            return "doc.badge.gearshape"
        case .analyzing:
            return "waveform.path.ecg"
        case .matching:
            return "dot.radiowaves.forward"
        case .matched:
            return "checkmark"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var glowColor: Color {
        switch self {
        case .failed:
            return Color.red.opacity(0.32)
        case .matched:
            return Color(red: 0.58, green: 0.86, blue: 0.68).opacity(0.34)
        default:
            return BeatColors.uploadAccentBlueGlow
        }
    }
}

struct OrbitingIconField: View {
    let state: UploadOrbitState

    private let symbols = [
        "applelogo",
        "music.note",
        "headphones",
        "waveform",
        "play.rectangle.fill",
        "dot.radiowaves.left.and.right",
        "mic.fill",
        "sparkles"
    ]

    @State private var baseAngle: Double = 0
    @State private var phaseStartDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = currentAngle(at: timeline.date)
            let pulse = (state == .analyzing || state == .matching) ? 1.0 + 0.05 * sin(time * 4.4) : 1.0

            ZStack {
                Circle()
                    .fill(state.glowColor)
                    .frame(width: 234, height: 234)
                    .blur(radius: 24)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 288, height: 288)

                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 204, height: 204)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                BeatColors.uploadAccentBlueStrong.opacity(0.84),
                                Color(red: 0.07, green: 0.11, blue: 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: state.centerSymbol)
                            .font(.system(size: state == .matched ? 34 : 30, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .scaleEffect(pulse)
                    .shadow(color: state.glowColor, radius: 18, x: 0, y: 10)

                ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                    let iconAngle = angle + (Double(index) / Double(symbols.count)) * .pi * 2
                    orbitIcon(symbol: symbol, angle: iconAngle)
                }
            }
        }
        .frame(width: 320, height: 320)
        .onAppear {
            phaseStartDate = Date()
        }
        .onChange(of: state) { _, _ in
            let now = Date()
            baseAngle = currentAngle(at: now)
            phaseStartDate = now
        }
    }

    private func orbitIcon(symbol: String, angle: Double) -> some View {
        let radius: CGFloat = 144
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(width: 46, height: 46)
        .offset(x: x, y: y)
    }

    private func currentAngle(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(phaseStartDate)
        let progress = elapsed / state.revolutionDuration
        return baseAngle + progress * .pi * 2
    }
}

private struct UploadMatchedArtworkView: View {
    let result: BeatResultModel?

    var body: some View {
        Group {
            if let thumbnailURL = result?.youtubeThumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
    }

    private var fallbackArtwork: some View {
        Image(result?.artworkName ?? "nest_music")
            .resizable()
            .scaledToFill()
    }
}

private enum YouTubePreviewLoadState {
    case loading
    case ready
    case failed
}

struct YouTubePreviewPlayerView: View {

    let videoID: String?
    let title: String
    let artworkName: String?
    let watchURL: URL?

    @State private var loadState: YouTubePreviewLoadState = .loading

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BeatColors.surfaceSecondary)

            if let videoID, !videoID.isEmpty {
                EmbeddedYouTubePlayer(videoID: videoID, loadState: $loadState)
                    .opacity(loadState == .ready ? 1 : 0.001)
                    .allowsHitTesting(loadState == .ready)

                if loadState != .ready {
                    fallback(showLoading: loadState == .loading)
                }
            } else {
                fallback(showLoading: false)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            guard videoID != nil else {
                loadState = .failed
                return
            }

            loadState = .loading

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if loadState == .loading {
                    loadState = .failed
                }
            }
        }
    }

    @ViewBuilder
    private func fallback(showLoading: Bool) -> some View {
        ZStack {
            if let artworkName {
                Image(artworkName)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.34)
            }

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                Image(systemName: showLoading ? "dot.radiowaves.left.and.right" : "play.rectangle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(showLoading ? "Loading preview..." : "Preview unavailable in app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if !showLoading, let watchURL {
                    Link(destination: watchURL) {
                        Text("Open on YouTube")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BeatColors.uploadAccentBlueText)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(BeatColors.uploadAccentBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EmbeddedYouTubePlayer: UIViewRepresentable {
    let videoID: String
    @Binding var loadState: YouTubePreviewLoadState

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1") else {
            return
        }

        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(loadState: $loadState)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadState: Binding<YouTubePreviewLoadState>

        init(loadState: Binding<YouTubePreviewLoadState>) {
            self.loadState = loadState
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadState.wrappedValue = .ready
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadState.wrappedValue = .failed
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadState.wrappedValue = .failed
        }
    }
}

@MainActor
private final class UploadResultViewModel: ObservableObject {
    let model: BeatResultModel

    init(model: BeatResultModel) {
        self.model = model
    }

    var previewVideoID: String? {
        model.youtubeVideoID
    }

    var watchURL: URL? {
        if let direct = model.youtubeWatchURLString, let url = URL(string: direct) {
            return url
        }

        if let videoID = model.youtubeVideoID {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: "\(model.title) \(model.artist)")
        ]
        return components?.url
    }

    var releaseDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: model.releaseDate)
    }
}

enum BeatDetailContext {
    case explore
    case upload
}

struct UploadResultView: View {
    let model: BeatResultModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var savedBeatStore: SavedBeatStore
    @StateObject private var viewModel: UploadResultViewModel
    @State private var isCreatorPresented = false
    @State private var isPreviewPlaying = false
    @State private var isLiked = false
    @State private var didSaveToSafe = false
    let sourceContext: BeatDetailContext
    private let onClose: (() -> Void)?
    private let onAnalyzeAnother: (() -> Void)?

    init(
        model: BeatResultModel,
        sourceContext: BeatDetailContext = .explore,
        onClose: (() -> Void)? = nil,
        onAnalyzeAnother: (() -> Void)? = nil
    ) {
        self.model = model
        self.sourceContext = sourceContext
        self.onClose = onClose
        self.onAnalyzeAnother = onAnalyzeAnother
        _viewModel = StateObject(wrappedValue: UploadResultViewModel(model: model))
    }

    var body: some View {
        GeometryReader { proxy in
            let isRegularWidth = horizontalSizeClass == .regular
            let heroHeight = min(
                max(proxy.size.height * (isRegularWidth ? 0.58 : 0.52), isRegularWidth ? 420 : 360),
                isRegularWidth ? 640 : 500
            )

            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(height: heroHeight)

                        VStack(spacing: 22) {
                            progressSection
                            transportControls
                            metadataRow
                            backendDiscoverySection
                            watchButton
                            actionGrid
                        }
                        .padding(.horizontal, isRegularWidth ? 34 : 20)
                        .padding(.top, 22)
                        .padding(.bottom, sourceContext == .upload ? 44 : 28)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isCreatorPresented) {
            NavigationStack {
                UserProfileView(user: creatorProfile)
            }
            .preferredColorScheme(.dark)
        }
    }

    private func heroSection(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            heroArtwork
                .frame(height: height)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.28),
                            Color.clear,
                            Color.black.opacity(0.58),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 18)
                .padding(.top, 14)

                HStack {
                    Spacer()

                    BeatLyricPad(
                        beatID: model.id,
                        beatTitle: model.title
                    )
                    .frame(maxWidth: min(horizontalSizeClass == .regular ? 520 : 420, 520))

                    Spacer()
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 18)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 10) {
                    Text(model.title)
                        .font(.system(size: horizontalSizeClass == .regular ? 42 : 36, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(model.artist)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BeatColors.textSecondary)

                    Text(sourceContext == .upload ? "Matched track" : "Beat detail")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalSizeClass == .regular ? 80 : 26)
                .padding(.bottom, horizontalSizeClass == .regular ? 54 : 42)
            }
        }
        .background(Color.black)
    }

    private var heroArtwork: some View {
        ZStack {
            Image(resolvedArtworkName)
                .resizable()
                .scaledToFill()
                .saturation(model.artworkName == nil ? 1.05 : 0.94)
                .contrast(model.artworkName == nil ? 1.08 : 1.02)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            Color.clear,
                            BeatColors.subscriptionDeepNavy.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(resolvedArtworkName)
                .resizable()
                .scaledToFill()
                .blur(radius: 42)
                .opacity(0.26)
                .scaleEffect(1.18)

            Circle()
                .fill(BeatColors.uploadAccentBlueGlow)
                .frame(width: horizontalSizeClass == .regular ? 340 : 260, height: horizontalSizeClass == .regular ? 340 : 260)
                .blur(radius: 54)
                .offset(y: 22)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var resolvedArtworkName: String {
        model.artworkName ?? "nest_music"
    }

    private var closeButton: some View {
        Button {
            BeatHaptics.tap()
            if let onClose {
                onClose()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
        .accessibilityIdentifier("beatDetail.closeButton")
    }

    private var progressSection: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(BeatColors.uploadAccentBlueStrong)
                        .frame(width: proxy.size.width * (isPreviewPlaying ? 0.58 : 0.22))
                }
            }
            .frame(height: 4)

            HStack {
                Text("00:08")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)

                Spacer()

                Text(model.genre)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BeatColors.textTertiary)

                Spacer()

                Text("1:34")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 18) {
            transportButton(systemImage: "backward.fill")

            Button {
                BeatHaptics.tap()
                isPreviewPlaying.toggle()
            } label: {
                Circle()
                    .fill(BeatColors.surfaceSecondary)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPreviewPlaying ? 0 : 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(BeatPressableButtonStyle())

            transportButton(systemImage: "forward.fill")
        }
        .frame(maxWidth: .infinity)
    }

    private func transportButton(systemImage: String) -> some View {
        Button {
            BeatHaptics.tap()
        } label: {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BeatColors.surfaceSecondary)
                .frame(width: 88, height: 72)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var metadataRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metadataPill(title: model.genre)
                metadataPill(title: "\(model.bpm) BPM")
                metadataPill(title: viewModel.releaseDateText)
            }

            VStack(alignment: .center, spacing: 10) {
                metadataPill(title: model.genre)
                metadataPill(title: "\(model.bpm) BPM")
                metadataPill(title: viewModel.releaseDateText)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var watchButton: some View {
        Button(action: openWatchURL) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Watch on YouTube")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(BeatColors.uploadAccentBlueText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(BeatColors.uploadAccentBlue)
            .clipShape(Capsule())
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private func metadataPill(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var backendDiscoverySection: some View {
        if model.hasBackendDiscoveryDetails {
            SectionCard(cornerRadius: 24, padding: 16, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: resultDiscoveryIcon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(resultDiscoveryTint)
                            .frame(width: 32, height: 32)
                            .background(resultDiscoveryTint.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(resultDiscoveryHeadline)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Backend audio/hybrid search result")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.64))
                        }
                    }

                    resultDiscoveryField("Confidence", value: model.confidenceLabel?.readableUploadToken ?? "Unknown")
                    resultDiscoveryField("Matched producer channel", value: model.matchedProducerChannelName ?? "None")
                    resultDiscoveryField("Producer tag confidence", value: model.producerTagConfidence.map { "\(Int(($0 * 100).rounded()))%" } ?? "Unknown")
                    resultDiscoveryField("Discovery status", value: model.discoveryStatus?.readableUploadToken ?? "Not applicable")

                    if let title = model.youtubeVideoMatchTitle, !title.isEmpty {
                        resultDiscoveryField("YouTube video match", value: title)
                    }

                    if model.discoveryStatus == "possible_sold_or_deleted", let reasons = model.possibleReasons, !reasons.isEmpty {
                        resultDiscoveryChips(title: "Possible reasons", values: reasons, prettifyValues: true)
                    }

                    if let searches = model.recommendedNextSearches, !searches.isEmpty {
                        resultDiscoveryChips(title: "Recommended next searches", values: searches)
                    }
                }
            }
        }
    }

    private var resultDiscoveryHeadline: String {
        switch model.discoveryStatus {
        case "found_candidate":
            return "Possible Match Found"
        case "possible_sold_or_deleted":
            return "Producer found, but beat may be sold/deleted"
        case "insufficient_evidence":
            return "Producer evidence is weak"
        default:
            return "Backend search details"
        }
    }

    private var resultDiscoveryIcon: String {
        switch model.discoveryStatus {
        case "found_candidate":
            return "checkmark.seal.fill"
        case "possible_sold_or_deleted":
            return "exclamationmark.triangle.fill"
        case "insufficient_evidence":
            return "questionmark.diamond.fill"
        default:
            return "waveform.path.ecg"
        }
    }

    private var resultDiscoveryTint: Color {
        switch model.discoveryStatus {
        case "found_candidate":
            return Color(red: 0.58, green: 0.86, blue: 0.68)
        case "possible_sold_or_deleted":
            return .yellow.opacity(0.9)
        case "insufficient_evidence":
            return .orange.opacity(0.9)
        default:
            return BeatColors.uploadAccentBlue
        }
    }

    private func resultDiscoveryField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    private func resultDiscoveryChips(title: String, values: [String], prettifyValues: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(prettifyValues ? value.readableUploadToken : value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
        }
    }

    private var creatorProfile: ProfileUser {
        let creatorHandle = model.artist
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        return ProfileUser(
            id: ProfileUser.stableID(for: creatorHandle),
            name: model.artist,
            handle: creatorHandle,
            genre: model.genre,
            avatarName: model.artworkName,
            tags: [model.genre, "\(model.bpm) BPM", "BeatFinder"],
            followers: 1204,
            following: 88,
            beats: [
                FeedBeat(
                    title: model.title,
                    artist: model.artist,
                    genre: model.genre,
                    bpm: model.bpm,
                    price: "Free",
                    artworkName: model.artworkName
                ),
                FeedBeat(
                    title: "\(model.title) Alt",
                    artist: model.artist,
                    genre: model.genre,
                    bpm: max(model.bpm - 4, 70),
                    price: "Get",
                    artworkName: model.artworkName
                )
            ]
        )
    }

    private var actionGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            saveButton
            creatorButton

            shareButton

            if sourceContext == .upload {
                analyzeAnotherButton
            }
        }
    }

    private var saveButton: some View {
        let isSaved = savedBeatStore.isSaved(model)
        let title = isSaved
            ? (didSaveToSafe ? "Saved to Safe" : "Already in Safe")
            : "Save to Safe"

        return Button {
            if isSaved {
                BeatHaptics.tap()
            } else {
                _ = savedBeatStore.save(model)
                didSaveToSafe = true
                BeatHaptics.success()
            }
        } label: {
            actionTile(
                title: title,
                systemImage: isSaved ? "bookmark.fill" : "bookmark"
            )
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var creatorButton: some View {
        Button {
            BeatHaptics.tap()
            isCreatorPresented = true
        } label: {
            actionTile(title: "Open Creator", systemImage: "person.crop.circle")
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var analyzeAnotherButton: some View {
        Button {
            BeatHaptics.tap()
            if let onAnalyzeAnother {
                onAnalyzeAnother()
            } else {
                dismiss()
            }
        } label: {
            actionTile(title: "Analyze Another", systemImage: "arrow.clockwise")
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var shareButton: some View {
        ShareLink(item: sharePayload) {
            actionTile(title: sourceContext == .upload ? "Share Result" : "Share Beat", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var sharePayload: String {
        viewModel.watchURL?.absoluteString ?? "\(model.title) by \(model.artist)"
    }

    private func actionTile(title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BeatColors.uploadAccentBlue)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(18)
        .background(BeatColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func openWatchURL() {
        BeatHaptics.tap()
        guard let watchURL = viewModel.watchURL else { return }
        openURL(watchURL)
    }
}

private struct UploadSourceCard: View {
    let option: UploadSourceOption
    let isDisabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(option.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text(option.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isDisabled ? 0.03 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(BeatPressableButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

private struct UploadProgressRowView: View {
    let item: UploadProgressItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingIcon
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch item.state {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.28))
        case .active:
            ProgressView()
                .tint(BeatColors.uploadAccentBlue)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.86, blue: 0.68))
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.46))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.red.opacity(0.88))
        }
    }
}

struct UploadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let scrollToTopToken: Int
    @StateObject private var viewModel = UploadViewModel()
    @State private var presentedResult: BeatResultModel?
    @State private var presentationTask: Task<Void, Never>?
    @State private var isResultPopupVisible = false
    @State private var isFileImporterPresented = false
    @State private var isVideoPickerPresented = false
    @State private var isLinkSheetPresented = false
    @State private var isSourceSheetPresented = false
    @State private var linkDraft = ""

    var body: some View {
        ZStack {
            ScreenContainer(
                spacing: 18,
                topPadding: 12,
                bottomPadding: 40,
                maxWidthStyle: .standard,
                includeTabBarClearance: true,
                scrollToTopToken: scrollToTopToken
            ) {
                uploadBackground
            } content: {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Upload")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    uploadHeroCard
                    helperSection

                    Spacer(minLength: 16)

                    bottomAction
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.matchedResult?.id) { _, _ in
            presentationTask?.cancel()

            guard let result = viewModel.matchedResult else {
                presentedResult = nil
                return
            }

            presentationTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                guard viewModel.matchedResult?.id == result.id else { return }
                openFullResult(for: result)
            }
        }
        .sheet(isPresented: $isSourceSheetPresented) {
            UploadSourceSheet { option in
                openSource(option)
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.height(330), .medium])
            .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.beginProcessing(source: .file(url))
            case .failure(let error):
                guard !isUserCancellation(error) else { return }
                viewModel.presentFailure(.failedToReadFile)
            }
        }
        .sheet(isPresented: $isVideoPickerPresented) {
            UploadVideoPicker { result in
                switch result {
                case .success(let url):
                    viewModel.beginProcessing(source: .video(url))
                case .failure(let error):
                    guard !isUserCancellation(error) else { return }
                    viewModel.presentFailure(.failedToReadFile)
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isLinkSheetPresented) {
            UploadLinkSheet(
                initialValue: linkDraft,
                onCancel: {
                    isLinkSheetPresented = false
                },
                onConfirm: { value in
                    linkDraft = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    isLinkSheetPresented = false
                    viewModel.beginProcessing(source: .link(linkDraft))
                }
            )
            .preferredColorScheme(.dark)
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var uploadBackground: some View {
        ZStack {
            Color.black

            if let result = viewModel.displayedResult {
                UploadMatchedArtworkView(result: result)
                    .blur(radius: 70)
                    .scaleEffect(1.28)
                    .saturation(1.08)
                    .overlay(Color.black.opacity(0.66))
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    BeatColors.uploadAccentBlue.opacity(viewModel.displayedResult == nil ? 0.22 : 0.14),
                    Color.clear,
                    Color.black.opacity(0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(BeatColors.uploadAccentBlueGlow)
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: 120, y: -180)
        }
    }

    private var uploadHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    UploadMatchedArtworkView(result: viewModel.displayedResult)
                        .opacity(viewModel.displayedResult == nil ? 0.34 : 0.94)
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            BeatColors.uploadAccentBlue.opacity(0.14),
                            Color.black.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    if let source = viewModel.activeSource {
                        Text(source.option.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BeatColors.uploadAccentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BeatColors.uploadAccentBlue.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(BeatColors.uploadAccentBlue)
                    } else {
                        Image(systemName: heroStatusSymbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(heroStatusColor)
                    }
                }

                Spacer(minLength: 0)

                Text(heroHeadline)
                    .font(.system(size: horizontalSizeClass == .regular ? 30 : 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(heroSupportingText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))

                ProgressView(value: viewModel.progressValue)
                    .tint(BeatColors.uploadAccentBlue)
                    .opacity(viewModel.activeSource == nil ? 0.18 : 1)
            }
            .padding(horizontalSizeClass == .regular ? 24 : 20)
        }
        .frame(height: horizontalSizeClass == .regular ? 410 : 330)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var helperSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.caption)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))

            producerTagField

            if let source = viewModel.activeSource {
                Text(source.sourceSummary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            if let error = viewModel.currentError {
                Text(error.errorDescription ?? "The upload could not be processed.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.88))
            }

            if viewModel.activeSource != nil {
                SectionCard(cornerRadius: 24, padding: 16, fill: Color.white.opacity(0.04), strokeOpacity: 0.07) {
                    ForEach(viewModel.progressItems) { item in
                        UploadProgressRowView(item: item)
                    }
                }
            }

            if let response = viewModel.backendSearchResponse {
                uploadBackendResultCard(response)
            }
        }
    }

    private var producerTagField: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.and.magnifyingglass")
                .foregroundStyle(BeatColors.uploadAccentBlue)

            TextField("Detected producer tag (optional)", text: $viewModel.detectedProducerTag)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .disabled(viewModel.isProcessing)

            if !viewModel.detectedProducerTag.isEmpty {
                Button {
                    viewModel.detectedProducerTag = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func uploadBackendResultCard(_ response: BeatSearchResponse) -> some View {
        let discovery = response.discovery
        return SectionCard(cornerRadius: 24, padding: 16, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: uploadDiscoveryIcon(discovery?.discoveryStatus))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(uploadDiscoveryTint(discovery?.discoveryStatus))
                        .frame(width: 32, height: 32)
                        .background(uploadDiscoveryTint(discovery?.discoveryStatus).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(uploadDiscoveryHeadline(discovery?.discoveryStatus))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)

                        Text(response.summary)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                uploadDiscoveryField("Top beat", value: response.matches.first?.title ?? "No visible indexed beat found")
                uploadDiscoveryField("Confidence", value: response.backendConfidence ?? response.matches.first?.confidencePercentText ?? "Unknown")
                uploadDiscoveryField("Matched producer channel", value: matchedProducerChannelText(discovery))
                uploadDiscoveryField("Producer tag confidence", value: producerTagConfidenceText(discovery))
                uploadDiscoveryField("Discovery status", value: readableBackendToken(discovery?.discoveryStatus))

                if let title = discovery?.youtubeVideoMatch?.title, !title.isEmpty {
                    uploadDiscoveryField("YouTube video match", value: title)
                }

                if discovery?.discoveryStatus == "possible_sold_or_deleted", let reasons = discovery?.possibleReasons, !reasons.isEmpty {
                    uploadDiscoveryChips(title: "Possible reasons", values: reasons, prettifyValues: true)
                }

                if let searches = discovery?.recommendedNextSearches, !searches.isEmpty {
                    uploadDiscoveryChips(title: "Recommended next searches", values: searches)
                }
            }
        }
    }

    private func uploadDiscoveryField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    private func uploadDiscoveryChips(title: String, values: [String], prettifyValues: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(prettifyValues ? readableBackendToken(value) : value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
        }
    }

    private var bottomAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeatHaptics.tap()
                isSourceSheetPresented = true
            } label: {
                Text(viewModel.isProcessing ? "Analyzing..." : "Select Beat")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BeatColors.uploadAccentBlueText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(BeatColors.uploadAccentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(viewModel.isProcessing)

            if viewModel.currentError != nil || viewModel.matchedResult != nil {
                PrimaryButton(title: "Reset Upload", kind: .dark) {
                    viewModel.reset()
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var heroSupportingText: String {
        switch viewModel.state {
        case .idle:
            if let result = viewModel.displayedResult {
                return "\(result.artist) • \(result.genre) • \(result.bpm) BPM"
            }
            return "Choose a file, video, or link to start the real BeatFinder analysis flow."
        case .success(_, let result):
            return "\(result.title) by \(result.artist) is ready."
        default:
            return viewModel.caption
        }
    }

    private var heroHeadline: String {
        switch viewModel.state {
        case .idle:
            return viewModel.displayedResult?.title ?? viewModel.headline
        case .success(_, let result):
            return result.title
        default:
            return viewModel.headline
        }
    }

    private var heroStatusSymbol: String {
        switch viewModel.state {
        case .idle:
            return "waveform"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        default:
            return "sparkles"
        }
    }

    private var heroStatusColor: Color {
        switch viewModel.state {
        case .success(_, let result) where result.discoveryStatus == "possible_sold_or_deleted":
            return .yellow.opacity(0.9)
        case .success:
            return Color(red: 0.58, green: 0.86, blue: 0.68)
        case .failure:
            return .red.opacity(0.88)
        default:
            return BeatColors.uploadAccentBlue
        }
    }

    private func uploadDiscoveryHeadline(_ status: String?) -> String {
        switch status {
        case "found_candidate":
            return "Possible Match Found"
        case "possible_sold_or_deleted":
            return "Producer found, but beat may be sold/deleted"
        case "insufficient_evidence":
            return "Producer evidence is weak"
        default:
            return "Backend audio search"
        }
    }

    private func uploadDiscoveryIcon(_ status: String?) -> String {
        switch status {
        case "found_candidate":
            return "checkmark.seal.fill"
        case "possible_sold_or_deleted":
            return "exclamationmark.triangle.fill"
        case "insufficient_evidence":
            return "questionmark.diamond.fill"
        default:
            return "waveform.path.ecg"
        }
    }

    private func uploadDiscoveryTint(_ status: String?) -> Color {
        switch status {
        case "found_candidate":
            return Color(red: 0.58, green: 0.86, blue: 0.68)
        case "possible_sold_or_deleted":
            return .yellow.opacity(0.9)
        case "insufficient_evidence":
            return .orange.opacity(0.9)
        default:
            return BeatColors.uploadAccentBlue
        }
    }

    private func matchedProducerChannelText(_ discovery: DiscoveryEnrichment?) -> String {
        let channel = discovery?.matchedProducerChannel
        return channel?.channelID ?? channel?.producerName ?? "None"
    }

    private func producerTagConfidenceText(_ discovery: DiscoveryEnrichment?) -> String {
        guard let confidence = discovery?.producerTagConfidence else {
            return "Unknown"
        }
        return "\(Int((confidence * 100).rounded()))%"
    }

    private func readableBackendToken(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return "Not applicable" }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func openSource(_ option: UploadSourceOption) {
        isSourceSheetPresented = false
        switch option {
        case .browseFile:
            isFileImporterPresented = true
        case .videoLibrary:
            isVideoPickerPresented = true
        case .link:
            isLinkSheetPresented = true
        }
    }

    @ViewBuilder
    private func resultPopup(for result: BeatResultModel) -> some View {
        GeometryReader { proxy in
            let isRegularWidth = proxy.size.width >= 768
            let popupWidth = min(proxy.size.width - 20, isRegularWidth ? BeatLayout.wideContentMaxWidth + 32 : proxy.size.width - 12)
            let popupHeight = min(
                proxy.size.height - max(proxy.safeAreaInsets.top, 12) - 8,
                isRegularWidth ? 860 : proxy.size.height
            )

            ZStack(alignment: isRegularWidth ? .center : .bottom) {
                Color.black
                    .opacity(isResultPopupVisible ? 0.48 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissPresentedResult()
                    }

                NavigationStack {
                    UploadResultView(
                        model: result,
                        sourceContext: .upload,
                        onClose: dismissPresentedResult,
                        onAnalyzeAnother: dismissPresentedResult
                    )
                }
                .preferredColorScheme(.dark)
                .frame(width: popupWidth, height: popupHeight)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 18)
                .scaleEffect(isRegularWidth ? (isResultPopupVisible ? 1 : 0.96) : 1)
                .offset(y: isResultPopupVisible ? 0 : (isRegularWidth ? 24 : proxy.size.height))
                .opacity(isResultPopupVisible ? 1 : 0)
            }
            .animation(MotionTokens.slowEase, value: isResultPopupVisible)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func dismissPresentedResult() {
        presentationTask?.cancel()
        withAnimation(MotionTokens.slowEase) {
            isResultPopupVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(MotionTokens.slowDuration * 1_000)))
            guard !isResultPopupVisible else { return }
            presentedResult = nil
            viewModel.reset()
        }
    }

    private func openFullResult(for result: BeatResultModel) {
        presentationTask?.cancel()
        withAnimation(MotionTokens.fastEase) {
            isResultPopupVisible = false
        }
        presentedResult = nil
        viewModel.reset()
        appState.openUploadResult(result)
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

private extension String {
    var readableUploadToken: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct UploadSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (UploadSourceOption) -> Void

    var body: some View {
        NavigationStack {
            ScreenContainer(
                spacing: 16,
                topPadding: 18,
                bottomPadding: 20,
                maxWidthStyle: .compact
            ) {
                Color.black
            } content: {
                Text("Choose Source")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Select where BeatFinder should import or fetch the media from.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))

                VStack(spacing: 12) {
                    ForEach(UploadSourceOption.allCases) { option in
                        Button {
                            BeatHaptics.tap()
                            dismiss()
                            onSelect(option)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.systemImage)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(BeatColors.uploadAccentBlue)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.rawValue)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(option.subtitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.58))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(BeatPressableButtonStyle())
                    }
                }

                PrimaryButton(title: "Cancel", kind: .dark) {
                    dismiss()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct UploadLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    let onCancel: () -> Void
    let onConfirm: (String) -> Void

    init(initialValue: String, onCancel: @escaping () -> Void, onConfirm: @escaping (String) -> Void) {
        _draft = State(initialValue: initialValue)
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ScreenContainer(
                spacing: 18,
                topPadding: 20,
                bottomPadding: 24,
                maxWidthStyle: .standard
            ) {
                Color.black
            } content: {
                Text("Paste Link")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                TextField("https://", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                PrimaryButton(title: "Paste from Clipboard", kind: .dark) {
                    BeatHaptics.tap()
                    if let value = UIPasteboard.general.string {
                        draft = value
                    }
                }

                HStack(spacing: 12) {
                    PrimaryButton(title: "Cancel", kind: .dark) {
                        onCancel()
                        dismiss()
                    }

                    PrimaryButton(title: "Analyze Link") {
                        onConfirm(draft)
                        dismiss()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct UploadVideoPicker: UIViewControllerRepresentable {
    let onPick: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Result<URL, Error>) -> Void

        init(onPick: @escaping (Result<URL, Error>) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }
            let provider = result.itemProvider
            let identifier = provider.registeredTypeIdentifiers.first ?? UTType.movie.identifier

            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                if let error {
                    DispatchQueue.main.async {
                        self.onPick(.failure(error))
                    }
                    return
                }

                guard let url else { return }

                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async {
                        self.onPick(.success(destination))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.onPick(.failure(error))
                    }
                }
            }
        }
    }
}

@MainActor
final class LyricPadStore: ObservableObject {
    struct Entry: Codable, Hashable {
        var text: String
        var updatedAt: Date
    }

    @Published private(set) var entries: [String: Entry] = [:]

    private let defaultsKey = "beatfinder.lyric_pad.entries.v1"

    init() {
        load()
    }

    func text(for beatID: String) -> String {
        entries[beatID]?.text ?? ""
    }

    func update(_ text: String, for beatID: String) {
        let trimmedTrailing = text.replacingOccurrences(of: "\r\n", with: "\n")
        entries[beatID] = Entry(text: trimmedTrailing, updatedAt: Date())
        persist()
    }

    func statusText(for beatID: String) -> String {
        guard let entry = entries[beatID] else { return "Ready" }
        return entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ready" : "Saved"
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        entries = decoded
    }
}

struct BeatLyricPad: View {
    let beatID: String
    let beatTitle: String

    @EnvironmentObject private var lyricPadStore: LyricPadStore
    @State private var isExpanded = false
    @State private var draftText = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button {
                BeatHaptics.tap()
                withAnimation(MotionTokens.topModalSpring) {
                    isExpanded.toggle()
                }
                if isExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isEditorFocused = true
                    }
                } else {
                    isEditorFocused = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Lyric Pad")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text(lyricPadStore.statusText(for: beatID))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BeatColors.textSecondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.74))
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.58))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .accessibilityIdentifier("beat.lyricPad.toggle")

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lyric Pad")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)

                            Text(beatTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(BeatColors.textSecondary)
                        }

                        Spacer()

                        Text(lyricPadStore.statusText(for: beatID))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BeatColors.uploadAccentBlue)
                    }

                    ZStack(alignment: .topLeading) {
                        if draftText.isEmpty {
                            Text("Write lyrics, bars, hooks, ideas…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(BeatColors.textTertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }

                        TextEditor(text: $draftText)
                            .focused($isEditorFocused)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 168)
                            .background(Color.clear)
                            .accessibilityIdentifier("beat.lyricPad.editor")
                            .accessibilityValue(draftText.isEmpty ? "empty" : draftText)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.46))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(BeatColors.surfacePrimary.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .frame(maxWidth: 460)
        .onAppear {
            draftText = lyricPadStore.text(for: beatID)
        }
        .onChange(of: draftText) { _, newValue in
            lyricPadStore.update(newValue, for: beatID)
        }
    }
}

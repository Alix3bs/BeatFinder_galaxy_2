import SwiftUI
import Combine
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct SearchView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var saved: SavedMatchesStore
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel = BeatSearchViewModel()
    @StateObject private var recorder = AudioSnippetRecorder()

    @State private var showInputInfo = false
    @State private var inputInfoText = ""
    @State private var showSnippetImporter = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                queryCard
                actionRow
                statusSection
                resultsSection
            }
            .padding(.horizontal, BeatLayout.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .alert("Input Mode", isPresented: $showInputInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inputInfoText)
        }
        .fileImporter(
            isPresented: $showSnippetImporter,
            allowedContentTypes: [.audio, .wav, .mp3, .mpeg4Audio, .aiff],
            allowsMultipleSelection: false
        ) { result in
            handleSnippetImportResult(result)
        }
        .onChange(of: recorder.isRecording) { wasRecording, isRecording in
            guard wasRecording, !isRecording, viewModel.inputMode == .record else { return }
            guard let url = recorder.takeRecordedFileURL() else { return }
            Task {
                await viewModel.ingestSnippetAndSearch(fileURL: url, mode: .record, userId: auth.sessionUserId)
            }
        }
        .preferredColorScheme(settings.preferredColorScheme)
    }
}

private extension SearchView {
    var topBar: some View {
        HStack {
            Text("Search")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                if viewModel.inputMode != .text {
                    viewModel.inputMode = .text
                }
                viewModel.search(forceWeb: true, userId: auth.sessionUserId)
            } label: {
                searchWebButtonLabel
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .frame(minHeight: BeatLayout.iconButtonSize)
                    .background(Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSearching || viewModel.isPreparingSnippet || recorder.isRecording)
        }
        .padding(.top, 2)
    }

    var queryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.65))

                TextField(queryPlaceholder, text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.search(forceWeb: false, userId: auth.sessionUserId)
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))

            HStack(spacing: 8) {
                ForEach(BeatSearchViewModel.QueryInputMode.allCases) { mode in
                    Button {
                        handleInputModeTap(mode)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(viewModel.inputMode == mode ? Color.black : Color.white.opacity(0.86))
                            .frame(maxWidth: .infinity, minHeight: BeatLayout.iconButtonSize)
                            .background(viewModel.inputMode == mode ? Color.white : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                PrimaryButton(title: primaryActionTitle, systemImage: "scope") {
                    viewModel.search(forceWeb: false, userId: auth.sessionUserId)
                }
                .disabled(viewModel.isSearching || viewModel.isPreparingSnippet || recorder.isRecording)

                secondaryActionButton
            }

            VStack(spacing: 10) {
                PrimaryButton(title: primaryActionTitle, systemImage: "scope") {
                    viewModel.search(forceWeb: false, userId: auth.sessionUserId)
                }
                .disabled(viewModel.isSearching || viewModel.isPreparingSnippet || recorder.isRecording)

                secondaryActionButton
            }
        }
    }

    @ViewBuilder
    var secondaryActionButton: some View {
        switch viewModel.inputMode {
        case .text, .link:
            PrimaryButton(title: "Paste Link", systemImage: "link", kind: .dark) {
                pasteAndSearch()
            }
            .disabled(viewModel.isSearching || viewModel.isPreparingSnippet || recorder.isRecording)

        case .upload:
            PrimaryButton(
                title: viewModel.isPreparingSnippet ? "Uploading..." : "Choose Snippet",
                systemImage: "waveform.badge.plus",
                kind: .dark
            ) {
                showSnippetImporter = true
            }
            .disabled(viewModel.isSearching || viewModel.isPreparingSnippet || recorder.isRecording)

        case .record:
            PrimaryButton(
                title: recorder.isRecording ? "Stop & Match" : "Start Mic",
                systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill",
                kind: .dark
            ) {
                handleRecordTap()
            }
            .disabled(viewModel.isSearching || viewModel.isPreparingSnippet)
        }
    }

    @ViewBuilder
    var statusSection: some View {
        if viewModel.isPreparingSnippet {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Uploading snippet to secure storage...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        } else if viewModel.isSearching {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text(searchingStatusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        } else if let errorText = viewModel.errorText {
            Text(errorText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
        }

        if recorder.isRecording {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("Recording snippet \(recorder.durationText) / 00:30")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red.opacity(0.96))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }

        if let snippetLabel = viewModel.preparedSnippetLabel, !snippetLabel.isEmpty {
            Text("Snippet ready: \(snippetLabel)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
        }

        if let response = viewModel.response {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(response.source == .edgeFunction ? "LIVE" : "MVP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(response.source == .edgeFunction ? Color.green : Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (response.source == .edgeFunction ? Color.green : Color.orange).opacity(0.15)
                        )
                        .clipShape(Capsule())

                    resultStateBadge(response.resultState)
                }

                Text(response.summary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    var resultsSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if filteredMatches.isEmpty, viewModel.response != nil, !viewModel.isSearching {
                    Text(viewModel.response?.resultState == .notFound
                        ? "Not found in index."
                        : "No candidates were returned for this query.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }

                if settings.explicitFilterEnabled, filteredMatches.isEmpty, !viewModel.matches.isEmpty {
                    Text("Explicit filter hid all current matches.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(filteredMatches) { match in
                    NavigationLink {
                        ResultDetailView(
                            match: match,
                            likelyCustom: viewModel.response?.likelyCustom ?? false
                        )
                    } label: {
                        resultRow(match)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 36)
        }
    }

    var searchWebButtonLabel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text("Search Web")
            }
            .font(.system(size: 12, weight: .bold))

            Image(systemName: "globe")
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 4)
        }
    }

    var filteredMatches: [BeatSearchMatch] {
        guard settings.explicitFilterEnabled else { return viewModel.matches }
        return viewModel.matches.filter { match in
            !containsExplicitTerms(match)
        }
    }

    func containsExplicitTerms(_ match: BeatSearchMatch) -> Bool {
        let explicitTerms = ["explicit", "nsfw", "dirty", "uncensored", "18+"]
        let source = "\(match.title) \(match.note ?? "")".lowercased()
        return explicitTerms.contains { source.contains($0) }
    }

    func resultRow(_ match: BeatSearchMatch) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: match.platform.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(match.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(match.platform.title)
                    Text("•")
                    Text(match.confidencePercentText)
                    Text("•")
                    Text(match.verdict.title)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))

                if let note = match.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                if let url = URL(string: match.url) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Circle())
                    }
                }

                Button {
                    saved.toggle(match, userId: auth.sessionUserId)
                } label: {
                    Image(systemName: saved.isSaved(match) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    func handleInputModeTap(_ mode: BeatSearchViewModel.QueryInputMode) {
        viewModel.inputMode = mode
        switch mode {
        case .text, .link:
            break
        case .upload:
            inputInfoText = "Select an audio snippet file (10–30s). BeatFinder uploads it to your private snippets bucket and runs matching automatically."
            showInputInfo = true
        case .record:
            inputInfoText = "Tap Start Mic to record up to 30 seconds. BeatFinder uploads the recording and matches it automatically."
            showInputInfo = true
        }
    }

    func pasteAndSearch() {
        let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pasted.isEmpty else {
            inputInfoText = "Clipboard is empty. Copy a track URL first."
            showInputInfo = true
            return
        }

        viewModel.inputMode = .link
        viewModel.query = pasted
        viewModel.search(forceWeb: true, userId: auth.sessionUserId)
    }

    func handleSnippetImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.ingestSnippetAndSearch(fileURL: url, mode: .upload, userId: auth.sessionUserId)
            }
        case .failure(let error):
            inputInfoText = "Snippet import failed: \(error.localizedDescription)"
            showInputInfo = true
        }
    }

    func handleRecordTap() {
        if recorder.isRecording {
            guard let url = recorder.stopRecording() else {
                inputInfoText = "Recording ended but no file was produced."
                showInputInfo = true
                return
            }

            Task {
                await viewModel.ingestSnippetAndSearch(fileURL: url, mode: .record, userId: auth.sessionUserId)
            }
            return
        }

        guard auth.sessionUserId != nil else {
            inputInfoText = "Sign in first to upload and match recorded snippets."
            showInputInfo = true
            return
        }

        Task {
            do {
                try await recorder.startRecording(maxDuration: 30)
            } catch {
                inputInfoText = error.localizedDescription
                showInputInfo = true
            }
        }
    }

    var queryPlaceholder: String {
        switch viewModel.inputMode {
        case .text:
            return "Find exact type beat, artist x type beat, BPM, key, mood..."
        case .link:
            return "Paste YouTube / SoundCloud / Spotify / Apple Music URL..."
        case .upload:
            return "Choose an audio snippet to upload and match..."
        case .record:
            return "Record a mic snippet to upload and match..."
        }
    }

    var searchingStatusText: String {
        switch viewModel.inputMode {
        case .text:
            return "Embedding query and searching indexed beats..."
        case .link:
            return "Fingerprinting source and searching by hash..."
        case .upload, .record:
            return "Fingerprinting snippet and searching by hash..."
        }
    }

    var primaryActionTitle: String {
        switch viewModel.inputMode {
        case .text:
            return "Find Beat"
        case .link:
            return "Match Link"
        case .upload, .record:
            return "Match Snippet"
        }
    }

    func resultStateTint(_ state: BeatSearchResultState) -> Color {
        switch state {
        case .exactMatch:
            return .green
        case .closeMatches:
            return .yellow
        case .notFound:
            return .orange
        }
    }

    func resultStateBadge(_ state: BeatSearchResultState) -> some View {
        let tint = resultStateTint(state)
        return Text(state.title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }
}

@MainActor
final class AudioSnippetRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?

    var durationText: String {
        let clamped = max(0, min(30, Int(elapsedSeconds.rounded())))
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startRecording(maxDuration: TimeInterval) async throws {
        let hasPermission = await requestPermission()
        guard hasPermission else {
            throw RecorderError.permissionDenied
        }

        stopTimer()
        elapsedSeconds = 0

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snippet-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()

        guard recorder.record(forDuration: maxDuration) else {
            throw RecorderError.couldNotStart
        }

        self.recorder = recorder
        currentURL = outputURL
        isRecording = true
        startTimer()
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
        return takeRecordedFileURL()
    }

    func takeRecordedFileURL() -> URL? {
        let url = currentURL
        currentURL = nil
        return url
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsedSeconds += 0.2
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

private enum RecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required to record snippets."
        case .couldNotStart:
            return "Could not start recording."
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(AuthStore())
            .environmentObject(SavedMatchesStore())
    }
}

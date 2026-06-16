import Combine
import Foundation
import SwiftUI

@MainActor
final class SafeViewModel: ObservableObject {
    struct SavedBeat: Identifiable, Equatable {
        let result: BeatResultModel
        let descriptor: String
        let note: String
        let savedAt: Date?
        let canRemove: Bool

        var id: String { result.id }
        var title: String { result.title }
        var artist: String { result.artist }
    }

    @Published var beats: [SavedBeat] = [
        SavedBeat(
            result: BeatResultModel(
                id: "safe-1",
                title: "Hollow Point",
                artist: "Velvet",
                bpm: 128,
                genre: "R&B",
                releaseDate: Date(),
                artworkName: "nest_music",
                youtubeVideoID: "dQw4w9WgXcQ",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            ),
            descriptor: "R&B • Saved this week",
            note: "Main release",
            savedAt: Date(),
            canRemove: false
        ),
        SavedBeat(
            result: BeatResultModel(
                id: "safe-2",
                title: "Neon Echo",
                artist: "Nova",
                bpm: 142,
                genre: "Trap",
                releaseDate: Date(),
                artworkName: "nest_music",
                youtubeVideoID: "kJQP7kiw5Fk",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
            ),
            descriptor: "Trap • Quick access",
            note: "Pinned",
            savedAt: Date().addingTimeInterval(-86_400),
            canRemove: false
        ),
        SavedBeat(
            result: BeatResultModel(
                id: "safe-3",
                title: "Blue Ember",
                artist: "Tray3",
                bpm: 136,
                genre: "Soul Trap",
                releaseDate: Date(),
                artworkName: "nest_music",
                youtubeVideoID: "JGwWNGJdvx8",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=JGwWNGJdvx8"
            ),
            descriptor: "Soul Trap • Saved from Explore",
            note: "Recent",
            savedAt: Date().addingTimeInterval(-86_400 * 3),
            canRemove: false
        ),
        SavedBeat(
            result: BeatResultModel(
                id: "safe-4",
                title: "Midnight Loop",
                artist: "Aero",
                bpm: 146,
                genre: "Drill",
                releaseDate: Date(),
                artworkName: "nest_music",
                youtubeVideoID: "2Vv-BfVoq4g",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=2Vv-BfVoq4g"
            ),
            descriptor: "Drill • Saved from Upload",
            note: "Match",
            savedAt: Date().addingTimeInterval(-86_400 * 6),
            canRemove: false
        )
    ]
}

struct SafeView: View {
    @EnvironmentObject private var savedBeatStore: SavedBeatStore
    let scrollToTopToken: Int
    @StateObject private var viewModel = SafeViewModel()
    @State private var selectedBeat: SafeViewModel.SavedBeat?

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 12,
            bottomPadding: 30,
            maxWidthStyle: .standard,
            includeTabBarClearance: true,
            fillsAvailableHeight: false,
            scrollToTopToken: scrollToTopToken
        ) {
            backgroundLayer
        } content: {
            header
            headerStrip
            cardsSection
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedBeat) { beat in
            UploadResultView(model: beat.result, sourceContext: .explore)
                .preferredColorScheme(.dark)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Circle()
                .fill(BeatColors.accentBlueGlow)
                .frame(width: 320, height: 320)
                .blur(radius: 96)
                .offset(x: 120, y: 180)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Beats")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(BeatColors.textPrimary)

            Text("where your beats are saved")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }

    private var headerStrip: some View {
        SectionCard(cornerRadius: 26, padding: 18, fill: BeatColors.surfacePrimary, strokeOpacity: 0.08) {
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeatColors.surfaceSecondary)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(BeatColors.accentBlue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved collection")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BeatColors.textPrimary)

                    Text("Keep your favorite beats close and reopen them anytime.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BeatColors.textSecondary)
                }

                Spacer()
            }
        }
    }

    private var cardsSection: some View {
        VStack(spacing: 16) {
            ForEach(displayedBeats) { beat in
                savedBeatCard(beat)
            }
        }
    }

    private func savedBeatCard(_ beat: SafeViewModel.SavedBeat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(beat.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(BeatColors.accentBlueText)

                    Text(producerText(for: beat))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlueText.opacity(0.82))
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(beat.note)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BeatColors.accentBlueText.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())

                    if beat.canRemove {
                        Button {
                            BeatHaptics.tap()
                            savedBeatStore.remove(beat.result)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BeatColors.accentBlueText)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(beat.title) from Safe")
                    }
                }
            }

            Text(beat.descriptor)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.accentBlueText.opacity(0.78))

            VStack(alignment: .leading, spacing: 8) {
                safeMetadataRow("Discovery", value: beat.result.discoveryStatus?.readableSafeToken ?? "Saved beat")
                safeMetadataRow("Confidence", value: beat.result.confidenceLabel?.readableSafeToken ?? "Unknown")
                safeMetadataRow("Saved", value: savedDateText(for: beat))

                if let youtubeTitle = beat.result.youtubeVideoMatchTitle, !youtubeTitle.isEmpty {
                    safeMetadataRow("YouTube match", value: youtubeTitle)
                }
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(height: 68)
                .overlay(
                    HStack {
                        Text("Open beat")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(BeatColors.accentBlueText)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(BeatColors.accentBlueText)
                    }
                    .padding(.horizontal, 18)
                )
        }
        .padding(20)
        .background(BeatColors.accentBlue)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            BeatHaptics.tap()
            selectedBeat = beat
        }
    }

    private var displayedBeats: [SafeViewModel.SavedBeat] {
        let mapped = savedBeatStore.savedBeats.map(mapSavedBeat)
        return mapped.isEmpty ? viewModel.beats : mapped
    }

    private func mapSavedBeat(_ savedBeat: SavedBeat) -> SafeViewModel.SavedBeat {
        let result = savedBeat.result
        let confidence = result.confidenceLabel?.readableSafeToken ?? "Unknown confidence"
        let discovery = result.discoveryStatus?.readableSafeToken ?? "Saved beat"
        return SafeViewModel.SavedBeat(
            result: result,
            descriptor: "\(discovery) • \(confidence)",
            note: "Saved",
            savedAt: savedBeat.savedAt,
            canRemove: true
        )
    }

    private func producerText(for beat: SafeViewModel.SavedBeat) -> String {
        beat.result.matchedProducerChannelName ?? beat.artist
    }

    private func safeMetadataRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(BeatColors.accentBlueText.opacity(0.58))
                .textCase(.uppercase)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeatColors.accentBlueText.opacity(0.86))
                .multilineTextAlignment(.leading)
        }
    }

    private func savedDateText(for beat: SafeViewModel.SavedBeat) -> String {
        guard let savedAt = beat.savedAt else {
            return beat.descriptor
        }
        return Self.savedDateFormatter.string(from: savedAt)
    }

    private static let savedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension String {
    var readableSafeToken: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}

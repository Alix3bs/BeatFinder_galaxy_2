import SwiftUI

struct ResultDetailView: View {
    let match: BeatSearchMatch
    let likelyCustom: Bool

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var saved: SavedMatchesStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScreenContainer(
            spacing: 16,
            topPadding: BeatLayout.sectionSpacingTight,
            bottomPadding: 32,
            maxWidthStyle: .standard,
            includeTabBarClearance: true
        ) {
            AnimatedGalaxyBackground()
            Color.black.opacity(0.72)
        } content: {
            topBar
            confidenceCard
            waveformCard
            metadataCard
            actions
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(settings.preferredColorScheme)
    }
}

private extension ResultDetailView {
    var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Match Detail")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
        }
    }

    var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(match.platform.title, systemImage: match.platform.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                verdictBadge(match.verdict)
            }

            Text(match.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("Confidence \(match.confidencePercentText)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            if likelyCustom {
                Text("Likely custom or not publicly indexed. Showing closest match context.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.95))
            }

            if let note = match.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var waveformCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snippet Preview")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(height: 110)
                .overlay(
                    WaveformPreviewBars()
                        .padding(.horizontal, 10)
                )
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, item in
                metadataRow(item.title, item.value)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var actions: some View {
        let isSaved = saved.isSaved(match)
        return VStack(spacing: 10) {
            if let url = URL(string: match.url) {
                externalLinkButton(url: url)
            }

            Button {
                saved.toggle(match, userId: auth.sessionUserId)
            } label: {
                HStack {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    Text(isSaved ? "Remove from Saved" : "Save Match")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("result.detail.saveToggle")

            // Shares only metadata text and the public source link — never
            // audio files.
            ShareLink(item: shareText) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Match Info")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("result.detail.share")
        }
    }

    var shareText: String {
        var lines = ["BeatFinder match: \(match.title)"]
        if let bpm = match.bpm {
            lines.append("BPM: \(bpm)")
        }
        if let key = match.key, !key.isEmpty {
            lines.append("Key: \(key)")
        }
        lines.append("Source: \(match.platform.title)")
        lines.append("Confidence: \(match.confidencePercentText)")
        if !match.url.isEmpty {
            lines.append(match.url)
        }
        return lines.joined(separator: "\n")
    }

    func metadataRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.68))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .semibold))
        }
        .font(.system(size: 14, weight: .medium))
    }

    var metadataItems: [(title: String, value: String)] {
        var items: [(title: String, value: String)] = []
        if let bpm = match.bpm {
            items.append(("BPM", "\(bpm)"))
        }
        if let key = match.key, !key.isEmpty {
            items.append(("Key", key))
        }
        items.append(("Source", match.platform.title))
        items.append(("Verdict", match.verdict.title))
        return items
    }

    func externalLinkButton(url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Image(systemName: "arrow.up.forward.app.fill")
                Text("Open on \(match.platform.title)")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .accessibilityIdentifier("result.detail.openSource")
    }

    func verdictBadge(_ verdict: BeatMatchVerdict) -> some View {
        let tint: Color
        switch verdict {
        case .exact:
            tint = .green
        case .similar:
            tint = .yellow
        case .lowConfidence:
            tint = .orange
        }

        return Text(verdict.title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct WaveformPreviewBars: View {
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<44, id: \.self) { idx in
                Capsule()
                    .fill(Color.white.opacity(idx.isMultiple(of: 2) ? 0.35 : 0.18))
                    .frame(width: 4, height: CGFloat(22 + (idx * 7) % 70))
            }
        }
    }
}

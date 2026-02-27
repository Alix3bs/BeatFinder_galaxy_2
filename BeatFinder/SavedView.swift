import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var saved: SavedMatchesStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if saved.savedMatches.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(saved.savedMatches) { match in
                            NavigationLink {
                                ResultDetailView(match: match, likelyCustom: match.verdict == .lowConfidence)
                            } label: {
                                row(match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(BeatLayout.screenHorizontal)
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(settings.toolbarColorScheme, for: .navigationBar)
        .preferredColorScheme(settings.preferredColorScheme)
        .task(id: auth.sessionUserId) {
            await saved.syncFromRemote(userId: auth.sessionUserId)
        }
    }
}

private extension SavedView {
    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))

            Text("No saved matches yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            Text("Run a search and save the beats you want to revisit.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, BeatLayout.screenHorizontal)
        }
    }

    func row(_ match: BeatSearchMatch) -> some View {
        HStack(spacing: 12) {
            Image(systemName: match.platform.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(match.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(match.platform.title)
                    Text("•")
                    Text(match.confidencePercentText)
                    Text("•")
                    Text(match.verdict.title)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Button {
                saved.remove(match, userId: auth.sessionUserId)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

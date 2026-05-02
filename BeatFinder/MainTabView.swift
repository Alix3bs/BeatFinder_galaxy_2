import SwiftUI

private enum MVPMainTab: CaseIterable, Hashable {
    case explore
    case upload
    case studio
    case safe

    var title: String {
        switch self {
        case .explore:
            return "Explore"
        case .upload:
            return "Upload"
        case .studio:
            return "My Studio"
        case .safe:
            return "Safe"
        }
    }

    var systemImage: String {
        switch self {
        case .explore:
            return "magnifyingglass"
        case .upload:
            return "plus.circle.fill"
        case .studio:
            return "person.circle.fill"
        case .safe:
            return "lock.shield.fill"
        }
    }
}

private enum MVPMainTabBarMetrics {
    static func barHeight(isPad: Bool) -> CGFloat { isPad ? 72 : 64 }
    static let barCornerRadius: CGFloat = 18
    static let selectionBubbleSize: CGFloat = 42
}

private struct MVPMainTabBar: View {
    let isPad: Bool
    let selection: MVPMainTab
    let onSelect: (MVPMainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MVPMainTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == tab {
                                Circle()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: MVPMainTabBarMetrics.selectionBubbleSize, height: MVPMainTabBarMetrics.selectionBubbleSize)
                            }

                            Image(systemName: tab.systemImage)
                                .font(.system(size: tab == .upload ? 19 : 17, weight: .semibold))
                                .foregroundStyle(selection == tab ? .white : .white.opacity(0.72))
                        }
                        .frame(height: MVPMainTabBarMetrics.selectionBubbleSize)

                        Text(tab.title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(selection == tab ? .white : .white.opacity(0.72))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: MVPMainTabBarMetrics.barHeight(isPad: isPad) - 8)
                }
                .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.97))
                .accessibilityIdentifier("floatingTab.\(tab.title.replacingOccurrences(of: " ", with: "").lowercased())")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: MVPMainTabBarMetrics.barHeight(isPad: isPad))
        .background(
            RoundedRectangle(cornerRadius: MVPMainTabBarMetrics.barCornerRadius, style: .continuous)
                .fill(BeatColors.surfacePrimary.opacity(0.94))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MVPMainTabBarMetrics.barCornerRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MVPMainTabBarMetrics.barCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.42), radius: 16, x: 0, y: 8)
        .accessibilityIdentifier("floatingTabBar")
    }
}

private struct TopActionButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            BeatHaptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: horizontalSizeClass == .regular ? 52 : 44, height: horizontalSizeClass == .regular ? 52 : 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BeatColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(BeatPressableButtonStyle())
    }
}

private struct BeatsFilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? BeatColors.textPrimary : BeatColors.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? BeatColors.elevatedCard : BeatColors.surfaceSecondary.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.11 : 0.06), lineWidth: 1)
            )
    }
}

private struct ExploreBeat: Identifiable, Hashable {
    let result: BeatResultModel
    let priceLabel: String
    let tagline: String

    var id: String { result.id }
}

private struct ExploreFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedGenre: String?
    @Binding var freeOnly: Bool
    @State private var selectedSort = "Trending"

    private let genres = ["Trap", "R&B", "Soul Trap", "Melodic", "Drill"]
    private let sorts = ["Trending", "Recent", "Free First"]

    var body: some View {
        NavigationStack {
            ScreenContainer(
                spacing: 18,
                topPadding: 18,
                bottomPadding: 24,
                maxWidthStyle: .compact
            ) {
                Color.black
            } content: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Explore Filters")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Adjust sort, genre, and free-only preferences.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    AppIconButton(systemImage: "xmark") {
                        dismiss()
                    }
                }

                SectionCard(cornerRadius: 24, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    Text("Sort")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 10) {
                        ForEach(sorts, id: \.self) { sort in
                            Button {
                                BeatHaptics.tap()
                                selectedSort = sort
                            } label: {
                                Text(sort)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(selectedSort == sort ? BeatColors.accentBlueText : .white)
                                    .padding(.horizontal, 14)
                                    .frame(height: 40)
                                    .background(selectedSort == sort ? BeatColors.accentBlue : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(BeatPressableButtonStyle())
                        }
                    }
                }

                SectionCard(cornerRadius: 24, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    Text("Genre")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(genres, id: \.self) { genre in
                            Button {
                                BeatHaptics.tap()
                                selectedGenre = selectedGenre == genre ? nil : genre
                            } label: {
                                Text(genre)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(selectedGenre == genre ? BeatColors.accentBlueText : .white)
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(selectedGenre == genre ? BeatColors.accentBlue : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(BeatPressableButtonStyle())
                        }
                    }

                    Toggle(isOn: $freeOnly) {
                        Text("Free beats only")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(BeatColors.accentBlueStrong)
                }

                HStack(spacing: 12) {
                    PrimaryButton(title: "Reset", kind: .dark) {
                        selectedSort = "Trending"
                        selectedGenre = nil
                        freeOnly = false
                    }

                    PrimaryButton(title: "Apply") {
                        dismiss()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct GiftRedeemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ScreenContainer(
                spacing: 18,
                topPadding: 18,
                bottomPadding: 24,
                maxWidthStyle: .compact
            ) {
                Color.black
            } content: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gift / Redeem Membership")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Enter an offer code to redeem membership or gift access later.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    AppIconButton(systemImage: "xmark") {
                        dismiss()
                    }
                }

                SectionCard(cornerRadius: 24, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    Text("Membership Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.74))

                    TextField("Enter code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(BeatColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 12) {
                    PrimaryButton(title: "Dismiss", kind: .dark) {
                        dismiss()
                    }

                    PrimaryButton(title: "Redeem") {
                        dismiss()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ExploreSearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var recentSearches = ["Neon Echo", "Velvet", "Soul Trap"]

    private let beats: [BeatResultModel] = [
        BeatResultModel(
            id: "search-1",
            title: "Hollow Point",
            artist: "Velvet",
            bpm: 128,
            genre: "R&B",
            releaseDate: Date(),
            artworkName: "nest_music",
            youtubeVideoID: "dQw4w9WgXcQ",
            youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        ),
        BeatResultModel(
            id: "search-2",
            title: "Neon Echo",
            artist: "Nova",
            bpm: 142,
            genre: "Trap",
            releaseDate: Date().addingTimeInterval(-86_400 * 3),
            artworkName: "nest_music",
            youtubeVideoID: "kJQP7kiw5Fk",
            youtubeWatchURLString: "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
        ),
        BeatResultModel(
            id: "search-3",
            title: "Blue Ember",
            artist: "Tray3",
            bpm: 136,
            genre: "Soul Trap",
            releaseDate: Date().addingTimeInterval(-86_400 * 10),
            artworkName: "nest_music",
            youtubeVideoID: "JGwWNGJdvx8",
            youtubeWatchURLString: "https://www.youtube.com/watch?v=JGwWNGJdvx8"
        )
    ]

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 14,
            bottomPadding: 24,
            maxWidthStyle: .standard,
            includeTabBarClearance: true
        ) {
            Color.black
        } content: {
            Text("Search Beats")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BeatColors.textSecondary)

                TextField("Search by beat, creator, or genre", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(BeatColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Searches")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recentSearches, id: \.self) { term in
                                Button {
                                    BeatHaptics.tap()
                                    query = term
                                } label: {
                                    Text(term)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(BeatColors.surfaceSecondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(BeatPressableButtonStyle())
                            }
                        }
                    }
                }
            }

            if filteredBeats.isEmpty {
                SectionCard(cornerRadius: 24, padding: 20, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    Text("No results yet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Start typing to search the current BeatFinder catalog.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BeatColors.textSecondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredBeats, id: \.id) { beat in
                        Button {
                            BeatHaptics.tap()
                            recentSearches = Array(([beat.title] + recentSearches).uniqued().prefix(5))
                            appState.homePath.append(.beatDetail(beat))
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 58, height: 58)
                                    .overlay {
                                        if let artworkName = beat.artworkName {
                                            Image(artworkName)
                                                .resizable()
                                                .scaledToFill()
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(beat.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text("\(beat.artist) • \(beat.genre)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(BeatColors.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(BeatColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(BeatPressableButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var filteredBeats: [BeatResultModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return beats.filter { beat in
            beat.title.localizedCaseInsensitiveContains(trimmed)
                || beat.artist.localizedCaseInsensitiveContains(trimmed)
                || beat.genre.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private struct MondayReleaseTile: View {
    let beat: ExploreBeat
    let isPreviewing: Bool
    let onOpen: () -> Void
    let onTogglePreview: () -> Void
    var tileWidth: CGFloat = 132
    private let artworkCornerRadius: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                Button {
                    BeatHaptics.tap()
                    onOpen()
                } label: {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: tileWidth, height: tileWidth * 1.24)
                        .overlay {
                            if let artworkName = beat.result.artworkName {
                                Image(artworkName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: tileWidth, height: tileWidth * 1.24)
                                    .opacity(0.58)
                                    .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
                            } else {
                                Text(beat.result.artist.uppercased())
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(.white.opacity(0.16))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
                }
                .buttonStyle(BeatPressableButtonStyle())

                Button {
                    onTogglePreview()
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: isPreviewing ? 0 : 1)
                        )
                }
                .buttonStyle(BeatPressableButtonStyle())
                .padding(12)
            }

            Button {
                BeatHaptics.tap()
                onOpen()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(beat.result.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(beat.result.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
                .frame(width: tileWidth, alignment: .leading)
            }
            .buttonStyle(BeatPressableButtonStyle())
        }
        .frame(width: tileWidth, alignment: .leading)
    }
}

private struct MondayReleasesView: View {
    let beats: [BeatResultModel]

    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var previewingBeatID: String?

    private var exploreBeats: [ExploreBeat] {
        beats.map {
            ExploreBeat(
                result: $0,
                priceLabel: $0.bpm > 138 ? "Get" : "Free",
                tagline: "\($0.artist)  •  \($0.genre)"
            )
        }
    }

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 14,
            bottomPadding: 24,
            maxWidthStyle: .wide,
            includeTabBarClearance: true
        ) {
            Color.black
        } content: {
            Text("Monday Releases")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text("Fresh drops from the current BeatFinder release rotation.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            LazyVGrid(columns: releaseColumns, spacing: 16) {
                ForEach(exploreBeats) { beat in
                    MondayReleaseTile(
                        beat: beat,
                        isPreviewing: previewingBeatID == beat.id,
                        onOpen: {
                            appState.homePath.append(.beatDetail(beat.result))
                        },
                        onTogglePreview: {
                            togglePreview(for: beat.id)
                        },
                        tileWidth: horizontalSizeClass == .regular ? 180 : 150
                    )
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var releaseColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 220 : 160), spacing: 16)]
    }

    private func togglePreview(for beatID: String) {
        BeatHaptics.tap()
        previewingBeatID = previewingBeatID == beatID ? nil : beatID
    }
}

private struct ExploreProducerRailItem: Identifiable {
    let name: String
    let handle: String
    let tagline: String
    let followers: Int
    let following: Int

    var id: UUID {
        ProfileUser.stableID(for: handle)
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var profileUser: ProfileUser {
        ProfileUser(
            id: ProfileUser.stableID(for: handle),
            name: name,
            handle: handle,
            genre: tagline,
            avatarName: nil,
            tags: tagline
                .split(separator: "•")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            followers: followers,
            following: following,
            beats: []
        )
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let scrollToTopToken: Int

    @State private var selectedFilter = "Trending"
    @State private var heroIndex = 0
    @State private var previewingBeatID: String?
    @State private var previewResetTask: Task<Void, Never>?
    @State private var isGiftSheetPresented = false
    @State private var isFiltersSheetPresented = false
    @State private var selectedGenre: String?
    @State private var showFreeOnly = false

    private let filters = ["Trending", "All Beats", "Purchased", "Favorites"]
    private let allBeats: [ExploreBeat] = [
        ExploreBeat(
            result: BeatResultModel(
                id: "explore-1",
                title: "Hollow Point",
                artist: "Velvet",
                bpm: 128,
                genre: "R&B",
                releaseDate: Date(),
                artworkName: "nest_music",
                youtubeVideoID: "dQw4w9WgXcQ",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            ),
            priceLabel: "Free",
            tagline: "Velvet  •  R&B & Soul"
        ),
        ExploreBeat(
            result: BeatResultModel(
                id: "explore-2",
                title: "Neon Echo",
                artist: "Nova",
                bpm: 142,
                genre: "Trap",
                releaseDate: Date().addingTimeInterval(-86_400 * 3),
                artworkName: "nest_music",
                youtubeVideoID: "kJQP7kiw5Fk",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
            ),
            priceLabel: "Get",
            tagline: "Nova  •  Trap"
        ),
        ExploreBeat(
            result: BeatResultModel(
                id: "explore-3",
                title: "Blue Ember",
                artist: "Tray3",
                bpm: 136,
                genre: "Soul Trap",
                releaseDate: Date().addingTimeInterval(-86_400 * 11),
                artworkName: "nest_music",
                youtubeVideoID: "JGwWNGJdvx8",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=JGwWNGJdvx8"
            ),
            priceLabel: "Free",
            tagline: "Tray3  •  Soul Trap"
        ),
        ExploreBeat(
            result: BeatResultModel(
                id: "explore-4",
                title: "Midnight Loop",
                artist: "Velvet",
                bpm: 118,
                genre: "R&B",
                releaseDate: Date().addingTimeInterval(-86_400 * 14),
                artworkName: "nest_music",
                youtubeVideoID: "2Vv-BfVoq4g",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=2Vv-BfVoq4g"
            ),
            priceLabel: "Get",
            tagline: "Velvet  •  Soul Trap"
        ),
        ExploreBeat(
            result: BeatResultModel(
                id: "explore-5",
                title: "Night Shift",
                artist: "Aero",
                bpm: 146,
                genre: "Drill",
                releaseDate: Date().addingTimeInterval(-86_400 * 18),
                artworkName: "nest_music",
                youtubeVideoID: "3JZ4pnNtyxQ",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=3JZ4pnNtyxQ"
            ),
            priceLabel: "Get",
            tagline: "Aero  •  Drill"
        )
    ]
    private let trendingProducers: [ExploreProducerRailItem] = [
        ExploreProducerRailItem(name: "Velvet", handle: "velvetloops", tagline: "R&B • Soul", followers: 48200, following: 134),
        ExploreProducerRailItem(name: "Nova", handle: "nova808", tagline: "Boom Bap", followers: 31900, following: 92),
        ExploreProducerRailItem(name: "Sage", handle: "sageloops", tagline: "Lo-Fi", followers: 17600, following: 141),
        ExploreProducerRailItem(name: "Rico Atlas", handle: "ricoatlas", tagline: "Trap • Drill", followers: 40800, following: 73)
    ]

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 14,
            bottomPadding: 24,
            maxWidthStyle: .wide,
            includeTabBarClearance: true,
            scrollToTopToken: scrollToTopToken
        ) {
            Color.black
        } content: {
            header
            filtersRow
            heroCard
            featuredBeatRow
            mondayReleasesSection
            trendingProducersSection
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isFiltersSheetPresented) {
            ExploreFilterSheet(selectedGenre: $selectedGenre, freeOnly: $showFreeOnly)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isGiftSheetPresented) {
            GiftRedeemSheet()
                .preferredColorScheme(.dark)
                .presentationDetents([.height(340), .medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedFilter) { _, _ in
            heroIndex = 0
        }
        .onChange(of: selectedGenre) { _, _ in
            heroIndex = 0
        }
        .onChange(of: showFreeOnly) { _, _ in
            heroIndex = 0
        }
        .onDisappear {
            previewResetTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Beats")
                .font(BeatTypography.screenTitle)
                .foregroundStyle(.white)

            Spacer(minLength: 10)

            Button {
                BeatHaptics.tap()
                appState.presentSubscription()
            } label: {
                HStack(spacing: 8) {
                    Text("Get")
                        .font(.system(size: 14, weight: .bold))

                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(BeatColors.accentBlueText)
                .padding(.horizontal, 16)
                .frame(height: horizontalSizeClass == .regular ? 52 : 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BeatColors.accentBlue)
                )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .accessibilityIdentifier("explore.getButton")

            TopActionButton(systemImage: "gift") {
                isGiftSheetPresented = true
            }
            .accessibilityIdentifier("explore.giftButton")
            TopActionButton(systemImage: "slider.horizontal.3") {
                isFiltersSheetPresented = true
            }
            .accessibilityIdentifier("explore.filterButton")
            TopActionButton(systemImage: "magnifyingglass") {
                appState.homePath.append(.search)
            }
            .accessibilityIdentifier("explore.searchButton")
        }
    }

    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        BeatHaptics.tap()
                        selectedFilter = filter
                    } label: {
                        BeatsFilterChip(title: filter, isSelected: selectedFilter == filter)
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            TabView(selection: $heroIndex) {
                ForEach(Array(heroBeats.enumerated()), id: \.element.id) { index, beat in
                    Button {
                        BeatHaptics.tap()
                        appState.homePath.append(.beatDetail(beat.result))
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(BeatColors.surfaceSecondary)
                                .overlay {
                                    heroArtwork(for: beat)
                                }
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color.black.opacity(0.82)
                                        ],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(BeatColors.thinBorder, lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(beat.result.title)
                                    .font(.system(size: horizontalSizeClass == .regular ? 34 : 28, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(beat.tagline)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BeatColors.textSecondary)

                                Text(beat.priceLabel)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .padding(horizontalSizeClass == .regular ? 24 : 20)
                        }
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                    .accessibilityIdentifier("explore.heroCard.\(index)")
                    .tag(index)
                }
            }
            .frame(height: horizontalSizeClass == .regular ? 350 : 320)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(Array(heroBeats.enumerated()), id: \.element.id) { index, beat in
                    Button {
                        BeatHaptics.tap()
                        heroIndex = index
                    } label: {
                        Capsule()
                            .fill(index == clampedHeroIndex ? Color.white : Color.white.opacity(0.24))
                            .frame(width: index == clampedHeroIndex ? 24 : 8, height: 6)
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                    .accessibilityLabel("Show \(beat.result.title)")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var featuredBeatRow: some View {
        ZStack(alignment: .leading) {
            Button {
                BeatHaptics.tap()
                appState.homePath.append(.beatDetail(featuredBeat.result))
            } label: {
                HStack(spacing: 14) {
                    Spacer()
                        .frame(width: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(featuredBeat.result.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text(featuredBeat.tagline)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    Text(featuredBeat.priceLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 92)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BeatColors.surfaceSecondary.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BeatColors.thinBorder, lineWidth: 1)
                )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .accessibilityIdentifier("explore.featuredRow")

            Button {
                togglePreview(for: featuredBeat.id)
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: previewingBeatID == featuredBeat.id ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: previewingBeatID == featuredBeat.id ? 0 : 1)
                    )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .padding(.leading, 16)
        }
    }

    private var mondayReleasesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monday Releases")
                    .font(BeatTypography.sectionTitle)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    BeatHaptics.tap()
                    appState.homePath.append(.mondayReleases(mondayReleaseBeats.map(\.result)))
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.56))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: horizontalSizeClass == .regular ? 32 : 24) {
                    ForEach(mondayReleaseBeats) { beat in
                        MondayReleaseTile(
                            beat: beat,
                            isPreviewing: previewingBeatID == beat.id,
                            onOpen: {
                                appState.homePath.append(.beatDetail(beat.result))
                            },
                            onTogglePreview: {
                                togglePreview(for: beat.id)
                            },
                            tileWidth: horizontalSizeClass == .regular ? 148 : 136
                        )
                        .accessibilityIdentifier("explore.mondayCard.\(beat.id)")
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
        }
    }

    private var trendingProducersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending Producers")
                    .font(BeatTypography.sectionTitle)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 30, height: 30)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(trendingProducers) { producer in
                        NavigationLink {
                            UserProfileView(user: producer.profileUser)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 62, height: 62)
                                    .overlay(
                                        Text(producer.initials)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    )

                                Text(producer.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(producer.tagline)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(BeatColors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: horizontalSizeClass == .regular ? 170 : 150, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(BeatColors.thinBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(BeatPressableButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func heroArtwork(for beat: ExploreBeat) -> some View {
        ZStack {
            if let artworkName = beat.result.artworkName {
                Image(artworkName)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.42)
            } else {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Image("nest_music")
                .resizable()
                .scaledToFill()
                .opacity(0.22)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.40)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var displayedBeats: [ExploreBeat] {
        let base: [ExploreBeat]
        switch selectedFilter {
        case "All Beats":
            base = allBeats
        case "Purchased":
            base = allBeats.filter { $0.priceLabel != "Free" }
        case "Favorites":
            base = [allBeats[0], allBeats[2], allBeats[3]]
        default:
            base = Array(allBeats.prefix(4))
        }

        return base.filter { beat in
            let genreMatch = selectedGenre.map { beat.result.genre.localizedCaseInsensitiveContains($0) } ?? true
            let freeMatch = !showFreeOnly || beat.priceLabel == "Free"
            return genreMatch && freeMatch
        }
    }

    private var fallbackBeat: ExploreBeat {
        allBeats[0]
    }

    private var heroBeats: [ExploreBeat] {
        let beats = Array(displayedBeats.prefix(3))
        return beats.isEmpty ? [fallbackBeat] : beats
    }

    private var clampedHeroIndex: Int {
        min(heroIndex, max(heroBeats.count - 1, 0))
    }

    private var featuredBeat: ExploreBeat {
        if displayedBeats.count > 1 {
            return displayedBeats[1]
        }
        return heroBeats[clampedHeroIndex]
    }

    private var mondayReleaseBeats: [ExploreBeat] {
        let beats = displayedBeats
        return beats.isEmpty ? Array(allBeats.prefix(4)) : beats
    }

    private func togglePreview(for beatID: String) {
        BeatHaptics.tap()

        if previewingBeatID == beatID {
            previewResetTask?.cancel()
            previewingBeatID = nil
            return
        }

        previewResetTask?.cancel()
        previewingBeatID = beatID

        previewResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            if previewingBeatID == beatID {
                previewingBeatID = nil
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MVPMainTab = .explore
    @State private var scrollToTopTokens: [MVPMainTab: Int] = [
        .explore: 0,
        .upload: 0,
        .studio: 0,
        .safe: 0
    ]

    var body: some View {
        GeometryReader { proxy in
            let isPad = proxy.size.width >= 768
            let barHeight = MVPMainTabBarMetrics.barHeight(isPad: isPad)
            let reservedBottomSpace = proxy.safeAreaInsets.bottom + barHeight + (isPad ? 28 : 22)
            let tabBarWidth = isPad ? min(520, proxy.size.width - 120) : proxy.size.width - 32

            ZStack {
                ZStack(alignment: .topLeading) {
                    shellContent(.explore)
                    shellContent(.upload)
                    shellContent(.studio)
                    shellContent(.safe)
                }
                .environment(\.tabBarClearance, reservedBottomSpace)
                .background(Color.black.ignoresSafeArea())
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(height: reservedBottomSpace)

                    MVPMainTabBar(isPad: isPad, selection: selectedTab, onSelect: handleTabSelection)
                        .frame(maxWidth: tabBarWidth)
                }
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .onAppear {
                selectedTab = localTab(for: appState.selectedTab)
            }
            .onChange(of: appState.selectedTab) { _, newValue in
                let mapped = localTab(for: newValue)
                if mapped != selectedTab {
                    selectedTab = mapped
                }
            }
        }
    }

    @ViewBuilder
    private func shellContent(_ tab: MVPMainTab) -> some View {
        tabRoot(for: tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    @ViewBuilder
    private func tabRoot(for tab: MVPMainTab) -> some View {
        switch tab {
        case .explore:
            NavigationStack(path: $appState.homePath) {
                HomeView(scrollToTopToken: scrollToTopTokens[.explore, default: 0])
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .search:
                            ExploreSearchView()
                        case .beatDetail(let result):
                            UploadResultView(model: result, sourceContext: .explore)
                        case .mondayReleases(let releases):
                            MondayReleasesView(beats: releases)
                        case .placeholder(let destination):
                            PlaceholderDetailView(destination: destination)
                        }
                    }
            }
            .accessibilityIdentifier("tab.explore")

        case .upload:
            NavigationStack(path: $appState.uploadPath) {
                UploadView(scrollToTopToken: scrollToTopTokens[.upload, default: 0])
                    .navigationDestination(for: UploadRoute.self) { route in
                        switch route {
                        case .result(let result):
                            UploadResultView(model: result, sourceContext: .upload)
                        }
                    }
            }
            .accessibilityIdentifier("tab.upload")

        case .studio:
            NavigationStack(path: $appState.profilePath) {
                ProfileView(scrollToTopToken: scrollToTopTokens[.studio, default: 0])
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .settings:
                            SettingsView()
                        case .wallet:
                            WalletView()
                        }
                    }
            }
            .accessibilityIdentifier("tab.mystudio")

        case .safe:
            NavigationStack(path: $appState.safePath) {
                SafeView(scrollToTopToken: scrollToTopTokens[.safe, default: 0])
            }
            .accessibilityIdentifier("tab.safe")
        }
    }

    private func handleTabSelection(_ tab: MVPMainTab) {
        BeatHaptics.tap()
        let mapped = appTab(for: tab)

        if selectedTab == tab {
            switch mapped {
            case .home:
                if !appState.homePath.isEmpty {
                    appState.homePath = []
                } else {
                    scrollToTopTokens[tab, default: 0] += 1
                }
            case .upload:
                if !appState.uploadPath.isEmpty {
                    appState.uploadPath = []
                } else {
                    scrollToTopTokens[tab, default: 0] += 1
                }
            case .profile:
                if !appState.profilePath.isEmpty {
                    appState.profilePath = []
                } else {
                    scrollToTopTokens[tab, default: 0] += 1
                }
            case .safe:
                if !appState.safePath.isEmpty {
                    appState.safePath = []
                } else {
                    scrollToTopTokens[tab, default: 0] += 1
                }
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            selectedTab = tab
        }
        appState.selectedTab = mapped
    }

    private func localTab(for appTab: AppTab) -> MVPMainTab {
        switch appTab {
        case .home:
            return .explore
        case .upload:
            return .upload
        case .profile:
            return .studio
        case .safe:
            return .safe
        }
    }

    private func appTab(for localTab: MVPMainTab) -> AppTab {
        switch localTab {
        case .explore:
            return .home
        case .upload:
            return .upload
        case .studio:
            return .profile
        case .safe:
            return .safe
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

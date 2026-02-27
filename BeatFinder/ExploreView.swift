import SwiftUI

// MARK: - Explore (Beats) Page
// Single-file Explore page inspired by your reference screenshot.
// Includes: top bar, pill tabs, hero carousel, sections, and bottom mini-player.

struct ExploreView: View {
    @EnvironmentObject private var settings: SettingsStore

    enum Tab: String, CaseIterable {
        case trending = "Trending"
        case allBeats = "All Beats"
        case purchased = "Purchased"
        case favorites = "Favorites"
    }

    @State private var selectedTab: Tab = .trending
    @State private var searchText: String = ""
    @State private var heroIndex: Int = 0

    @State private var nowPlaying: FeedBeat? = ExploreMockData.hero.first
    @State private var selectedBeat: FeedBeat? = nil
    @State private var showSearchSheet = false
    @State private var showPaywallSheet = false
    @State private var topBarFeedbackMessage: String?
    @State private var isMiniPlayerPlaying = false

    var body: some View {
        GeometryReader { proxy in
            let compactWidth = proxy.size.width < 360
            let heroHeight = min(max(proxy.size.height * 0.34, compactWidth ? 240 : 260), 320)
            let contentBottomPadding: CGFloat = nowPlaying == nil ? 34 : 128

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, BeatLayout.screenHorizontal)
                        .padding(.top, compactWidth ? 8 : BeatLayout.sectionSpacingTight)

                    tabs
                        .padding(.horizontal, BeatLayout.screenHorizontal)
                        .padding(.top, 10)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: BeatLayout.sectionSpacing) {
                            heroCarousel(height: heroHeight)
                                .padding(.top, 14)

                            sectionHeader("Monday Releases")

                            horizontalRail(beats: ExploreMockData.mondayReleases)

                            sectionHeader("Trending Producers")

                            producerRail(producers: ExploreMockData.producers)

                            Color.clear.frame(height: 1)
                        }
                        .padding(.horizontal, BeatLayout.screenHorizontal)
                        .padding(.bottom, contentBottomPadding)
                    }

                    if let nowPlaying {
                        miniPlayer(nowPlaying)
                            .padding(.horizontal, BeatLayout.screenHorizontal)
                            .padding(.bottom, compactWidth ? 8 : BeatLayout.sectionSpacingTight)
                    }
                }
            }
            .preferredColorScheme(settings.preferredColorScheme)
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedBeat) { beat in
                BeatResultView(model: .init(from: beat))
            }
            .sheet(isPresented: $showSearchSheet) {
                NavigationStack {
                    TextSearchView()
                }
                .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showPaywallSheet) {
                NavigationStack {
                    PaywallView()
                }
                .preferredColorScheme(settings.preferredColorScheme)
            }
            .alert("Coming soon", isPresented: Binding(
                get: { topBarFeedbackMessage != nil },
                set: { if !$0 { topBarFeedbackMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(topBarFeedbackMessage ?? "This feature is coming soon.")
            }
            .onAppear {
                isMiniPlayerPlaying = settings.autoplayPreviews
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            fullTopBar
            compactTopBar
        }
    }

    private var fullTopBar: some View {
        HStack(spacing: 12) {
            Text("Beats")
                .font(BeatTypography.screenTitle)
                .foregroundStyle(.white)

            Spacer()

            Button {
                showPaywallSheet = true
            } label: {
                HStack(spacing: 8) {
                    Text("Get")
                        .font(.system(size: 14, weight: .bold))

                    Image(systemName: "crown")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(minHeight: BeatLayout.iconButtonSize)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            AppIconButton(systemImage: "gift") {
                topBarFeedbackMessage = "Gifts are coming soon."
            }

            AppIconButton(systemImage: "slider.horizontal.3") {
                topBarFeedbackMessage = "Filters are coming soon."
            }

            AppIconButton(systemImage: "magnifyingglass") {
                showSearchSheet = true
            }
        }
    }

    private var compactTopBar: some View {
        HStack(spacing: 8) {
            Text("Beats")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            Button {
                showPaywallSheet = true
            } label: {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            Menu {
                Button("Gifts") {
                    topBarFeedbackMessage = "Gifts are coming soon."
                }

                Button("Filters") {
                    topBarFeedbackMessage = "Filters are coming soon."
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
            }

            AppIconButton(systemImage: "magnifyingglass") {
                showSearchSheet = true
            }
        }
    }

    // MARK: - Tabs

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isOn = (tab == selectedTab)

                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.45))
                        .padding(.horizontal, 14)
                        .frame(minHeight: BeatLayout.iconButtonSize)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(isOn ? 0.18 : 0.08), lineWidth: 1)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedTab = tab
                            }
                            // You can later swap data sets here.
                        }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Hero Carousel

    private func heroCarousel(height: CGFloat) -> some View {
        VStack(spacing: 10) {
            TabView(selection: $heroIndex) {
                ForEach(Array(ExploreMockData.hero.enumerated()), id: \.offset) { idx, beat in
                    ExploreHeroCard(beat: beat)
                        .tag(idx)
                        .onTapGesture {
                            nowPlaying = beat
                            selectedBeat = beat
                    }
                }
            }
            .frame(height: height)
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: ExploreMockData.hero.count, index: heroIndex)
                .padding(.top, 2)

            // Large hero bottom bar (play + title)
            if let beat = ExploreMockData.hero[safe: heroIndex] {
                HeroNowRow(beat: beat) {
                    nowPlaying = beat
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(BeatTypography.sectionTitle)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 6)
    }

    private func horizontalRail(beats: [FeedBeat]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(beats) { beat in
                    ExploreSmallBeatCard(beat: beat)
                        .onTapGesture {
                            nowPlaying = beat
                            selectedBeat = beat
                        }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func producerRail(producers: [ExploreProducer]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(producers) { p in
                    NavigationLink {
                        UserProfileView(user: p.profileUser)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 62, height: 62)
                                .overlay(
                                    Text(p.initials)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                )

                            Text(p.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(p.tagline)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Mini Player

    private func miniPlayer(_ beat: FeedBeat) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.10))

                artworkView(for: beat.artworkName)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(2)
            }
            .frame(width: 42, height: 42)
            .frame(minWidth: BeatLayout.iconButtonSize, minHeight: BeatLayout.iconButtonSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(beat.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(beat.artist)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                isMiniPlayerPlaying.toggle()
            } label: {
                Image(systemName: isMiniPlayerPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func artworkView(for name: String?) -> some View {
        Group {
            if let name, let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.06)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                    )
            }
        }
    }
}

// MARK: - Hero Card

private struct ExploreHeroCard: View {
    let beat: FeedBeat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Big artwork
            Group {
                if let name = beat.artworkName, let ui = UIImage(named: name) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Text(beat.artist.uppercased())
                            .font(.system(size: 44, weight: .black))
                            .foregroundStyle(.white.opacity(0.16))
                            .padding(.bottom, 50)
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Dark fade
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.70)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Spacer()
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct HeroNowRow: View {
    let beat: FeedBeat
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.black.opacity(0.45))
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(beat.artist)  •  \(beat.genre)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Text(beat.isFree ? "Free" : "Get")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.black.opacity(0.35))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Small Beat Card

private struct ExploreSmallBeatCard: View {
    let beat: FeedBeat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                Group {
                    if let name = beat.artworkName, let ui = UIImage(named: name) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .frame(width: 150, height: 150)

            Text(beat.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(beat.artist)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
            .frame(width: 150, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

// MARK: - Page Dots

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == index ? 26 : 8, height: 6)
                    .animation(.easeInOut(duration: 0.18), value: index)
            }
        }
    }
}

// MARK: - Mock Data

private struct ExploreProducer: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let tagline: String
    let avatarName: String?
    let followers: Int
    let following: Int

    init(
        name: String,
        handle: String? = nil,
        tagline: String,
        avatarName: String? = nil,
        followers: Int,
        following: Int
    ) {
        self.name = name
        self.handle = handle ?? name.lowercased().replacingOccurrences(of: " ", with: "")
        self.tagline = tagline
        self.avatarName = avatarName
        self.followers = followers
        self.following = following
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var tags: [String] {
        tagline
            .split(separator: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var profileUser: ProfileUser {
        ProfileUser(
            id: id,
            name: name,
            handle: handle,
            genre: tagline,
            avatarName: avatarName,
            tags: tags,
            followers: followers,
            following: following,
            beats: ExploreMockData.producerBeats(for: name)
        )
    }
}

private enum ExploreMockData {
    static let hero: [FeedBeat] = [
        FeedBeat(id: UUID(), title: "Hollow Point", artist: "Velvet", genre: "R&B & Soul", bpm: 92, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Moon Dust", artist: "Velvet", genre: "R&B & Soul", bpm: 88, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Feel Good Season", artist: "Velvet", genre: "R&B & Soul", bpm: 96, price: "Get", artworkName: nil)
    ]

    static let mondayReleases: [FeedBeat] = [
        FeedBeat(id: UUID(), title: "Night Drive", artist: "Kai", genre: "Lo-Fi", bpm: 84, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Blue Tape", artist: "Nova", genre: "Boom Bap", bpm: 90, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Amber", artist: "Sage", genre: "R&B", bpm: 98, price: "Get", artworkName: nil),
        FeedBeat(id: UUID(), title: "After Hours", artist: "Rico", genre: "Trap", bpm: 140, price: "Get", artworkName: nil)
    ]

    static let producers: [ExploreProducer] = [
        ExploreProducer(name: "Velvet", handle: "velvetloops", tagline: "R&B • Soul", followers: 48200, following: 134),
        ExploreProducer(name: "Nova", handle: "nova808", tagline: "Boom Bap", followers: 31900, following: 92),
        ExploreProducer(name: "Sage", handle: "sageloops", tagline: "Lo-Fi", followers: 17600, following: 141),
        ExploreProducer(name: "Rico", handle: "ricoatlas", tagline: "Trap", followers: 40800, following: 73),
        ExploreProducer(name: "Kai", handle: "kaidreams", tagline: "Ambient", followers: 22500, following: 116),
    ]

    static func producerBeats(for producerName: String) -> [FeedBeat] {
        let pool = hero + mondayReleases
        let matched = pool.filter { $0.artist == producerName || $0.producer == producerName }
        if !matched.isEmpty {
            return matched
        }
        return Array(pool.prefix(4))
    }
}

private extension FeedBeat {
    var isFree: Bool {
        price.lowercased() == "free" || price == "$0"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    ExploreView()
        .preferredColorScheme(.dark)
}
